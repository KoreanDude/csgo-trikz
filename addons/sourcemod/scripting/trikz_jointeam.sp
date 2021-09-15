#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name        = "JoinTeam Fix",
	author      = "SHIM",
	description = "",
	version     = "",
	url         = "https://steamcommunity.com/id/ultrashim/"
};

public OnPluginStart()
{
	RegConsoleCmd("jointeam", Command_JoinTeam);
}

public Action:Command_JoinTeam(client, args)
{
	decl String:Team[8];
	GetCmdArg(1, Team, sizeof(Team));
	
	if(StrEqual(Team, "0"))
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
			ForcePlayerSuicide(client);
		
		ChangeClientTeam(client, 3);
	}
	else if(StrEqual(Team, "2"))
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
			ForcePlayerSuicide(client);
		
		ChangeClientTeam(client, 3);
	}
	else if(StrEqual(Team, "3"))
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
			ForcePlayerSuicide(client);
		
		ChangeClientTeam(client, 3);
	}
	else if(StrEqual(Team, "1"))
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
			ForcePlayerSuicide(client);
		
		ChangeClientTeam(client, 1);
	}
	
	return Plugin_Handled;
}