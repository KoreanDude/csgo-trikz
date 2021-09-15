#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <trikz>
#include <colorvariables>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name        = "boost-fix for CS:GO",
	author      = "Tengu, Smesh, Modified by. SHIM",
	description = "<insert_description_here>",
	version     = "0.2",
	url         = "http://steamcommunity.com/id/tengulawl/"
}

Handle gH_SkyStats = INVALID_HANDLE;
int gI_SkyStats[MAXPLAYERS + 1]; 
int gI_SpectatorTarget[MAXPLAYERS + 1]; 
int gI_boost[MAXPLAYERS + 1];
int gI_playerFlags[MAXPLAYERS + 1];
int gI_skyFrame[MAXPLAYERS + 1];
int gI_skyStep[MAXPLAYERS + 1];
float gF_boostTime[MAXPLAYERS + 1];
float gF_fallVelBooster[MAXPLAYERS + 1][3];
float gF_fallVel[MAXPLAYERS + 1][3];
float gF_vecVelBoostFix[MAXPLAYERS + 1][3];

public void OnPluginStart()
{
	RegConsoleCmd("sm_sbs", Command_SkyStats);
	
	gH_SkyStats = RegClientCookie("SkyStats", "SkyStats", CookieAccess_Private);
	
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i)) 
		{
			OnClientPutInServer(i);
		
			if(AreClientCookiesCached(i))
				OnClientCookiesCached(i);
			else
				gI_SkyStats[i] = 0;
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_StartTouch, StartTouch_SkyFix);
	
	gI_SpectatorTarget[client] = -1;
}

public void OnClientCookiesCached(int client)
{
	char sCookie[12];
	GetClientCookie(client, gH_SkyStats, sCookie, sizeof(sCookie));
	
	if (StringToInt(sCookie) == 0)
	{
		gI_SkyStats[client] = 0;
		return;
	}
	gI_SkyStats[client] = StringToInt(sCookie);
}

public void OnClientDisconnect(int client)
{
	gI_skyFrame[client] = 0;
	gI_skyStep[client] = 0;
	gF_boostTime[client] = 0.0;
	gI_playerFlags[client] = 0;
}

Action Command_SkyStats(int client, int args)
{
	if(gI_SkyStats[client] == 0)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Sky stats is on.");
		gI_SkyStats[client] = 1;
	}
	else
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Sky stats is off.");
		gI_SkyStats[client] = 0;
	}
	
	char sCookie[12];
	Format(sCookie, sizeof(sCookie), "%i", gI_SkyStats[client]);
	SetClientCookie(client, gH_SkyStats, sCookie);
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	SpectatorCheck(client);
	
	gI_playerFlags[client] = GetEntityFlags(client);

	if(gI_boost[client] == 10)
	{
		gI_boost[client] = 0;
	}

	if(gI_boost[client] == 15)
	{
		for(int i = 0; i <= 2; i++)
		{
			gF_vecVelBoostFix[client][i] = 0.0;
		}

		gI_boost[client] = 0;
		gI_skyStep[client] = 0;
	}

	if(7 >= gI_boost[client] >= 1)
	{
		gI_skyStep[client] = 0;
	}

	if(gI_boost[client] == 8)
	{
		for(int i = 0; i <= 2; i++)
		{
			gF_vecVelBoostFix[client][i] = 0.0;
		}

		gI_boost[client] = 0;
		gI_skyStep[client] = 0;
	}

	if(1 <= gI_skyFrame[client] <= 5)
	{
		gI_skyFrame[client]++;
	}

	if(gI_skyFrame[client] >= 5)
	{
		gI_skyFrame[client] = 0;
		gI_skyStep[client] = 0;
	}

	if(gI_boost[client] && gI_skyStep[client])
	{
		gI_skyFrame[client] = 0;
		gI_skyStep[client] = 0;
	}

	if(gI_skyStep[client] == 1 && GetEntityFlags(client) & FL_ONGROUND && GetGameTime() - gF_boostTime[client] > 0.15)
	{
		gF_fallVelBooster[client][2] = gF_fallVelBooster[client][2] * 2.7;
		gF_fallVel[client][2] = gF_fallVelBooster[client][2];

		if(gF_fallVelBooster[client][2] > 800.0)
		{
			//PrintToChatAll("%.1f", gF_fallVelBooster[client][2]);
			gF_fallVel[client][2] = 800.0;
		}

		if(buttons & IN_JUMP)
		{
			int iPartner = Trikz_FindPartner(client);
			
			if(gI_SkyStats[client] == 1)
			{
				CPrintToChat(client, "{green}[Trikz]{lightgreen} {default}Velocity: {lightgreen}%.1f{grey}", gF_fallVel[client][2]);
			}
			
			if(iPartner != -1)
			{
				if(gI_SkyStats[iPartner] == 1)
				{
					CPrintToChat(iPartner, "{green}[Trikz]{lightgreen} {default}Velocity: {lightgreen}%.1f {grey}| {teamcolor}%N", gF_fallVel[client][2], client);
				}
			}
			
			if(iPartner == -1)
			{
				SpectatorCheck(client);
				
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || !IsPlayerAlive(i)) && gI_SkyStats[i] == 1)
					{
						if(gI_SpectatorTarget[i] == client)
						{
							CPrintToChat(i, "{green}[Trikz]{lightgreen} {default}Velocity: {lightgreen}%.1f{grey}", gF_fallVel[client][2]);
						}
					}
				}
			}
			
			else
			{
				SpectatorCheck(iPartner);
			
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || !IsPlayerAlive(i)) && gI_SkyStats[i] == 1)
					{
						if(gI_SpectatorTarget[i] == client || gI_SpectatorTarget[i] == iPartner)
						{
							CPrintToChat(i, "{green}[Trikz]{lightgreen} {default}Velocity: {lightgreen}%.1f{grey} | {teamcolor}%N", gF_fallVel[client][2], client);
						}
					}
				}
			}
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, gF_fallVel[client]);
			
			gI_skyStep[client] = 0;
			gF_fallVel[client][2] = 0.0;
			gI_skyFrame[client] = 0;
		}
	}

	return Plugin_Continue;
}

