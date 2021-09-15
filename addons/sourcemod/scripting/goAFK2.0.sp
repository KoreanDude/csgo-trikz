#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csgocolors>
#pragma newdecls required

#define CHECK_INTERVAL         1.0
#define isResistant(%1) (g_iAdminFlag == 0 ? GetUserFlagBits(%1)!=0 : (GetUserFlagBits(%1) & g_iAdminFlag || GetUserFlagBits(%1) & ADMFLAG_ROOT))

#define PREFIX    "\x01[\x10GoAFK\x01]"

ConVar g_cvEnablePlugin;
ConVar g_cvPluginMode;
ConVar g_cvMinPlayers;
ConVar g_cvMoveTime;
ConVar g_cvKickTime;
ConVar g_cvWarnTime;
ConVar g_cvAdminImmunity;
ConVar g_cvAdminImmunityFlag;
ConVar g_cvSpectKick;
ConVar g_cvExcludeBots;
ConVar g_cvCheckByKeys;
ConVar g_cvCheckBySpawnPos;
ConVar g_cvCheckByEyePos;
ConVar g_cvCheckByPos;

ConVar g_cvSpawnPosDistance;

bool g_bPluginEnabled;
bool g_bIsCheckTimerEnabled;
bool g_bExcludeBotsFromChecking;
bool g_bShouldCheckByEyePos;
bool g_bShouldCheckBySpawnPos;
bool g_bShouldCheckByKeys;
bool g_bShouldCheckByPos;
bool g_bIsInitialized[MAXPLAYERS+1];
bool g_bHasLeftSpawn[MAXPLAYERS+1];
bool g_bKickSpect;

float g_fMoveTime;
float g_fKickTime;
float g_fWarnTime;
float g_fSpawnPosDistance;
float g_fSpawnTime[MAXPLAYERS+1];
float g_fEyePosition[MAXPLAYERS+1][3];
float g_fClientOrigin[MAXPLAYERS+1][3];
float g_fSpawnPosition[MAXPLAYERS+1][3];
float g_fAfkTime[MAXPLAYERS+1] = {0.0, ...};

int g_iLastPlayerKeys[MAXPLAYERS+1];
int g_iObserverMode[MAXPLAYERS+1];
int g_iObserverTarget[MAXPLAYERS+1];
int g_iPluginMode;
int g_iImmunityMode;
int g_iMinPlayers;
int g_iAdminFlag;

public Plugin myinfo = {
    name = "goAFK Manager",
    author = "SUPER TIMOR/ credits: Dr.Api",
    description = "AFK Manager z dedykacją dla korzystających z goboosting.pl",
    version = "2.0.0",
    url = "https://goboosting.pl"
}

public void OnPluginStart() {
    LoadTranslations("goAFK.phrases");
    g_cvEnablePlugin = CreateConVar("goafk_enable", "1", "1 - ON /// 0 - OFF");
    g_cvPluginMode = CreateConVar("goafk_mode", "2", "1 - KICK / 2 - MOVE TO SPECT")
    g_cvSpectKick = CreateConVar("goafk_kickspect", "1", "If goafk_mode = 1, include spectators to checkin' if AFK?")
    g_cvMinPlayers = CreateConVar("goafk_minplayers", "1", "Minimum amount of players to enable plugin actions")
    g_cvMoveTime = CreateConVar("goafk_movetime", "300.0", "Time to move player");
    g_cvKickTime = CreateConVar("goafk_kicktime", "600.0", "Time to kick player");
    g_cvWarnTime = CreateConVar("goafk_warntime", "270.0", "Time to warn player");    
    g_cvExcludeBots = CreateConVar("goafk_excludebots", "1", "Exclude bots from plugin actions? \n1 = exclude\n 0 = include");
        
    g_cvAdminImmunity = CreateConVar("goafk_adminimmunity", "0", "0 = no immunity for admins \n 1 = complete immunity for admins \n 2 = immunity for kick AFK admins \n 3 = immunity for moving AFK admins");
    g_cvAdminImmunityFlag = CreateConVar("goafk_adminflag", "z", "Admin flag for immunity, blank = any flag");
    
    g_cvCheckByKeys = CreateConVar("goafk_checkbykeys", "1", "1, if you want to include keys check in global checking, 0 otherwise");
    g_cvCheckBySpawnPos = CreateConVar("goafk_checkbyspawnpos", "1", "1, if you want to include spawn position check in global checking, 0 otherwise");
    g_cvCheckByEyePos = CreateConVar("goafk_checkbyeyepos", "1", "1, if you want to include eye position check in global checking, 0 otherwise");
    g_cvCheckByPos = CreateConVar("goafk_checkbypos", "1", "1, if you want to include position check in global checking, 0 otherwise");
    g_cvSpawnPosDistance = CreateConVar("goafk_spawnposdistance", "300.0", "Minimal distance to go from spawn");
    SetFlag(g_cvAdminImmunityFlag);

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_team", Event_PlayerTeam);
    HookEvent("player_death", Event_PlayerDeath);
    
    HookConVarChange(g_cvEnablePlugin, Event_CvarChange);
    HookConVarChange(g_cvPluginMode, Event_CvarChange);
    HookConVarChange(g_cvMinPlayers, Event_CvarChange);
    HookConVarChange(g_cvMoveTime, Event_CvarChange);
    HookConVarChange(g_cvKickTime, Event_CvarChange);
    HookConVarChange(g_cvWarnTime, Event_CvarChange);
    HookConVarChange(g_cvAdminImmunity, Event_CvarChange);
    HookConVarChange(g_cvAdminImmunityFlag, Event_CvarChange);
    HookConVarChange(g_cvSpectKick, Event_CvarChange);    
    HookConVarChange(g_cvExcludeBots, Event_CvarChange);   
    HookConVarChange(g_cvCheckByKeys, Event_CvarChange);
    HookConVarChange(g_cvCheckBySpawnPos, Event_CvarChange);    
    HookConVarChange(g_cvCheckByEyePos, Event_CvarChange);    
    HookConVarChange(g_cvSpawnPosDistance, Event_CvarChange);  
    HookConVarChange(g_cvCheckByPos, Event_CvarChange);  
    
    AutoExecConfig(true, "GoAFK_2.0", "sourcemod");
    g_bIsCheckTimerEnabled = false;
}

