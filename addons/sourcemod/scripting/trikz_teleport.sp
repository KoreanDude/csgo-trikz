#include <sdktools>
#include <trikz>
#include <shavit>
#include <colorvariables>

#pragma semicolon 1
#pragma newdecls required

char gS_CMD_Teleport[][] = {"sm_teleportto", "sm_teleport", "sm_tpto", "sm_tp"};
bool gB_request[MAXPLAYERS + 1][MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Teleport",
	author = "https://github.com/Figawe2/trikz-plugin/blob/master/scripting/trikz.sp (denwo), Smesh, https://hlmod.ru/resources/vip-aim-teleport.584/ (Grey83)",
	description = "Make able to teleport to player or teleport to view point.",
	version = "14.01.2021",
	url = "https://steamcommunity.com/id/smesh292/"
};

public void OnPluginStart()
{
	for(int i = 0; i < sizeof(gS_CMD_Teleport); i++)
	{
		RegConsoleCmd(gS_CMD_Teleport[i], Cmd_Teleport, "Teleport menu");
	}
	
	RegConsoleCmd("sm_inbox", cmd_inbox);
}

Action cmd_inbox(int client, int args)
{
	inbox(client);
}

Action inbox(int client)
{
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
		
		return Plugin_Handled;
	}
	
	Menu mMenu = new Menu(M_MenuInbox);
	mMenu.SetTitle("Teleport request inbox\n ");
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i == client || !IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
		{
			continue;
		}
		
		if(gB_request[client][i])
		{
			char sInfo[64];
			FormatEx(sInfo, sizeof(sInfo), "%i", GetClientUserId(i));
			char sDisplay[64];
			GetClientName(i, sDisplay, sizeof(sDisplay));
			mMenu.AddItem(sInfo, sDisplay);
		}
	}
	
	if(mMenu.ItemCount == 0)
	{
		Cmd_Teleport(client, 0);
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Inbox is empty!");
		
		return Plugin_Handled;
	}
	
	mMenu.ExitBackButton = true;
	mMenu.ExitButton = true;
	mMenu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int M_MenuInbox(Menu oldmenu, MenuAction action, int param1, int param2)
{
	if(!param1 || !IsValidClient(param1))
	{
		return view_as<int>(Plugin_Handled);
	}
	
	switch(action)
	{
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_ExitBack:
				{
					FakeClientCommand(param1, "sm_trikz");
				}
			}
		}
	}
	
	char sInfo[32];
	
	if(!GetMenuItem(oldmenu, param2, sInfo, sizeof(sInfo)))
	{
		return view_as<int>(Plugin_Handled);
	}
	
	if(!IsPlayerAlive(param1))
	{
		CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
		
		return view_as<int>(Plugin_Handled);
	}
	
	int sender = GetClientOfUserId(StringToInt(sInfo));
	
	if(!sender)
	{
		return view_as<int>(Plugin_Handled);
	}
	
	/*if(Shavit_GetTimerStatus(param1) == Timer_Running)
	{
		OpenStopWarningMenu(param1);
		
		return view_as<int>(Plugin_Continue);
	}
	
	else*/
	{
		char sDisplay[64];
		GetClientName(sender, sDisplay, sizeof(sDisplay));
		
		Menu menu = new Menu(H_TeleportMenu_Confirm);
		menu.SetTitle("%s wants to teleport to you! Do you accept?\n ", sDisplay);
		FormatEx(sInfo, sizeof(sInfo), "%i", GetClientUserId(sender));
		menu.AddItem(sInfo, "Agree\n ");
		menu.AddItem(sInfo, "Decline");
		menu.ExitButton = false;
		
		if(IsPlayerAlive(param1))
		{
			menu.Display(param1, MENU_TIME_FOREVER);
		}
		
		else
		{
			GetClientName(sender, sDisplay, sizeof(sDisplay));
			CPrintToChat(param1, "{green}[Trikz]{lime} %s {lightgreen}should be alive to teleport to him/her.", sDisplay);
		}
	}
	
	return view_as<int>(Plugin_Continue);
}

public void OnClientDisconnect(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		gB_request[i][client] = false;
	}
}

