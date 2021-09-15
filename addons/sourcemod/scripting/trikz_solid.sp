#define MAX_SOLIDS 1024
#define MAX_COUNTERS 128

#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <dhooks>
#include <trikz>
#include <shavit>
#include <collisionhook>
#include <outputinfo_botox>

#pragma tabsize 0
#define VERSION "0.2"

public Plugin:myinfo = 
{
    name = "trikz solidity",
    author = "george, Modified by. SHIM",
    description = "navy seals or something",
    version = VERSION,
    url = ""
}

Handle g_hAcceptInput;
Handle g_hCheckSolidity;

bool g_bLateLoad = false;
bool g_bAllowSpawnBreakables;
bool g_bUsedEdict[2049];
bool g_bAllowCollision[2049];
bool g_bFlashbang[2049];
bool g_bPlayerSolid[MAX_SOLIDS][MAXPLAYERS + 1];
bool g_bWasSolid[MAX_SOLIDS][MAXPLAYERS + 1];
bool g_bStartTouch[MAX_SOLIDS][MAXPLAYERS + 1];
bool g_bNotDefault[MAX_SOLIDS][MAXPLAYERS + 1];
bool g_bDefaultState[MAX_SOLIDS];
int g_iSolidIds[MAX_SOLIDS];
int g_iPointSolidSpawn[MAX_SOLIDS];
int g_iAllowedToggles[MAX_SOLIDS][MAXPLAYERS + 1];
int g_iOldToggles[MAX_SOLIDS][MAXPLAYERS + 1];
int g_iToggleAmount[MAX_SOLIDS][12];
int g_iLinkedSolids[2049][12];

int g_CurrentSolid = 0;

bool g_bClientButton[2049];
bool g_bButtonLockedDefault[2049];
bool g_bButtonLocked[2049][MAXPLAYERS + 1];
bool g_bButtonFound[2049];
float g_fButtonDelay[2049];
float g_fButtonNextPress[2049][MAXPLAYERS + 1];

float g_fMathCounterValue[MAX_COUNTERS][MAXPLAYERS + 1];
int g_iMathCounters[MAX_COUNTERS];
float g_fMathCounterDefaultValue[MAX_COUNTERS];
float g_fMathCounterMin[MAX_COUNTERS];
float g_fMathCounterMax[MAX_COUNTERS];

int g_CurrentCounter = 0;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLateLoad = late;
    
    CreateNative("Trikz_IsToggleableEnabledForPlayer", Native_IsToggleableEnabledForPlayer);
    CreateNative("Trikz_IsEntityToggleable", Native_IsEntityToggleable);
}

public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
    
    g_hCheckSolidity = CreateGlobalForward("Trikz_CheckSolidity", ET_Hook, Param_Cell, Param_Cell)
        
    Handle hGameData = LoadGameConfigFile("sdktools.games");
    if (!hGameData)
        SetFailState("Failed to load sdktools gamedata.");
    
    int offset = GameConfGetOffset(hGameData, "AcceptInput"); //createfromconf is borked with object types lmao
    g_hAcceptInput = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity);
    DHookAddParam(g_hAcceptInput, HookParamType_CharPtr);
    DHookAddParam(g_hAcceptInput, HookParamType_CBaseEntity);
    DHookAddParam(g_hAcceptInput, HookParamType_CBaseEntity);
    DHookAddParam(g_hAcceptInput, HookParamType_Object, 20, DHookPass_ByVal|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP); //varaint_t is a union of 12 (float[3]) plus two int type params 12 + 8 = 20
    DHookAddParam(g_hAcceptInput, HookParamType_Int);
    
    if(!g_hAcceptInput)
    {
        delete hGameData;
        SetFailState("Failed to setup detour for AcceptInput");
    }
    
    delete hGameData;

    if(g_bLateLoad)
        CreateTimer(1.0,Timer_FindAllValidSolids,_,TIMER_FLAG_NO_MAPCHANGE);
}

//public OnTrikzNewPartner(int client, int partner)
public Trikz_OnPartner(int client, int partner)
{
    for(int i = 0; i < g_CurrentSolid; i++)
    {
        g_bPlayerSolid[i][client] = g_bDefaultState[i];
        g_bPlayerSolid[i][partner] = g_bDefaultState[i];
        
        g_iOldToggles[i][partner] = g_iAllowedToggles[i][partner];
        g_iOldToggles[i][client] = g_iAllowedToggles[i][client];
        
        g_iAllowedToggles[i][partner] = 0;
        g_iAllowedToggles[i][client] = 0;
        
        g_bStartTouch[i][partner] = false;
        g_bStartTouch[i][client] = false;
    }
    
    for(int i = 0; i <= 2048; i++)
    {
        g_bButtonLocked[i][client] = g_bButtonLockedDefault[i];
        g_bButtonLocked[i][partner] = g_bButtonLockedDefault[i];
        g_fButtonNextPress[i][client] = 0.0;
        g_fButtonNextPress[i][partner] = 0.0;
    }
    
    for(int i = 0; i < g_CurrentCounter; i++)
    {
        g_fMathCounterValue[i][client] = g_fMathCounterDefaultValue[i];
        g_fMathCounterValue[i][partner] = g_fMathCounterDefaultValue[i];
    }
}

//public OnTrikzBreakup(int client, int partner)
public Trikz_OnBreakPartner(int client, int partner)
{
    for(int i = 0; i < g_CurrentSolid; i++)
    {
        g_bPlayerSolid[i][client] = g_bDefaultState[i];
        g_bPlayerSolid[i][partner] = g_bDefaultState[i];
        
        g_bStartTouch[i][partner] = false;
        g_bStartTouch[i][client] = false;
        
        g_iAllowedToggles[i][partner] = 0;
        g_iAllowedToggles[i][client] = 0;
        g_iOldToggles[i][client] = 0;
        g_iOldToggles[i][partner] = 0;
    }
    
    for(int i = 0; i <= 2048; i++)
    {
        g_bButtonLocked[i][client] = g_bButtonLockedDefault[i];
        g_bButtonLocked[i][partner] = g_bButtonLockedDefault[i];
        g_fButtonNextPress[i][client] = 0.0;
        g_fButtonNextPress[i][partner] = 0.0;
    }
    
    for(int i = 0; i < g_CurrentCounter; i++)
    {
        g_fMathCounterValue[i][client] = g_fMathCounterDefaultValue[i];
        g_fMathCounterValue[i][partner] = g_fMathCounterDefaultValue[i];
    }
}

public void OnClientPutInServer(int client)
{
    for(int i = 0; i < g_CurrentSolid; i++)
    {
        g_iAllowedToggles[i][client] = 0;
        g_bStartTouch[i][client] = false;
        g_bNotDefault[i][client] = false;
    }
    
    for(int i = 0; i <= 2048; i++)
    {
        g_fButtonNextPress[i][client] = 0.0;
        g_bButtonLocked[i][client] = g_bButtonLockedDefault[i];
    }
}

