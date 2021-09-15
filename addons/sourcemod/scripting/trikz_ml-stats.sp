#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <colorvariables>
#include <trikz>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

Handle gH_MLStats = INVALID_HANDLE;
int gI_MLStats[MAXPLAYERS + 1];
int gI_xCount[MAXPLAYERS + 1];
bool gB_groundBoost[MAXPLAYERS + 1];
bool gB_bouncedOff[2048];

float gF_posStart[MAXPLAYERS + 1][3];
float gF_posFinish[MAXPLAYERS + 1][3];
int gI_thrower[MAXPLAYERS + 1];
float gF_speedMax[MAXPLAYERS + 1];
bool gB_IsPlayerInAir[MAXPLAYERS + 1];
int gI_SpectatorTarget[MAXPLAYERS + 1];

float gF_speedPre[MAXPLAYERS + 1][1000];
float gF_speedPost[MAXPLAYERS + 1][1000];
float gF_distance;
float gF_speed[MAXPLAYERS + 1];
char gS_status[64];
int gI_tick;

enum PlayerState
{
	ILLEGAL_JUMP_FLAGS:IllegalJumpFlags
}

enum ILLEGAL_JUMP_FLAGS
{
	IJF_NONE = 0,
	IJF_WORLD,
	IJF_BOOSTER,
	IJF_GRAVITY,
	IJF_TELEPORT,
	IJF_LAGGEDMOVEMENTVALUE,
	IJF_PRESTRAFE,
	IJF_SCOUT,
	IJF_NOCLIP
}

int gI_PlayerStates[MAXPLAYERS + 1][PlayerState];

// forwards
Handle gH_Forwards_boostSpeed = null;

int g_boostStep[MAXPLAYERS + 1];
int g_boostEnt[MAXPLAYERS + 1];
float g_boostVel[MAXPLAYERS + 1][3];
float g_boostTime[MAXPLAYERS + 1];
float g_playerVel[MAXPLAYERS + 1][3];
int g_playerFlags[MAXPLAYERS + 1];
bool g_groundBoost[MAXPLAYERS + 1];
bool g_bouncedOff[2048];

public Plugin myinfo =
{
	name = "Mega long stats",
	author = "Smesh, extrem, Skipper (Gurman), Modified by. SHIM",
	description = "You can see the boost counts, speed, distance.",
	version = "14.01.2021",
	url = "https://steamcommunity.com/id/smesh292/"
};

bool IsValidClient(int client, bool bAlive = false)
{
	return (client >= 1 &&
			client <= MaxClients &&
			IsClientConnected(client) &&
			IsClientInGame(client) &&
			!IsClientSourceTV(client) &&
			(!bAlive || IsPlayerAlive(client)));
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Trikz_GetClientStateMLS", Native_GetClientStateMLS);
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_mls", Command_MLS);
	
	gH_MLStats = RegClientCookie("MLStats", "MLStats", CookieAccess_Private);
	
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i)) 
		{
			OnClientPutInServer(i);
		
			if(AreClientCookiesCached(i))
				OnClientCookiesCached(i);
			else
				gI_MLStats[i] = 0;
		}
	}
	
	HookEvent("player_jump", Event_PlayerJump);
	HookEntityOutput("trigger_teleport", "OnStartTouch", Event_OnStartTriggerTp);
	HookEntityOutput("trigger_push", "OnStartTouch", Event_OnStartTriggerPush);
	gF_distance = -1.0;
	//forwards
	gH_Forwards_boostSpeed = CreateGlobalForward("Trikz_OnBoost", ET_Event, Param_Cell, Param_Cell);
	
}

public void OnClientPutInServer(int client)
{
	gI_SpectatorTarget[client] = -1;
	
	SDKHook(client, SDKHook_StartTouch, Client_StartTouchWorld);
	SDKHook(client, SDKHook_PostThinkPost, Client_PostThinkPost);
}

public void OnClientCookiesCached(int client)
{
	char sCookie[12];
	GetClientCookie(client, gH_MLStats, sCookie, sizeof(sCookie));
	
	if (StringToInt(sCookie) == 0)
	{
		gI_MLStats[client] = 0;
		return;
	}
	gI_MLStats[client] = StringToInt(sCookie);
}

