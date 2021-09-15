#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name        = "Spectator CMD",
	author      = "SHIM",
	description = "",
	version     = "",
	url         = "https://steamcommunity.com/id/ultrashim/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_spec", Command_Spectate);
}

public Action Command_Spectate(int client, int args)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
		ForcePlayerSuicide(client);
		
	ChangeClientTeam(client, 1);
	
	return Plugin_Handled;
}