//public OnTimerStart_Post(int client, int Type, int Style)
public Shavit_OnEnterZonePartnerMode(int client, int type, int track, int id, int entity, int data)
{
	if(type == Zone_Start && track != Track_Solobonus)
	{
		int partner = Trikz_FindPartner(client);
		
		if(partner != -1)
		{
			for(int i = 0; i < g_CurrentSolid; i++)
			{
				g_bStartTouch[i][client] = false;
				g_bStartTouch[i][partner] = false;
				g_bPlayerSolid[i][client] = g_bDefaultState[i];
				g_bPlayerSolid[i][partner] = g_bDefaultState[i];
				g_iAllowedToggles[i][client] = 0;
				g_iAllowedToggles[i][partner] = 0;
				g_iOldToggles[i][partner] = g_iAllowedToggles[i][partner];
                g_iOldToggles[i][client] = g_iAllowedToggles[i][client];
			}
			
			for(int i = 0; i <= 2048; i++)
			{
				g_bButtonLocked[i][client] = g_bButtonLockedDefault[i];
				g_bButtonLocked[i][partner] = g_bButtonLockedDefault[i];
				g_fButtonNextPress[i][client] = 0.0;
				g_fButtonNextPress[i][partner] = 0.0;
			}
			
			for(int i = 0; i < g_CurrentCounter; i++)
			{
				g_fMathCounterValue[i][client] = g_fMathCounterDefaultValue[i];
				g_fMathCounterValue[i][partner] = g_fMathCounterDefaultValue[i];
			}
		}
	}
}

public Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data)
{
	if(type == Zone_Start && track == Track_Solobonus)
	{		
		//PrintToChatAll("%i", g_CurrentSolid);
		
		for(int i = 0; i < g_CurrentSolid; i++)
		{
			g_bStartTouch[i][client] = false;
			g_bPlayerSolid[i][client] = g_bDefaultState[i];
			g_iAllowedToggles[i][client] = 0;
			g_iOldToggles[i][client] = g_iAllowedToggles[i][client];
		}
		
		for(int i = 0; i <= 2048; i++)
		{
			g_bButtonLocked[i][client] = g_bButtonLockedDefault[i];
			g_fButtonNextPress[i][client] = 0.0;
		}
		
		for(int i = 0; i < g_CurrentCounter; i++)
		{
			g_fMathCounterValue[i][client] = g_fMathCounterDefaultValue[i];
		}
	}
}

// bool CBaseEntity::AcceptInput(char const*, CBaseEntity*, CBaseEntity*, variant_t, int)
public MRESReturn AcceptInputCounter(int pThis, Handle hReturn, Handle hParams)
{
    int iCounterId = -1;
    
    for(int i = 0; i < g_CurrentCounter; i++)
    {
        if(g_iMathCounters[i] == pThis)
        {
            iCounterId = i;
            break;
        }
    }
    
    if(iCounterId == -1)
        return MRES_Ignored;
        
    static char input[64];
    
    DHookGetParamString(hParams, 1, input, sizeof(input));
    
    if(!StrEqual(input, "Add") && !StrEqual(input, "Subtract") && !StrEqual(input, "SetValue") && !StrEqual(input, "SetValueNoFire"))
        return MRES_Ignored;
        
    int realactivator = 0;
    
    if(!DHookIsNullParam(hParams, 2))
        realactivator = DHookGetParam(hParams, 2);
        
    int activator = realactivator;
        
    if(0 > activator || activator > MaxClients)
    {
        DHookSetReturn(hReturn, false);
        return MRES_Supercede;
    }
        
    int partner = Trikz_FindPartner(activator);
    if(partner == -1)
	{
        activator = 0;
        partner = 0;
	}
    
    static char sValue[128];
    
    DHookGetParamObjectPtrString(hParams, 4, 0, ObjectValueType_String, sValue, sizeof(sValue));

    float flVal = StringToFloat(sValue);

    if(StrEqual(input, "Add"))
    {
        if(g_fMathCounterValue[iCounterId][activator] < g_fMathCounterMax[iCounterId])
        {
            g_fMathCounterValue[iCounterId][activator] = g_fMathCounterValue[iCounterId][activator] + flVal;
            g_fMathCounterValue[iCounterId][partner] = g_fMathCounterValue[iCounterId][activator];
            
            if(g_fMathCounterValue[iCounterId][activator] >= g_fMathCounterMax[iCounterId])
            {
                g_fMathCounterValue[iCounterId][activator] = g_fMathCounterMax[iCounterId];
                g_fMathCounterValue[iCounterId][partner] = g_fMathCounterMax[iCounterId];
                
                AcceptEntityInput(pThis, "FireUser3", realactivator, realactivator);
            }
        }
    }
    else if(StrEqual(input, "Subtract"))
    {
        if(g_fMathCounterValue[iCounterId][activator] > g_fMathCounterMin[iCounterId])
        {
            g_fMathCounterValue[iCounterId][activator] = g_fMathCounterValue[iCounterId][activator] - flVal;
            g_fMathCounterValue[iCounterId][partner] = g_fMathCounterValue[iCounterId][activator];
            
            if(g_fMathCounterValue[iCounterId][activator] <= g_fMathCounterMin[iCounterId])
            {
                g_fMathCounterValue[iCounterId][activator] = g_fMathCounterMin[iCounterId];
                g_fMathCounterValue[iCounterId][partner] = g_fMathCounterMin[iCounterId];
                
                AcceptEntityInput(pThis, "FireUser4", realactivator, realactivator);
            }
        }
    }
    else
    {
        g_fMathCounterValue[iCounterId][activator] = flVal;
        g_fMathCounterValue[iCounterId][partner] = flVal;
        
        //PrintToServer("FLVALUE %s, %f", sValue, flVal);
        
        if(g_fMathCounterValue[iCounterId][activator] < g_fMathCounterMin[iCounterId])
        {
            g_fMathCounterValue[iCounterId][activator] = g_fMathCounterMin[iCounterId];
            g_fMathCounterValue[iCounterId][partner] = g_fMathCounterMin[iCounterId];
        }
        else if(g_fMathCounterValue[iCounterId][activator] > g_fMathCounterMax[iCounterId])
        {
            g_fMathCounterValue[iCounterId][activator] = g_fMathCounterMax[iCounterId];
            g_fMathCounterValue[iCounterId][partner] = g_fMathCounterMax[iCounterId];
        }
    }
    
    DHookSetReturn(hReturn, false);
    return MRES_Supercede;
}

// bool CBaseEntity::AcceptInput(char const*, CBaseEntity*, CBaseEntity*, variant_t, int)
public MRESReturn AcceptInputButton(int pThis, Handle hReturn, Handle hParams)
{
    if(!g_bButtonFound[pThis])
        return MRES_Ignored;
        
    static char input[64];
    
    DHookGetParamString(hParams, 1, input, sizeof(input));
    
    if(!StrEqual(input, "Lock") && !StrEqual(input, "Unlock"))
        return MRES_Ignored;
        
    int activator = 0;
    
    if(!DHookIsNullParam(hParams, 2))
        activator = DHookGetParam(hParams, 2);
        
    if(0 > activator || activator > MaxClients)
    {
        DHookSetReturn(hReturn, false);
        return MRES_Supercede;
    }
        
    int partner = Trikz_FindPartner(activator);
    if(partner == -1)
	{
        activator = 0;
        partner = 0;
	}
        
    if(StrEqual(input, "Lock"))
    {
        g_bButtonLocked[pThis][activator] = true;
        g_bButtonLocked[pThis][partner] = true;
    }
    else
    {
        g_bButtonLocked[pThis][activator] = false;
        g_bButtonLocked[pThis][partner] = false;
    }
    
    DHookSetReturn(hReturn, false);
    return MRES_Supercede;
}

