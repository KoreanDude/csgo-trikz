#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colorvariables>
#include <trikz>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

#define MAX_STRAFES 50
#define BHOP_TIME 0.3
#define STAMINA_RECHARGE_TIME 0.58579
#define SW_ANGLE_THRESHOLD 20.0
#define LJ_HEIGHT_DELTA_MIN -0.01 //Dropjump limit
#define LJ_HEIGHT_DELTA_MAX 1.5 //Upjump limit
#define CJ_HEIGHT_DELTA_MIN -0.01
#define CJ_HEIGHT_DELTA_MAX 1.5
#define WJ_HEIGHT_DELTA_MIN -0.01
#define WJ_HEIGHT_DELTA_MAX 1.5
#define BJ_HEIGHT_DELTA_MIN -2.0 //dynamic pls
#define BJ_HEIGHT_DELTA_MAX 2.0
#define LAJ_HEIGHT_DELTA_MIN -6.0
#define LAJ_HEIGHT_DELTA_MAX 0.0
#define HUD_HINT_SIZE 256

public Plugin myinfo = 
{
	name = "ljstats",
	author = "Miu, modified by Smesh, Modified by. SHIM",
	description = "longjump stats",
	version = "2.0.1",
	url = "https://forums.alliedmods.net/showthread.php?p=2060983"
}

enum PlayerState
{
	bool:bHidePanel,
	bool:bBlockMode,
	
	Float:fBlockDistance,
	Float:vBlockNormal[2],
	Float:vBlockEndPos[3],
	bool:bFailedBlock,
	
	bool:bDuck,
	bool:bLastDuckState,
	bool:bSecondLastDuckState,
	
	JUMP_DIRECTION:JumpDir,
	ILLEGAL_JUMP_FLAGS:IllegalJumpFlags,
	
	JUMP_TYPE:LastJumpType,
	JUMP_TYPE:JumpType,
	Float:fLandTime,
	Float:fLastJumpHeightDelta,
	nBhops,
	
	bool:bOnGround,
	bool:bOnLadder,
	
	Float:fEdge,
	Float:vJumpOrigin[3],
	Float:fWJDropPre,
	Float:fPrestrafe,
	Float:fJumpDistance,
	Float:fHeightDelta,
	Float:fJumpHeight,
	Float:fSync,
	Float:fMaxSpeed,
	Float:fFinalSpeed,
	Float:fGain,
	Float:fLoss,
	
	STRAFE_DIRECTION:CurStrafeDir,
	nStrafes,
	STRAFE_DIRECTION:StrafeDir[MAX_STRAFES],
	Float:fStrafeGain[MAX_STRAFES],
	Float:fStrafeLoss[MAX_STRAFES],
	Float:fStrafeSync[MAX_STRAFES],
	nStrafeTicks[MAX_STRAFES],
	nStrafeTicksSynced[MAX_STRAFES],
	nTotalTicks,
	Float:fTotalAngle,
	Float:fSyncedAngle,
	
	Float:vLastOrigin[3],
	Float:vLastAngles[3],
	Float:vLastVelocity[3],
	
	String:strHUDHint[HUD_HINT_SIZE / 4], //string characters are stored as cells
	
	Float:fPersonalBest,
	
	nSpectators,
	nSpectatorTarget,
	
	GAP_SELECTION_MODE:GapSelectionMode,
	Float:vGapPoint1[3],
	LastButtons
}

enum ILLEGAL_JUMP_FLAGS
{
	IJF_NONE = 0,
	IJF_WORLD = 1 << 0,
	IJF_BOOSTER = 1 << 1,
	IJF_GRAVITY = 1 << 2,
	IJF_TELEPORT = 1 << 3,
	IJF_LAGGEDMOVEMENTVALUE = 1 << 4,
	IJF_PRESTRAFE = 1 << 5,
	IJF_SCOUT = 1 << 6,
	IJF_NOCLIP = 1 << 7
}

enum JUMP_TYPE
{
	JT_LONGJUMP,
	JT_COUNTJUMP,
	JT_WEIRDJUMP,
	JT_BHOPJUMP,
	JT_LADDERJUMP,
	JT_BHOP,
	JT_DROP,
	JT_NONE,
	JT_END
}

enum JUMP_DIRECTION
{
	JD_NONE, //Indeterminate
	JD_NORMAL,
	JD_FORWARDS = JD_NORMAL,
	JD_SIDEWAYS,
	JD_BACKWARDS,
	JD_END
}

enum STRAFE_DIRECTION
{
	SD_NONE,
	SD_W,
	SD_D,
	SD_A,
	SD_S,
	SD_WA,
	SD_WD,
	SD_SA,
	SD_SD,
	SD_END
}

enum GAP_SELECTION_MODE
{
	GSM_NONE,
	GSM_GAP,
	GSM_GAPSECOND,
	GSM_BLOCKGAP
}

char g_strJumpType[JT_END][] =
{
	"Longjump",
	"Countjump",
	"Weirdjump",
	"Bhopjump",
	"Ladderjump",
	"Bhop",
	"Drop",
	""
};

char g_strJumpTypeLwr[JT_END][] =
{
	"longjump",
	"countjump",
	"weirdjump",
	"bhopjump",
	"ladderjump",
	"bhop",
	"drop",
	""
};

char g_strJumpTypeShort[JT_END][] =
{
	"LJ",
	"CJ",
	"WJ",
	"BJ",
	"LAJ",
	"Bhop",
	"Drop",
	""
};

float g_fHeightDeltaMin[JT_END] =
{
	LJ_HEIGHT_DELTA_MIN,
	LJ_HEIGHT_DELTA_MIN,
	WJ_HEIGHT_DELTA_MIN,
	BJ_HEIGHT_DELTA_MIN,
	LAJ_HEIGHT_DELTA_MIN,
	-3.402823466e38,
	-3.402823466e38,
	-3.402823466e38
};

float g_fHeightDeltaMax[JT_END] =
{
	LJ_HEIGHT_DELTA_MAX,
	LJ_HEIGHT_DELTA_MAX,
	WJ_HEIGHT_DELTA_MAX,
	BJ_HEIGHT_DELTA_MAX,
	LAJ_HEIGHT_DELTA_MAX,
	3.402823466e38,
	3.402823466e38,
	3.402823466e38
};

//SourcePawn is silly
#define HEIGHT_DELTA_MIN(%0) (view_as<float>(g_fHeightDeltaMin[view_as<float>(%0)]))
#define HEIGHT_DELTA_MAX(%0) (view_as<float>(g_fHeightDeltaMax[view_as<float>(%0)]))

int gI_JumpStats[MAXPLAYERS+1] = 0;
Handle gH_JumpStats = INVALID_HANDLE;
bool g_PlayerStates[MAXPLAYERS + 1][PlayerState];

float g_fLJMin = 260.0;
float g_fLJMaxPrestrafe = 280.0;
bool g_bLJScoutStats = false;
float g_fLJNoDuckMin = 256.0;
float g_fLJClientMin = 0.0;
float g_fWJMin = 270.0;
float g_fWJDropMax = 30.0;
float g_fBJMin = 270.0;
float g_fLAJMin = 150.0;

bool g_bPrintFailedBlockStats = true;

float g_fMaxspeed = 320.0; //sv_maxspeed

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Trikz_GetClientStateJS", Native_GetClientStateJS);
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	gH_JumpStats = RegClientCookie("JumpStats", "JumpStats", CookieAccess_Private);
	
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i)) 
		{
			OnClientPutInServer(i);
		
			if(AreClientCookiesCached(i))
				OnClientCookiesCached(i);
			else
				gI_JumpStats[i] = 0;
		}
	}
	
	CreateNative("LJStats_CancelJump", Native_CancelJump);
	
	HookEvent("player_jump", Event_PlayerJump);
	
	RegConsoleCmd("sm_jshelp", Command_LJHelp);
	RegConsoleCmd("sm_js", Command_LJ);
	RegConsoleCmd("sm_lj", Command_LJ);
	RegConsoleCmd("sm_jssettings", Command_LJSettings);
	RegConsoleCmd("sm_jss", Command_LJSettings);
	RegConsoleCmd("sm_jspanel", Command_LJPanel);
	RegConsoleCmd("sm_gap", Command_Gap);
	RegConsoleCmd("sm_blockgap", Command_BlockGap);
}

public void OnClientPutInServer(int client)
{
	g_PlayerStates[client][bBlockMode] = true;
	g_PlayerStates[client][bOnGround] = true;
	view_as<float>(g_PlayerStates[client][fBlockDistance]) = -1.0;
	g_PlayerStates[client][IllegalJumpFlags] = IJF_NONE;
	g_PlayerStates[client][nSpectators] = 0;
	g_PlayerStates[client][nSpectatorTarget] = -1;
	
	SDKHook(client, SDKHook_Touch, hkTouch);
}

public void OnClientCookiesCached(int client)
{
	char sCookie[12];
	GetClientCookie(client, gH_JumpStats, sCookie, sizeof(sCookie));
	
	if (StringToInt(sCookie) == 0)
	{
		gI_JumpStats[client] = 0;
		return;
	}
	gI_JumpStats[client] = StringToInt(sCookie);
}

Action hkTouch(int client, int other)
{
	float vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);
	
	if(other == 0 && !(GetEntityFlags(client) & FL_ONGROUND) && !(g_PlayerStates[client][bBlockMode] && g_PlayerStates[client][bFailedBlock] && vOrigin[2] - g_PlayerStates[client][vJumpOrigin][2] < HEIGHT_DELTA_MIN(JT_LONGJUMP)))
	{
		g_PlayerStates[client][IllegalJumpFlags] |= IJF_WORLD;
	}
	
	else
	{
		char strClassname[64];
		GetEdictClassname(other, strClassname, sizeof(strClassname));
		
		if(!strcmp(strClassname, "trigger_push"))
		{
			g_PlayerStates[client][IllegalJumpFlags] |= IJF_BOOSTER;
		}
	}
}

Action Command_LJHelp(int client, int args)
{
	Handle hHelpPanel = CreatePanel();
	
	SetPanelTitle(hHelpPanel, "Jump Stats Commands");
	DrawPanelText(hHelpPanel, " ");
	DrawPanelText(hHelpPanel, "!js, lj");
	DrawPanelText(hHelpPanel, "!jssettings, !jss");
	DrawPanelText(hHelpPanel, "!jspanel");
	DrawPanelText(hHelpPanel, "!gap");
	DrawPanelText(hHelpPanel, "!blockgap");
	
	SendPanelToClient(hHelpPanel, client, EmptyPanelHandler, 10);
	
	CloseHandle(hHelpPanel);
	
	return Plugin_Handled;
}

