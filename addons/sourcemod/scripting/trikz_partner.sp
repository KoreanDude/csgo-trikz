#include <trikz>
#include <shavit>
#include <colorvariables>

#pragma semicolon 1
#pragma newdecls required

char gS_CMD_Partner[][] = {"sm_p", "sm_partner", "sm_mate"};
char gS_CMD_UnPartner[][] = {"sm_unp", "sm_unpartner", "sm_nomate"};
int gI_Partner[MAXPLAYERS + 1] = {-1, ...};

// forwards
Handle gH_Forwards_OnPartner = null;
Handle gH_Forwards_OnBreakPartner = null;

public Plugin myinfo =
{
	name = "Partner system",
	author = "shavit (trikz redux), modified by Smesh, SHIM",
	description = "Make able to be as partner for mate.",
	version = "14.01.2021",
	url = "https://steamcommunity.com/id/smesh292/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//CreateNative("Trikz_HasPartner", Native_HasPartner);
	CreateNative("Trikz_FindPartner", Native_FindPartner);
	//CreateNative("Trikz_UnPartner", Native_UnPartner);
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	
	for(int i = 0; i < sizeof(gS_CMD_Partner); i++)
	{
		RegConsoleCmd(gS_CMD_Partner[i], Command_Partner, "Select your partner.");
	}
	
	for(int i = 0; i < sizeof(gS_CMD_UnPartner); i++)
	{
		RegConsoleCmd(gS_CMD_UnPartner[i], Command_UnPartner, "Disable your partnership.");
	}
	
	// forwards
	gH_Forwards_OnPartner = CreateGlobalForward("Trikz_OnPartner", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnBreakPartner = CreateGlobalForward("Trikz_OnBreakPartner", ET_Event, Param_Cell, Param_Cell);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	int iPartner = gI_Partner[client];
	
	if(gI_Partner[client] != -1 && gI_Partner[iPartner] != -1)
	{
		Call_StartForward(gH_Forwards_OnBreakPartner);
		Call_PushCell(client);
		Call_PushCell(iPartner);
		Call_Finish();
		
		gI_Partner[client] = -1;
		gI_Partner[iPartner] = -1;
		
		if(Shavit_GetTimerStatus(client) == Timer_Running)
		{
			Shavit_StopTimer(client);
			Shavit_StopTimer(iPartner);
		}
	}
}

public void Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data)
{
	if((type == Zone_Start || type == Zone_End) && track == Track_Solobonus)
	{
		int iPartner = gI_Partner[client];
		
		if(gI_Partner[client] != -1 && gI_Partner[iPartner] != -1)
		{
			Call_StartForward(gH_Forwards_OnBreakPartner);
			Call_PushCell(client);
			Call_PushCell(iPartner);
			Call_Finish();
			
			gI_Partner[client] = -1;
			gI_Partner[iPartner] = -1;
			
			if(Shavit_GetTimerStatus(client) == Timer_Running)
			{
				Shavit_StopTimer(client);
				Shavit_StopTimer(iPartner);
			}
		}
	}
}

public void OnClientDisconnect(int client)
{
	if(IsClientInGame(client) || !IsFakeClient(client))
	{
		int iPartner = gI_Partner[client];
		
		if(iPartner != -1)
		{
			Call_StartForward(gH_Forwards_OnBreakPartner);
			Call_PushCell(client);
			Call_PushCell(iPartner);
			Call_Finish();
			
			if(Shavit_GetTimerStatus(client) == Timer_Running)
			{
				Shavit_StopTimer(iPartner);
				
				Shavit_PrintToChat(client, "Timer has been stopped while disconnecting.");
				Shavit_PrintToChat(iPartner, "Timer has been stopped while your partner disconnecting.");
			}
			
			gI_Partner[gI_Partner[client]] = -1;
			gI_Partner[client] = -1;
		}
	}
}

Action Command_Partner(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
		
		return Plugin_Handled;
	}
	
	if(gI_Partner[client] != -1)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} You already have a partner.");
		
		return Plugin_Handled;
	}
	
	PartnerMenu(client);
	
	return Plugin_Handled;
}

void PartnerMenu(int client)
{
	Menu menu = new Menu(PartnerAsk_MenuHandler);
	menu.SetTitle("Select your partner:\n ");
	
	char sDisplay[MAX_NAME_LENGTH];
	char sClientID[8];
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
		{
			continue;
		}
		
		if(IsValidClient(i, true) && !IsFakeClient(i) && !IsClientSourceTV(i) && gI_Partner[i] == -1)
		{
			GetClientName(i, sDisplay, MAX_NAME_LENGTH);
			ReplaceString(sDisplay, MAX_NAME_LENGTH, "#", "?");
			IntToString(i, sClientID, sizeof(sClientID));
			menu.AddItem(sClientID, sDisplay);
		}
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	
	if(menu.ItemCount > 0)
	{
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	
	else
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} No partners are available.");
		
		delete menu;
	}
}

int PartnerAsk_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{	
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			int client = StringToInt(info);
			
			if(IsValidClient(client, true) && IsValidClient(param1, true) && gI_Partner[client] == -1)
			{
				Menu menuask = new Menu(Partner_MenuHandler);
				menuask.SetTitle("%N wants to be your partner\n ", param1);
				char sDisplay[32];
				char sMenuInfo[32];
				IntToString(param1, sMenuInfo, sizeof(sMenuInfo));
				FormatEx(sDisplay, MAX_NAME_LENGTH, "Accept");
				menuask.AddItem(sMenuInfo, "Accept\n ");
				FormatEx(sDisplay, MAX_NAME_LENGTH, "Deny");
				menuask.AddItem(sMenuInfo, "Deny");
				menuask.ExitButton = false;
				menuask.Display(client, MENU_TIME_FOREVER);
			}
			
			else if(gI_Partner[client] != -1)
			{
				CPrintToChat(client, "{green}[Trikz]{lime} %N {lightgreen}wants to be your partner.", param1);
			}
		}
		
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				FakeClientCommand(param1, "sm_trikz");
			}
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

