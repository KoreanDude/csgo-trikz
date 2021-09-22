#include <sdktools>
#include <sdkhooks>
#include <shavit>
#include <trikz>

#pragma semicolon 1
#pragma newdecls required

bool gB_Check[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Smart anti-stuck",
	author = "Smesh, Gurman, Modified by. SHIM",
	description = "",
	version = "29.08.2020",
	url = "http://www.sourcemod.net/"
}

stock int IsPlayerStuck(int client)
{
	float vMin[3];
	float vMax[3];
	float vOrigin[3];
	GetClientMins(client, vMin);
	GetClientMaxs(client, vMax);
	GetClientAbsOrigin(client, vOrigin);
	TR_TraceHullFilter(vOrigin, vOrigin, vMin, vMax, MASK_PLAYERSOLID, TR_DontHitSelf, client);
	return TR_GetEntityIndex();
}

public bool TR_DontHitSelf(int entity, int mask, int client) 
{
	return (entity != client && IsValidClient(entity));
}

public Action OnPlayerRunCmd(int client)
{
	int iOther = IsPlayerStuck(client);
	
	if(IsValidClient(iOther) && !IsFakeClient(iOther))
	{
		if(Trikz_FindPartner(iOther) == client && Trikz_FindPartner(client) == iOther)
		{
			if(GetEntProp(client, Prop_Data, "m_CollisionGroup") == 5)
			{
				SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
				SetEntityRenderMode(client, RENDER_TRANSALPHA);
				SetEntityRenderColor(client, 255, 255, 255, 75);
				
				gB_Check[client] = false;
			}
		}
		else if(Trikz_FindPartner(iOther) == -1 && Trikz_FindPartner(client) == -1)
		{
			if(GetEntProp(client, Prop_Data, "m_CollisionGroup") == 5)
			{
				SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);

				gB_Check[client] = false;
			}
		}
	}
	else
	{
		if(!gB_Check[client])
		{
			if(GetEntProp(client, Prop_Data, "m_CollisionGroup") == 2)
			{
				SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
				SetEntityRenderMode(client, RENDER_NORMAL);
				gB_Check[client] = true;
			}
		}
	}
	
	return Plugin_Continue;
}