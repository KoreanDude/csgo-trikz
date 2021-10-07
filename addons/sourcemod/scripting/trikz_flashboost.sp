#pragma semicolon 1

#include <sdktools_sound>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_engine>
#include <sdktools_trace>
#include <sdkhooks>
//#include <clientprefs>
#include <trikznobug>
#include <trikz>

// FlashBoost Extra Settings
#define REMOVE_FLASH 1

#pragma newdecls required

bool bLateLoad = false;
float g_fFlashMultiplier = 0.869325;

// FlashBoost
bool g_bFlashBoost[MAXPLAYERS+1];
bool g_bAirFlash[MAXPLAYERS+1];
float g_vFlashAbsVelocity[MAXPLAYERS+1][3];

// SkyBoost
bool g_bSkyEnable[MAXPLAYERS+1] = {true, ...};
float g_fBoosterAbsVelocityZ[MAXPLAYERS+1];
int g_SkyTouch[MAXPLAYERS+1];
int g_SkyReq[MAXPLAYERS+1];
float g_vSkyBoostVel[MAXPLAYERS+1][3];

public Plugin myinfo = 
{
	name = "[Trikz] Flash/Sky Fix",
	author = "ici & george, Modified by. SHIM",
	version = "2.02 GO"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {

	bLateLoad = late;
	CreateNative("Trikz_SkyFix", Native_Trikz_SkyFix);
	return APLRes_Success;
}

public int Native_Trikz_SkyFix(Handle plugin, int numParams) {
	g_bSkyEnable[GetNativeCell(1)] = view_as<bool>(GetNativeCell(2));
	return 1;
}

public void OnPluginStart() {
	if (bLateLoad)
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientConnected(i) && IsClientInGame(i))
				OnClientPutInServer(i);
				
	HookEvent("grenade_thrown", Event_GrenadeThrown);
}

public Action Event_GrenadeThrown(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsValidClient(client))
		return;
	
	if(!(GetEntityFlags(client) & FL_ONGROUND))
		g_bAirFlash[client] = true;
	else
		g_bAirFlash[client] = false;
}

public void OnClientPutInServer(int client) {

	// FlashBoost
	SDKHook(client, SDKHook_TraceAttack, Hook_OnTakeDamage);
	
	// SkyBoost
	//SDKHook(client, SDKHook_Touch, Hook_Touch);
	
	g_SkyTouch[client] = 0;
	g_SkyReq[client] = 0;
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {

	if (g_bFlashBoost[victim]
	|| !IsValidClient(victim)
	|| GetEntityMoveType(victim) == MOVETYPE_LADDER) return Plugin_Continue;
	
	char Weapon[32];
	GetEdictClassname(inflictor, Weapon, sizeof(Weapon));
	if (StrContains(Weapon, "flashbang", false) == -1) return Plugin_Continue;
	
	if(GetEntityFlags(victim) & FL_ONGROUND)
		return Plugin_Continue;
	
	float vFlashOrigin[3];
	float vVictimOrigin[3];
	float vVictimAbsVelocity[3];
	float vAttackerOrigin[3];
	
	GetEntPropVector(inflictor, Prop_Data, "m_vecOrigin", vFlashOrigin);
	GetEntPropVector(victim, Prop_Data, "m_vecOrigin", vVictimOrigin);
	GetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", vVictimAbsVelocity);
	GetEntPropVector(attacker, Prop_Data, "m_vecOrigin", vAttackerOrigin);
	
	GetEntPropVector(inflictor, Prop_Data, "m_vecAbsVelocity", g_vFlashAbsVelocity[victim]);
	g_bFlashBoost[victim] = true;
	
#if (REMOVE_FLASH == 1)
	CreateTimer(0.1, Timer_RemoveFlash, inflictor);
#endif
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client) {

	if (g_bFlashBoost[client]) {
	
		float vClientAbsVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vClientAbsVelocity);
		
		int iPartner = Trikz_FindPartner(client);
		
		if(g_bAirFlash[iPartner])
		{
			// 0.8693248760112110724220573123187
			vClientAbsVelocity[0] += g_vFlashAbsVelocity[client][0] * -g_fFlashMultiplier;
			vClientAbsVelocity[1] += g_vFlashAbsVelocity[client][1] * -g_fFlashMultiplier;
			vClientAbsVelocity[2] = g_vFlashAbsVelocity[client][2] * 0.94;
			
		} else {
		
			vClientAbsVelocity[0] += g_vFlashAbsVelocity[client][0] * -0.94;
			vClientAbsVelocity[1] += g_vFlashAbsVelocity[client][1] * -0.94;
			vClientAbsVelocity[2] = g_vFlashAbsVelocity[client][2];
		}
		
		if(vClientAbsVelocity[2] <= 200.0)
			vClientAbsVelocity[2] = 600.0;
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vClientAbsVelocity);
		
		g_bFlashBoost[client] = false;
	}
	
	return Plugin_Continue;
}