Action Command_LJ(int client, int args)
{
	if(gI_JumpStats[client] == 0)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Jump stats is on.");
		gI_JumpStats[client] = 1;
	}
	else
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Jump stats is off.");
		gI_JumpStats[client] = 0;
	}
	
	char sCookie[12];
	Format(sCookie, sizeof(sCookie), "%i", gI_JumpStats[client]);
	SetClientCookie(client, gH_JumpStats, sCookie);
	
	return Plugin_Handled;
}

Action Command_LJSettings(int client, int args)
{
	ShowSettingsPanel(client);
	
	return Plugin_Handled;
}

void ShowSettingsPanel(int client)
{
	Handle hMenu = CreateMenu(SettingsMenuHandler);
	
	char buf[64];
	
	SetMenuTitle(hMenu, "Jump stats settings\n ");
	
	//Format(buf, sizeof(buf), "Jump stats: %s", g_PlayerStates[client][bLJEnabled] ? "On" : "Off");
	//AddMenuItem(hMenu, "ljenabled", buf);
	
	Format(buf, sizeof(buf), "Panel: %s", !g_PlayerStates[client][bHidePanel] ? "On" : "Off");
	AddMenuItem(hMenu, "panel", buf);
	
	DisplayMenu(hMenu, client, 0);
}

int SettingsMenuHandler(Handle hMenu, MenuAction ma, int client, int nItem)
{
	switch(ma)
	{
		case MenuAction_Select:
		{
			char strInfo[16];
			
			if(!GetMenuItem(hMenu, nItem, strInfo, sizeof(strInfo)))
			{
				LogError("rip menu...");
				
				return;
			}
			
			if(!strcmp(strInfo, "panel"))
			{
				g_PlayerStates[client][bHidePanel] = !g_PlayerStates[client][bHidePanel];
				
				CPrintToChat(client, "{green}[Trikz]{lightgreen} Panel is now %s.", g_PlayerStates[client][bHidePanel] ? "hidden" : "visible");
				
				ShowSettingsPanel(client);
			}
		}
		
		case MenuAction_End:
		{
			CloseHandle(hMenu);
		}
	}
}

Action Command_LJPanel(int client, int args)
{
	g_PlayerStates[client][bHidePanel] = !g_PlayerStates[client][bHidePanel];
	
	CPrintToChat(client, "{green}[Trikz]{lightgreen} Jump stats panel %s.", g_PlayerStates[client][bHidePanel] ? "on" : "off");
	
	return Plugin_Handled;
}

Action Command_Gap(int client, int args)
{
	Handle hGapPanel = CreatePanel();
	
	SetPanelTitle(hGapPanel, "Select point 1");
	
	SendPanelToClient(hGapPanel, client, EmptyPanelHandler, 10);
	
	CloseHandle(hGapPanel);
	
	g_PlayerStates[client][GapSelectionMode] = GSM_GAP;
	
	return Plugin_Handled;
}

Action Command_BlockGap(int client, int args)
{
	Handle hGapPanel = CreatePanel();
	
	SetPanelTitle(hGapPanel, "Select block");
	
	SendPanelToClient(hGapPanel, client, EmptyPanelHandler, 10);
	
	CloseHandle(hGapPanel);
	
	g_PlayerStates[client][GapSelectionMode] = GSM_BLOCKGAP;
	
	return Plugin_Handled;
}

void GapSelect(int client, int buttons)
{
	if(!(buttons & IN_ATTACK || buttons & IN_ATTACK2 || buttons & IN_USE) ||
	g_PlayerStates[client][LastButtons] & IN_ATTACK || g_PlayerStates[client][LastButtons] & IN_ATTACK2 || g_PlayerStates[client][LastButtons] & IN_USE)
	{
		return;
	}
	
	float vPoint[3];
	float vNormal[3];
	GetGapPoint(vPoint, vNormal, client);
	
	switch(g_PlayerStates[client][GapSelectionMode])
	{
		case GSM_GAP:
		{
			Array_Copy(vPoint, g_PlayerStates[client][vGapPoint1], 3);
			
			SendPanelMsg(client, "Select point 2");
			
			g_PlayerStates[client][GapSelectionMode] = GSM_GAPSECOND;
		}
		
		case GSM_GAPSECOND:
		{
			float vPoint1[3];
			Array_Copy(g_PlayerStates[client][vGapPoint1], vPoint1, 3);
			
			float xy = Pow(Pow(vPoint[0] - vPoint1[0], 2.0) + Pow(vPoint[1] - vPoint1[1], 2.0), 0.5);
			
			SendPanelMsg(client, "Distance: %.2f, xy: %.2f, z: %.2f", GetVectorDistance(vPoint, vPoint1), xy, vPoint1[2] - vPoint[2]);
			
			g_PlayerStates[client][GapSelectionMode] = GSM_NONE;
		}
		
		case GSM_BLOCKGAP:
		{
			float vBlockEnd[3];
			float vOrigin[3];
			GetClientAbsOrigin(client, vOrigin);
			GetOppositePoint(vBlockEnd, vPoint, vNormal);
			
			SendPanelMsg(client, "Block: %.2f", GetVectorDistance(vPoint, vBlockEnd));
			
			g_PlayerStates[client][GapSelectionMode] = GSM_NONE;
		}
	}
}

void GetStrafeKey(char[] str, STRAFE_DIRECTION Dir)
{
	if(Dir == SD_W)
	{
		strcopy(str, 3, "W");
	}
	
	else if(Dir == SD_A)
	{
		strcopy(str, 3, "A");
	}
	
	else if(Dir == SD_S)
	{
		strcopy(str, 3, "S");
	}
	
	else if(Dir == SD_D)
	{
		strcopy(str, 3, "D");
	}
	
	else if(Dir == SD_WA)
	{
		strcopy(str, 3, "WA");
	}
	
	else if(Dir == SD_WD)
	{
		strcopy(str, 3, "WD");
	}
	
	else if(Dir == SD_SA)
	{
		strcopy(str, 3, "SA");
	}
	
	else if(Dir == SD_SD)
	{
		strcopy(str, 3, "SD");
	}
}

int Native_CancelJump(Handle hPlugin, int nParams)
{
	CancelJump(GetNativeCell(1));
}

void CancelJump(int client)
{
	g_PlayerStates[client][bOnGround] = true;
}

Action Event_PlayerJump(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	PlayerJump(client);
}

//cba with another enum so JT_LONGJUMP = jump, JT_DROP = slide off edge, JT_LADDERJUMP = ladder
void PlayerJump(int client, JUMP_TYPE JumpType2 = JT_LONGJUMP)
{
	g_PlayerStates[client][bOnGround] = false;
	
	float fTime = GetGameTime();
	if(fTime - g_PlayerStates[client][fLandTime] < BHOP_TIME)
	{
		g_PlayerStates[client][nBhops]++;
	}
	
	else
	{
		g_PlayerStates[client][nBhops] = 0;
		
		//Only reset flags when jump chain stops so that players can't e.g. boost in the first jump and get a high distance on the next in a bhopjump
		g_PlayerStates[client][IllegalJumpFlags] = IJF_NONE;
	}
	
	g_PlayerStates[client][fLastJumpHeightDelta] = g_PlayerStates[client][fHeightDelta];
	
	for(int i = 0; i < g_PlayerStates[client][nStrafes] && i < MAX_STRAFES; i++)
	{
		view_as<float>(g_PlayerStates[client][fStrafeGain][i]) = 0.0;
		view_as<float>(g_PlayerStates[client][fStrafeLoss][i]) = 0.0;
		view_as<float>(g_PlayerStates[client][fStrafeSync][i]) = 0.0;
		g_PlayerStates[client][nStrafeTicks][i] = 0;
		g_PlayerStates[client][nStrafeTicksSynced][i] = 0;
	}
	
	//Reset stuff
	g_PlayerStates[client][JumpDir] = JD_NONE;
	g_PlayerStates[client][CurStrafeDir] = SD_NONE;
	g_PlayerStates[client][nStrafes] = 0;
	view_as<float>(g_PlayerStates[client][fSync]) = 0.0;
	view_as<float>(g_PlayerStates[client][fMaxSpeed]) = 0.0;
	view_as<float>(g_PlayerStates[client][fJumpHeight]) = 0.0;
	g_PlayerStates[client][nTotalTicks] = 0;
	view_as<float>(g_PlayerStates[client][fTotalAngle]) = 0.0;
	view_as<float>(g_PlayerStates[client][fSyncedAngle]) = 0.0;
	view_as<float>(g_PlayerStates[client][fEdge]) = -1.0;
	view_as<float>(g_PlayerStates[client][fBlockDistance]) = -1.0;
	g_PlayerStates[client][bFailedBlock] = false;
	view_as<float>(g_PlayerStates[client][fGain]) = 0.0;
	view_as<float>(g_PlayerStates[client][fLoss]) = 0.0;
	
	if(JumpType2 == JT_LONGJUMP && g_PlayerStates[client][bBlockMode])
	{
		view_as<float>(g_PlayerStates[client][fBlockDistance]) = GetBlockDistance(client);
	}
	
	g_PlayerStates[client][LastJumpType] = g_PlayerStates[client][JumpType];
	
	//Determine jump type
	if(JumpType2 == JT_DROP || JumpType2 == JT_LADDERJUMP)
	{
		g_PlayerStates[client][JumpType] = JumpType2;
	}
	
	else
	{
		if(g_PlayerStates[client][nBhops] > 1)
		{
			//g_PlayerStates[client][JumpType] = JT_BHOP;
			g_PlayerStates[client][JumpType] = JT_NONE;
		}
		
		else if(g_PlayerStates[client][nBhops] == 1)
		{
			if(g_PlayerStates[client][LastJumpType] == JT_DROP)
			{
				g_PlayerStates[client][fWJDropPre] = g_PlayerStates[client][fPrestrafe];
				g_PlayerStates[client][JumpType] = JT_WEIRDJUMP;
			}
			
			else if(g_PlayerStates[client][fLastJumpHeightDelta] > HEIGHT_DELTA_MIN(JT_LONGJUMP))
			{
				//g_PlayerStates[client][JumpType] = JT_BHOPJUMP;
				g_PlayerStates[client][JumpType] = JT_NONE;
			}
			
			else
			{
				//g_PlayerStates[client][JumpType] = JT_BHOP;
				g_PlayerStates[client][JumpType] = JT_NONE;
			}
		}
		
		else
		{
			if(GetEntProp(client, Prop_Send, "m_bDucking", 1))
			{
				g_PlayerStates[client][JumpType] = JT_COUNTJUMP;
			}
			
			else
			{
				g_PlayerStates[client][JumpType] = JT_LONGJUMP;
			}
		}
	}
	
	//Jumpoff origin
	float vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);
	Array_Copy(vOrigin, g_PlayerStates[client][vJumpOrigin], 3);
	
	//Prestrafe
	view_as<float>(g_PlayerStates[client][fPrestrafe]) = GetSpeed(client);
	
	if(g_PlayerStates[client][JumpType] == JT_LONGJUMP)
	{
		if(g_PlayerStates[client][fPrestrafe] > g_fLJMaxPrestrafe)
		{
			g_PlayerStates[client][IllegalJumpFlags] |= IJF_PRESTRAFE;
		}
		
		if(!g_bLJScoutStats && (g_fMaxspeed > 250.0 && GetEntPropFloat(client, Prop_Data, "m_flMaxspeed") > 250.0))
		{
			char strPlayerWeapon[32];
			GetClientWeapon(client, strPlayerWeapon, sizeof(strPlayerWeapon));
			
			if(!strcmp(strPlayerWeapon, "weapon_ssg08") || strPlayerWeapon[0] == 0)
			{
				g_PlayerStates[client][IllegalJumpFlags] |= IJF_SCOUT;
			}
		}
	}
	
	if(JumpType2 == JT_LONGJUMP)
	{
		view_as<float>(g_PlayerStates[client][fEdge]) = GetEdge(client);
	}
}