public void OnClientDisconnect(int client)
{
	g_boostStep[client] = 0;
	g_boostTime[client] = 0.0;
	g_playerFlags[client] = 0;
}

Action Command_MLS(int client, int args)
{
	if(gI_MLStats[client] == 0)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} ML stats is on.");
		gI_MLStats[client] = 1;
	}
	else
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} ML stats is off.");
		gI_MLStats[client] = 0;
	}

	char sCookie[12];
	Format(sCookie, sizeof(sCookie), "%i", gI_MLStats[client]);
	SetClientCookie(client, gH_MLStats, sCookie);

	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "_projectile") != -1)
	{
		SDKHook(entity, SDKHook_StartTouch, Projectile_StartTouch);
		SDKHook(entity, SDKHook_EndTouch, Projectile_EndTouch);
		gB_bouncedOff[entity] = false;
		SDKHook(entity, SDKHook_StartTouch, Projectile_StartTouch2);
		SDKHook(entity, SDKHook_EndTouch, Projectile_EndTouch2);
		g_bouncedOff[entity] = false;
	}
}

Action Projectile_StartTouch(int entity, int client)
{
	if(!IsValidClient(client, true) || !IsValidEntity(entity))
	{
		return Plugin_Continue;
	}
	
	gB_groundBoost[client] = !gB_bouncedOff[entity];
	
	if(!gB_groundBoost[client])
	{
		return Plugin_Continue;
	}
	
	if(GetEntityFlags(client) & FL_ONGROUND)
		return Plugin_Continue;
	
	gI_xCount[client]++;
	
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	
	//Thanks to https://github.com/Nickelony/Velocities/blob/5a8915c81e2806797adc26a5f742edb52af20605/scripting/velocities.sp#L162
	gF_speedPre[client][gI_xCount[client]] = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));
	
	if(IsValidEntity(entity))
	{
		int other = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		gI_thrower[client] = other;
	}
	
	return Plugin_Continue;
}

Action Projectile_EndTouch(int entity, int other)
{
	if(other)
	{
		gB_bouncedOff[entity] = true;
	}
}

public void Trikz_OnBoost(int client, float velxy)
{
	if(!IsValidClient(client) || !IsValidClient(gI_thrower[client]))
	{
		return;
	}
	
	gF_speedPost[client][gI_xCount[client]] = velxy;
	
	if(gI_MLStats[client] == 1)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} X%d {grey}| {lightgreen}%.1f {default}- {lightgreen}%.1f {default}U/S", gI_xCount[client], gF_speedPre[client][gI_xCount[client]], gF_speedPost[client][gI_xCount[client]]);
	}
	
	if(gI_MLStats[gI_thrower[client]] == 1)
	{
		CPrintToChat(gI_thrower[client], "{green}[Trikz]{lightgreen} X%d {grey}| {lightgreen}%.1f {default}- {lightgreen}%.1f {default}U/S", gI_xCount[client], gF_speedPre[client][gI_xCount[client]], gF_speedPost[client][gI_xCount[client]]);
	}
	
	SpectatorCheck(client);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || !IsPlayerAlive(i)) && gI_MLStats[i] == 1)
		{
			if(gI_SpectatorTarget[i] == client || gI_SpectatorTarget[i] == gI_thrower[client])
			{
				CPrintToChat(i, "{green}[Trikz]{lightgreen} X%d {grey}| {lightgreen}%.1f {default}- {lightgreen}%.1f {default}U/S", gI_xCount[client], gF_speedPre[client][gI_xCount[client]], gF_speedPost[client][gI_xCount[client]]);
			}
		}
	}
}

Action Event_PlayerJump(Handle event, const char[] name, bool dB)
{	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	GetClientAbsOrigin(client, gF_posStart[client]);
}

Action Event_OnStartTriggerTp(const char[] output, int caller, int activator, float delay)
{
	if(IsValidClient(activator))
	{
		if(!(GetEntityFlags(activator) & FL_ONGROUND) && gI_xCount[activator] > 0)
		{
			gI_PlayerStates[activator][IllegalJumpFlags] = IJF_TELEPORT;
			GetClientAbsOrigin(activator, gF_posFinish[activator]);
			gS_status = "{grey}({default}TP{grey})";
		}
	}
}