public void Event_CvarChange(Handle cvar, const char[] oldValue, const char[] newValue) {
    CvarUpdate();
}

public void OnConfigsExecuted() {
    CvarUpdate();
}

public void OnMapStart() {
    AutoExecConfig(true, "GoAFK", "sourcemod");    
    g_bIsCheckTimerEnabled = false;
    CvarUpdate();
}

void CvarUpdate() {
    g_bPluginEnabled = GetConVarBool(g_cvEnablePlugin);
    g_iPluginMode = GetConVarInt(g_cvPluginMode);
    g_iMinPlayers = GetConVarInt(g_cvMinPlayers);
    g_iImmunityMode = GetConVarInt(g_cvAdminImmunity);
    g_fMoveTime = GetConVarFloat(g_cvMoveTime);
    g_fKickTime = GetConVarFloat(g_cvKickTime);
    g_fWarnTime = GetConVarFloat(g_cvWarnTime);
    g_bKickSpect = GetConVarBool(g_cvSpectKick);
    g_bExcludeBotsFromChecking = GetConVarBool(g_cvExcludeBots);
    
    g_bShouldCheckByKeys = GetConVarBool(g_cvCheckByKeys);
    g_bShouldCheckBySpawnPos = GetConVarBool(g_cvCheckBySpawnPos);
    g_bShouldCheckByEyePos = GetConVarBool(g_cvCheckByEyePos);
    g_bShouldCheckByPos = GetConVarBool(g_cvCheckByPos);
    g_fSpawnPosDistance = GetConVarFloat(g_cvSpawnPosDistance);
    SetFlag(g_cvAdminImmunityFlag);
    if(g_bPluginEnabled) {
        if(!g_bIsCheckTimerEnabled) {
            g_bIsCheckTimerEnabled = true;
            CreateTimer(CHECK_INTERVAL, Timer_CheckPlayerAfkManagerCsgo, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        }
        
        for (int i = 1; i <= MaxClients; i++) {
            g_bIsInitialized[i] = false;
            
            if (IsClientConnected(i) && IsClientInGame(i))
                InitializeClient(i);
        }
    }
}

void SetFlag(ConVar convar) {
    char flags[4];
    AdminFlag flag;
    GetConVarString(convar, flags, sizeof(flags));
    if(flags[0]!='\0' && FindFlagByChar(flags[0], flag))
         g_iAdminFlag = FlagToBit(flag);
    else 
        g_iAdminFlag = 0;
}

public void OnClientPostAdminCheck(int client) {
    if(g_bPluginEnabled) {
        if(IsFakeClient(client) && g_bExcludeBotsFromChecking)
            return;
        else
            g_bIsInitialized[client] = true;
    }
}

public void OnClientDisconnect(int client) {
    if(g_bPluginEnabled)
        g_bIsInitialized[client] = false;
}

public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
    if(g_bPluginEnabled) {
        int client = GetClientOfUserId(GetEventInt(event, "userid"));
        if(IsFakeClient(client) && g_bExcludeBotsFromChecking)
            return;

        g_fSpawnTime[client] = GetEngineTime();
        GetClientAbsOrigin(client, g_fSpawnPosition[client]);
        
        if(IsValidClient(client) && !IsClientObserver(client) && IsPlayerAlive(client)) {
            ResetAFKVariables(client);
            g_bHasLeftSpawn[client] = false;
        }
    }
}