void GetJumpDistance(int client)
{
	float vCurOrigin[3];
	GetClientAbsOrigin(client, vCurOrigin);
	
	view_as<float>(g_PlayerStates[client][fHeightDelta]) = vCurOrigin[2] - g_PlayerStates[client][vJumpOrigin][2];
	
	vCurOrigin[2] = 0.0;
	
	float v[3];
	Array_Copy(g_PlayerStates[client][vJumpOrigin], v, 3);
	
	v[2] = 0.0;
	
	if(g_PlayerStates[client][JumpType] == JT_LADDERJUMP)
	{
		view_as<float>(g_PlayerStates[client][fJumpDistance]) = GetVectorDistance(v, vCurOrigin);
	}
	
	else
	{
		view_as<float>(g_PlayerStates[client][fJumpDistance]) = GetVectorDistance(v, vCurOrigin) + 32;
	}
	
	g_PlayerStates[client][bDuck] = view_as<bool>(GetEntProp(client, Prop_Send, "m_bDucked", 1));
}

void GetJumpDistanceLastTick(int client)
{
	float vCurOrigin[3];
	Array_Copy(g_PlayerStates[client][vLastOrigin], vCurOrigin, 3);
	
	view_as<float>(g_PlayerStates[client][fHeightDelta]) = vCurOrigin[2] - g_PlayerStates[client][vJumpOrigin][2];
	
	vCurOrigin[2] = 0.0;
	
	float v[3];
	Array_Copy(g_PlayerStates[client][vJumpOrigin], v, 3);
	
	v[2] = 0.0;
	
	view_as<float>(g_PlayerStates[client][fJumpDistance]) = GetVectorDistance(v, vCurOrigin) + 32.0;
	
	g_PlayerStates[client][bDuck] = g_PlayerStates[client][bSecondLastDuckState];
}

void CheckValidJump(int client)
{
	float vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);
	
	//Check gravity
	float fGravity = GetEntPropFloat(client, Prop_Data, "m_flGravity");
	
	if(fGravity != 1.0 && fGravity != 0.0)
	{
		g_PlayerStates[client][IllegalJumpFlags] |= IJF_GRAVITY;
	}
	
	//Check speed
	if(GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != 1.0)
	{
		g_PlayerStates[client][IllegalJumpFlags] |= IJF_LAGGEDMOVEMENTVALUE;
	}
	
	if(GetEntityMoveType(client) & MOVETYPE_NOCLIP)
	{
		g_PlayerStates[client][IllegalJumpFlags] |= IJF_NOCLIP;
	}
	
	//Teleport check
	float vLastOrig[3];
	float vLastVel[3];
	float vVel[3];
	Array_Copy(g_PlayerStates[client][vLastOrigin], vLastOrig, 3);
	Array_Copy(g_PlayerStates[client][vLastVelocity], vLastVel, 3);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	
	vLastOrig[2] = 0.0;
	vOrigin[2] = 0.0;
	vLastVel[2] = 0.0;
	vVel[2] = 0.0;
	
	// If the player moved further than their last velocity, they teleported
	// It's slightly off, so adjust velocity
	// pretty suk // less suk
	/*
	teleported 2.461413, 2.461400
	teleported 2.468606, 2.468604
	teleported 2.488778, 2.488739
	teleported 2.517628, 2.517453
	teleported 2.534332, 2.534170
	teleported 2.550610, 2.550508
	teleported 2.567417, 2.567395
	teleported 2.598604, 2.598514
	teleported 2.612708, 2.612616
	teleported 2.633581, 2.633533
	teleported 2.634170, 2.634044
	teleported 2.646703, 2.646473
	teleported 2.657407, 2.657327
	teleported 2.669471, 2.669248
	teleported 2.710047, 2.709968
	teleported 2.723108, 2.722937
	teleported 2.742104, 2.742006
	teleported 2.744069, 2.743859
	teleported 2.751010, 2.750807
	teleported 2.759773, 2.759721
	teleported 2.771660, 2.771600
	teleported 2.822698, 2.822640
	teleported 2.839976, 2.839771
	teleported 2.839976, 2.839771
	teleported 2.850264, 2.850194
	teleported 2.882310, 2.882229
	teleported 2.894205, 2.894115
	teleported 2.905041, 2.905009
	teleported 2.920642, 2.920416
	*/
	if(GetVectorDistance(vLastOrig, vOrigin) > GetVectorLength(vVel) / (1.0 / GetTickInterval()) + 0.001)
	{		
		if(g_PlayerStates[client][bBlockMode])
		{
			if(g_PlayerStates[client][bFailedBlock])
			{				
				return;
			}
			
			else
			{				
				if(g_PlayerStates[client][vLastOrigin][2] >= g_PlayerStates[client][vJumpOrigin][2] + HEIGHT_DELTA_MIN(JT_LONGJUMP))
				{
					GetJumpDistanceLastTick(client);
					g_PlayerStates[client][bFailedBlock] = true;
					
					return;
				}
			}
		}
		
		g_PlayerStates[client][IllegalJumpFlags] |= IJF_TELEPORT;
	}
}

void TBAnglesToUV(float vOut[3], const float vAngles[3])
{
	vOut[0] = Cosine(vAngles[1] * FLOAT_PI / 180.0) * Cosine(vAngles[0] * FLOAT_PI / 180.0);
	vOut[1] = Sine(vAngles[1] * FLOAT_PI / 180.0) * Cosine(vAngles[0] * FLOAT_PI / 180.0);
	vOut[2] = -Sine(vAngles[0] * FLOAT_PI / 180.0);
}

