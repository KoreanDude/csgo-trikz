#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colorvariables>
#include <trikz>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

Handle gH_AngleStats = INVALID_HANDLE;
int gI_AngleStats[MAXPLAYERS + 1];
int gI_SpectatorTarget[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[Trikz] Stats angles",
	author = "Skipper, Modified by. SHIM"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_ac", Command_AngleStats);
	
	gH_AngleStats = RegClientCookie("AngleStats", "AngleStats", CookieAccess_Private);
	
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i)) 
		{
			OnClientPutInServer(i);
		
			if(AreClientCookiesCached(i))
				OnClientCookiesCached(i);
			else
				gI_AngleStats[i] = 0;
		}
	}
}

public void OnClientPutInServer(int client)
{
	gI_SpectatorTarget[client] = -1;
}

public void OnClientCookiesCached(int client)
{
	char sCookie[12];
	GetClientCookie(client, gH_AngleStats, sCookie, sizeof(sCookie));
	
	if (StringToInt(sCookie) == 0)
	{
		gI_AngleStats[client] = 0;
		return;
	}
	gI_AngleStats[client] = StringToInt(sCookie);
}

Action Command_AngleStats(int client, int args)
{
	if(gI_AngleStats[client] == 0)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Angles check is on.");
		gI_AngleStats[client] = 1;
	}
	else
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Angles check is off.");
		gI_AngleStats[client] = 0;
	}
	
	char sCookie[12];
	Format(sCookie, sizeof(sCookie), "%i", gI_AngleStats[client]);
	SetClientCookie(client, gH_AngleStats, sCookie);
	
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname) 
{
	if(StrContains(classname, "_projectile") != -1) 
	{
		SDKHook(entity, SDKHook_Spawn, SpawnPost_Grenade); 
	}
}

Action SpawnPost_Grenade(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	float iAngles[3];
	GetClientEyeAngles(client, iAngles);
	
	int iAngle = RoundFloat(iAngles[0] * -1);
	
	char sStatus[64];
	
	//Thanks to https://forums.alliedmods.net/showpost.php?p=1856915&postcount=2
	//Thanks to https://www.unknowncheats.me/forum/1900520-post1.html
	//For angles measure thanks to "Trikzbb"
	
	if(-27 < iAngle < 7)
	{
		sStatus = "Low Megalong";
	}
	
	else if(6 < iAngle < 26)
	{
		sStatus = "Megalong";
	}

	else if(25 < iAngle < 41)
	{
		sStatus = "Medium high Megalong";
	}
	
	else if(40 < iAngle < 66)
	{
		sStatus = "High Megalong";
	}
	
	else if(65 < iAngle < 76)
	{
		sStatus = "Low fast Megahigh";
	}
	
	else if(75 < iAngle < 86)
	{
		sStatus = "Medium fast Megahigh";
	}
	
	else if(85 < iAngle < 90)
	{
		sStatus = "Megahigh";
	}
	
	if(-27 < iAngle < 90)
	{
		int iPartner = Trikz_FindPartner(client);
		
		if(gI_AngleStats[client] == 1)
		{
			CPrintToChat(client, "{green}[Trikz]{lightgreen} {default}Angle: {lightgreen}%i{default}° {grey}| {lime}%s", iAngle, sStatus);
		}
				
		if(iPartner != -1)
		{
			if(gI_AngleStats[iPartner] == 1)
			{
				CPrintToChat(iPartner, "{green}[Trikz]{lightgreen} {default}Angle: {lightgreen}%i{default}° {grey}| {lime}%s {grey}| {teamcolor}%N", iAngle, sStatus, client);
			}
		}
		
		if(iPartner == -1)
		{
			SpectatorCheck(client);
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || !IsPlayerAlive(i)) && gI_AngleStats[i] == 1)
				{
					if(gI_SpectatorTarget[i] == client)
					{
						CPrintToChat(i, "{green}[Trikz]{lightgreen} {default}Angle: {lightgreen}%i{default}° {grey}| {lime}%s", iAngle, sStatus);
					}
				}
			}
		}
		else
		{
			SpectatorCheck(iPartner);
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || !IsPlayerAlive(i)) && gI_AngleStats[i] == 1)
				{
					if(gI_SpectatorTarget[i] == client || gI_SpectatorTarget[i] == iPartner)
					{
						CPrintToChat(i, "{green}[Trikz]{lightgreen} {default}Angle: {lightgreen}%i{default}° {grey}| {lime}%s {grey}| {teamcolor}%N", iAngle, sStatus, client);
					}
				}
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	SpectatorCheck(client);
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