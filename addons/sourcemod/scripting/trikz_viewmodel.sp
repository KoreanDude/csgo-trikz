#include <colorvariables>

#pragma semicolon 1
#pragma newdecls required

bool gB_Viewmodel[MAXPLAYERS + 1];

bool IsValidClient(int client, bool bAlive = false)
{
	return (client >= 1 &&
			client <= MaxClients &&
			IsClientConnected(client) &&
			IsClientInGame(client) &&
			!IsClientSourceTV(client) &&
			(!bAlive || IsPlayerAlive(client)));
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_vm", Command_vm);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	if(IsValidClient(client))
	{
		gB_Viewmodel[client] = true;
	}
}

public Action Command_vm(int client, int args)
{
	if(view_as<bool>(GetEntProp(client, Prop_Send, "m_bDrawViewmodel")) == false)
	{
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", true);
		ChangeEdictState(client, FindDataMapInfo(client, "m_bDrawViewmodel"));
		gB_Viewmodel[client] = true;
		CPrintToChat(client, "{green}[Trikz]{lightgreen} %s", gB_Viewmodel[client] ? "Viewmodel is on." : "Viewmodel is off.");
		
		return Plugin_Handled;
	}
	
	if(view_as<bool>(GetEntProp(client, Prop_Send, "m_bDrawViewmodel")) == true)
	{
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", false);
		ChangeEdictState(client, FindDataMapInfo(client, "m_bDrawViewmodel"));
		gB_Viewmodel[client] = false;
		CPrintToChat(client, "{green}[Trikz]{lightgreen} %s", gB_Viewmodel[client] ? "Viewmodel is on." : "Viewmodel is off.");
		
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}