void _OnPlayerRunCmd(int client, int buttons, const float vOrigin[3], const float vAngles[3], const float vVelocity[3], bool bDucked, bool bGround)
{
	if(g_PlayerStates[client][GapSelectionMode] != GSM_NONE)
	{
		GapSelect(client, buttons);
	}
	
	//Manage spectators
	if(IsClientObserver(client))
	{
		if(gI_JumpStats[client] == 1)
		{
			int nObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
			
			if(3 < nObserverMode < 7)
			{
				int nTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				
				if(g_PlayerStates[client][nSpectatorTarget] != nTarget)
				{
					if(g_PlayerStates[client][nSpectatorTarget] != -1 && g_PlayerStates[client][nSpectatorTarget] > 0 && g_PlayerStates[client][nSpectatorTarget] < MaxClients)
					{
						g_PlayerStates[g_PlayerStates[client][nSpectatorTarget]][nSpectators]--;
					}
					
					//g_PlayerStates[nTarget][nSpectators]++;
					g_PlayerStates[client][nSpectatorTarget] = nTarget;
				}
			}
		}
		
		else
		{
			if(g_PlayerStates[client][nSpectatorTarget] != -1)
			{
				if(g_PlayerStates[client][nSpectatorTarget] > 0 && g_PlayerStates[client][nSpectatorTarget] < MaxClients)
				{
					g_PlayerStates[g_PlayerStates[client][nSpectatorTarget]][nSpectators]--;
				}
				
				g_PlayerStates[client][nSpectatorTarget] = -1;
			}
		}
		
		return;
	}
	
	else
	{
		if(g_PlayerStates[client][nSpectatorTarget] != -1)
		{
			g_PlayerStates[g_PlayerStates[client][nSpectatorTarget]][nSpectators]--;
			g_PlayerStates[client][nSpectatorTarget] = -1;
		}
	}
	
	if(!g_PlayerStates[client][bOnGround])
	{
		CheckValidJump(client);
	}
	
	//Call PlayerJump for ladder jumps or walking off the edge
	if(GetEntityMoveType(client) == MOVETYPE_LADDER)
	{
		g_PlayerStates[client][bOnLadder] = true;
	}
	
	else
	{
		if(g_PlayerStates[client][bOnLadder])
		{
			PlayerJump(client, JT_LADDERJUMP);
		}
		
		g_PlayerStates[client][bOnLadder] = false;
	}
	
	if(!bGround)
	{
		if(g_PlayerStates[client][bOnGround])
		{
			PlayerJump(client, JT_DROP);
		}
	}
	
	if(g_PlayerStates[client][bOnGround] || g_PlayerStates[client][nStrafes] >= MAX_STRAFES || g_PlayerStates[client][bFailedBlock])
	{
		//dumb language
		if((bGround || g_PlayerStates[client][bOnLadder]) && !g_PlayerStates[client][bOnGround])
		{
			PlayerLand(client);
		}
		
		return;
	}
	
	
	if(!bGround)
	{		
		if(GetVSpeed(vVelocity) > g_PlayerStates[client][fMaxSpeed])
		{
			view_as<float>(g_PlayerStates[client][fMaxSpeed]) = GetVSpeed(vVelocity);
		}
		
		if(vOrigin[2] - g_PlayerStates[client][vJumpOrigin][2] > g_PlayerStates[client][fJumpHeight])
		{
			view_as<float>(g_PlayerStates[client][fJumpHeight]) = vOrigin[2] - g_PlayerStates[client][vJumpOrigin][2];
		}
		
		//Record the failed distance, but since it will trigger if you duck late, only save it if it's certain that the player will not land
		if(g_PlayerStates[client][bBlockMode] &&
		!g_PlayerStates[client][bFailedBlock] &&
		(bDucked && vOrigin[2] <= g_PlayerStates[client][vJumpOrigin][2] + 1.0 ||
		!bDucked && vOrigin[2] <= g_PlayerStates[client][vJumpOrigin][2] + 1.5) &&
		vOrigin[2] >= g_PlayerStates[client][vJumpOrigin][2] + HEIGHT_DELTA_MIN(JT_LONGJUMP))
		{
			GetJumpDistance(client);
		}
		
		//Check if the player is still capable of landing
		if(g_PlayerStates[client][bBlockMode] && !g_PlayerStates[client][bFailedBlock] && 
		(bDucked && vOrigin[2] <= g_PlayerStates[client][vJumpOrigin][2] + HEIGHT_DELTA_MIN(JT_LONGJUMP)/* + 1.0*/ || //You land at 0.79 elevation when ducking
		!bDucked && vOrigin[2] <= g_PlayerStates[client][vJumpOrigin][2] - 10.5))
		//Ducking increases your origin by 8.5; you land at 1.47 units elevation when ducking, so around 10.0; 10.5 for good measure
		{			
			g_PlayerStates[client][bDuck] = bDucked;
			g_PlayerStates[client][bFailedBlock] = true;
			
			if(bGround && !g_PlayerStates[client][bOnGround])
			{
				PlayerLand(client);
			}
			
			return;
		}
	}
	
	
	if(g_PlayerStates[client][JumpDir] == JD_BACKWARDS)
	{
		float vAnglesUV[3];
		TBAnglesToUV(vAnglesUV, vAngles);
		
		float vVelocityDir[3];
		vVelocityDir = vVelocity;
		vVelocityDir[2] = 0.0;
		NormalizeVector(vVelocityDir, vVelocityDir);
		
		if(ArcCosine(GetVectorDotProduct(vAnglesUV, vVelocityDir)) < FLOAT_PI / 2)
		{
			g_PlayerStates[client][JumpDir] = JD_NORMAL;
		}
	}
	
	//check for multiple keys -- it will spam strafes when multiple are held without this
	int nButtonCount;
	
	if(buttons & IN_MOVELEFT)
	{
		nButtonCount++;
	}
	
	if(buttons & IN_MOVERIGHT)
	{
		nButtonCount++;
	}
	
	if(buttons & IN_FORWARD)
	{
		nButtonCount++;
	}
	
	if(buttons & IN_BACK)
	{
		nButtonCount++;
	}
	
	if(nButtonCount == 1)
	{
		if(g_PlayerStates[client][CurStrafeDir] != SD_A && buttons & IN_MOVELEFT)
		{
			if(g_PlayerStates[client][JumpDir] == JD_NONE)
			{
				float vAnglesUV[3];
				TBAnglesToUV(vAnglesUV, vAngles);
				
				float vVelocityDir[3];
				vVelocityDir = vVelocity;
				vVelocityDir[2] = 0.0;
				NormalizeVector(vVelocityDir, vVelocityDir);
				
				if(ArcCosine(GetVectorDotProduct(vAnglesUV, vVelocityDir)) > FLOAT_PI / 2)
				{
					g_PlayerStates[client][JumpDir] = JD_BACKWARDS;
				}
				
				else
				{
					g_PlayerStates[client][JumpDir] = JD_NORMAL;
				}
			}
			
			if(g_PlayerStates[client][JumpDir] == JD_SIDEWAYS)
			{
				g_PlayerStates[client][JumpDir] = JD_NORMAL;
			}
			
			g_PlayerStates[client][StrafeDir][g_PlayerStates[client][nStrafes]] = SD_A;
			g_PlayerStates[client][CurStrafeDir] = SD_A;
			g_PlayerStates[client][nStrafes]++;
		}
		
		else if(g_PlayerStates[client][CurStrafeDir] != SD_D && buttons & IN_MOVERIGHT)
		{
			if(g_PlayerStates[client][JumpDir] == JD_NONE)
			{
				float vAnglesUV[3];
				TBAnglesToUV(vAnglesUV, vAngles);
				
				float vVelocityDir[3];
				vVelocityDir = vVelocity;
				vVelocityDir[2] = 0.0;
				NormalizeVector(vVelocityDir, vVelocityDir);
				
				if(ArcCosine(GetVectorDotProduct(vAnglesUV, vVelocityDir)) > FLOAT_PI / 2)
				{
					g_PlayerStates[client][JumpDir] = JD_BACKWARDS;
				}
				
				else
				{
					g_PlayerStates[client][JumpDir] = JD_NORMAL;
				}
			}
			
			else if(g_PlayerStates[client][JumpDir] == JD_SIDEWAYS)
			{
				g_PlayerStates[client][JumpDir] = JD_NORMAL;
			}
			
			g_PlayerStates[client][StrafeDir][g_PlayerStates[client][nStrafes]] = SD_D;
			g_PlayerStates[client][CurStrafeDir] = SD_D;
			g_PlayerStates[client][nStrafes]++;
		}
		
		else if(g_PlayerStates[client][CurStrafeDir] != SD_W && buttons & IN_FORWARD)
		{
			if(g_PlayerStates[client][JumpDir] == JD_NONE && (vVelocity[0] || vVelocity[1]))
			{
				float vAnglesUV[3];
				TBAnglesToUV(vAnglesUV, vAngles);
				
				float vVelocityDir[3];
				vVelocityDir = vVelocity;
				vVelocityDir[2] = 0.0;
				NormalizeVector(vVelocityDir, vVelocityDir);
				
				if(DegToRad(90.0 - SW_ANGLE_THRESHOLD) < ArcCosine(GetVectorDotProduct(vAnglesUV, vVelocityDir)) < DegToRad(90.0 + SW_ANGLE_THRESHOLD))
				{
					g_PlayerStates[client][JumpDir] = JD_SIDEWAYS;
				}
			}
			
			g_PlayerStates[client][StrafeDir][g_PlayerStates[client][nStrafes]] = SD_W;
			g_PlayerStates[client][CurStrafeDir] = SD_W;
			g_PlayerStates[client][nStrafes]++;
		}
		
		else if(g_PlayerStates[client][CurStrafeDir] != SD_S && buttons & IN_BACK)
		{
			if(g_PlayerStates[client][JumpDir] == JD_NONE && (vVelocity[0] || vVelocity[1]))
			{
				float vAnglesUV[3];
				TBAnglesToUV(vAnglesUV, vAngles);
				
				float vVelocityDir[3];
				vVelocityDir = vVelocity;
				vVelocityDir[2] = 0.0;
				NormalizeVector(vVelocityDir, vVelocityDir);
				
				if(DegToRad(90.0 - SW_ANGLE_THRESHOLD) < ArcCosine(GetVectorDotProduct(vAnglesUV, vVelocityDir)) < DegToRad(90.0 + SW_ANGLE_THRESHOLD))
				{
					g_PlayerStates[client][JumpDir] = JD_SIDEWAYS;
				}
			}
			
			g_PlayerStates[client][StrafeDir][g_PlayerStates[client][nStrafes]] = SD_S;
			g_PlayerStates[client][CurStrafeDir] = SD_S;
			g_PlayerStates[client][nStrafes]++;
		}
	}
	
	if(g_PlayerStates[client][nStrafes] > 0)
	{
		float v[3];
		float v2[3];
		Array_Copy(g_PlayerStates[client][vLastVelocity], v, 3);
		Array_Copy(g_PlayerStates[client][vLastAngles], v2, 3);
		
		float fVelDelta = GetSpeed(client) - GetVSpeed(v);
		
		float fAngleDelta = fmod((FloatAbs(vAngles[1] - v2[1]) + 180.0), 360.0) - 180.0;
		
		g_PlayerStates[client][nStrafeTicks][g_PlayerStates[client][nStrafes] - 1]++;
		
		g_PlayerStates[client][fTotalAngle] += fAngleDelta;
		
		if(fVelDelta > 0.0)
		{
			g_PlayerStates[client][fStrafeGain][g_PlayerStates[client][nStrafes] - 1] += fVelDelta;
			g_PlayerStates[client][fGain] += fVelDelta;
			
			g_PlayerStates[client][nStrafeTicksSynced][g_PlayerStates[client][nStrafes] - 1]++;
			
			g_PlayerStates[client][fSyncedAngle] += fAngleDelta;
		}
		
		else
		{
			g_PlayerStates[client][fStrafeLoss][g_PlayerStates[client][nStrafes] - 1] -= fVelDelta;
			g_PlayerStates[client][fLoss] -= fVelDelta;
		}
	}
	
	g_PlayerStates[client][nTotalTicks]++;
	
	if(bGround && !g_PlayerStates[client][bOnGround])
	{
		PlayerLand(client);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float vAngles[3], int &weapon)
{
	float vOrigin[3];
	float vVelocity[3];
	bool bDucked = view_as<bool>(GetEntProp(client, Prop_Send, "m_bDucked", 1));
	bool bGround = view_as<bool>(GetEntityFlags(client) & FL_ONGROUND);
	GetClientAbsOrigin(client, vOrigin);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
	
	_OnPlayerRunCmd(client, buttons, vOrigin, vAngles, vVelocity, bDucked, bGround);
	
	Array_Copy(vOrigin, g_PlayerStates[client][vLastOrigin], 3);
	Array_Copy(vAngles, g_PlayerStates[client][vLastAngles], 3);
	Array_Copy(vVelocity, g_PlayerStates[client][vLastVelocity], 3);
	g_PlayerStates[client][bSecondLastDuckState] = g_PlayerStates[client][bLastDuckState];
	g_PlayerStates[client][bLastDuckState] = bDucked;
	g_PlayerStates[client][LastButtons] = buttons;
	
	return Plugin_Continue;
}

void PlayerLand(int client)
{
	g_PlayerStates[client][bOnGround] = true;
	
	view_as<float>(g_PlayerStates[client][fLandTime]) = GetGameTime();
	
	if(g_PlayerStates[client][nBhops] > 1)
	{
		return;
	}
	
	//Final CheckValidJump
	//CheckValidJump(client);
	
	float vCurOrigin[3];
	GetClientAbsOrigin(client, vCurOrigin);
	view_as<float>(g_PlayerStates[client][fFinalSpeed]) = GetSpeed(client);
	
	//Calculate distances
	if(!g_PlayerStates[client][bFailedBlock])// || // if block longjump failed, distances have already been written in mid-air.
	//vCurOrigin[2] - g_PlayerStates[client][vJumpOrigin][2] >= HEIGHT_DELTA_MIN(JT_LONGJUMP)) // bugs sometimes if you land on last tick (I think) idk how else 2 fix
	{
		GetJumpDistance(client);
		
		g_PlayerStates[client][bFailedBlock] = false;
	}
	
	//don't show drop stats
	if(g_PlayerStates[client][JumpType] == JT_DROP)
	{
		return;
	}
	
	if(g_PlayerStates[client][JumpType] == JT_LONGJUMP)
	{
		if(g_PlayerStates[client][fHeightDelta] > HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType]) && g_PlayerStates[client][fHeightDelta] < HEIGHT_DELTA_MAX(g_PlayerStates[client][JumpType]))
		{
			if(g_PlayerStates[client][fJumpDistance] <= 240.0)
			{
				return;
			}
		}
		
		else //Dropjump/upjump
		{
			if(g_PlayerStates[client][fJumpDistance] <= 240.0 - g_PlayerStates[client][fHeightDelta])
			{
				return;
			}
		}
	}
	
	if(g_PlayerStates[client][JumpType] == JT_LADDERJUMP)
	{
		if(g_PlayerStates[client][fJumpDistance] <= 100.0)
		{
			return;
		}
	}
	
	else if(g_PlayerStates[client][fJumpDistance] <= 240.0 || g_PlayerStates[client][JumpType] == JT_NONE)
	{
		return;
	}
	
	//Check whether the player actually moved past the block edge
	if(g_PlayerStates[client][bBlockMode] && !g_PlayerStates[client][bFailedBlock])
	{
		if(!g_PlayerStates[client][vBlockNormal][0] || !g_PlayerStates[client][vBlockNormal][1])
		{
			//bools are not actually handled as 1 bit bools but 32 bit cells so n = normal.y gives out of bounds exception
			//!!normal.y or !normal.x rather
			//pawn good
			bool n = !g_PlayerStates[client][vBlockNormal][0];
			
			if(g_PlayerStates[client][vBlockNormal][n] > 0.0)
			{
				if(vCurOrigin[n] + 16.0 * g_PlayerStates[client][vBlockNormal][n] < g_PlayerStates[client][vBlockEndPos][n])
				{
					g_PlayerStates[client][bFailedBlock] = true;
				}
			}
			
			else
			{
				if(vCurOrigin[n] + 16.0 * g_PlayerStates[client][vBlockNormal][n] > g_PlayerStates[client][vBlockEndPos][n])
				{
					g_PlayerStates[client][bFailedBlock] = true;
				}
			}
		}
		
		else
		{
			float vAdjCurOrigin[3];
			float vInvNormal[3];
			vAdjCurOrigin = vCurOrigin;
			Array_Copy(g_PlayerStates[client][vBlockNormal], vInvNormal, 2);
			ScaleVector(vInvNormal, -1.0);
			Adjust(vAdjCurOrigin, vInvNormal);
			
			//f(endpos.x) + (origin.x - endpos.x) * b = (f(endpos.x) - endpos.x * b) + origin.x * b = f(0) + origin.x * b
			//block normal is perpendicular to the edge direction, so b = 1 / (normal rot 90).x
			//dx and dy should have same sign so ccw rot if facing down, cw rot if up
			float b = 1 / (view_as<float>(g_PlayerStates[client][vBlockNormal][0]) < 0 ? view_as<float>(g_PlayerStates[client][vBlockNormal][1]) : view_as<float>(-g_PlayerStates[client][vBlockNormal][1]));
			float fPos = g_PlayerStates[client][vBlockEndPos][1] + (vAdjCurOrigin[0] - g_PlayerStates[client][vBlockEndPos][0]) * b;
			
			if(g_PlayerStates[client][vBlockNormal][1] > 0.0 ? vAdjCurOrigin[1] < fPos : vAdjCurOrigin[1] > fPos)
			{
				g_PlayerStates[client][bFailedBlock] = true;
			}
		}
	}
	
	
	//sum sync
	view_as<float>(g_PlayerStates[client][fSync]) = 0.0;
	
	for(int i = 0; i < g_PlayerStates[client][nStrafes] && i < MAX_STRAFES; i++)
	{
		g_PlayerStates[client][fSync] += g_PlayerStates[client][nStrafeTicksSynced][i];
		view_as<float>(g_PlayerStates[client][fStrafeSync][i]) = float(g_PlayerStates[client][nStrafeTicksSynced][i]) / g_PlayerStates[client][nStrafeTicks][i] * 100;
	}
	
	g_PlayerStates[client][fSync] /= g_PlayerStates[client][nTotalTicks];
	g_PlayerStates[client][fSync] *= 100;
	
	////
	// Write HUD hint
	////
	
	char buf[512];
	
	g_PlayerStates[client][strHUDHint][0] = 0;
	
	if(g_PlayerStates[client][bBlockMode] && g_PlayerStates[client][fHeightDelta] >= HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType]))
	{
		if(g_PlayerStates[client][fBlockDistance] != -1.0 && !g_PlayerStates[client][bFailedBlock])
		{
			Format(buf, sizeof(buf), "%.1f block\n", g_PlayerStates[client][fBlockDistance]);
			
			StrCat(g_PlayerStates[client][strHUDHint], HUD_HINT_SIZE, buf);
		}
	}
	
	char strJump[32];
	
	if(g_PlayerStates[client][fHeightDelta] > HEIGHT_DELTA_MAX(g_PlayerStates[client][JumpType]))
	{
		if(g_PlayerStates[client][JumpType] == JT_LONGJUMP)
		{
			strJump = "Upjump";
		}
		
		else
		{
			Format(strJump, sizeof(strJump), "Up%s", g_strJumpTypeLwr[g_PlayerStates[client][JumpType]]);
		}
	}
	
	else if(g_PlayerStates[client][fHeightDelta] < HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType]))
	{
		if(g_PlayerStates[client][JumpType] == JT_LONGJUMP)
		{
			strJump = "Dropjump";
		}
		
		else
		{
			Format(strJump, sizeof(strJump), "Drop%s", g_strJumpTypeLwr[g_PlayerStates[client][JumpType]]);
		}
	}
	
	else
	{
		strcopy(strJump, sizeof(strJump), g_strJumpType[g_PlayerStates[client][JumpType]]);
	}
	
	char strJumpDir[16];
	strJumpDir = g_PlayerStates[client][JumpDir] == JD_SIDEWAYS ? " sideways" : g_PlayerStates[client][JumpDir] == JD_BACKWARDS ? " backwards" : "";
	
	Format(buf, sizeof(buf), "%s%s%s\nPrestrafe: [%.2f]\n",
	strJump, strJumpDir,
	g_PlayerStates[client][JumpType] == JT_LONGJUMP &&
	g_PlayerStates[client][fHeightDelta] >= HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType]) &&
	g_PlayerStates[client][IllegalJumpFlags] == IJF_NONE &&
	g_PlayerStates[client][nTotalTicks] > 77 ? " (extended)" : "",
	g_PlayerStates[client][fPrestrafe]);
	
	StrCat(g_PlayerStates[client][strHUDHint], HUD_HINT_SIZE, buf);
	
	if(g_PlayerStates[client][JumpType] == JT_WEIRDJUMP)
	{
		Format(buf, sizeof(buf), "Prestrafe dropped to: [%.2f]\n",
		g_PlayerStates[client][fWJDropPre]);
		
		StrCat(g_PlayerStates[client][strHUDHint], HUD_HINT_SIZE, buf);
	}
	
	Format(buf, sizeof(buf), "Distance: [%.2f]\n",
	g_PlayerStates[client][fJumpDistance]);
	
	StrCat(g_PlayerStates[client][strHUDHint], HUD_HINT_SIZE, buf);
	
	if(g_PlayerStates[client][fEdge] != -1.0)
	{
		Format(buf, sizeof(buf), "Edge: [%.2f]\n",
		g_PlayerStates[client][fEdge]);
		
		StrCat(g_PlayerStates[client][strHUDHint], HUD_HINT_SIZE, buf);
	}
	
	StrCat(g_PlayerStates[client][strHUDHint], HUD_HINT_SIZE, "\n");
	
	Format(buf, sizeof(buf), "Strafes: [%d]\nSync: [%.2f]\n",
	g_PlayerStates[client][nStrafes],
	g_PlayerStates[client][fSync]);
	
	StrCat(g_PlayerStates[client][strHUDHint], HUD_HINT_SIZE, buf);
	
	buf[0] = 0;
	
	Append(buf, sizeof(buf), "\n");
	
	if(g_PlayerStates[client][bBlockMode] && g_PlayerStates[client][fHeightDelta] >= HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType]))
	{
		if(g_PlayerStates[client][fBlockDistance] != -1.0 && !g_PlayerStates[client][bFailedBlock])
		{
			Append(buf, sizeof(buf), "%.01f block\n", g_PlayerStates[client][fBlockDistance]);
		}
	}
	
	Append(buf, sizeof(buf), "%s%s%s\nDistance: %.2f",
	strJump, strJumpDir, 
	g_PlayerStates[client][JumpType] == JT_LONGJUMP &&
	g_PlayerStates[client][fHeightDelta] > HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType])
	&& g_PlayerStates[client][nTotalTicks] > 77 ? " (extended)" : "",
	g_PlayerStates[client][fJumpDistance]);
	
	Append(buf, sizeof(buf), " | Prestrafe: %.2f",
	g_PlayerStates[client][fPrestrafe]);
	
	if(g_PlayerStates[client][JumpType] == JT_WEIRDJUMP)
	{
		Append(buf, sizeof(buf), " | Drop prestrafe: %.2f",
		g_PlayerStates[client][fWJDropPre]);
	}
	
	if(g_PlayerStates[client][fEdge] != -1.0)
	{
		Append(buf, sizeof(buf), " | Edge: %.2f",
		g_PlayerStates[client][fEdge]);
	}
	
	if(g_PlayerStates[client][nTotalTicks] == 78)
	{
		float vCurOrigin2[3];
		Array_Copy(g_PlayerStates[client][vLastOrigin], vCurOrigin2, 3);
		
		vCurOrigin2[2] = 0.0;
		
		float v[3];
		Array_Copy(g_PlayerStates[client][vJumpOrigin], v, 3);
		
		v[2] = 0.0;
		
		float ProjDist = GetVectorDistance(v, vCurOrigin2) + 32.0;
		
		Append(buf, sizeof(buf), " | Projected real distance: %.2f", ProjDist);
	}
	
	Append(buf, sizeof(buf), "\nStrafes: %d | Sync: %.2f | Max: %.2f u/s | Gain: %.2f",
	g_PlayerStates[client][nStrafes],
	g_PlayerStates[client][fSync],
	g_PlayerStates[client][fMaxSpeed],
	g_PlayerStates[client][fMaxSpeed] - g_PlayerStates[client][fPrestrafe]);
	
	if(gI_JumpStats[client] == 1)
	{
		PrintToConsole(client, buf);
		
		SetHudTextParams(0.41, 0.01, 5.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
		ShowHudText(client, 5, g_PlayerStates[client][strHUDHint]);
	}
	
	////
	// Panel
	////
	
	Handle hStatsPanel = CreatePanel();
	
	if(g_PlayerStates[client][fHeightDelta] > HEIGHT_DELTA_MAX(g_PlayerStates[client][JumpType]))
	{
		if(g_PlayerStates[client][JumpType] == JT_LONGJUMP)
		{
			strJump = "UP";
		}
		
		else
		{
			Format(strJump, sizeof(strJump), "UP%s", g_strJumpTypeShort[g_PlayerStates[client][JumpType]]);
		}
	}
	
	else if(g_PlayerStates[client][fHeightDelta] < HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType]))
	{
		if(g_PlayerStates[client][JumpType] == JT_LONGJUMP)
		{
			strJump = "DROP";
		}
		
		else
		{
			Format(strJump, sizeof(strJump), "DROP%s", g_strJumpTypeShort[g_PlayerStates[client][JumpType]]);
		}
	}
	
	else
	{
		strcopy(strJump, sizeof(strJump), g_strJumpTypeShort[g_PlayerStates[client][JumpType]]);
	}
	
	if(g_PlayerStates[client][JumpDir] == JD_FORWARDS)
	{
		Format(buf, 128, "%s %.2f", strJump, g_PlayerStates[client][fJumpDistance]);
	}
	
	if(g_PlayerStates[client][JumpDir] != JD_FORWARDS)
	{
		if(!(g_PlayerStates[client][bBlockMode] && g_PlayerStates[client][fBlockDistance] != -1.0 && g_PlayerStates[client][fHeightDelta] >= HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType])) && g_PlayerStates[client][JumpDir] == JD_SIDEWAYS)
		{
			Format(buf, 128, "%s SW %.2f", strJump, g_PlayerStates[client][fJumpDistance]);
		}
		
		else if(!(g_PlayerStates[client][bBlockMode] && g_PlayerStates[client][fBlockDistance] != -1.0 && g_PlayerStates[client][fHeightDelta] >= HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType])) && g_PlayerStates[client][JumpDir] == JD_BACKWARDS)
		{
			Format(buf, 128, "%s BW %.2f", strJump, g_PlayerStates[client][fJumpDistance]);
		}
	}
	
	if(!g_PlayerStates[client][bFailedBlock] && g_PlayerStates[client][bBlockMode] && g_PlayerStates[client][fBlockDistance] != -1.0 && g_PlayerStates[client][fHeightDelta] >= HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType]) && g_PlayerStates[client][JumpDir] == JD_FORWARDS)
	{
		Format(buf, 128, "%s %.2f | %.01f block", strJump, g_PlayerStates[client][fJumpDistance], g_PlayerStates[client][fBlockDistance]);
	}
	
	if(g_PlayerStates[client][JumpDir] != JD_FORWARDS)
	{
		if(!g_PlayerStates[client][bFailedBlock] && g_PlayerStates[client][bBlockMode] && g_PlayerStates[client][fBlockDistance] != -1.0 && g_PlayerStates[client][fHeightDelta] >= HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType]) && g_PlayerStates[client][JumpDir] == JD_SIDEWAYS)
		{
			Format(buf, 128, "%s SW %.2f | %.01f block", strJump, g_PlayerStates[client][fJumpDistance], g_PlayerStates[client][fBlockDistance]);
		}
		
		else if(!g_PlayerStates[client][bFailedBlock] && g_PlayerStates[client][bBlockMode] && g_PlayerStates[client][fBlockDistance] != -1.0 && g_PlayerStates[client][fHeightDelta] >= HEIGHT_DELTA_MIN(g_PlayerStates[client][JumpType]) && g_PlayerStates[client][JumpDir] == JD_BACKWARDS)
		{
			Format(buf, 128, "%s BW %.2f | %.01f block", strJump, g_PlayerStates[client][fJumpDistance], g_PlayerStates[client][fBlockDistance]);
		}
	}
	
	SetPanelTitle(hStatsPanel, buf);
	DrawPanelTextF(hStatsPanel, " ");
	
	if(gI_JumpStats[client] == 1)
	{
		PrintToConsole(client, "--------------------------------");
	}

	DrawPanelTextF(hStatsPanel, "# | Key | Gain  | Loss  | Sync");
	DrawPanelTextF(hStatsPanel, " ");
	
	// Print first 11 strafes to panel
	for(int i = 0; i < g_PlayerStates[client][nStrafes] && i < 11; i++)
	{
		char strStrafeKey[3];
		GetStrafeKey(strStrafeKey, g_PlayerStates[client][StrafeDir][i]);
		DrawPanelTextF(hStatsPanel, "%2d | %s   | %6.2f | %6.2f | %6.2f",
		i + 1,
		strStrafeKey,
		g_PlayerStates[client][fStrafeGain][i], g_PlayerStates[client][fStrafeLoss][i],
		float(g_PlayerStates[client][nStrafeTicksSynced][i]) / g_PlayerStates[client][nStrafeTicks][i] * 100);
	}
	
	// Print strafes to console
	if(gI_JumpStats[client] == 1)
	{
		PrintToConsole(client, " # | Key | Gain  | Loss  | Sync");
		
		for(int i = 0; i < g_PlayerStates[client][nStrafes] && i < MAX_STRAFES; i++)
		{
			char strStrafeKey[3];
			GetStrafeKey(strStrafeKey, g_PlayerStates[client][StrafeDir][i]);
			Format(buf, sizeof(buf), "%2d | %s   |%6.2f |%6.2f |%6.2f", i + 1,
			strStrafeKey,
			g_PlayerStates[client][fStrafeGain][i], g_PlayerStates[client][fStrafeLoss][i],
			float(g_PlayerStates[client][nStrafeTicksSynced][i]) / g_PlayerStates[client][nStrafeTicks][i] * 100);
			
			PrintToConsole(client, buf);
		}
	}
	
	DrawPanelTextF(hStatsPanel, " ");
	DrawPanelTextF(hStatsPanel, "    Sync: %.2f%% | %s", g_PlayerStates[client][fSync], g_PlayerStates[client][bDuck] ? "Duck" : g_PlayerStates[client][bLastDuckState] ? "Partial duck" : "No duck");
	
	if(gI_JumpStats[client] == 1)
	{
		PrintToConsole(client, "    %s", g_PlayerStates[client][bDuck] ? "Duck" : g_PlayerStates[client][bLastDuckState] ? "Partial duck" : "No duck");
		
		PrintToConsole(client, ""); //Newline
	}
	
	if(gI_JumpStats[client] == 1 && g_PlayerStates[client][JumpType] != JT_BHOP && g_PlayerStates[client][IllegalJumpFlags])
	{
		PrintToConsole(client, "Illegal jump: ");
		
		if(g_PlayerStates[client][IllegalJumpFlags] & IJF_WORLD)
		{
			PrintToConsole(client, "Lateral world collision (hit wall/surf)");
		}
		
		if(g_PlayerStates[client][IllegalJumpFlags] & IJF_BOOSTER)
		{
			PrintToConsole(client, "Booster");
		}
		
		if(g_PlayerStates[client][IllegalJumpFlags] & IJF_GRAVITY)
		{
			PrintToConsole(client, "Gravity");
		}
		
		if(g_PlayerStates[client][IllegalJumpFlags] & IJF_TELEPORT)
		{
			PrintToConsole(client, "Teleport");
		}
		
		if(g_PlayerStates[client][IllegalJumpFlags] & IJF_LAGGEDMOVEMENTVALUE)
		{
			PrintToConsole(client, "Lagged movement value");
		}
		
		if(g_PlayerStates[client][IllegalJumpFlags] & IJF_PRESTRAFE)
		{
			PrintToConsole(client, "Prestrafe > %.2f", g_fLJMaxPrestrafe);
		}
		
		if(g_PlayerStates[client][IllegalJumpFlags] & IJF_SCOUT)
		{
			PrintToConsole(client, "Scout");
		}
		
		if(g_PlayerStates[client][IllegalJumpFlags] & IJF_NOCLIP)
		{
			PrintToConsole(client, "noclip");
		}
	
		PrintToConsole(client, ""); // Newline
	}
	
	if(gI_JumpStats[client] == 1 && !g_PlayerStates[client][bHidePanel] && !(g_PlayerStates[client][nBhops] > 1))
	{
		SendPanelToClient(hStatsPanel, client, EmptyPanelHandler, 5);
	}
	
	//Send to spectators of this player
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(g_PlayerStates[i][nSpectatorTarget] == client)
			{
				if(!g_PlayerStates[i][bHidePanel])
				{
					SendPanelToClient(hStatsPanel, i, EmptyPanelHandler, 5);
				}
				
				SetHudTextParams(0.41, 0.01, 5.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
				ShowHudText(i, 5, g_PlayerStates[client][strHUDHint]);
			}
		}
	}
	
	CloseHandle(hStatsPanel);
	
	////
	// Print chat message
	////
	
	if(gI_JumpStats[client] == 0 ||
	g_PlayerStates[client][IllegalJumpFlags] != IJF_NONE ||
	g_PlayerStates[client][fHeightDelta] < HEIGHT_DELTA_MIN(view_as<JUMP_TYPE>((g_PlayerStates[client][JumpType]) == JT_BHOP ? JT_BHOPJUMP : g_PlayerStates[client][JumpType])) ||
	g_PlayerStates[client][bFailedBlock] && !g_bPrintFailedBlockStats)
	{
		return;
	}
	
	if(g_PlayerStates[client][JumpType] == JT_BHOPJUMP && g_PlayerStates[client][fLastJumpHeightDelta] < HEIGHT_DELTA_MIN(JT_BHOPJUMP))
	{
		return;
	}
	
	switch(g_PlayerStates[client][JumpType])
	{
		case JT_LONGJUMP, JT_COUNTJUMP:
		{
			float fMin = (g_fLJNoDuckMin != 0.0 && !g_PlayerStates[client][bDuck] && !g_PlayerStates[client][bLastDuckState]) ? g_fLJNoDuckMin : g_fLJMin;
			
			if(fMin != 0.0 && g_PlayerStates[client][fJumpDistance] >= fMin)
			{
				OutputJump(client, buf);
			}
		}
		
		case JT_WEIRDJUMP:
		{
			if(g_fWJMin != 0.0 && view_as<float>(g_PlayerStates[client][fJumpDistance]) > g_fWJMin && (g_fWJDropMax == 0.0 || g_fWJDropMax >= FloatAbs(view_as<float>(g_PlayerStates[client][fLastJumpHeightDelta]))))
			{
				OutputJump(client, buf);
			}
		}
		
		case JT_BHOPJUMP:
		{
			if(g_fBJMin != 0.0 && g_PlayerStates[client][fJumpDistance] >= g_fBJMin)
			{
				OutputJump(client, buf);
			}
		}
		
		case JT_LADDERJUMP:
		{
			if(g_fLAJMin != 0.0 && g_PlayerStates[client][fJumpDistance] >= g_fLAJMin)
			{
				OutputJump(client, buf);
			}
		}
	}
}