public void Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast) {
    if(g_bPluginEnabled) {
        int client = GetClientOfUserId(GetEventInt(event, "userid"));
        int team = GetEventInt(event, "team");
        if(IsFakeClient(client) && g_bExcludeBotsFromChecking)
            return;
            
        if(!IsValidClient(client))
            return;
            
        if(!g_bIsInitialized[client])
            InitializeClient(client);
            
        if(team != 1) {
            if(g_bIsInitialized[client])
                ResetAFKVariables(client);
        }
        else {
            GetClientEyeAngles(client, g_fEyePosition[client]);
            g_iObserverMode[client] = GetEntProp(client, Prop_Send, "m_iObserverMode");
            g_iObserverTarget[client] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        }
    }
}

public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
    if(g_bPluginEnabled) {
        int client = GetClientOfUserId(GetEventInt(event, "userid"));
        ResetAFKVariables(client);
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    if(!g_bPluginEnabled || !g_bShouldCheckByKeys || !IsValidClient(client))
        return Plugin_Continue;

    static int time[MAXPLAYERS+1];
    
    if(g_iLastPlayerKeys[client] != buttons && GetTime() > time[client]) {
        g_iLastPlayerKeys[client] = buttons;
        time[client] = GetTime() + RoundFloat(CHECK_INTERVAL);
    }
    
    return Plugin_Continue;
}

public Action Timer_CheckPlayerAfkManagerCsgo(Handle timer, any data) {
    int playersNow = GetClientCount(true);  
    if(g_iMinPlayers > playersNow)
        return Plugin_Continue;
        
    int clientTeam; 
    float fEyePosition[3], fClientOrigin[3];
    
    for(int client = 1; client <= MaxClients; client++) {
        if(!IsValidClient(client) || !g_bIsInitialized[client] || !IsClientInGame(client))
            continue;
        clientTeam = GetClientTeam(client);
        if(IsClientObserver(client) && g_bKickSpect) {    
            if(clientTeam != CS_TEAM_SPECTATOR && !IsPlayerAlive(client))
                continue; 
            
            if(!clientTeam || CheckSpectatorAFK(client)) {
                AddPointAndCheckPlayerAFK(client);
                return Plugin_Continue;
            }
            else {
                ResetAFKVariables(client);
                continue;
            }
        }
        
        if(GetEntityMoveType(client) == MOVETYPE_NONE || (GetEntityFlags(client) & FL_FROZEN)) {
            ResetAFKVariables(client);
            return Plugin_Continue;
        }

        fEyePosition = g_fEyePosition[client];
        fClientOrigin = g_fClientOrigin[client];
        GetClientEyeAngles(client, g_fEyePosition[client]);
        GetClientAbsOrigin(client, g_fClientOrigin[client]);
            
        if(g_bShouldCheckByEyePos) { 
            bool bIsMovingCursor = false;
            for(int i = 0; i < 3; i++) {
                if(g_fEyePosition[client][i] != fEyePosition[i]) {
                    bIsMovingCursor = true;
                    break;
                }
            }
            if(!bIsMovingCursor) {
                AddPointAndCheckPlayerAFK(client);
                return Plugin_Continue;
            }
        }
        
        if(g_bShouldCheckBySpawnPos && !g_bHasLeftSpawn[client]) {
            if(GetVectorDistance(g_fClientOrigin[client], g_fSpawnPosition[client]) >= g_fSpawnPosDistance)
                g_bHasLeftSpawn[client] = true;
            else {
                AddPointAndCheckPlayerAFK(client);
                return Plugin_Continue;
            }
        }
        
        if(g_bShouldCheckByPos) {
            bool bIsSamePosition = true;
            for(int i = 0; i < 3; i++) {
                if(g_fClientOrigin[client][i] != fClientOrigin[i]) {
                    bIsSamePosition = false;
                    break;
                }
            }
            
            if(bIsSamePosition) {
                AddPointAndCheckPlayerAFK(client);
                return Plugin_Continue;
            }
        }
        if(g_bShouldCheckByKeys) {
            if(g_iLastPlayerKeys[client] == GetClientButtons(client) && GetClientButtons(client) > 0) {
                AddPointAndCheckPlayerAFK(client);
                return Plugin_Continue;
            }
        }
        ResetAFKVariables(client);
    }
    return Plugin_Continue;
}