Action Cmd_Teleport(int client, int args)
{
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
		
		return Plugin_Handled;
	}
	
	Menu menu = new Menu(H_TeleportMenu);
	menu.SetTitle("Teleport menu\n ");
	menu.AddItem("aim_tp", "Aim teleport");
	
	bool bOnceCircle = false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
		{
			continue;
		}
		
		if(!bOnceCircle && i != client && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			menu.AddItem("inbox", "Your inbox\n \nActive player list:\n ");
			bOnceCircle = true;
		}
	}
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!bOnceCircle && i == client && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			menu.AddItem("inbox", "Your inbox\n ");
			bOnceCircle = true;
		}
	}
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i == client || !IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
		{
			continue;
		}
		
		char sInfo[64];
		FormatEx(sInfo, sizeof(sInfo), "%i", GetClientUserId(i));
		char sDisplay[64];
		GetClientName(i, sDisplay, sizeof(sDisplay));
		menu.AddItem(sInfo, sDisplay);
	}
	
	if(menu.ItemCount == 0)
	{
		FakeClientCommand(client, "sm_trikz");
		CPrintToChat(client, "{green}[Trikz]{lightgreen} No alive players that you could teleport to!");
		
		return Plugin_Handled;
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int H_TeleportMenu(Menu oldmenu, MenuAction action, int param1, int param2)
{
	if(!param1 || !IsValidClient(param1))
	{
		return view_as<int>(Plugin_Handled);
	}
	
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[64];
			oldmenu.GetItem(param2, sItem, sizeof(sItem));
			
			if(StrEqual(sItem, "inbox"))
			{
				if(!IsPlayerAlive(param1))
				{
					FakeClientCommand(param1, "sm_t");
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
				}
				
				else
				{
					inbox(param1);
				}
				
				return view_as<int>(Plugin_Continue);
			}
			
			if(StrEqual(sItem, "aim_tp"))
			{
				if(!IsPlayerAlive(param1))
				{
					FakeClientCommand(param1, "sm_t");
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
				}
				
				else
				{
					TeleportClient(param1);
					Cmd_Teleport(param1, 0);
				}
			}
		}
		
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_ExitBack:
				{
					FakeClientCommand(param1, "sm_trikz");
				}
			}
		}
	}
	
	char sInfo[32];
	
	if(!GetMenuItem(oldmenu, param2, sInfo, sizeof(sInfo)))
	{
		return view_as<int>(Plugin_Handled);
	}
	
	if(!IsPlayerAlive(param1))
	{
		CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
		
		return view_as<int>(Plugin_Handled);
	}
	
	int reciever = GetClientOfUserId(StringToInt(sInfo));
	
	if(!reciever)
	{
		return view_as<int>(Plugin_Handled);
	}
	
	gB_request[reciever][param1] = true;
	CPrintToChat(reciever, "{green}[Trikz]{lime} %N {lightgreen}wants to teleport to you.", param1);
	
	/*if(Shavit_GetTimerStatus(param1) == Timer_Running)
	{
		OpenStopWarningMenu(param1);
		
		return view_as<int>(Plugin_Continue);
	}
	
	else
	{
		char sDisplay[64];
		GetClientName(param1, sDisplay, sizeof(sDisplay));
		
		Menu menu = new Menu(H_TeleportMenu_Confirm);
		menu.SetTitle("%s wants to teleport to you! Do you accept?\n ", sDisplay);
		FormatEx(sInfo, sizeof(sInfo), "%i", GetClientUserId(param1));
		menu.AddItem(sInfo, "Agree\n ");
		menu.AddItem(sInfo, "Decline");
		menu.ExitButton = false;
		
		if(IsPlayerAlive(reciever))
		{
			menu.Display(reciever, MENU_TIME_FOREVER);
		}
		
		else
		{
			GetClientName(reciever, sDisplay, sizeof(sDisplay));
			CPrintToChat(param1, "{green}[Trikz]{lime} %s {lightgreen}should be alive to teleport to him/her.", sDisplay);
		}
	}*/
	
	return view_as<int>(Plugin_Continue);
}

/*void OpenStopWarningMenu(int client)
{
	Menu hMenu = new Menu(MenuHandler_StopWarning);
	hMenu.SetTitle("Would you like to stop timer?\n ");
	hMenu.AddItem("yes", "Yes\n ");
	hMenu.AddItem("no", "No");
	hMenu.ExitButton = false;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_StopWarning(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if(StrEqual(sInfo, "yes"))
		{
			Shavit_StopTimer(param1);
			Cmd_Teleport(param1, 1);
			
			if(Trikz_FindPartner(param1) != -1)
			{
				Shavit_StopTimer(Trikz_FindPartner(param1));
			}
		}
		
		else if(StrEqual(sInfo, "no"))
		{
			Cmd_Teleport(param1, 1);
		}
	}

	return view_as<int>(Plugin_Continue);
}*/