int EmptyPanelHandler(Handle hPanel, MenuAction ma, int Param1, int Param2)
{
}

void OutputJump(int client, char buf[512])
{
	float fMin = (g_fLJNoDuckMin != 0.0 && !g_PlayerStates[client][bDuck] && !g_PlayerStates[client][bLastDuckState]) ? g_fLJNoDuckMin : g_fLJMin;
	
	bool bPrintToAll = false;
	
	if(g_PlayerStates[client][JumpType] == JT_LONGJUMP && g_fLJClientMin != 0 && g_PlayerStates[client][fJumpDistance] < fMin)
	{
		fMin = g_fLJClientMin;
		
		bPrintToAll = false;
	}
	
	char strOutput[512];
	
	if(g_PlayerStates[client][JumpDir] == JD_FORWARDS)
	{
		Format(strOutput, sizeof(strOutput), "{default}%s:", g_strJumpTypeShort[g_PlayerStates[client][JumpType]]);
		
		Format(buf, sizeof(buf), " {lightgreen}%.2f {grey}|", g_PlayerStates[client][fJumpDistance]);
		
		StrCat(strOutput, sizeof(strOutput), buf);
	}
	
	if(g_PlayerStates[client][JumpDir] != JD_FORWARDS)
	{
		if(g_PlayerStates[client][JumpDir] == JD_SIDEWAYS)
		{
			Format(strOutput, sizeof(strOutput), "{default}%sSW:", g_strJumpTypeShort[g_PlayerStates[client][JumpType]]);
			
			Format(buf, sizeof(buf), " {lightgreen}%.2f {grey}|", g_PlayerStates[client][fJumpDistance]);
			
			StrCat(strOutput, sizeof(strOutput), buf);
		}
		
		else if(g_PlayerStates[client][JumpDir] == JD_BACKWARDS)
		{
			Format(strOutput, sizeof(strOutput), "{default}%sBW:", g_strJumpTypeShort[g_PlayerStates[client][JumpType]]);
			
			Format(buf, sizeof(buf), " {lightgreen}%.2f {grey}|", g_PlayerStates[client][fJumpDistance]);
			
			StrCat(strOutput, sizeof(strOutput), buf);
		}
	}
	
	//LJ: 273.61 | Pre: 349.45 u/s | Strafe: 5 | Sync: 76%
	
	//LJ: 273.61 | Pre: 349.45 u/s | Strafe: 5 | Sync: 76%
	//Edge: 5.24 | Block: 245.0
	
	//LJ: 273.61 | Pre: 349.45 u/s | Strafe: 5 | Sync: 76%
	//Edge: 5.24 | Block: 245.0 | No duck
	
	Format(buf, sizeof(buf), " {default}Pre: {lightgreen}%.2f {grey}| {default}Strafe: {lightgreen}%d {grey}| {default}Sync: {lightgreen}%d{default}%%\n",
	view_as<float>(g_PlayerStates[client][fPrestrafe]), g_PlayerStates[client][nStrafes], RoundFloat(view_as<float>(g_PlayerStates[client][fSync])));
	
	StrCat(strOutput, sizeof(strOutput), buf);
	
	if(g_PlayerStates[client][bBlockMode] && !g_PlayerStates[client][bFailedBlock] && g_PlayerStates[client][fBlockDistance] != -1.0)
	{
		if(g_PlayerStates[client][fEdge] != -1.0)
		{
			Format(buf, sizeof(buf), "{default}Edge: {lightgreen}%.2f {grey}| ", g_PlayerStates[client][fEdge]);
			
			StrCat(strOutput, sizeof(strOutput), buf);
		}
		
		if(g_PlayerStates[client][bDuck] && g_PlayerStates[client][bLastDuckState])
		{
			Format(buf, sizeof(buf), "{default}Block: {lightgreen}%.1f ", g_PlayerStates[client][fBlockDistance]);
			
			StrCat(strOutput, sizeof(strOutput), buf);
		}
		
		else
		{
			Format(buf, sizeof(buf), "{default}Block: {lightgreen}%.1f {grey}| ", g_PlayerStates[client][fBlockDistance]);
			
			StrCat(strOutput, sizeof(strOutput), buf);
		}
	}
	
	if(!g_PlayerStates[client][bDuck] && !g_PlayerStates[client][bLastDuckState])
	{
		StrCat(strOutput, sizeof(strOutput), "{default}No duck");
	}
	
	if(bPrintToAll)
	{
		CPrintToChatAll("{green}[Trikz]{lightgreen} %s", strOutput);
	}
	
	else
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} %s", strOutput);
	}
}

