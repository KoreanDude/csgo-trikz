#include <sdktools>
#include <sdkhooks>
#include <trikz>
#include <shavit>
#include <colorvariables>

#pragma semicolon 1
#pragma newdecls required

char gS_CMD_Trikz[][] = {"sm_t", "sm_trikz", "sm_menu"};
int gI_partner[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Trikz menu",
	author = "Smesh",
	description = "",
	version = "17.11.2020",
	url = ""
}

public void OnPluginStart()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}
	
	for(int i = 0; i < sizeof(gS_CMD_Trikz); i++)
	{
		RegConsoleCmd(gS_CMD_Trikz[i], Command_Trikz, "Trikz menu");
	}
}

public void OnClientPutInServer(int client)
{
	if(IsValidClient(client))
	{
		gI_partner[client] = -1;
	}
}

public void OnClientDisconnect(int client)
{
	if(IsClientInGame(client))
	{
		if(gI_partner[client] != -1)
		{
			gI_partner[gI_partner[client]] = -1;
		}
		
		gI_partner[client] = -1;
	}
}

Action Command_Trikz(int client, int args)
{
	if(IsValidClient(client))
	{
		TrikzMenu(client); //Open trikz menu
	}
	
	return Plugin_Handled;
}

void TrikzMenu(int client)
{
	Menu menu = new Menu(Trikz_MenuHandler);
	menu.SetTitle("Trikz menu\n ");
	menu.AddItem("sm_equipment", "Equipments");
	menu.AddItem("sm_block", "Blocking\n ");
	menu.AddItem("sm_cp", "Checkpoints");
	menu.AddItem("sm_tp", "Teleport\n ");
	menu.AddItem("sm_nc", "Noclip\n");
	gI_partner[client] = Trikz_FindPartner(client);
	char sDisplay[32];
	FormatEx(sDisplay, sizeof(sDisplay), "%s", (gI_partner[client] != -1) ? "Cancel partnership" : "Select partner");
	char sInfo[32];
	FormatEx(sInfo, sizeof(sInfo), "%s", (gI_partner[client] != -1) ? "sm_cancelpartner" : "sm_trikzpartner");
	menu.AddItem(sInfo, sDisplay);
	menu.AddItem("sm_stats", "Statistics");
	menu.Pagination = MENU_NO_PAGINATION;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Trikz_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[64];
			menu.GetItem(param2, sItem, sizeof(sItem));
			
			if(StrEqual(sItem, "sm_equipment"))
			{
				if(!IsPlayerAlive(param1))
				{
					TrikzMenu(param1);
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
				}
				
				else
				{
					FakeClientCommandEx(param1, "sm_equipment");
				}
				
				return view_as<int>(Plugin_Continue);
			}
			
			if(StrEqual(sItem, "sm_block"))
			{
				FakeClientCommandEx(param1, "sm_block");
			}
			
			if(StrEqual(sItem, "sm_cp"))
			{
				FakeClientCommandEx(param1, "sm_cp");
				
				return view_as<int>(Plugin_Continue);
			}
			
			if(StrEqual(sItem, "sm_tp"))
			{
				if(!IsPlayerAlive(param1))
				{
					TrikzMenu(param1);
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
				}
				
				else
				{
					FakeClientCommandEx(param1, "sm_tp");
				}
				
				return view_as<int>(Plugin_Continue);
			}
			
			if(StrEqual(sItem, "sm_nc"))
			{
				ClientCommand(param1, "sm_nc");
			}
			
			if(StrEqual(sItem, "sm_cancelpartner"))
			{
				FakeClientCommandEx(param1, "sm_unpartner");
				
				return view_as<int>(Plugin_Continue);
			}
			
			if(StrEqual(sItem, "sm_trikzpartner"))
			{
				if(!IsPlayerAlive(param1))
				{
					TrikzMenu(param1);
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
				}
				
				else
				{
					FakeClientCommandEx(param1, "sm_partner");
				}
				
				return view_as<int>(Plugin_Continue);
			}
			
			if(StrEqual(sItem, "sm_stats"))
			{
				FakeClientCommandEx(param1, "sm_stats");
				
				return view_as<int>(Plugin_Continue);
			}
			
			TrikzMenu(param1);
		}
		
		case MenuAction_DisplayItem:
		{
			char sInfo[64];
			char sDisplay[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			
			if(StrEqual(sInfo, "sm_cancelpartner"))
			{
				FormatEx(sDisplay, sizeof(sDisplay), "Cancel partnership");
				
				return RedrawMenuItem(sDisplay);
			}
			
			if(StrEqual(sInfo, "sm_trikzpartner"))
			{
				FormatEx(sDisplay, sizeof(sDisplay), "Select partner");
				
				return RedrawMenuItem(sDisplay);
			}
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return view_as<int>(Plugin_Continue);
}
