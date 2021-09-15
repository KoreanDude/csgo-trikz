#include <sdktools>
#include <colorvariables>

public Plugin myinfo =
{
	name        = "Print Trigger",
	author      = "SHIM",
	description = "",
	version     = "",
	url         = "https://steamcommunity.com/id/ultrashim/"
};

int gI_PTrigger[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_ptrigger", Command_PTrigger);
	
	HookEntityOutput("func_brush", "OnStartTouch", OnToggleEntity);
	HookEntityOutput("func_wall_toggle", "OnStartTouch", OnToggleEntity);
	HookEntityOutput("trigger_teleport", "OnStartTouch", OnToggleEntity);
	HookEntityOutput("trigger_teleport_relative", "OnStartTouch", OnToggleEntity);
	HookEntityOutput("trigger_multiple", "OnStartTouch", OnToggleEntity);
	HookEntityOutput("trigger_push", "OnStartTouch", OnToggleEntity);
	HookEntityOutput("func_button", "OnPressed", OnToggleEntity);
}

Action Command_PTrigger(int client, int args)
{	
	if(gI_PTrigger[client] == 0)
	{
		gI_PTrigger[client] = 1;
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Print Trigger is on.");
	}
	
	else if(gI_PTrigger[client] == 1)
	{
		gI_PTrigger[client] = 0;
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Print Trigger is off.");
	}
	
	return Plugin_Handled;
}

void OnToggleEntity(const char[] output, int caller, int activator, float delay)
{
	if(!IsValidClient(activator) || !IsValidEntity(caller))
		return;
	
	if(gI_PTrigger[activator] == 1)
	{
		int iHammerID = GetEntProp(caller, Prop_Data, "m_iHammerID");
		
		CPrintToChat(activator, "{green}[Trikz]{lightgreen} %i", iHammerID);
	}
}

public bool IsValidClient( int client ) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) || !IsPlayerAlive(client) ) 
        return false; 
     
    return true; 
}