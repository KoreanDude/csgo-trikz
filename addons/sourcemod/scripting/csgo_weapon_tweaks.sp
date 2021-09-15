#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

ConVar hConVar_NoSpread;

public Plugin myinfo =
{
	name = "CSGO Weapon Tweaks",
	author = "Keith Warren (Drixevel), Modified by. SHIM",
	description = "Allows to tweak certain weapons while in use.",
	version = "1.0.2",
	url = "http://www.drixevel.com/"
};

public void OnPluginStart()
{
	//Hook the ConVar we need to edit and make sure It's set to 0.
	hConVar_NoSpread = FindConVar("weapon_accuracy_nospread");
	SetConVarInt(hConVar_NoSpread, 0);

	//Load clients in already on the server.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}

	HookEvent("weapon_fire", OnWeaponFire, EventHookMode_Pre);
}

//We do the dirty work of hooking when the weapon fires so we can enable/disable the spread ConVar the same frame.
//MESSY MESSY MESSY MESSY MESSY
public Action OnWeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client == 0)
	{
		return;
	}

	SetConVarInt(hConVar_NoSpread, 1);
	RequestFrame(Frame_DisableNoSpread);
}

public void Frame_DisableNoSpread(any data)
{
	SetConVarInt(hConVar_NoSpread, 0);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}

	SendConVarValue(client, hConVar_NoSpread, "0");

	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}

	SendConVarValue(client, hConVar_NoSpread, "0");

	SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public void OnPostThinkPost(int client)
{
	int iActive = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	if (IsValidEntity(iActive))
	{
		SendConVarValue(client, hConVar_NoSpread, "1");
		SetEntPropFloat(iActive, Prop_Send, "m_fAccuracyPenalty", 0.0);
	}
}