public Action Hook_Touch(int victim, int other) {

	if (!g_bSkyEnable[victim]
	|| g_bFlashBoost[victim]
	|| !IsValidClient(other)
	|| GetEntityMoveType(victim) == MOVETYPE_LADDER
	|| GetEntityMoveType(other) == MOVETYPE_LADDER) return Plugin_Continue;
	
	int col = GetEntProp(other, Prop_Data, "m_CollisionGroup");
	if (col != 5) return Plugin_Continue;
	
	float vVictimOrigin[3];
	float vBoosterOrigin[3];
	
	GetEntPropVector(victim, Prop_Data, "m_vecOrigin", vVictimOrigin);
	GetEntPropVector(other, Prop_Data, "m_vecOrigin", vBoosterOrigin);
	
	if ((Math_Abs(vVictimOrigin[0] - vBoosterOrigin[0]) > 32.0)
	|| (Math_Abs(vVictimOrigin[1] - vBoosterOrigin[1]) > 32.0)
	|| (vVictimOrigin[2] - vBoosterOrigin[2]) < 45.0)
		return Plugin_Continue;
	
	float vBoosterAbsVelocity[3];
	GetEntPropVector(other, Prop_Data, "m_vecAbsVelocity", vBoosterAbsVelocity);
	if (vBoosterAbsVelocity[2] <= 0.0) return Plugin_Continue;
	
	g_fBoosterAbsVelocityZ[victim] += vBoosterAbsVelocity[2];
	++g_SkyTouch[victim];
	GetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", g_vSkyBoostVel[victim]);
	
	RequestFrame(SkyFrame_Callback, victim);
	return Plugin_Continue;
}

public void SkyFrame_Callback(any victim) {

	if (g_SkyTouch[victim] == 0)
		return;
	
	if (g_bFlashBoost[victim]) {
		g_fBoosterAbsVelocityZ[victim] = 0.0;
		g_SkyTouch[victim] = 0;
		g_SkyReq[victim] = 0;
		return;
	}
	
	++g_SkyReq[victim];
	float vVictimAbsVelocity[3];
	GetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", vVictimAbsVelocity);
	
	if (vVictimAbsVelocity[2] > 0.0) {
		g_vSkyBoostVel[victim][2] = vVictimAbsVelocity[2] + g_fBoosterAbsVelocityZ[victim] * 0.5;
		TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, g_vSkyBoostVel[victim]);
		g_fBoosterAbsVelocityZ[victim] = 0.0;
		g_SkyTouch[victim] = 0;
		g_SkyReq[victim] = 0;
	} else {
		if (g_SkyReq[victim] > 150) {
			g_fBoosterAbsVelocityZ[victim] = 0.0;
			g_SkyTouch[victim] = 0;
			g_SkyReq[victim] = 0;
			return;
		}
		// Recurse for a few more frames
		RequestFrame(SkyFrame_Callback, victim);
	}
}

public bool IsValidClient(int client) {
	return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsPlayerAlive(client));
}

public float Math_Abs(float value) {
	return (value >= 0.0 ? value : -value);
}

#if (REMOVE_FLASH == 1)
public Action Timer_RemoveFlash(Handle timer, any inflictor) {
	if (IsValidEdict(inflictor))
		AcceptEntityInput(inflictor, "Kill");
}
#endif