public void AddPointAndCheckPlayerAFK(int client) {
    if(!IsValidClient(client))
        return;
        
    float timeleft;
    g_fAfkTime[client] ++;
    switch(g_iPluginMode) {
        case 1: {
            if(!g_iImmunityMode || g_iImmunityMode == 3 || !isResistant(client)) {
                timeleft = g_fKickTime - g_fAfkTime[client];
                if(timeleft > 0.0) {
                    if(timeleft <= g_fWarnTime)
                        CPrintToChat(client, "%t", "Kick_Warning", RoundToFloor(timeleft));
                }
                else {
                    char clientName[MAX_NAME_LENGTH+4];
                    Format(clientName,sizeof(clientName),"%N",client);
                    CPrintToChatAll("%t", "Kick_Announce", clientName);
                    KickClient(client, "%t", "Kick_Message");
                }
            }
        }
        case 2: {
            if(GetClientTeam(client) > 1 && (!g_iImmunityMode || g_iImmunityMode == 2 || !isResistant(client))) {
                timeleft = g_fMoveTime - g_fAfkTime[client];
                if(timeleft > 0.0) {
                    if(timeleft <= g_fWarnTime)
                        CPrintToChat(client, "%t", "Move_Warning", RoundToFloor(timeleft));
                }
                else {
                    char clientName[MAX_NAME_LENGTH+4];
                    Format(clientName,sizeof(clientName),"%N",client);
                    CPrintToChatAll("%t", "Move_Announce", clientName);    
                    int death = GetEntProp(client, Prop_Data, "m_iDeaths");
                    int frags = GetEntProp(client, Prop_Data, "m_iFrags");
					ForcePlayerSuicide(client);
                    ChangeClientTeam(client, 1);
                    SetEntProp(client, Prop_Data, "m_iFrags", frags);
                    SetEntProp(client, Prop_Data, "m_iDeaths", death);
                }
            }
        }
    }
}

bool CheckSpectatorAFK(int client) {
    int lastTarget; 
    int lastObserverMode = g_iObserverMode[client];
    g_iObserverMode[client] = GetEntProp(client, Prop_Send, "m_iObserverMode");
    
    if(lastObserverMode > 0 && g_iObserverMode[client] != lastObserverMode)
        return false;

    float EyeLocation[3];
    EyeLocation = g_fEyePosition[client];
    
    if(g_iObserverMode[client] == 6)
        GetClientEyeAngles(client, g_fEyePosition[client]);
    else {
        lastTarget = g_iObserverTarget[client];
        g_iObserverTarget[client] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

        if(lastObserverMode == 0 && lastTarget == 0)
            return true;

        if(lastTarget > 0 && g_iObserverTarget[client] != lastTarget) {
            if (lastTarget > MaxClients || !IsClientConnected(lastTarget) || !IsClientInGame(lastTarget))
                return false;
            return (!IsPlayerAlive(lastTarget));
        }
    }

    if((g_fEyePosition[client][0] == EyeLocation[0]) && (g_fEyePosition[client][1] == EyeLocation[1]) && (g_fEyePosition[client][2] == EyeLocation[2]))
        return true;
    
    return false;
}

void ResetAFKVariables(int client) {
    g_fAfkTime[client] = 0.0;
    for(int i = 0; i < 3; i++)
        g_fEyePosition[client][i] = 0.0;
        
    g_iObserverMode[client] = g_iObserverTarget[client] = 0;
}

void InitializeClient(int client) {
    if(g_bPluginEnabled) {
        if(IsFakeClient(client) && g_bExcludeBotsFromChecking)
            return;
            
        g_bIsInitialized[client] = true;
        ResetAFKVariables(client);
    }
}

int GetPlayersAlive(int team) {
    int iCount = 0;
    for(int i = 1; i <= MaxClients; i++)  {
        if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)
            iCount++; 
    }
    return iCount; 
}

bool IsValidClient(int client) {
    if(IsClientInGame(client) && client >= 1 && client <= MaxClients)
        return true;

    return false;
}