// bool CBaseEntity::AcceptInput(char const*, CBaseEntity*, CBaseEntity*, variant_t, int)
public MRESReturn AcceptInputToggle(int pThis, Handle hReturn, Handle hParams)
{
    bool bIsTemplate = false;
    bool bIsSolid = false;
    int iSolidId = 0;
    
    for(int i = 0; i < g_CurrentSolid; i++)
    {
        if(g_iSolidIds[i] == pThis)
        {
            bIsSolid = true;
            iSolidId = i;
            break;
        }
        
        if(g_iPointSolidSpawn[i] == pThis)
        {
            bIsTemplate = true;
            iSolidId = i;
            break;
        }
    }
    
    if(!bIsSolid && !bIsTemplate)
        return MRES_Ignored;
        
    static char input[64];
    
    DHookGetParamString(hParams, 1, input, sizeof(input));
    
    if(!StrEqual(input, "Enable") && !StrEqual(input, "Disable") && !StrEqual(input, "Break") && !StrEqual(input, "Toggle") && !StrEqual(input, "ForceSpawn"))
        return MRES_Ignored;
    
    int realactivator = 0;
    
    if(!DHookIsNullParam(hParams, 2))
        realactivator = DHookGetParam(hParams, 2);
    
    int activator = realactivator;

    if(0 > activator || activator > MaxClients)
    {
        DHookSetReturn(hReturn, false);
        return MRES_Supercede;
    }
        
    int partner = Trikz_FindPartner(activator);
    if(partner == -1)
	{
        activator = 0;
        partner = 0;
	}
        
    if(StrEqual(input, "Disable"))
    {
        g_bPlayerSolid[iSolidId][activator] = false;
        g_bPlayerSolid[iSolidId][partner] = false;
        
        if(activator == 0 && g_bPlayerSolid[iSolidId][activator] != g_bDefaultState[iSolidId])
            g_bNotDefault[iSolidId][realactivator] = true;
        else if(activator == 0)
            g_bNotDefault[iSolidId][realactivator] = false;
        else if(g_bNotDefault[iSolidId][realactivator] && g_bDefaultState[iSolidId] == false)
        {
            g_bNotDefault[iSolidId][0] = false;
            g_bPlayerSolid[iSolidId][0] = false;
        }
    }
    else if(StrEqual(input, "Break"))
    {
        g_bPlayerSolid[iSolidId][activator] = false;
        g_bPlayerSolid[iSolidId][partner] = false;
        AcceptEntityInput(pThis, "FireUser4", activator, pThis);
        
        if(activator == 0 && g_bPlayerSolid[iSolidId][activator] != g_bDefaultState[iSolidId])
            g_bNotDefault[iSolidId][realactivator] = true;
        else if(activator == 0)
            g_bNotDefault[iSolidId][realactivator] = false;
        else if(g_bNotDefault[iSolidId][realactivator] && g_bDefaultState[iSolidId] == false)
        {
            g_bNotDefault[iSolidId][realactivator] = false;
            g_bPlayerSolid[iSolidId][0] = false;
        }
    }
    else if(StrEqual(input, "Toggle"))
    {
        if(g_iAllowedToggles[iSolidId][activator])
        {
            g_iAllowedToggles[iSolidId][activator] -= 1;
            g_iAllowedToggles[iSolidId][partner] = g_iAllowedToggles[iSolidId][activator];
            
            g_bPlayerSolid[iSolidId][activator] = !g_bPlayerSolid[iSolidId][activator];
            g_bPlayerSolid[iSolidId][partner] = g_bPlayerSolid[iSolidId][activator];
            
            if(activator == 0 && g_iAllowedToggles[iSolidId][realactivator])
                g_iAllowedToggles[iSolidId][realactivator] -= 1;
        }
        
        if(g_iOldToggles[iSolidId][activator])
        {
            g_iOldToggles[iSolidId][activator] -= 1;
            
            g_bPlayerSolid[iSolidId][0] = !g_bPlayerSolid[iSolidId][0];
        }
        
        if(activator == 0 && g_bPlayerSolid[iSolidId][activator] != g_bDefaultState[iSolidId])
            g_bNotDefault[iSolidId][realactivator] = true;
        else if(activator == 0)
            g_bNotDefault[iSolidId][realactivator] = false;
    }
    else if(StrEqual(input, "Enable"))
    {
        g_bPlayerSolid[iSolidId][activator] = true;
        g_bPlayerSolid[iSolidId][partner] = true;
        
        if(activator == 0 && g_bPlayerSolid[iSolidId][activator] != g_bDefaultState[iSolidId])
            g_bNotDefault[iSolidId][realactivator] = true;
        else if(activator == 0)
            g_bNotDefault[iSolidId][realactivator] = false;
        else if(g_bNotDefault[iSolidId][realactivator] && g_bDefaultState[iSolidId] == true)
        {
            g_bNotDefault[iSolidId][realactivator] = false;
            g_bPlayerSolid[iSolidId][0] = true;
        }
    }
    else
    {
        g_bPlayerSolid[iSolidId][activator] = true; //forcespawn
        g_bPlayerSolid[iSolidId][partner] = true;
        g_bAllowSpawnBreakables = false;
        
        if(activator == 0 && g_bPlayerSolid[iSolidId][activator] != g_bDefaultState[iSolidId])
            g_bNotDefault[iSolidId][realactivator] = true;
        else if(activator == 0)
            g_bNotDefault[iSolidId][realactivator] = false;
        else if(g_bNotDefault[iSolidId][realactivator] && g_bDefaultState[iSolidId] == true)
        {
            g_bNotDefault[iSolidId][realactivator] = false;
            g_bPlayerSolid[iSolidId][0] = true;
        }
        
        CreateTimer(0.02, Timer_AllowBreakableSpawn, _, TIMER_FLAG_NO_MAPCHANGE);
        return MRES_Ignored;
    }
    
    DHookSetReturn(hReturn, false);
    return MRES_Supercede;
}

public Action Timer_AllowBreakableSpawn(Handle timer, any data)
{
    g_bAllowSpawnBreakables = true;
    return Plugin_Handled;
}

public void OnMapStart()
{
    for (int i = 0; i < MAX_SOLIDS; i++)
    {
        g_iSolidIds[i] = 0;
        
        for(int j = 0; j < 12; j++)
        {
            g_iToggleAmount[i][j] = 0;
        }
        
        for(int j = 0; j <= MaxClients; j++)
        {
            g_iAllowedToggles[i][j] = 0;
            g_bNotDefault[i][j] = false;
        }
    }
    
    for (int i = 0; i < MAX_COUNTERS; i++)
    {
        g_iMathCounters[i] = 0;
    }
    
    for (int i = 0; i <= 2048; i++)
    {
        g_bUsedEdict[i] = false;
        g_bButtonFound[i] = false;
        
        for(int j = 0; j < 12; j++)
        {
            g_iLinkedSolids[i][j] = -1;
        }
        
        for(int j = 0; j <= MaxClients; j++)
        {
            g_fButtonNextPress[i][j] = 0.0;
            g_bButtonLocked[i][j] = false;
        }
        
        g_bButtonLockedDefault[i] = false;
    }
    
    g_bAllowSpawnBreakables = true;
    g_CurrentSolid = 0;
    g_CurrentCounter = 0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if(0 < entity <= 2048)
    {
        g_bAllowCollision[entity] = true;
        g_bFlashbang[entity] = false;
    }

    if(IsValidEntity(entity) && StrEqual(classname,"func_breakable"))
    {
        SDKHook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
        g_bAllowCollision[entity] = false;
    }
    
    if(IsValidEntity(entity) && StrEqual(classname, "flashbang_projectile"))
        g_bFlashbang[entity] = true;
    else if(0 <= entity <= 2048)
        g_bFlashbang[entity] = false;
}

