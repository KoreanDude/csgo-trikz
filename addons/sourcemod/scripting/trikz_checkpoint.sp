#include <sdktools>
#include <trikz>
#include <shavit>
#include <colorvariables>

#pragma semicolon 1
#pragma newdecls required

char gS_checkpoint[][] = {"sm_checkpoints", "sm_checkpoint", "sm_cpmenu", "sm_cp"};
//Thanks to https://github.com/Figawe2/trikz-plugin
float gF_checkpoint[MAXPLAYERS + 1][2][3][3];
bool gB_restore[MAXPLAYERS + 1][2];
bool gB_checkpoint[MAXPLAYERS + 1][3];
bool gB_IsCPLoaded;
float gF_autocheckpoint[MAXPLAYERS + 1][3][3];

float gF_checkpoint_command[MAXPLAYERS + 1][256][3][3];
bool gB_checkpoint_command[MAXPLAYERS + 1][256];
bool gB_NotCommand[MAXPLAYERS + 1] = false;
int cpnumber_command[MAXPLAYERS + 1] = 0;

public Plugin myinfo =
{
	name = "Checkpoints",
	author = "https://github.com/Figawe2/trikz-plugin (denwo), modified by Smesh, SHIM",
	description = "Make able to use checkpoints.",
	version = "14.01.2021",
	url = "https://steamcommunity.com/id/smesh292/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Trikz_LoadCP", Native_LoadCP);
	
	return APLRes_Success;
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
	
	for(int i = 0; i < sizeof(gS_checkpoint); i++)
	{
		RegConsoleCmd(gS_checkpoint[i], Cmd_Checkpoint, "Checkpoints menu");
	}
	
	RegConsoleCmd("sm_save", Command_Save);
	RegConsoleCmd("sm_tel", Command_Teleport);
	RegConsoleCmd("sm_tele", Command_Teleport);
}

public void OnClientPutInServer(int client)
{
	if(IsValidClient(client))
	{
		for(int i = 0; i < 2; i++)
		{
			gB_restore[client][i] = true;
		}
		
		for(int i = 0; i < 3; i++)
		{
			gB_checkpoint[client][i] = false;
		}
	}
	cpnumber_command[client] = 0;
}