public void StartTouch_SkyFix(int client, int other) //client = booster; other = flyer
{
	if(!IsValidClient(other) || gI_playerFlags[other] & FL_ONGROUND || gI_boost[client] || GetGameTime() - gF_boostTime[client] < 0.15)
	{
		return;
	}
	
	float vecAbsBooster[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", vecAbsBooster);

	float vecAbsFlyer[3];
	GetEntPropVector(other, Prop_Data, "m_vecOrigin", vecAbsFlyer);

	float vecMaxs[3];
	GetEntPropVector(client, Prop_Data, "m_vecMaxs", vecMaxs);

	float delta = vecAbsFlyer[2] - vecAbsBooster[2] - vecMaxs[2]; //https://github.com/tengulawl/scripting/blob/master/boost-fix.sp#L71

	if(0.0 <= delta <= 2.0) //https://github.com/tengulawl/scripting/blob/master/boost-fix.sp#L75
	{
		if(!(GetEntityFlags(client) & FL_ONGROUND) && gI_skyStep[other] == 0)// can duck sky
		{
			float vecVelBooster[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecVelBooster);
			gF_fallVelBooster[other][2] = vecVelBooster[2];
			
			if(vecVelBooster[2] > 0.0)
			{
				float vecVelFlyer[3];
				GetEntPropVector(other, Prop_Data, "m_vecVelocity", vecVelFlyer);

				gF_fallVel[other][0] = vecVelFlyer[0];
				gF_fallVel[other][1] = vecVelFlyer[1];
				gF_fallVel[other][2] = FloatAbs(vecVelFlyer[2]);

				gI_skyStep[other] = 1;
				gI_skyFrame[other] = 1;
			}
		}
	}
}

void SpectatorCheck(int client)
{
	//Manage spectators
	if(!IsClientObserver(client))
	{
		return;
	}
	
	int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
	
	if(3 < iObserverMode < 7)
	{
		int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		
		if(gI_SpectatorTarget[client] != iTarget)
		{
			gI_SpectatorTarget[client] = iTarget;
		}
	}
	
	else
	{
		if(gI_SpectatorTarget[client] != -1)
		{
			gI_SpectatorTarget[client] = -1;
		}
	}
}

bool IsValidClient(int client, bool alive = false)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && (!alive || IsPlayerAlive(client));
}