public Action Hook_SpawnPost(int entity)
{
    if(!IsValidEntity(entity))
        return Plugin_Continue;
        
    if(!g_bAllowSpawnBreakables)
    {
        AcceptEntityInput(entity, "Kill"); //KILL THAT MOFO BREAKABLE
    }
    else
        g_bAllowCollision[entity] = true;
            
    return Plugin_Continue;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GameRules_GetProp("m_bWarmupPeriod") == 1)
		return;
	
    CreateTimer(1.0,Timer_FindAllValidSolids,_,TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_FindAllValidSolids(Handle timer)
{
    static char sDebug1[128];
    static char sDebug2[128];

    new ent = -1;
    while ((ent = FindEntityByClassname(ent, "trigger_*")) != -1)
    {
        if(!IsValidEdict(ent))
            continue;
    
        if (!(GetEntProp(ent, Prop_Data, "m_spawnflags") & 1))
            continue;
        
        GetEntPropString(ent, Prop_Data, "m_iName", sDebug1, sizeof(sDebug1));
        
        GetEdictClassname(ent, sDebug2, sizeof(sDebug2));
        
        //PrintToServer("PROCESSING: %s | %s", sDebug1, sDebug2);
        
        //PrintToServer("OUTPUT OnStartTouch:");
        FindAllSolidsWithOutput(ent, "OnStartTouch");
        //PrintToServer("OUTPUT OnEndTouch:");
        FindAllSolidsWithOutput(ent, "OnEndTouch");
        
        char classname[64];
        
        GetEdictClassname(ent, classname, sizeof(classname));
        
        if(StrEqual(classname,"trigger_multiple"))
            FindAllSolidsWithOutput(ent, "OnTrigger");
    }
    
    while ((ent = FindEntityByClassname(ent, "func_button")) != -1)
    {
        if(!IsValidEdict(ent))
            continue;
            
        SDKHook(ent, SDKHook_OnTakeDamage, Button_OnTakeDamage_Fix);
            
        GetEntPropString(ent, Prop_Data, "m_iName", sDebug1, sizeof(sDebug1));
        
        GetEdictClassname(ent, sDebug2, sizeof(sDebug2));
        
        //PrintToServer("PROCESSING: %s | %s", sDebug1, sDebug2);
            
        //PrintToServer("OUTPUT OnPressed:");
        g_bClientButton[ent] = FindAllSolidsWithOutput(ent, "OnPressed");
        //PrintToServer("OUTPUT OnDamaged:");
        FindAllSolidsWithOutput(ent, "OnDamaged");
        
        if(!(GetEntProp(ent, Prop_Data, "m_spawnflags") & 1))
            g_bClientButton[ent] = false;
        
        if(g_bClientButton[ent])
        {
            g_fButtonDelay[ent] = GetEntPropFloat(ent, Prop_Data, "m_flWait");
            SetEntPropFloat(ent, Prop_Data, "m_flWait", 0.1);
            SDKHook(ent, SDKHook_Use, OnUse);
            SetEntProp(ent, Prop_Data, "m_fStayPushed", 0);
        }
    }
    
    return Plugin_Handled;
}

bool FindAllSolidsWithOutput(int entity, const char[] output)
{
    char sOutput[32];
    FormatEx(sOutput, sizeof(sOutput), "m_%s", output);
    
    int count = GetOutputActionCount(entity, sOutput);
    
    //PrintToServer("-> Count: %i", count);
    
    bool ret = true;
    
    for (int i = 0; i < count; i++)
    {
        static char input[64];
        static char target[64];
        
        GetOutputActionTargetInput(entity, sOutput, i, input, sizeof(input));
        
        //PrintToServer("-> %i: INPUT = %s", i, input);
        
        if (StrEqual(input,"Enable",false) || StrEqual(input,"Disable",false) || StrEqual(input,"Toggle",false) || StrEqual(input,"Break",false))
        {
            GetOutputActionTarget(entity, sOutput, i, target, sizeof(target));
            
            //PrintToServer("-> %i: TARGET = %s", i, target);
            
            int entityS = 0;
            
            if(StrEqual(input,"Toggle",false))
            {
                entityS = entity;
                if(StrEqual(output,"OnHitMax"))
				{
                    //HookSingleEntityOutput(entity, "OnUser3", OnToggleEntity);
					HookEntityOutput("func_brush", "OnUser3", OnToggleEntity);
					HookEntityOutput("func_wall_toggle", "OnUser3", OnToggleEntity);
					HookEntityOutput("trigger_teleport", "OnUser3", OnToggleEntity);
					HookEntityOutput("trigger_teleport_relative", "OnUser3", OnToggleEntity);
					HookEntityOutput("trigger_multiple", "OnUser3", OnToggleEntity);
					HookEntityOutput("trigger_push", "OnUser3", OnToggleEntity);
					HookEntityOutput("func_button", "OnUser3", OnToggleEntity);
					HookEntityOutput("math_counter", "OnUser3", OnToggleEntity);
				}
                else if(StrEqual(output,"OnHitMin"))
				{
                    //HookSingleEntityOutput(entity, "OnUser4", OnToggleEntity);
					HookEntityOutput("func_brush", "OnUser4", OnToggleEntity);
					HookEntityOutput("func_illusionary", "OnUser4", OnToggleEntity)
					HookEntityOutput("func_wall_toggle", "OnUser4", OnToggleEntity);
					HookEntityOutput("trigger_teleport", "OnUser4", OnToggleEntity);
					HookEntityOutput("trigger_teleport_relative", "OnUser4", OnToggleEntity);
					HookEntityOutput("trigger_multiple", "OnUser4", OnToggleEntity);
					HookEntityOutput("trigger_push", "OnUser4", OnToggleEntity);
					HookEntityOutput("func_button", "OnUser4", OnToggleEntity);
					HookEntityOutput("math_counter", "OnUser4", OnToggleEntity);
				}
                else
				{
                    //HookSingleEntityOutput(entity, output, OnToggleEntity);
					HookEntityOutput("func_brush", output, OnToggleEntity);
					HookEntityOutput("func_illusionary", output, OnToggleEntity);
					HookEntityOutput("func_wall_toggle", output, OnToggleEntity);
					HookEntityOutput("trigger_teleport", output, OnToggleEntity);
					HookEntityOutput("trigger_teleport_relative", output, OnToggleEntity);
					HookEntityOutput("trigger_multiple", output, OnToggleEntity);
					HookEntityOutput("trigger_push", output, OnToggleEntity);
					HookEntityOutput("func_button", output, OnToggleEntity);
				}
            }
            
            ProccessToggleEntitiesWithName(target, "func_brush", entityS, output);
			ProccessToggleEntitiesWithName(target, "func_illusionary", entityS, output);
            ProccessToggleEntitiesWithName(target, "func_wall_toggle", entityS, output);
            ProccessToggleEntitiesWithName(target, "trigger_teleport", entityS, output);
            ProccessToggleEntitiesWithName(target, "trigger_teleport_relative", entityS, output);
            ProccessToggleEntitiesWithName(target, "trigger_multiple", entityS, output);
            ProccessToggleEntitiesWithName(target, "trigger_push", entityS, output);
            ProccessBreakableEntitiesWithName(target, "func_breakable");
        }
        else if (StrEqual(input,"Lock",false) || StrEqual(input,"Unlock",false))
        {
            GetOutputActionTarget(entity, sOutput, i, target, sizeof(target));
            
            //PrintToServer("-> %i: TARGET = %s", i, target);
            
            ProccessButtonWithName(target);
        }
        else if(StrEqual(input,"Add",false) || StrEqual(input,"Subtract",false))
        {
            GetOutputActionTarget(entity, sOutput, i, target, sizeof(target));
            
            //PrintToServer("-> %i: TARGET = %s", i, target);
            
            ProccessMathCounterWithName(target);
        }
        else if(!StrEqual(input,"ForceSpawn",false) && !StrEqual(input,"Open",false) && !StrEqual(input,"Color",false))
        {
            ret = false;
        }
    }
    
    return ret;
}

public void OnToggleEntity(const char[] output, int caller, int activator, float delay)
{
    if(0 > activator || MaxClients < activator)
        return;
        
    static int iSolidId;
	
    int rEnt = caller;
                
    if(caller < 0)
    {
        for(int i = 0; i <= g_CurrentCounter; i++)
        {
            if(g_iMathCounters[i] == caller)
            {
                rEnt = i;
                break;
            }
        }
    }
    
    if(0 > rEnt || 2048 < rEnt)
        return;

    for(int i = 0; i < 12; i++)
    {
        if(g_iLinkedSolids[rEnt][i] != -1)
        {
            iSolidId = g_iLinkedSolids[rEnt][i];
            
            int person = activator;
            int partner = Trikz_FindPartner(person);
            
            if(partner == -1)
			{
                person = 0;
                partner = 0;
			}
            
            g_iAllowedToggles[iSolidId][person] += g_iToggleAmount[iSolidId][GetOutputIDFromName(output)];
            g_iAllowedToggles[iSolidId][partner] = g_iAllowedToggles[iSolidId][person];
            
            //PrintToServer("ALLOWED TOGGLES %i", g_iAllowedToggles[iSolidId][person]);
            
            if(person == 0)
                g_iAllowedToggles[iSolidId][activator] += g_iToggleAmount[iSolidId][GetOutputIDFromName(output)];
        }
    }
}

void ProccessMathCounterWithName(const char[] sTargetname)
{
    int entity = INVALID_ENT_REFERENCE;
    
    entity = FindEntityByTargetname(entity, sTargetname, "math_counter");
    
    if(!IsValidEntity(entity))
        return;
    
    if((GetOutputActionCount(entity, "m_OutValue") > 0) || (GetOutputActionCount(entity, "m_OnGetValue") > 0) || (GetOutputActionCount(entity, "m_OnUser3") > 0) || (GetOutputActionCount(entity, "m_OnUser4") > 0)) //this shit is bananas b a n a n a s
        return;
        
    static bool bReturn;
    
    bReturn = false;
        
    for(int i = 0; i <= g_CurrentCounter; i++)
    {
        if(g_iMathCounters[i] == entity)
        {
            bReturn = true;
            break;
        }
    }
    
    if(bReturn)
        return;
        
    g_iMathCounters[g_CurrentCounter] = entity;
    
    FindAllSolidsWithOutput(entity, "OnHitMax");
    FindAllSolidsWithOutput(entity, "OnHitMin");
    
    static int offset = -1;
    if (offset == -1)
        offset = FindDataMapInfo(entity, "m_OutValue");
    
    float defaultval = GetEntDataFloat(entity, offset);
    
    g_fMathCounterDefaultValue[g_CurrentCounter] = defaultval;
    
    for(int i = 0; i <= MaxClients; i++)
        g_fMathCounterValue[g_CurrentCounter][i] = defaultval;
        
    g_fMathCounterMax[g_CurrentCounter] = GetEntPropFloat(entity, Prop_Data, "m_flMax");
    g_fMathCounterMin[g_CurrentCounter] = GetEntPropFloat(entity, Prop_Data, "m_flMin");
    
    //PrintToServer("MATH COUNTER %s FOUND: MIN - %f, MAX - %f", sTargetname, g_fMathCounterMin[g_CurrentCounter], g_fMathCounterMax[g_CurrentCounter]);
    
    int count = GetOutputActionCount(entity, "m_OnHitMax");
    
    //static char sOutput[256];
    static char sOutputTarget[256];
    static char sOutputTargetInput[256];
    static char sOutputParameter[256];
    static char sOutputFormatted[256];
    
    for(int i = 0; i < count; i++)
    {
        /*GetOutputFormatted(entity, "m_OnHitMax", i, sOutput, sizeof(sOutput));
        
        ReplaceString(sOutput, sizeof(sOutput), ",", ":");
        
        Format(sOutput, sizeof(sOutput), "OnUser3 %s",sOutput);
        
        SetVariantString(sOutput);*/
        
        GetOutputActionTarget(entity, "m_OnHitMax", i, sOutputTarget, sizeof(sOutputTarget));
        GetOutputActionTargetInput(entity, "m_OnHitMax", i, sOutputTargetInput, sizeof(sOutputTargetInput));
        GetOutputActionParameter(entity, "m_OnHitMax", i, sOutputParameter, sizeof(sOutputParameter));
        float iOutputDelay = GetOutputActionDelay(entity, "m_OnHitMax", i);
        int iOutputTimesToFire = GetOutputActionTimesToFire(entity, "m_OnHitMax", i);
        Format(sOutputFormatted, sizeof(sOutputFormatted), "OnUser3 %s:%s:%s:%f:%i", sOutputTarget, sOutputTargetInput, sOutputParameter, iOutputDelay, iOutputTimesToFire);
        SetVariantString(sOutputFormatted);
        
        AcceptEntityInput(entity, "AddOutput");
    }
    
    count = GetOutputActionCount(entity, "m_OnHitMin");
    
    for(int i = 0; i < count; i++)
    {
        /*GetOutputFormatted(entity, "m_OnHitMin", i, sOutput, sizeof(sOutput));
        
        ReplaceString(sOutput, sizeof(sOutput), ",", ":");
        
        Format(sOutput, sizeof(sOutput), "OnUser4 %s",sOutput);
        
        SetVariantString(sOutput);*/
        
        GetOutputActionTarget(entity, "m_OnHitMin", i, sOutputTarget, sizeof(sOutputTarget));
        GetOutputActionTargetInput(entity, "m_OnHitMin", i, sOutputTargetInput, sizeof(sOutputTargetInput));
        GetOutputActionParameter(entity, "m_OnHitMin", i, sOutputParameter, sizeof(sOutputParameter));
        float iOutputDelay = GetOutputActionDelay(entity, "m_OnHitMin", i);
        int iOutputTimesToFire = GetOutputActionTimesToFire(entity, "m_OnHitMin", i);
        Format(sOutputFormatted, sizeof(sOutputFormatted), "OnUser4 %s:%s:%s:%f:%i", sOutputTarget, sOutputTargetInput, sOutputParameter, iOutputDelay, iOutputTimesToFire);
        SetVariantString(sOutputFormatted);
        
        AcceptEntityInput(entity, "AddOutput");
    }
    
    DHookEntity(g_hAcceptInput, false, entity, INVALID_FUNCTION, AcceptInputCounter);
    
    g_CurrentCounter++;
}

void ProccessButtonWithName(const char[] sTargetname)
{
    int iTarget = INVALID_ENT_REFERENCE;
    while((iTarget = FindEntityByTargetname(iTarget, sTargetname, "func_button")) != INVALID_ENT_REFERENCE)
    {
        if(g_bButtonFound[iTarget])
            continue;
            
        g_bButtonFound[iTarget] = true;
        
        bool locked = (GetEntProp(iTarget, Prop_Data, "m_bLocked") == 1);
        
        if(locked)
        {
            AcceptEntityInput(iTarget, "Unlock");
        }
        
        for(int i = 0; i <= MaxClients; i++)
            g_bButtonLocked[iTarget][i] = locked;
            
        g_bButtonLockedDefault[iTarget] = locked;
            
        DHookEntity(g_hAcceptInput, false, iTarget, INVALID_FUNCTION, AcceptInputButton);
    }
}

public Action OnUse(int entity, int activator, int caller, UseType type, float value)
{
    if(0 >= activator || MaxClients < activator)
        return Plugin_Continue;
        
    int player = activator;
    int partner = Trikz_FindPartner(activator)
    
    if(partner == -1)
	{
        player = 0;
        partner = 0;
	}
        
    if(g_bButtonLocked[entity][player])
        return Plugin_Handled;
        
    if(!g_bClientButton[entity])
        return Plugin_Continue;
                
    if(GetGameTime() < g_fButtonNextPress[entity][player])
        return Plugin_Handled;
        
    if(g_fButtonNextPress[entity][player] == -1.0)
        return Plugin_Handled;
        
    if(g_fButtonDelay[entity] == -1.0)
    {
        g_fButtonNextPress[entity][player] = -1.0;
        g_fButtonNextPress[entity][partner] = -1.0;
    }
        
    g_fButtonNextPress[entity][player] = GetGameTime() + g_fButtonDelay[entity];
    g_fButtonNextPress[entity][partner] = GetGameTime() + g_fButtonDelay[entity];
    
    return Plugin_Continue;
}

void ProccessToggleEntitiesWithName(const char[] sTargetname, const char[] sClassname, int parentEnt, const char[] sOutput)
{
	//PrintToServer("PASS");
    int iTarget = INVALID_ENT_REFERENCE;
    while((iTarget = FindEntityByTargetname(iTarget, sTargetname, sClassname, parentEnt)) != INVALID_ENT_REFERENCE)
    {
		//PrintToServer("PASS2");
        if(!g_bUsedEdict[iTarget])
        {
			//PrintToServer("PASS3");
            //if(StrEqual(sClassname,"func_brush") && GetEntProp(iTarget, Prop_Data, "m_iSolidity") != 0) //unsupported
            //    continue;
                
            if((StrContains(sClassname, "trigger_", false) != -1) && !(GetEntProp(iTarget, Prop_Data, "m_spawnflags") & 1))
                continue;

            g_bUsedEdict[iTarget] = true;
        
            g_iSolidIds[g_CurrentSolid] = iTarget;
            
            if(parentEnt)
            {
                g_iToggleAmount[g_CurrentSolid][GetOutputIDFromName(sOutput)] += 1;
                
                int rEnt = parentEnt;
                
                if(parentEnt < 0)
                {
                    for(int i = 0; i <= g_CurrentCounter; i++)
                    {
                        if(g_iMathCounters[i] == parentEnt)
                        {
                            rEnt = i;
                            break;
                        }
                    }
                }
                
                if(rEnt >= 0)
                {
                
                    for(int i = 0; i < 12; i++)
                    {
                        if(g_iLinkedSolids[rEnt][i] == -1)
                        {
                            g_iLinkedSolids[rEnt][i] = g_CurrentSolid;
                            break;
                        }
                    }
                }
            }
            
            bool enabled = false;
        
            if(StrContains(sClassname, "trigger_", false) != -1)
                enabled = (GetEntProp(iTarget, Prop_Data, "m_bDisabled") == 0);
            else
			{
                enabled = !(GetEntProp(iTarget, Prop_Data, "m_usSolidFlags") & 4);
                if(StrEqual(sClassname, "func_brush") && GetEntProp(iTarget, Prop_Data, "m_usSolidFlags") & 4)
                    enabled = GetEntProp(iTarget, Prop_Data, "m_iDisabled") == 0;
			}
    
            if (!enabled)
            {
                if(StrContains(sClassname, "trigger_", false) != -1 || StrEqual(sClassname,"func_brush",false))
                    AcceptEntityInput(iTarget, "Enable"); //safer
                else
                    AcceptEntityInput(iTarget, "Toggle");
            }
    
            for(int i = 0; i <= MaxClients; i++)
            {
                g_bPlayerSolid[g_CurrentSolid][i] = enabled;
            }
        
            g_bDefaultState[g_CurrentSolid] = enabled;
        
            g_iPointSolidSpawn[g_CurrentSolid] = -1;
        
            if(StrContains(sClassname, "trigger_", false) == -1)
                SDKHook(iTarget, SDKHook_SetTransmit, Hook_SetTransmit);
            else if(StrContains(sClassname, "trigger_", false) != -1)
            {
                //SDKHook(iTarget, SDKHook_StartTouch, Hook_StartTouch);
                //SDKHook(iTarget, SDKHook_EndTouch, Hook_EndTouch);
                SDKHook(iTarget, SDKHook_Touch, Hook_Touch);
                //HookSingleEntityOutput(iTarget, "OnStartTouch", Output_OnStartTouch);
                //HookSingleEntityOutput(iTarget, "OnEndTouch", Output_OnEndTouch);
                HookEntityOutput("trigger_teleport", "OnStartTouch", Output_OnStartTouch);
                HookEntityOutput("trigger_teleport_relative", "OnStartTouch", Output_OnStartTouch);
                HookEntityOutput("trigger_multiple", "OnStartTouch", Output_OnStartTouch);
                HookEntityOutput("trigger_push", "OnStartTouch", Output_OnStartTouch);
                HookEntityOutput("trigger_teleport", "OnEndTouch", Output_OnEndTouch);
                HookEntityOutput("trigger_teleport_relative", "OnEndTouch", Output_OnEndTouch);
                HookEntityOutput("trigger_multiple", "OnEndTouch", Output_OnEndTouch);
                HookEntityOutput("trigger_push", "OnEndTouch", Output_OnEndTouch);
            }
            
            DHookEntity(g_hAcceptInput, false, iTarget, INVALID_FUNCTION, AcceptInputToggle);
    
            g_CurrentSolid++;
        }
        else if(parentEnt)
        {
            int iSolidId = -1;
        
            for(int i = 0; i < g_CurrentSolid; i++)
            {
                if(g_iSolidIds[i] == iTarget)
                {
                    iSolidId = i;
                    break;
                }
            }
            
            int rEnt = parentEnt;
                
            if(parentEnt < 0)
            {
                for(int i = 0; i <= g_CurrentCounter; i++)
                {
                    if(g_iMathCounters[i] == parentEnt)
                    {
                        rEnt = i;
                        break;
                    }
                }
            }
        
            if(rEnt >= 0 && iSolidId != -1)
            {
                for(int i = 0; i < 12; i++)
                {
                    if(g_iLinkedSolids[rEnt][i] == iSolidId)
                        break;
                    
                    if(g_iLinkedSolids[rEnt][i] == -1)
                    {
                        g_iLinkedSolids[rEnt][i] = iSolidId;
                        break;
                    }
                }
                
                g_iToggleAmount[iSolidId][GetOutputIDFromName(sOutput)] += 1;
            }
        }
    }
}

void ProccessBreakableEntitiesWithName(const char[] sTargetname, const char[] sClassname)
{
    int iTarget = INVALID_ENT_REFERENCE;
    while((iTarget = FindEntityByTargetname(iTarget, sTargetname, sClassname)) != INVALID_ENT_REFERENCE)
    {
        if(!g_bUsedEdict[iTarget])
        {
            g_bUsedEdict[iTarget] = true;
        
            g_iSolidIds[g_CurrentSolid] = iTarget;
    
            for(int i = 0; i <= MaxClients; i++)
            {
                g_bPlayerSolid[g_CurrentSolid][i] = true;
            }
            
            g_bDefaultState[g_CurrentSolid] = true;
        
            int iPoint = INVALID_ENT_REFERENCE;
        
            bool bBreak = false;
        
            while((iPoint = FindEntityByClassname(iPoint, "point_template")) != INVALID_ENT_REFERENCE)
            {
                for(int i = 0; i < 16; i++)
                {
                    char buffer[64];
                    Format(buffer, sizeof(buffer), "m_iszTemplateEntityNames[%i]", i);
                
                    GetEntPropString(iPoint, Prop_Data, buffer, buffer, sizeof(buffer));
                
                    //int wc = FindCharInString(buffer, '*');
                
                    //if(strncmp(buffer, sTargetname, wc, false) == 0)
                    if(StrEqual(buffer, sTargetname, false))
                    {
                        g_iPointSolidSpawn[g_CurrentSolid] = iPoint;
                        DHookEntity(g_hAcceptInput, false, iPoint, INVALID_FUNCTION, AcceptInputToggle);
                        bBreak = true;
                        break;
                    }
                }
            
                if (bBreak)
                    break;
            }
            
            int count = GetOutputActionCount(iTarget, "m_OnBreak");
    
            //static char sBreakOutput[256];
            static char sOutputTarget[256];
            static char sOutputTargetInput[256];
            static char sOutputParameter[256];
            static char sOutputFormatted[256];
			
            for(int i = 0; i < count; i++)
            {
                /*GetOutputFormatted(iTarget, "m_OnBreak", i, sBreakOutput, sizeof(sBreakOutput));
            
                ReplaceString(sBreakOutput, sizeof(sBreakOutput), ",", ":");
        
                Format(sBreakOutput, sizeof(sBreakOutput), "OnUser4 %s",sBreakOutput);
        
                SetVariantString(sBreakOutput);*/
                
                GetOutputActionTarget(iTarget, "m_OnBreak", i, sOutputTarget, sizeof(sOutputTarget));
                GetOutputActionTargetInput(iTarget, "m_OnBreak", i, sOutputTargetInput, sizeof(sOutputTargetInput));
                GetOutputActionParameter(iTarget, "m_OnBreak", i, sOutputParameter, sizeof(sOutputParameter));
                float iOutputDelay = GetOutputActionDelay(iTarget, "m_OnBreak", i);
                int iOutputTimesToFire = GetOutputActionTimesToFire(iTarget, "m_OnBreak", i);
                Format(sOutputFormatted, sizeof(sOutputFormatted), "OnUser4 %s:%s:%s:%f:%i", sOutputTarget, sOutputTargetInput, sOutputParameter, iOutputDelay, iOutputTimesToFire);
                SetVariantString(sOutputFormatted);
        
                AcceptEntityInput(iTarget, "AddOutput");
            }
        
            SDKHook(iTarget, SDKHook_SetTransmit, Hook_SetTransmit);
            
            DHookEntity(g_hAcceptInput, false, iTarget, INVALID_FUNCTION, AcceptInputToggle);
        
            g_CurrentSolid++;
        }
    }
}

int FindEntityByTargetname(int entity, const char[] sTargetname, const char[] sClassname="*", int self = -1)
{
    //int Wildcard = FindCharInString(sTargetname, '*');
    char sTargetnameBuf[64];

    while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
    {
        if(StrEqual(sTargetname,"!self") && entity == self)
            return entity;
    
        if(GetEntPropString(entity, Prop_Data, "m_iName", sTargetnameBuf, sizeof(sTargetnameBuf)) <= 0)
            continue;

        //if(strncmp(sTargetnameBuf, sTargetname, Wildcard, false) == 0)
        if(StrEqual(sTargetnameBuf, sTargetname, false))
            return entity;
    }

    return INVALID_ENT_REFERENCE;
}

public Action Output_OnStartTouch(const char[] output, int caller, int activator, float delay)
{
    if((0 >= activator || MaxClients < activator) && !g_bFlashbang[activator])
        return Plugin_Continue;
        
    int iSolidId = -1

    for(int i = 0; i < g_CurrentSolid; i++)
    {
        if(g_iSolidIds[i] == caller)
        {
            iSolidId = i;
            break;
        }
    }
    
    if(iSolidId == -1)
        return Plugin_Continue;
        
    int ractivator = activator;
    
    if(g_bFlashbang[activator])
        ractivator = GetEntPropEnt(activator, Prop_Data, "m_hOwnerEntity");
        
    if(g_bStartTouch[iSolidId][ractivator])
    {
        g_bStartTouch[iSolidId][ractivator] = false;
        return Plugin_Continue;
    }
        
    if(!(0 < ractivator <= MaxClients))
        return Plugin_Continue;
        
    if(Trikz_FindPartner(ractivator) == -1)
        ractivator = 0;

    if(!g_bPlayerSolid[iSolidId][ractivator])
        return Plugin_Handled;
        
    g_bWasSolid[iSolidId][ractivator] = true;    
    
    if(!g_bFlashbang[activator])
        g_bWasSolid[iSolidId][activator] = true;
        
    return Plugin_Continue;
}

/*public Action Hook_StartTouch(int entity, int other)
{
    if((0 >= other || MaxClients < other) && !g_bFlashbang[other])
        return Plugin_Continue;
        
    int iSolidId = -1

    for(int i = 0; i < g_CurrentSolid; i++)
    {
        if(g_iSolidIds[i] == entity)
        {
            iSolidId = i;
            break;
        }
    }
    
    if(iSolidId == -1)
        return Plugin_Continue;
        
    int activator = other;
    
    if(g_bFlashbang[other])
        activator = GetEntPropEnt(other, Prop_Data, "m_hOwnerEntity");
        
    if(!(0 < activator <= MaxClients))
        return Plugin_Continue;
        
    if(Trikz_FindPartner(activator) == -1)
        activator = 0;
        
    if(g_bWasSolid[iSolidId][activator] && g_bPlayerSolid[iSolidId][activator])
        return Plugin_Handled;

    if(!g_bPlayerSolid[iSolidId][activator])
        return Plugin_Handled;
        
    g_bWasSolid[iSolidId][activator] = true;    
        
    return Plugin_Continue;
}*/

public Action Hook_Touch(int entity, int other)
{
    if((0 >= other || MaxClients < other) && !g_bFlashbang[other])
        return Plugin_Continue;
        
    int iSolidId = -1;

    for(int i = 0; i < g_CurrentSolid; i++)
    {
        if(g_iSolidIds[i] == entity)
        {
            iSolidId = i;
            break;
        }
    }
    
    if(iSolidId == -1)
        return Plugin_Continue;
        
    int activator = other;
    
    if(g_bFlashbang[other])
        activator = GetEntPropEnt(other, Prop_Data, "m_hOwnerEntity");
        
    if(!(0 < activator <= MaxClients))
        return Plugin_Continue;
    
    if(Trikz_FindPartner(activator) == -1)
        activator = 0;
        
    if((g_bWasSolid[iSolidId][activator] || (!g_bFlashbang[other] && g_bWasSolid[iSolidId][other])) && !g_bPlayerSolid[iSolidId][activator])
    {
        AcceptEntityInput(entity, "EndTouch", other, other); //call any onendtouch outputs
    }
    else if((!g_bWasSolid[iSolidId][activator] || (!g_bFlashbang[other] && !g_bWasSolid[iSolidId][other])) && g_bPlayerSolid[iSolidId][activator])
    {
        if(!g_bFlashbang[other])
            g_bStartTouch[iSolidId][other] = true;
        
        AcceptEntityInput(entity, "StartTouch", other, other);
    }
        
    if(!g_bPlayerSolid[iSolidId][activator])
        return Plugin_Handled;
        
    g_bWasSolid[iSolidId][activator] = g_bPlayerSolid[iSolidId][activator];
    
    if(!g_bFlashbang[other])
        g_bWasSolid[iSolidId][other] = g_bWasSolid[iSolidId][other];
    
    return Plugin_Continue;
}

public Action Output_OnEndTouch(const char[] output, int caller, int activator, float delay)
{
    if((0 >= activator || MaxClients < activator) && !g_bFlashbang[activator])
        return Plugin_Continue;
        
    int iSolidId = -1

    for(int i = 0; i < g_CurrentSolid; i++)
    {
        if(g_iSolidIds[i] == caller)
        {
            iSolidId = i;
            break;
        }
    }
    
    if(iSolidId == -1)
        return Plugin_Continue;
        
    int ractivator = activator;
    
    if(g_bFlashbang[activator])
        ractivator = GetEntPropEnt(activator, Prop_Data, "m_hOwnerEntity");
        
    if(!(0 < ractivator <= MaxClients))
        return Plugin_Continue;
        
    if(Trikz_FindPartner(ractivator) == -1)
        ractivator = 0;
        
    if(!g_bPlayerSolid[iSolidId][ractivator] && !g_bWasSolid[iSolidId][ractivator] && (g_bFlashbang[activator] || !g_bWasSolid[iSolidId][activator]))
        return Plugin_Handled;
        
    g_bWasSolid[iSolidId][ractivator] = false;
    
    if(!g_bFlashbang[activator])
        g_bWasSolid[iSolidId][activator] = false;
    
    return Plugin_Continue;
}

/*public Action Hook_EndTouch(int entity, int other)
{
    if((0 >= other || MaxClients < other) && !g_bFlashbang[other])
        return Plugin_Continue;
        
    int iSolidId = -1

    for(int i = 0; i < g_CurrentSolid; i++)
    {
        if(g_iSolidIds[i] == entity)
        {
            iSolidId = i;
            break;
        }
    }
    
    if(iSolidId == -1)
        return Plugin_Continue;
        
    int activator = other;
    
    if(g_bFlashbang[other])
        activator = GetEntPropEnt(other, Prop_Data, "m_hOwnerEntity");
        
    if(!(0 < activator <= MaxClients))
        return Plugin_Continue;
        
    if(Trikz_FindPartner(activator) == -1)
        activator = 0;

    if(!g_bPlayerSolid[iSolidId][activator] && !g_bWasSolid[iSolidId][activator])
        return Plugin_Handled;
        
    g_bWasSolid[iSolidId][activator] = false;
        
    return Plugin_Continue;
}*/

public Action Hook_SetTransmit(int entity, int client)
{
    if(client == entity || (0 >= client || client > MaxClients))
        return Plugin_Continue;
        
    int iSolidId = -1

    for(int i = 0; i < g_CurrentSolid; i++)
    {
        if(g_iSolidIds[i] == entity)
        {
            iSolidId = i;
            break;
        }
    }
    
    if(iSolidId == -1)
        return Plugin_Continue;
        
    int activator = client;
    
    if(!IsPlayerAlive(activator))
    {
        int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        
        if(0 < target <= MaxClients)
            activator = target;
    }
        
    int partner = Trikz_FindPartner(activator);
    if(partner == -1)
        activator = 0;
    
    if (!g_bPlayerSolid[iSolidId][activator])
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}  

public Action CH_PassFilter(int ent1, int ent2, bool &result ) 
{
    if ((1 <= ent1 <= MaxClients && 1 <= ent2 <= MaxClients) || (g_bFlashbang[ent1] && g_bFlashbang[ent2]))
        return Plugin_Continue;
        
    if ((!(1 <= ent1 <= MaxClients) && !(1 <= ent2 <= MaxClients)) && !g_bFlashbang[ent1] && !g_bFlashbang[ent2])
        return Plugin_Continue;
        
    if((1 <= ent1 <= MaxClients && g_bFlashbang[ent2]) || (1 <= ent2 <= MaxClients && g_bFlashbang[ent1]))
        return Plugin_Continue;
		
	Call_StartForward(g_hCheckSolidity);
    Call_PushCell(ent1);
    Call_PushCell(ent2);
    Call_Finish(result);
    
    int player = ent1;
    int other = ent2;
    
    if(1 <= ent2 <= MaxClients || (!(1 <= ent2 <= MaxClients) && g_bFlashbang[ent2]))
    {
        player = ent2;
        other = ent1;
    }
    
    if((1 <= player <= MaxClients) && IsFakeClient(player))
        return Plugin_Continue;
    
    if(0 < other <= 2048 && (!g_bAllowCollision[other]))
    {
        result = false;
        return Plugin_Handled;
    }
    
    int iSolidId = -1;
    
    for(int i = 0; i < g_CurrentSolid; i++)
    {
        if(g_iSolidIds[i] == other)
        {
            iSolidId = i;
            break;
        }
    }
    
    if(iSolidId == -1)
        return Plugin_Continue;
        
    if(!(0 < player <= 2048))
        return Plugin_Continue;
        
    int owner = player
    
    if(g_bFlashbang[player])
        owner = GetEntPropEnt(player, Prop_Data, "m_hOwnerEntity");

    if(Trikz_FindPartner(owner) == -1)
        owner = 0;
        
    if(!(0 <= owner <= MaxClients))
        return Plugin_Continue;
        
    if(g_bPlayerSolid[iSolidId][owner])
        return Plugin_Continue;
        
    result = false;
    
    return Plugin_Handled;
}

public Action Button_OnTakeDamage_Fix(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) 
{
    if(IsValidEntity(attacker) && 0 < attacker <= MaxClients)
        SetEntPropEnt(victim, Prop_Data, "m_hActivator", attacker);
        
    return Plugin_Continue;
}

int GetOutputIDFromName(const char[] output)
{
    if(StrEqual(output, "OnStartTouch"))
        return 0;
    else if(StrEqual(output, "OnEndTouch"))
        return 1;
    else if(StrEqual(output, "OnTrigger"))
        return 2;
    else if(StrEqual(output, "OnPressed"))
        return 3;
    else if(StrEqual(output, "OnDamaged"))
        return 4;
    else
        return 5;
}

public int Native_IsEntityToggleable(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
    
    return g_bUsedEdict[entity];
}

public int Native_IsToggleableEnabledForPlayer(Handle plugin, int numParams)
{
    int client = GetNativeCell(2);
    int entity = GetNativeCell(1);
    
    static bool bIsSolid;
    static int iSolidId;
    
    for(int i = 0; i < g_CurrentSolid; i++)
    {
        if(g_iSolidIds[i] == entity)
        {
            bIsSolid = true;
            iSolidId = i;
            break;
        }
    }
    
    if(bIsSolid)
    {
        return g_bPlayerSolid[iSolidId][client]
    }
    
    return false
}