///////////////////////////////////
///////////////////////////////////
////////                   ////////
////////  Trace functions  ////////
////////                   ////////
///////////////////////////////////
///////////////////////////////////
#define RAYTRACE_Z_DELTA -0.1
#define GAP_TRACE_LENGTH 10000.0

bool WorldFilter(int entity, int mask)
{
	if(entity >= 1 && entity <= MaxClients)
	{
		return false;
	}
	
	return true;
}

bool TracePlayer(float vEndPos[3], float vNormal[3], const float vTraceOrigin[3], const float vEndPoint[3], bool bCorrectError = true)
{
	float vMins[3] = {-16.0, -16.0, 0.0};
	float vMaxs[3] = {16.0, 16.0, 0.0};
	
	TR_TraceHullFilter(vTraceOrigin, vEndPoint, vMins, vMaxs, MASK_PLAYERSOLID, WorldFilter);
	
	if(!TR_DidHit()) //although tracehull does not ever seem to not hit (merely returning a hit at the end of the line), I'm keeping this here just in case, I guess
	{
		return false;
	}
	
	TR_GetEndPosition(vEndPos);
	TR_GetPlaneNormal(INVALID_HANDLE, vNormal);
	
	//correct slopes
	if(vNormal[2])
	{
		vNormal[2] = 0.0;
		NormalizeVector(vNormal, vNormal);
	}
	
	Adjust(vEndPos, vNormal);
	
	//dunno where this error comes from
	if(bCorrectError)
	{
		vEndPos[0] -= vNormal[0] * 0.03125;
		vEndPos[1] -= vNormal[1] * 0.03125;
	}
	
	float fDist = GetVectorDistance(vTraceOrigin, vEndPos);
	
	return fDist != 0.0 && fDist < GetVectorDistance(vTraceOrigin, vEndPoint);
}

