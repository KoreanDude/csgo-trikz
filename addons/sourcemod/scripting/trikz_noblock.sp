#include <shavit>
#include <colorvariables>

#pragma semicolon 1
#pragma newdecls required

char gS_CMD_Block[][] = {"sm_bl", "sm_block", "sm_ghost", "sm_switch"};

public Plugin myinfo =
{
	name = "Noblock",
	author = "Shavit, Smesh, Modified by. SHIM",
	description = "You can toggle collision (solid, no-solid).",
	version = "14.01.2021",
	url = "https://steamcommunity.com/id/smesh292/"
};

public void OnPluginStart()
{	
	for(int i = 0; i < sizeof(gS_CMD_Block); i++)
	{
		RegConsoleCmd(gS_CMD_Block[i], Command_Block, "Toggle blocking");
	}
}

Action Command_Block(int client, int args)
{
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
		
		return Plugin_Handled;
	}
	
	if(Shavit_GetClientTrack(client) != Track_Solobonus)
	{
		if(GetEntProp(client, Prop_Data, "m_CollisionGroup") == 5)
		{
			SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
			SetEntityRenderMode(client, RENDER_TRANSALPHA);
			SetEntityRenderColor(client, 255, 255, 255, 75);
			CPrintToChat(client, "{green}[Trikz]{lightgreen} You are ghost.");
			
			return Plugin_Handled;
		}
			
		if(GetEntProp(client, Prop_Data, "m_CollisionGroup") == 2)
		{
			SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
			SetEntityRenderMode(client, RENDER_NORMAL);
			CPrintToChat(client, "{green}[Trikz]{lightgreen} You are blocking.");
			
			return Plugin_Handled;
		}
	}
	
	else
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Block cannot be toggled in solobonus track. Type {lightgreen}/r {default}or {lightgreen}/b {default}or {lightgreen}/end {default}or {lightgreen}/bend {default}to change the track.");
	}
	
	return Plugin_Handled;
}