int H_TeleportMenu_Confirm(Menu menu, MenuAction action, int param1, int param2)
{
	if(!param1 || !IsValidClient(param1))
	{
		return;
	}
	
	char sInfo[32];
	
	if(!GetMenuItem(menu, param2, sInfo, sizeof(sInfo)))
	{
		return;
	}
	
	int sender = GetClientOfUserId(StringToInt(sInfo));
	GetClientName(sender, sInfo, sizeof(sInfo));
	
	if(!sender || IsFakeClient(param1))
	{
		return;
	}
	
	gB_request[param1][sender] = false;
	
	char sDisplay[64];
	GetClientName(param1, sDisplay, sizeof(sDisplay));
	
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
				{					
					Shavit_StopTimer(sender);
					
					if(Trikz_FindPartner(sender) != -1)
					{
						if(Shavit_GetClientTrack(Trikz_FindPartner(sender)) != Track_Solobonus)
						{
							Shavit_StopTimer(Trikz_FindPartner(sender));
						}
					}
					
					if(Shavit_GetClientTrack(param1) != Track_Solobonus)
					{
						if(GetEntProp(param1, Prop_Data, "m_CollisionGroup") == 5)
						{
							SetEntProp(param1, Prop_Data, "m_CollisionGroup", 2);
							SetEntityRenderMode(param1, RENDER_TRANSALPHA);
							SetEntityRenderColor(param1, 255, 255, 255, 75);
							CreateTimer(2.0, EnableBlockAfterTpto, param1);
						}
					}
					
					if(Shavit_GetClientTrack(sender) != Track_Solobonus)
					{
						if(GetEntProp(sender, Prop_Data, "m_CollisionGroup") == 5)
						{
							SetEntProp(sender, Prop_Data, "m_CollisionGroup", 2);
							SetEntityRenderMode(sender, RENDER_TRANSALPHA);
							SetEntityRenderColor(sender, 255, 255, 255, 75);
							CreateTimer(2.0, EnableBlockAfterTpto, sender);
						}
					}
					
					float origin[3];
					GetEntPropVector(param1, Prop_Send, "m_vecOrigin", origin);
					TeleportEntity(sender, origin, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
					
					CPrintToChat(sender, "{green}[Trikz]{lightgreen} You teleported to {lime}%s{default}.", sDisplay);
					CPrintToChat(param1, "{green}[Trikz]{lime} %s{lightgreen} teleported to you.", sInfo);
				}
				
				case 1:
				{
					CPrintToChat(sender, "{green}[Trikz]{lightgreen} Your teleportation request to {lime}%s {default}is declined.", sDisplay);
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You have denied a teleportation request from {lime}%s{default}.", sInfo);
				}
			}
		}
	}
}

Action EnableBlockAfterTpto(Handle timer, int client)
{
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
	SetEntityRenderMode(client, RENDER_NORMAL);
}

//https://hlmod.ru/resources/vip-aim-teleport.584/
void TeleportClient(int client)
{
	if(!IsPlayerAlive(client))
	{
		return;
	}

	float ang[3];
	float pos[3];
	float vec[3];
	float start[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, ang);

	Handle trace = TR_TraceRayFilterEx(pos, ang, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(start, trace);
		GetVectorDistance(pos, start, false);
		GetAngleVectors(ang, vec, NULL_VECTOR, NULL_VECTOR);
		start[0] -= 35 * vec[0];
		start[1] -= 35 * vec[1];
		start[2] -= 35 * vec[2];
		GetClientAbsOrigin(client, pos);
		Shavit_StopTimer(client);
		if(Trikz_FindPartner(client) != -1 && Shavit_GetClientTrack(Trikz_FindPartner(client)) != Track_Solobonus)
			Shavit_StopTimer(Trikz_FindPartner(client));
		TeleportEntity(client, start, NULL_VECTOR, NULL_VECTOR);
		GetClientMins(client, vec);
		GetClientMaxs(client, ang);
		TR_TraceHullFilter(start, start, vec, ang, MASK_PLAYERSOLID, TraceEntityFilterPlayer, client);
		
		if(TR_DidHit())
		{
			CloseHandle(trace);
			TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
			
			return;
		}

		if(GetEntProp(client, Prop_Data, "m_CollisionGroup") > 0)
		{
			SetEntProp(client, Prop_Data, "m_CollisionGroup", 17);
			CreateTimer(3.0, OffNoBlockPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	CloseHandle(trace);
}

Action OffNoBlockPlayer(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) && IsPlayerAlive(client))
	{
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
	}
}

bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}