public void Trikz_OnBoost(int client)
{
	if(IsValidClient(client) || IsPlayerAlive(client))
	{
		float origin[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
		gF_autocheckpoint[client][0] = origin;
		float angles[3];
		GetClientEyeAngles(client, angles);
		gF_autocheckpoint[client][1] = angles;
		float velocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
		gF_autocheckpoint[client][2] = velocity;
		gB_checkpoint[client][2] = true;
	}
}

Action Command_Save(int client, int args)
{
	float origin[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
	float angles[3];
	GetClientEyeAngles(client, angles);
	float velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
	cpnumber_command[client] += 1;
	gF_checkpoint_command[client][cpnumber_command[client]][0] = origin;
	gF_checkpoint_command[client][cpnumber_command[client]][1] = angles;
	gF_checkpoint_command[client][cpnumber_command[client]][2] = velocity;
	gB_checkpoint_command[client][cpnumber_command[client]] = true;
	
	CPrintToChat(client, "{green}[Trikz]{lightgreen} Saved {lime}#%i", cpnumber_command[client]);
}

Action Command_Teleport(int client, int args)
{
	if (args < 1)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Usage: sm_tel or sm_tele <number>");
		return Plugin_Handled;
	}
	
	char sArg[6];
	GetCmdArg(1, sArg, sizeof(sArg));
	int cpnum = StringToInt(sArg);
	cpnumber_command[client] = cpnum;
	
	if(IsValidClient(client))
	{
		if(gB_checkpoint_command[client][cpnumber_command[client]])
		{
			if(Shavit_GetTimerStatus(client) == Timer_Running)
			{
				OpenStopWarningMenu(client);
				gB_NotCommand[client] = false;
			}
			else
			{
				LoadCP_command(client);
			}
		}
	}
	
	return Plugin_Handled;
}


Action Cmd_Checkpoint(int client, int args)
{
	Menu menu = new Menu(H_CheckpointPanel);
	menu.SetTitle("Checkpoints Menu\n ");
	menu.AddItem("save1", "Save Checkpoint 1");
	menu.AddItem("load1", "Load Checkpoint 1\n ", gB_checkpoint[client][0] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.AddItem("save2", "Save Checkpoint 2");
	menu.AddItem("load2", "Load Checkpoint 2\n ", gB_checkpoint[client][1] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.AddItem("loadautocp", "Load Auto-CP\n ");
	char sDisplay[64];
	FormatEx(sDisplay, sizeof(sDisplay), "Restore Angles [%s]", gB_restore[client][0] ? "ON" : "OFF");
	menu.AddItem("restoreang", sDisplay);
	FormatEx(sDisplay, sizeof(sDisplay), "Restore Velocity [%s]\n ", gB_restore[client][1] ? "ON" : "OFF");
	menu.AddItem("restorevel", sDisplay);
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int H_CheckpointPanel(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[64];
			menu.GetItem(param2, sItem, sizeof(sItem));
			
			if(StrEqual(sItem, "save1"))
			{
				SaveCP(param1, 1);
			}
			
			if(StrEqual(sItem, "load1"))
			{
				if(!IsPlayerAlive(param1))
				{
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
				}
				
				if(Shavit_GetTimerStatus(param1) == Timer_Running)
				{
					OpenStopWarningMenu(param1);
					gB_NotCommand[param1] = true;
					return view_as<int>(Plugin_Continue);
				}
				
				else
				{
					LoadCP(param1, 1);
				}
			}
			
			if(StrEqual(sItem, "save2"))
			{
				SaveCP(param1, 2);
			}
			
			if(StrEqual(sItem, "load2"))
			{
				if(!IsPlayerAlive(param1))
				{
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
				}
				
				if(Shavit_GetTimerStatus(param1) == Timer_Running)
				{
					OpenStopWarningMenu(param1);
					gB_NotCommand[param1] = true;
					return view_as<int>(Plugin_Continue);
				}
				
				else
				{
					LoadCP(param1, 2);
				}
			}
			
			if(StrEqual(sItem, "loadautocp"))
			{
				if(!IsPlayerAlive(param1))
				{
					CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
				}
				
				if(Shavit_GetTimerStatus(param1) == Timer_Running)
				{
					OpenStopWarningMenu(param1);
					gB_NotCommand[param1] = true;
					return view_as<int>(Plugin_Continue);
				}
				
				else
				{
					bool b[2];
					b[0] = gB_restore[param1][0];
					b[1] = gB_restore[param1][1];
					float origin[3];
					origin = gF_autocheckpoint[param1][0];
					float angles[3];
					angles = gF_autocheckpoint[param1][1];
					float velocity[3];
					velocity = gF_autocheckpoint[param1][2];
					
					if(gB_checkpoint[param1][2])
					{
						if(b[0] && b[1])
						{
							TeleportEntity(param1, origin, angles, velocity);
						}
						
						if(!b[0] && b[1])
						{		
							TeleportEntity(param1, origin, NULL_VECTOR, velocity);
						}
						
						if(b[0] && !b[1])
						{		
							TeleportEntity(param1, origin, angles, view_as<float>({0.0, 0.0, 0.0}));
						}
						
						if(!b[0] && !b[1])
						{	
							TeleportEntity(param1, origin, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
						}
					}
					
					else
					{
						CPrintToChat(param1, "{green}[Trikz]{lightgreen} You must get nade boost to use this feature!");
					}
				}
			}
			
			if(StrEqual(sItem, "restoreang"))
			{
				gB_restore[param1][0] = !gB_restore[param1][0];
			}
			
			if(StrEqual(sItem, "restorevel"))
			{
				gB_restore[param1][1] = !gB_restore[param1][1];
			}
			
			Cmd_Checkpoint(param1, 1);
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
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return view_as<int>(Plugin_Continue);
}

int SaveCP(int client, int cpnumber)
{
	if(IsValidClient(client) || cpnumber || IsPlayerAlive(client))
	{
		float origin[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
		float angles[3];
		GetClientEyeAngles(client, angles);
		float velocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
		cpnumber = cpnumber - 1;
		gF_checkpoint[client][cpnumber][0] = origin;
		gF_checkpoint[client][cpnumber][1] = angles;
		gF_checkpoint[client][cpnumber][2] = velocity;
		gB_checkpoint[client][cpnumber] = true;
	}
}

void OpenStopWarningMenu(int client)
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
			
			if(gB_NotCommand[param1])
			{
				Cmd_Checkpoint(param1, 1);
				gB_NotCommand[param1] = false;
			}
			
			if(Trikz_FindPartner(param1) != -1)
			{
				Shavit_StopTimer(Trikz_FindPartner(param1));
			}
		}
		
		else if(StrEqual(sInfo, "no"))
		{
			if(gB_NotCommand[param1])
			{
				Cmd_Checkpoint(param1, 1);
				gB_NotCommand[param1] = false;
			}
		}
	}

	return view_as<int>(Plugin_Continue);
}
 
int LoadCP(int client, int cpnumber)
{
	if(IsValidClient(client) || cpnumber)
	{
		cpnumber = cpnumber - 1;
		
		if(gB_checkpoint[client][cpnumber])
		{
			float origin[3];
			origin = gF_checkpoint[client][cpnumber][0];
			float angles[3];
			angles = gF_checkpoint[client][cpnumber][1];
			float velocity[3];
			velocity = gF_checkpoint[client][cpnumber][2];
			bool b[2];
			b[0] = gB_restore[client][0];
			b[1] = gB_restore[client][1];
			gB_IsCPLoaded = true;
			
			if(b[0] && b[1])
			{		
				TeleportEntity(client, origin, angles, velocity);
			}
			
			if(!b[0] && b[1])
			{		
				TeleportEntity(client, origin, NULL_VECTOR, velocity);
			}
			
			if(b[0] && !b[1])
			{		
				TeleportEntity(client, origin, angles, view_as<float>({0.0, 0.0, 0.0}));
			}
			
			if(!b[0] && !b[1])
			{	
				TeleportEntity(client, origin, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
			}
			
			RequestFrame(RF_frameFirst, client);
		}
	}
}

void LoadCP_command(int client)
{
	if(IsValidClient(client))
	{
		float origin[3];
		origin = gF_checkpoint_command[client][cpnumber_command[client]][0];
		float angles[3];
		angles = gF_checkpoint_command[client][cpnumber_command[client]][1];
		float velocity[3];
		velocity = gF_checkpoint_command[client][cpnumber_command[client]][2];
		bool b[2];
		b[0] = gB_restore[client][0];
		b[1] = gB_restore[client][1];
		gB_IsCPLoaded = true;
		
		if(b[0] && b[1])
		{		
			TeleportEntity(client, origin, angles, velocity);
		}
		
		if(!b[0] && b[1])
		{		
			TeleportEntity(client, origin, NULL_VECTOR, velocity);
		}
		
		if(b[0] && !b[1])
		{		
			TeleportEntity(client, origin, angles, view_as<float>({0.0, 0.0, 0.0}));
		}
		
		if(!b[0] && !b[1])
		{	
			TeleportEntity(client, origin, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		}
		
		RequestFrame(RF_frameFirst, client);
	}
}

void RF_frameFirst(int client)
{
	RequestFrame(RF_frameSecond, client);
}

void RF_frameSecond(int client)
{
	Shavit_StopTimer(client);
	
	if(Trikz_FindPartner(client) != -1)
	{
		Shavit_StopTimer(Trikz_FindPartner(client));
	}
	
	gB_IsCPLoaded = false;
}

int Native_LoadCP(Handle plugin, int numParams)
{
	return gB_IsCPLoaded;
}