//no function overloading... @__@
bool TracePlayer2(float vEndPos[3], const float vTraceOrigin[3], const float vEndPoint[3], bool bCorrectError = true)
{
	float vNormal[3];
	
	return TracePlayer(vEndPos, vNormal, vTraceOrigin, vEndPoint, bCorrectError);
}

bool TraceRay(float vEndPos[3], float vNormal[3], const float vTraceOrigin[3], const float vEndPoint[3], bool bCorrectError = true)
{
	TR_TraceRayFilter(vTraceOrigin, vEndPoint, MASK_PLAYERSOLID, RayType_EndPoint, WorldFilter);
	
	if(!TR_DidHit())
	{
		return false;
	}
	
	TR_GetEndPosition(vEndPos);
	TR_GetPlaneNormal(INVALID_HANDLE, vNormal);
	
	//correct slopes
	if(vNormal[2])
	{
		vNormal[2] = 0.0;
		NormalizeVector(vNormal, vNormal);
	}
	
	if(bCorrectError)
	{
		vEndPos[0] -= vNormal[0] * 0.03125;
		vEndPos[1] -= vNormal[1] * 0.03125;
	}
	
	float fDist = GetVectorDistance(vTraceOrigin, vEndPos);
	
	return fDist != 0.0 && fDist < GetVectorDistance(vTraceOrigin, vEndPoint);
}

bool TraceRay2(float vEndPos[3], const float vTraceOrigin[3], const float vEndPoint[3], bool bCorrectError = true)
{
	float vNormal[3];
	
	return TraceRay(vEndPos, vNormal, vTraceOrigin, vEndPoint, bCorrectError);
}

bool IsLeft(const float vDir[3], const float vNormal[3])
{
	if(vNormal[1] > 0)
	{
		if(vDir[0] > vNormal[0])
		{
			return true;
		}
		else
		{
			return false;
		}
	}
	else
	{
		if(vDir[0] > vNormal[0])
		{
			return false;
		}
		else
		{
			return true;
		}
	}
}