Action Event_OnStartTriggerPush(const char[] output, int caller, int activator, float delay)
{
	if(IsValidClient(activator))
	{
		if(!(GetEntityFlags(activator) & FL_ONGROUND) && gI_xCount[activator] > 0)
		{
			gI_PlayerStates[activator][IllegalJumpFlags] = IJF_BOOSTER;
			gS_status = "{grey}({default}PUSH{grey})";
		}
	}
}

Action Client_StartTouchWorld(int client, int other) 
{
	if(!(GetEntityFlags(client) & FL_ONGROUND) && gI_xCount[client] > 0 && other == 0)
	{		
		gI_PlayerStates[client][IllegalJumpFlags] = IJF_WORLD;
		gS_status = "{grey}({default}HIT WALL/SURF{grey})";
	}
}

void CheckIfHitInFeet(int client)
{	
	float velocity[3];

	if(g_boostStep[client])
	{
		if(g_boostStep[client] == 2)
		{
			velocity[0] = g_playerVel[client][0] - g_boostVel[client][0];
			velocity[1] = g_playerVel[client][1] - g_boostVel[client][1];
			velocity[2] = g_boostVel[client][2];
			
			g_boostStep[client] = 3;
		}
		
		else if(g_boostStep[client] == 3)
		{
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
			
			if(g_groundBoost[client])
			{
				velocity[0] += g_boostVel[client][0];
				velocity[1] += g_boostVel[client][1];
				velocity[2] += g_boostVel[client][2];
			}
			
			else
			{
				velocity[0] += g_boostVel[client][0] * 0.135;
				velocity[1] += g_boostVel[client][1] * 0.135;
			}

			g_boostStep[client] = 0;
			
			Call_StartForward(gH_Forwards_boostSpeed);
			Call_PushCell(client);
			Call_PushCell(SquareRoot(Pow(velocity[0], 2.0) + Pow(velocity[1], 2.0)));
			Call_Finish();
		}
	}
}

Action Projectile_StartTouch2(int entity, int client)
{
	if(!IsValidClient(client, true))
	{
		return Plugin_Continue;
	}
	
	if(g_boostStep[client] || g_playerFlags[client] & FL_ONGROUND)
	{
		return Plugin_Continue;
	}
	
	if(GetEntityFlags(client) & FL_ONGROUND)
		return Plugin_Continue;
	
	g_boostStep[client] = 1;
	g_boostEnt[client] = EntIndexToEntRef(entity);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", g_boostVel[client]);
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", g_playerVel[client]);
	g_groundBoost[client] = g_bouncedOff[entity];
	g_boostTime[client] = GetGameTime();
 
	return Plugin_Continue;
}
 
Action Projectile_EndTouch2(int entity, int other)
{
	if(!other)
	{
		g_bouncedOff[entity] = true;
	}
}

