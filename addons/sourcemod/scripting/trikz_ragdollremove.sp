#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Ragdoll remover",
	author = "shavit (bhoptimer), modified by Smesh",
	description = "Remove player bodies instantly after death.",
	version = "14.01.2021",
	url = "https://steamcommunity.com/id/smesh292/"
};

public void OnPluginStart()
{
	HookEvent("player_death", Player_Death);
}

Action Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	
	if(!IsValidEdict(ragdoll))
	{
		return Plugin_Continue;
	}
	
	AcceptEntityInput(ragdoll, "Kill");
	
	return Plugin_Continue;
}