//align with normal
void Align(float vOut[3], const float v1[3], const float v2[3], const float vNormal[3])
{
	// cardinal
	if(!vNormal[0] || !vNormal[1])
	{
		if(vNormal[0])
		{
			vOut[0] = v2[0];
			vOut[1] = v1[1];
		}
		else
		{
			vOut[0] = v1[0];
			vOut[1] = v2[1];
		}
		
		return;
	}
	
	//noncardinal
	//rotate to cardinal, perform the same operation, rotate the result back
	
	//		[ cos(t) -sin(t)  0 ]
	// Rz = [ sin(t)  cos(t)  0 ]
	//		[ 0		  0       1 ]
	
	float vTo[3] = {1.0, 0.0};
	float fAngle = ArcCosine(GetVectorDotProduct(vNormal, vTo));
	float fRotatedOriginY;
	float vRotatedEndPos[2];
	
	if(IsLeft(vTo, vNormal))
	{
		fAngle = -fAngle;
	}
	
	fRotatedOriginY = v1[0] * Sine(fAngle) + v1[1] * Cosine(fAngle);
	
	vRotatedEndPos[0] = v2[0] * Cosine(fAngle) - v2[1] * Sine(fAngle);
	vRotatedEndPos[1] = fRotatedOriginY;
	
	fAngle = -fAngle;
	
	vOut[0] = vRotatedEndPos[0] * Cosine(fAngle) - vRotatedEndPos[1] * Sine(fAngle);
	vOut[1] = vRotatedEndPos[0] * Sine(fAngle)   + vRotatedEndPos[1] * Cosine(fAngle);
}

//Adjust collision hitbox center to periphery (the furthest point you could be from the edge as inferred by the normal)
void Adjust(float vOrigin[3], const float vNormal[3])
{
	//cardinal
	if(!vNormal[0] || !vNormal[1])
	{
		vOrigin[0] -= vNormal[0] * 16.0;
		vOrigin[1] -= vNormal[1] * 16.0;
		
		return;
	}
	
	//noncardinal
	//since the corner will always be the furthest point, set it to the corner of the normal's quadrant
	if(vNormal[0] > 0.0)
	{
		vOrigin[0] -= 16.0;
	}
	
	else
	{
		vOrigin[0] += 16.0;
	}
	
	if(vNormal[1] > 0.0)
	{
		vOrigin[1] -= 16.0;
	}
	
	else
	{
		vOrigin[1] += 16.0;
	}
}

float GetEdge(int client)
{
	float vOrigin[3];
	float vTraceOrigin[3];
	float vDir[3];
	GetClientAbsOrigin(client, vOrigin);
	
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vDir);
	
	NormalizeVector(vDir, vDir);
	
	vTraceOrigin = vOrigin;
	vTraceOrigin[0] += vDir[0] * 64.0;
	vTraceOrigin[1] += vDir[1] * 64.0;
	vTraceOrigin[2] += RAYTRACE_Z_DELTA;
	
	float vEndPoint[3];
	vEndPoint = vOrigin;
	vEndPoint[0] -= vDir[0] * 16.0 * 1.414214;
	vEndPoint[1] -= vDir[1] * 16.0 * 1.414214;
	vEndPoint[2] += RAYTRACE_Z_DELTA;
	
	float vEndPos[3];
	float vNormal[3];
	
	if(!TracePlayer(vEndPos, vNormal, vTraceOrigin, vEndPoint))
	{
		return -1.0;
	}
	
	Adjust(vOrigin, vNormal);
	
	Align(vEndPos, vOrigin, vEndPos, vNormal);
	
	//Correct Z -- the trace ray is a bit lower
	vEndPos[2] = vOrigin[2];
	
	return GetVectorDistance(vEndPos, vOrigin);
}

float GetBlockDistance(int client)
{
	float vOrigin[3];
	float vTraceOrigin[3];
	float vDir[3];
	float vEndPoint[3];
	GetClientAbsOrigin(client, vOrigin);
	
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vDir);
	
	NormalizeVector(vDir, vDir);
	
	vTraceOrigin = vOrigin;
	vTraceOrigin[0] += vDir[0] * 64.0;
	vTraceOrigin[1] += vDir[1] * 64.0;
	vTraceOrigin[2] += RAYTRACE_Z_DELTA;
	
	vEndPoint = vOrigin;
	vEndPoint[0] -= vDir[0] * 16.0 * 1.414214;
	vEndPoint[1] -= vDir[1] * 16.0 * 1.414214;
	vEndPoint[2] += RAYTRACE_Z_DELTA;
	
	float vBlockStart[3];
	float vNormal[3];
	
	if(!TracePlayer(vBlockStart, vNormal, vTraceOrigin, vEndPoint))
	{
		return -1.0;
	}
	
	float vBlockEnd[3];
	
	Array_Copy(vNormal, g_PlayerStates[client][vBlockNormal], 2);
	
	vEndPoint = vBlockStart;
	vEndPoint[0] += vNormal[0] * 300.0;
	vEndPoint[1] += vNormal[1] * 300.0;
	
	if(TracePlayer2(vBlockEnd, vBlockStart, vEndPoint))
	{
		Array_Copy(vBlockEnd, g_PlayerStates[client][vBlockEndPos], 3);
		
		Align(vBlockEnd, vBlockStart, vBlockEnd, vNormal);
		
		if(vNormal[0] == 0.0 || vNormal[1] == 0.0)
		{
			return GetVectorDistance(vBlockStart, vBlockEnd);
		}
		
		else
		{
			return GetVectorDistance(vBlockStart, vBlockEnd) - 32.0 * (FloatAbs(vNormal[0]) + FloatAbs(vNormal[1]) - 1.0);
		}
	}
	
	else
	{
		//Trace the other direction
		
		//rotate normal da way opposite da direction
		bool bLeft = IsLeft(vDir, vNormal);
		
		vDir = vNormal;
		
		float fTempSwap = vDir[0];
		
		vDir[0] = vDir[1];
		vDir[1] = fTempSwap;
		
		if(bLeft)
		{
			vDir[0] = -vDir[0];
		}
		
		else
		{
			vDir[1] = -vDir[1];
		}
		
		vTraceOrigin = vOrigin;
		vTraceOrigin[0] += vDir[0] * 48.0;
		vTraceOrigin[1] += vDir[1] * 48.0;
		vTraceOrigin[2] += RAYTRACE_Z_DELTA;
		
		vEndPoint = vTraceOrigin;
		vEndPoint[0] += vNormal[0] * 300.0;
		vEndPoint[1] += vNormal[1] * 300.0;
		
		if(!TracePlayer2(vBlockEnd, vTraceOrigin, vEndPoint))
		{
			return -1.0;
		}
		
		Array_Copy(vBlockEnd, g_PlayerStates[client][vBlockEndPos], 3);
		
		//adjust vBlockStart -- the second trace was on a different axis
		Align(vBlockStart, vBlockStart, vBlockEnd, vNormal);
		
		if(vNormal[0] == 0.0 || vNormal[1] == 0.0)
		{
			return GetVectorDistance(vBlockStart, vBlockEnd);
		}
		
		else
		{
			return GetVectorDistance(vBlockStart, vBlockEnd) - 32.0 * (FloatAbs(vNormal[0]) + FloatAbs(vNormal[1]) - 1.0);
		}
	}
}

bool GetGapPoint(float vOut[3], float vNormal[3], int client)
{
	float vAngles[3];
	float vTraceOrigin[3];
	float vDir[3];
	float vEndPoint[3];
	GetClientEyePosition(client, vTraceOrigin);
	GetClientEyeAngles(client, vAngles);
	
	TBAnglesToUV(vDir, vAngles);
	
	vEndPoint = vTraceOrigin;
	vEndPoint[0] += vDir[0] * GAP_TRACE_LENGTH;
	vEndPoint[1] += vDir[1] * GAP_TRACE_LENGTH;
	vEndPoint[2] += vDir[2] * GAP_TRACE_LENGTH;
	
	if(!TraceRay(vOut, vNormal, vTraceOrigin, vEndPoint))
	{
		return false;
	}
	
	return true;
}

bool GetOppositePoint(float vOut[3], const float vTraceOrigin[3], const float vNormal[3])
{
	float vDir[3];
	float vEndPoint[3];
	
	vDir = vNormal;
	
	if(vDir[2])
	{
		vDir[2] = 0.0;
		NormalizeVector(vDir, vDir);
	}
	
	vEndPoint = vTraceOrigin;
	vEndPoint[0] += vDir[0] * 10000.0;
	vEndPoint[1] += vDir[1] * 10000.0;
	
	if(!TraceRay2(vOut, vTraceOrigin, vEndPoint))
	{
		return false;
	}
	
	return true;
}

//generic utility functions
float GetSpeed(int client)
{
	float vVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
	vVelocity[2] = 0.0;
	
	return GetVectorLength(vVelocity); 
}

float GetVSpeed(const float v[3])
{
	float vVelocity[3];
	vVelocity = v;
	vVelocity[2] = 0.0;
	
	return GetVectorLength(vVelocity);
}

void SendPanelMsg(int client, const char[] strFormat, any ...)
{
	Handle hPanel = CreatePanel();
	
	char buf[512];
	
	VFormat(buf, sizeof(buf), strFormat, 3);
	
	SetPanelTitle(hPanel, buf);
	
	SendPanelToClient(hPanel, client, EmptyPanelHandler, 10);
	
	CloseHandle(hPanel);
}

void DrawPanelTextF(Handle hPanel, const char[] strFormat, any ...)
{
	char buf[512];
	
	VFormat(buf, sizeof(buf), strFormat, 3);
	
	DrawPanelText(hPanel, buf);
}

void Append(char[] sOutput, int maxlen, const char[] sFormat, any ...)
{
	char buf[512];
	
	VFormat(buf, sizeof(buf), sFormat, 4);
	
	StrCat(sOutput, maxlen, buf);
}

//undefined for negative numbers
float fmod(float a, float b)
{
	while(a > b)
	{
		a -= b;
	}
	
	return a;
}

stock float round(float a, int b, float Base = 10.0)
{
	float f = Pow(Base, float(b));

	return RoundFloat(a * f) / f;
}

stock void Array_Copy(const any[] array, any[] newArray, int size)
{
	for(int i=0; i < size; i++)
	{
		newArray[i] = array[i];
	}
}

int Native_GetClientStateJS(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
	
    return gI_JumpStats[client];
}