void Client_PostThinkPost(int client)
{
	if(g_boostStep[client] == 1)
	{
		int entity = EntRefToEntIndex(g_boostEnt[client]);

		if(entity != INVALID_ENT_REFERENCE)
		{
			float velocity[3];
			GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", velocity);

			if(velocity[2] > 0.0)
			{
				velocity[0] = g_boostVel[client][0] * 0.135;
				velocity[1] = g_boostVel[client][1] * 0.135;
				velocity[2] = g_boostVel[client][2] * -0.135;
			}
		}

		g_boostStep[client] = 2;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) 
{
	SpectatorCheck(client);
	CheckIfHitInFeet(client);
	
	if(!IsPlayerAlive(client))
	{		
		return Plugin_Continue;
	}
	
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	
	gF_speed[client] = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));
	
	//Player max speed
	if(gF_speed[client] > gF_speedMax[client])
	{
		gF_speedMax[client] = gF_speed[client];
	}
	
	if(GetEntityFlags(client) & FL_ONGROUND && gI_xCount[client] == 0)
	{
		gF_speedMax[client] = 0.0;
		gI_xCount[client] = 0; //Thanks to extrem
		gB_IsPlayerInAir[client] = false;
		gI_PlayerStates[client][IllegalJumpFlags] = IJF_NONE;
	}
	
	if(!(GetEntityFlags(client) & FL_ONGROUND) && gI_xCount[client] > 0)
	{		
		gB_IsPlayerInAir[client] = true;
	}
	
	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	
	if(!IsValidEdict(iGroundEntity))
	{
		return Plugin_Continue;
	}
	
	char sClass[64];
	GetEdictClassname(iGroundEntity, sClass, 64);
	
	//If ground entity is not grenade and boost is not 0
	if(!(StrContains(sClass, "_projectile", false) == -1)) //Thanks to Log
	{
		return Plugin_Continue;
	}
	
	if(!(GetEntityFlags(client) & FL_ONGROUND && gI_xCount[client] > 0)) //Thanks to extrem
	{
		return Plugin_Continue;
	}
	
	if(gI_PlayerStates[client][IllegalJumpFlags] != IJF_TELEPORT)
	{
		GetClientAbsOrigin(client, gF_posFinish[client]);
	}
	
	gF_distance = CalculateJumpDistance(client, gF_posStart[client], gF_posFinish[client]);
	
	if(!gB_IsPlayerInAir[client])
	{	
		return Plugin_Continue;
	}
	
	float fGravity = GetEntPropFloat(client, Prop_Data, "m_flGravity");
	
	if(fGravity != 1.0 && fGravity != 0.0)
	{
		gI_PlayerStates[client][IllegalJumpFlags] = IJF_GRAVITY;
	}
	
	if(gI_PlayerStates[client][IllegalJumpFlags] == IJF_GRAVITY)
	{
		gS_status = "{grey}(GRAV){default}";
	}
	
	if(gI_PlayerStates[client][IllegalJumpFlags] == IJF_NONE)
	{
		gS_status = "";
	}
	
	if(gI_MLStats[client] == 1)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} {default}Counted: {lightgreen}X%i {grey}| {default}Distance: {lightgreen}%.1f {grey}| {default}Max: {lightgreen}%.1f {default}U/S\n %s", gI_xCount[client], gF_distance, gF_speedMax[client], gS_status);
	}
	
	if(gI_MLStats[gI_thrower[client]] == 1 && IsValidClient(gI_thrower[client]) && !IsClientObserver(gI_thrower[client]))
	{
		CPrintToChat(gI_thrower[client], "{green}[Trikz]{lightgreen} {default}Counted: {lightgreen}X%i {grey}| {default}Distance: {lightgreen}%.1f {grey}| {default}Max: {lightgreen}%.1f {default}U/S\n %s", gI_xCount[client], gF_distance, gF_speedMax[client], gS_status);
	}
	
	SpectatorCheck(client);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || !IsPlayerAlive(i)) && gI_MLStats[i] == 1)
		{
			if(gI_SpectatorTarget[i] == client || gI_SpectatorTarget[i] == gI_thrower[client])
			{
				CPrintToChat(i, "{green}[Trikz]{lightgreen} {default}Counted: {lightgreen}X%i {grey}| {default}Distance: {lightgreen}%.1f {grey}| {default}Max: {lightgreen}%.1f {default}U/S\n %s", gI_xCount[client], gF_distance, gF_speedMax[client], gS_status);
			}
		}
	}
	
	gI_xCount[client] = 0; //Thanks to extrem
	gB_IsPlayerInAir[client] = false;
	gI_PlayerStates[client][IllegalJumpFlags] = IJF_NONE;
	
	if(gI_tick == 0)
	{
		gI_tick++;
	}
	
	gF_speedMax[client] = 0.0;
	gI_tick = 0;
	
	return Plugin_Continue;
}

//Thanks to Skipper
float CalculateJumpDistance(any ..., float posStart[3], float posEnd[3])
{
	float X = posEnd[0] - posStart[0];
	float Y = posEnd[1] - posStart[1];
	
	return SquareRoot(Pow(X, 2.0) + Pow(Y, 2.0)) + 32.0;
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

int Native_GetClientStateMLS(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
	
    return gI_MLStats[client];
}