int Partner_MenuHandler(Menu menuask, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menuask.GetItem(param2, info, sizeof(info));
			
			int client = StringToInt(info);
			
			if(gI_Partner[client] == -1)
			{
				switch(param2)
				{
					case 0:
					{
						gI_Partner[client] = param1; //partner = param1
						gI_Partner[param1] = client; //client = client
						
						Call_StartForward(gH_Forwards_OnPartner);
						Call_PushCell(client);
						Call_PushCell(param1);
						Call_Finish();
						
						/*if(gI_Partner[client] != -1 && gI_Partner[param1] != -1)
						{
							Shavit_SetClientTrack(client, Track_Main);
							Shavit_SetClientTrack(param1, Track_Main);
						}*/
						
						if((Shavit_GetClientTrack(param1) == Track_Main || Shavit_GetClientTrack(param1) == Track_Bonus) 
							&& (Shavit_GetClientTrack(client) == Track_Main || Shavit_GetClientTrack(client) == Track_Bonus))
						{
							if(IsPlayerAlive(client))
							{
								SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
								SetEntityRenderMode(client, RENDER_NORMAL);
							}
							
							if(IsPlayerAlive(param1))
							{
								SetEntProp(param1, Prop_Data, "m_CollisionGroup", 5);
								SetEntityRenderMode(param1, RENDER_NORMAL);
							}
						}
						
						CPrintToChat(client, "{green}[Trikz]{lime} %N {lightgreen}has accepted your partnership request.", param1);
						CPrintToChat(param1, "{green}[Trikz]{lightgreen} You accepted partnership request with {lime}%N.", client);
					}
					
					case 1:
					{
						CPrintToChat(client, "{green}[Trikz]{lime} %N {lightgreen}has denied your partnership request.", param1);
						CPrintToChat(param1, "{green}[Trikz]{lightgreen} You denied partnership request with {lime}%N.", client);
					}
				}
			}
			
			else
			{
				CPrintToChat(param1, "{green}[Trikz]{lime} %N {lightgreen} already have a partner.", client);
			}
		}
		
		case MenuAction_End:
		{
			delete menuask;
		}
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!IsPlayerAlive(client) && GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_USE)
	{
		int nObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		int nObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	
		if(4 <= nObserverMode <= 6 && !IsFakeClient(nObserverTarget))
		{
			int iPartner = Trikz_FindPartner(nObserverTarget);
			
			if(iPartner != -1)
			{
				SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iPartner);
			}
		}
	}
}

Action Command_UnPartner(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(gI_Partner[client] == -1)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} You need a partner to cancel your partnership with the current one.");
		
		return Plugin_Handled;
	}
	
	UnPartnerMenu(client);
	
	return Plugin_Handled;
}

void UnPartnerMenu(int client)
{
	Menu menu = new Menu(UnPartnerAsk_MenuHandler);
	menu.SetTitle("Do you want to cancel your partnership with %N\n ", gI_Partner[client]);
	menu.AddItem("sm_accept", "Accept\n ");
	menu.AddItem("sm_deny", "Deny");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int UnPartnerAsk_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if(StrEqual(info, "sm_accept"))
			{
				int iPartner = gI_Partner[param1];
				
				if(gI_Partner[param1] != -1 && gI_Partner[iPartner] != -1)
				{
					gI_Partner[param1] = -1; //client
					gI_Partner[iPartner] = -1; //partner
					Call_StartForward(gH_Forwards_OnBreakPartner);
					Call_PushCell(param1);
					Call_PushCell(iPartner);
					Call_Finish();
					Shavit_StopTimer(param1);
					Shavit_StopTimer(iPartner);
					CPrintToChat(param1, "{green}[Trikz]{lime} %N {lightgreen}is not your partner anymore.", iPartner);
					CPrintToChat(iPartner, "{green}[Trikz]{lime} %N {lightgreen}has disabled his partnership with you.", param1);
				}
				
				else if(gI_Partner[param1] == -1)
				{
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You don't have partner anymore.");
				}
			}
			
			if(StrEqual(info, "sm_deny"))
			{
				if(gI_Partner[param1] == -1)
				{
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You don't have partner anymore.");
				}
			}
		}
		
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				FakeClientCommand(param1, "sm_trikz");
			}
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

/*int Native_HasPartner(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	
	if(!IsValidClient(client))
	{
		ThrowError("Player index %d is invalid.", client);

		return -1;
	}
	
	return view_as<int>(gI_Partner[client] != -1);
}*/

int Native_FindPartner(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	
	if(!IsValidClient(client))
	{
		ThrowError("Player index %d is invalid.", client);

		return -1;
	}

	if(gI_Partner[client] != -1 && client == gI_Partner[gI_Partner[client]])
	{
		return gI_Partner[client];
	}
	
	return -1;
}

/*int Native_UnPartner(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int partner = gI_Partner[client];
	
	if(!IsValidClient(client))
	{
		ThrowError("Player index %d is invalid.", client);

		return -1;
	}

	if(partner != -1 && client == gI_Partner[partner])
	{
		gI_Partner[partner] = -1;
		gI_Partner[client] = -1;
		
		CPrintToChat(client, "{green}[Trikz]{lime} %N {lightgreen}is not your partner anymore.", partner);
		CPrintToChat(partner, "{green}[Trikz]{lime} %N {lightgreen}has disabled his partnership with you.", client);
		
		return partner;
	}

	return -1;
}*/
