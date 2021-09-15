/*
 * shavit's Timer - Core
 * by: shavit
 *
 * This file is part of shavit's Timer.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
*/

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <geoip>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#define USES_CHAT_COLORS
#include <shavit>
#include <trikz>

#pragma newdecls required
#pragma semicolon 1

// #define DEBUG

enum struct playertimer_t
{
	bool bEnabled;
	float fTimer;
	bool bPaused;
	int iJumps;
	int iStyle;
	bool bAuto;
	int iLastButtons;
	int iStrafes;
	int iNades;
	float fLastAngle;
	int iTotalMeasures;
	int iGoodGains;
	//bool bDoubleSteps;
	float fStrafeWarning;
	bool bPracticeMode;
	int iSHSWCombination;
	int iTrack;
	int iMeasuredJumps;
	int iPerfectJumps;
	MoveType iMoveType;
	bool bCanUseAllKeys;
	bool bJumped; // not exactly a timer variable but still
	int iLandingTick;
	bool bOnGround;
	float fTimescale;
}

// database handle
Database gH_SQL = null;
bool gB_MySQL = false;

// forwards
Handle gH_Forwards_Start = null;
Handle gH_Forwards_Stop = null;
Handle gH_Forwards_StopPre = null;
Handle gH_Forwards_FinishPre = null;
Handle gH_Forwards_Finish = null;
Handle gH_Forwards_OnRestart = null;
Handle gH_Forwards_OnEnd = null;
Handle gH_Forwards_OnPause = null;
Handle gH_Forwards_OnResume = null;
Handle gH_Forwards_OnStyleChanged = null;
Handle gH_Forwards_OnTrackChanged = null;
Handle gH_Forwards_OnStyleConfigLoaded = null;
Handle gH_Forwards_OnDatabaseLoaded = null;
Handle gH_Forwards_OnChatConfigLoaded = null;
Handle gH_Forwards_OnUserCmdPre = null;
Handle gH_Forwards_OnTimerIncrement = null;
Handle gH_Forwards_OnTimerIncrementPost = null;
Handle gH_Forwards_OnTimescaleChanged = null;

StringMap gSM_StyleCommands = null;

// player timer variables
playertimer_t gA_Timers[MAXPLAYERS+1];

// these are here until the compiler bug is fixed
float gF_PauseOrigin[MAXPLAYERS+1][3];
float gF_PauseAngles[MAXPLAYERS+1][3];
float gF_PauseVelocity[MAXPLAYERS+1][3];

// cookies
Handle gH_StyleCookie = null;
Handle gH_AutoBhopCookie = null;

// late load
bool gB_Late = false;

// modules
bool gB_Zones = false;
bool gB_WR = false;
bool gB_Replay = false;
bool gB_Rankings = false;
bool gB_HUD = false;

// cvars
ConVar gCV_Pause = null;
ConVar gCV_BlockPreJump = null;
ConVar gCV_NoZAxisSpeed = null;
ConVar gCV_VelocityTeleport = null;
ConVar gCV_DefaultStyle = null;
ConVar gCV_NoChatSound = null;
ConVar gCV_SimplerLadders = null;

// cached cvars
int gI_DefaultStyle = 0;
bool gB_StyleCookies = true;

// table prefix
char gS_MySQLPrefix[32];

// server side
//ConVar sv_airaccelerate = null;
//ConVar sv_autobunnyhopping = null;
//ConVar sv_enablebunnyhopping = null;

// timer settings
bool gB_Registered = false;
int gI_Styles = 0;
int gI_OrderedStyles[STYLE_LIMIT];
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
stylesettings_t gA_StyleSettings[STYLE_LIMIT];

// chat settings
chatstrings_t gS_ChatStrings;

// misc cache
bool gB_StopChatSound = false;
bool gB_HookedJump = false;
char gS_LogPath[PLATFORM_MAX_PATH];
char gS_DeleteMap[MAXPLAYERS+1][160];
int gI_WipePlayerID[MAXPLAYERS+1];
char gS_Verification[MAXPLAYERS+1][8];
bool gB_CookiesRetrieved[MAXPLAYERS+1];
//float gF_ZoneAiraccelerate[MAXPLAYERS+1];
float gF_ZoneSpeedLimit[MAXPLAYERS+1];
int gI_TickCount = 0;
char gS_Map[160]; // blame workshop paths being so fucking long
int gI_track;

// flags
int gI_StyleFlag[STYLE_LIMIT];
char gS_StyleOverride[STYLE_LIMIT][32];

public Plugin myinfo =
{
	name = "[shavit] Core",
	author = "shavit, sejiya, Smesh",
	description = "The core for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Shavit_CanPause", Native_CanPause);
	CreateNative("Shavit_ChangeClientStyle", Native_ChangeClientStyle);
	CreateNative("Shavit_FinishMap", Native_FinishMap);
	CreateNative("Shavit_GetBhopStyle", Native_GetBhopStyle);
	CreateNative("Shavit_GetChatStrings", Native_GetChatStrings);
	CreateNative("Shavit_GetClientJumps", Native_GetClientJumps);
	CreateNative("Shavit_GetClientTime", Native_GetClientTime);
	CreateNative("Shavit_GetClientTrack", Native_GetClientTrack);
	CreateNative("Shavit_GetDatabase", Native_GetDatabase);
	CreateNative("Shavit_GetDB", Native_GetDB);
	CreateNative("Shavit_GetOrderedStyles", Native_GetOrderedStyles);
	CreateNative("Shavit_GetPerfectJumps", Native_GetPerfectJumps);
	CreateNative("Shavit_GetStrafeCount", Native_GetStrafeCount);
	CreateNative("Shavit_GetThrowedNadesCount", Native_GetThrowedNadesCount);
	CreateNative("Shavit_GetStyleCount", Native_GetStyleCount);
	CreateNative("Shavit_GetStyleSettings", Native_GetStyleSettings);
	CreateNative("Shavit_GetStyleStrings", Native_GetStyleStrings);
	CreateNative("Shavit_GetSync", Native_GetSync);
	CreateNative("Shavit_GetTimer", Native_GetTimer);
	CreateNative("Shavit_GetTimerStatus", Native_GetTimerStatus);
	CreateNative("Shavit_HasStyleAccess", Native_HasStyleAccess);
	CreateNative("Shavit_IsPaused", Native_IsPaused);
	CreateNative("Shavit_IsPracticeMode", Native_IsPracticeMode);
	CreateNative("Shavit_LoadSnapshot", Native_LoadSnapshot);
	CreateNative("Shavit_LogMessage", Native_LogMessage);
	CreateNative("Shavit_PauseTimer", Native_PauseTimer);
	CreateNative("Shavit_PrintToChat", Native_PrintToChat);
	CreateNative("Shavit_RestartTimer", Native_RestartTimer);
	CreateNative("Shavit_ResumeTimer", Native_ResumeTimer);
	CreateNative("Shavit_SaveSnapshot", Native_SaveSnapshot);
	CreateNative("Shavit_SetPracticeMode", Native_SetPracticeMode);
	CreateNative("Shavit_StartTimer", Native_StartTimer);
	CreateNative("Shavit_StopChatSound", Native_StopChatSound);
	CreateNative("Shavit_StopTimer", Native_StopTimer);
	CreateNative("Shavit_GetClientTimescale", Native_GetClientTimescale);
	CreateNative("Shavit_SetClientTimescale", Native_SetClientTimescale);
	CreateNative("Shavit_SetClientTrack", Native_SetClientTrack);
	CreateNative("Shavit_Teleport", Native_Teleport);

	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	// forwards
	gH_Forwards_Start = CreateGlobalForward("Shavit_OnStart", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_Stop = CreateGlobalForward("Shavit_OnStop", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_StopPre = CreateGlobalForward("Shavit_OnStopPre", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_FinishPre = CreateGlobalForward("Shavit_OnFinishPre", ET_Event, Param_Cell, Param_Array);
	gH_Forwards_Finish = CreateGlobalForward("Shavit_OnFinish", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnRestart = CreateGlobalForward("Shavit_OnRestart", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnEnd = CreateGlobalForward("Shavit_OnEnd", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnPause = CreateGlobalForward("Shavit_OnPause", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnResume = CreateGlobalForward("Shavit_OnResume", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnStyleChanged = CreateGlobalForward("Shavit_OnStyleChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnTrackChanged = CreateGlobalForward("Shavit_OnTrackChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnStyleConfigLoaded = CreateGlobalForward("Shavit_OnStyleConfigLoaded", ET_Event, Param_Cell);
	gH_Forwards_OnDatabaseLoaded = CreateGlobalForward("Shavit_OnDatabaseLoaded", ET_Event);
	gH_Forwards_OnChatConfigLoaded = CreateGlobalForward("Shavit_OnChatConfigLoaded", ET_Event);
	gH_Forwards_OnUserCmdPre = CreateGlobalForward("Shavit_OnUserCmdPre", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_Cell, Param_Cell, Param_Cell, Param_Array, Param_Array);
	gH_Forwards_OnTimerIncrement = CreateGlobalForward("Shavit_OnTimeIncrement", ET_Event, Param_Cell, Param_Array, Param_CellByRef, Param_Array);
	gH_Forwards_OnTimerIncrementPost = CreateGlobalForward("Shavit_OnTimeIncrementPost", ET_Event, Param_Cell, Param_Cell, Param_Array);
	gH_Forwards_OnTimescaleChanged = CreateGlobalForward("Shavit_OnTimescaleChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell);

	LoadTranslations("shavit-core.phrases");
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-misc.phrases");

	// hooks
	gB_HookedJump = HookEventEx("player_jump", Player_Jump);

	// commands START
	// style
	RegConsoleCmd("sm_style", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_styles", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_diff", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_difficulty", Command_Style, "Choose your bhop style.");
	gH_StyleCookie = RegClientCookie("shavit_style", "Style cookie", CookieAccess_Protected);
	
	// timer start
	RegConsoleCmd("sm_s", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_start", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_r", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_restart", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_m", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_main", Command_StartTimer, "Start your timer.");

	RegConsoleCmd("sm_b", Command_StartTimer, "Start your timer on the bonus track.");
	RegConsoleCmd("sm_bonus", Command_StartTimer, "Start your timer on the bonus track.");
	
	RegConsoleCmd("sm_sb", Command_StartTimer, "Start your timer on the solobonus track.");
	RegConsoleCmd("sm_solobonus", Command_StartTimer, "Start your timer on the solobonus track.");
	
	// teleport to end
	RegConsoleCmd("sm_end", Command_TeleportEnd, "Teleport to endzone.");
	RegConsoleCmd("sm_mend", Command_TeleportEnd, "Teleport to endzone.");
	RegConsoleCmd("sm_mainend", Command_TeleportEnd, "Teleport to endzone.");

	RegConsoleCmd("sm_bend", Command_TeleportEnd, "Teleport to endzone of the bonus track.");
	RegConsoleCmd("sm_bonusend", Command_TeleportEnd, "Teleport to endzone of the bonus track.");
	
	RegConsoleCmd("sm_sbend", Command_TeleportEnd, "Teleport to endzone of the solobonus track.");
	RegConsoleCmd("sm_sbonusend", Command_TeleportEnd, "Teleport to endzone of the solobonus track.");

	// timer stop
	RegConsoleCmd("sm_stop", Command_StopTimer, "Stop your timer.");

	// timer pause / resume
	RegConsoleCmd("sm_pause", Command_TogglePause, "Toggle pause.");
	RegConsoleCmd("sm_unpause", Command_TogglePause, "Toggle pause.");
	RegConsoleCmd("sm_resume", Command_TogglePause, "Toggle pause");

	// autobhop toggle
	RegConsoleCmd("sm_auto", Command_AutoBhop, "Toggle autobhop.");
	RegConsoleCmd("sm_autobhop", Command_AutoBhop, "Toggle autobhop.");
	RegConsoleCmd("sm_bh", Command_AutoBhop, "Toggle autobhop.");
	RegConsoleCmd("sm_bhop", Command_AutoBhop, "Toggle autobhop.");
	RegConsoleCmd("sm_bunnyhop", Command_AutoBhop, "Toggle autobhop.");
	RegConsoleCmd("sm_bunnyhopping", Command_AutoBhop, "Toggle autobhop.");
	gH_AutoBhopCookie = RegClientCookie("shavit_autobhop", "Autobhop cookie", CookieAccess_Protected);

	// doublestep fixer
	//AddCommandListener(Command_DoubleStep, "+ds");
	//AddCommandListener(Command_DoubleStep, "-ds");

	// style commands
	gSM_StyleCommands = new StringMap();

	#if defined DEBUG
	RegConsoleCmd("sm_finishtest", Command_FinishTest);
	#endif

	// admin
	RegAdminCmd("sm_deletemap", Command_DeleteMap, ADMFLAG_ROOT, "Deletes all map data. Usage: sm_deletemap <map>");
	RegAdminCmd("sm_wipeplayer", Command_WipePlayer, ADMFLAG_BAN, "Wipes all bhoptimer data for specified player. Usage: sm_wipeplayer <steamid3>");
	// commands END

	// logs
	BuildPath(Path_SM, gS_LogPath, PLATFORM_MAX_PATH, "logs/shavit.log");

	CreateConVar("shavit_version", SHAVIT_VERSION, "Plugin version.", (FCVAR_NOTIFY | FCVAR_DONTRECORD));

	gCV_Pause = CreateConVar("shavit_core_pause", "1", "Allow pausing?", 0, true, 0.0, true, 1.0);
	gCV_BlockPreJump = CreateConVar("shavit_core_blockprejump", "0", "Prevents jumping in the start zone.", 0, true, 0.0, true, 1.0);
	gCV_NoZAxisSpeed = CreateConVar("shavit_core_nozaxisspeed", "1", "Don't start timer if vertical speed exists (btimes style).", 0, true, 0.0, true, 1.0);
	gCV_VelocityTeleport = CreateConVar("shavit_core_velocityteleport", "0", "Teleport the client when changing its velocity? (for special styles)", 0, true, 0.0, true, 1.0);
	gCV_DefaultStyle = CreateConVar("shavit_core_defaultstyle", "0", "Default style ID.\nAdd the '!' prefix to disable style cookies - i.e. \"!3\" to *force* scroll to be the default style.", 0, true, 0.0);
	gCV_NoChatSound = CreateConVar("shavit_core_nochatsound", "0", "Disables click sound for chat messages.", 0, true, 0.0, true, 1.0);
	gCV_SimplerLadders = CreateConVar("shavit_core_simplerladders", "1", "Allows using all keys on limited styles (such as sideways) after touching ladders\nTouching the ground enables the restriction again.", 0, true, 0.0, true, 1.0);

	gCV_DefaultStyle.AddChangeHook(OnConVarChanged);

	AutoExecConfig();

	//sv_airaccelerate = FindConVar("sv_airaccelerate");
	//sv_airaccelerate.Flags &= ~(FCVAR_NOTIFY | FCVAR_REPLICATED);

	//sv_enablebunnyhopping = FindConVar("sv_enablebunnyhopping");
	
	/*if(sv_enablebunnyhopping != null)
	{
		sv_enablebunnyhopping.Flags &= ~(FCVAR_NOTIFY | FCVAR_REPLICATED);
	}*/

	gB_Zones = LibraryExists("shavit-zones");
	gB_WR = LibraryExists("shavit-wr");
	gB_Replay = LibraryExists("shavit-replay");
	gB_Rankings = LibraryExists("shavit-rankings");
	gB_HUD = LibraryExists("shavit-hud");

	// database connections
	SQL_DBConnect();

	// late
	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gB_StyleCookies = (newValue[0] != '!');
	gI_DefaultStyle = StringToInt(newValue[1]);
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-zones"))
	{
		gB_Zones = true;
	}

	else if(StrEqual(name, "shavit-wr"))
	{
		gB_WR = true;
	}

	else if(StrEqual(name, "shavit-replay"))
	{
		gB_Replay = true;
	}

	else if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = true;
	}

	else if(StrEqual(name, "shavit-hud"))
	{
		gB_HUD = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-zones"))
	{
		gB_Zones = false;
	}

	else if(StrEqual(name, "shavit-wr"))
	{
		gB_WR = false;
	}
	
	else if(StrEqual(name, "shavit-replay"))
	{
		gB_Replay = false;
	}
	
	else if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = false;
	}

	else if(StrEqual(name, "shavit-hud"))
	{
		gB_HUD = false;
	}
}

public void OnMapStart()
{
	// styles
	if(!LoadStyles())
	{
		SetFailState("Could not load the styles configuration file. Make sure it exists (addons/sourcemod/configs/shavit-styles.cfg) and follows the proper syntax!");
	}

	// messages
	if(!LoadMessages())
	{
		SetFailState("Could not load the chat messages configuration file. Make sure it exists (addons/sourcemod/configs/shavit-messages.cfg) and follows the proper syntax!");
	}
	
	GetCurrentMap(gS_Map, 160);
	GetMapDisplayName(gS_Map, gS_Map, 160);

	char sLowerCase[160];
	strcopy(sLowerCase, 160, gS_Map);
}

public Action Command_StartTimer(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	int track = Track_Main;
	gI_track = Track_Main;
	
	if(StrContains(sCommand, "sm_b", false) == 0)
	{
		track = Track_Bonus;
		gI_track = Track_Bonus;
	}
	
	else if(StrContains(sCommand, "sm_sb", false) == 0 || StrContains(sCommand, "sm_solobonus", false) == 0)
	{
		track = Track_Solobonus;
		gI_track = Track_Solobonus;
	}

	if(Shavit_ZoneExists(Zone_Start, track))
	{
		if(!Shavit_StopTimer(client, false))
		{
			return Plugin_Handled;
		}
		
		if(IsPlayerAlive(client))
		{
			Call_StartForward(gH_Forwards_OnRestart);
			Call_PushCell(client);
			Call_PushCell(track);
			Call_Finish();
			
			RequestFrame(Request_SetTrack, client);
			RequestFrame(Request_AntiAbuse, client);
		}
		
		else
		{
			Shavit_PrintToChat(client, "You must be alive to use this feature.");
		}
	}

	else
	{
		char sTrack[32];
		GetTrackName(client, track, sTrack, 32);

		Shavit_PrintToChat(client, "%T", "StartZoneUndefined", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sTrack, gS_ChatStrings.sText);
	}
	
	return Plugin_Handled;
}

public Action Command_TeleportEnd(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	int track = Track_Main;
	gI_track = Track_Main;
	
	if(StrContains(sCommand, "sm_b", false) == 0)
	{
		track = Track_Bonus;
		gI_track = Track_Bonus;
	}
	
	else if(StrContains(sCommand, "sm_sb", false) == 0 || StrContains(sCommand, "sm_solobonus", false) == 0)
	{
		track = Track_Solobonus;
		gI_track = Track_Solobonus;
	}

	if(Shavit_ZoneExists(Zone_End, track))
	{
		if(IsPlayerAlive(client) && Shavit_StopTimer(client, false))
		{
			Call_StartForward(gH_Forwards_OnEnd);
			Call_PushCell(client);
			Call_PushCell(track);
			Call_Finish();
			
			RequestFrame(Request_SetTrack, client);
			RequestFrame(Request_AntiAbuse, client);
		}
		
		else if(!IsPlayerAlive(client))
		{
			Shavit_PrintToChat(client, "You must be alive to use this feature.");
		}
	}

	else
	{
		Shavit_PrintToChat(client, "%T", "EndZoneUndefined", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
	}

	return Plugin_Handled;
}

void Request_SetTrack(int client)
{
	RequestFrame(Request_SetTrackSecondFrame, client);
}

void Request_SetTrackSecondFrame(int client)
{
	Shavit_SetClientTrack(client, gI_track);
	
	Shavit_UpdateClientWRs(client);
}

void Request_AntiAbuse(int client)
{
	RequestFrame(Request_AntiAbuseTwo, client);
}

void Request_AntiAbuseTwo(int client)
{
	StopTimer(client);
}

public Action Command_StopTimer(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	StopTimer(client);

	return Plugin_Handled;
}

public Action Command_TogglePause(int client, int args)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	int iFlags = Shavit_CanPause(client);

	if((iFlags & CPR_NoTimer) > 0)
	{
		Shavit_PrintToChat(client, "You cannot use this feature until the timer is started.");
		
		return Plugin_Handled;
	}

	if((iFlags & CPR_InStartZone) > 0)
	{
		//Shavit_PrintToChat(client, "%T", "PauseStartZone", client, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText, gS_ChatStrings.sVariable, gS_ChatStrings.sText);

		//return Plugin_Handled;
	}

	if((iFlags & CPR_ByConVar) > 0)
	{
		char sCommand[16];
		GetCmdArg(0, sCommand, 16);

		Shavit_PrintToChat(client, "%T", "CommandDisabled", client, gS_ChatStrings.sVariable, sCommand, gS_ChatStrings.sText);

		return Plugin_Handled;
	}

	if((iFlags & CPR_NotOnGround) > 0)
	{
		Shavit_PrintToChat(client, "%T", "PauseNotOnGround", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText);

		return Plugin_Handled;
	}
	
	if(Shavit_GetClientTrack(client) == Track_Solobonus)
	{
		if(gA_Timers[client].bPaused)
		{
			TeleportEntity(client, gF_PauseOrigin[client], gF_PauseAngles[client], gF_PauseVelocity[client]);
			ResumeTimer(client);

			Shavit_PrintToChat(client, "%T", "MessageUnpause", client, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
		}

		else
		{
			GetClientAbsOrigin(client, gF_PauseOrigin[client]);
			GetClientEyeAngles(client, gF_PauseAngles[client]);
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", gF_PauseVelocity[client]);

			PauseTimer(client);

			Shavit_PrintToChat(client, "%T", "MessagePause", client, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
		}
	}

	else
	{
		int partner = Trikz_FindPartner(client);
		
		if(gA_Timers[client].bPaused)
		{
			TeleportEntity(client, gF_PauseOrigin[client], gF_PauseAngles[client], gF_PauseVelocity[client]);
			TeleportEntity(partner, gF_PauseOrigin[partner], gF_PauseAngles[partner], gF_PauseVelocity[partner]);
			ResumeTimer(client);
			ResumeTimer(partner);

			Shavit_PrintToChat(client, "%T", "MessageUnpause", client, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
			Shavit_PrintToChat(partner, "%T", "MessageUnpause", partner, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
		}

		else
		{
			GetClientAbsOrigin(client, gF_PauseOrigin[client]);
			GetClientAbsOrigin(partner, gF_PauseOrigin[partner]);
			GetClientEyeAngles(client, gF_PauseAngles[client]);
			GetClientEyeAngles(partner, gF_PauseAngles[partner]);
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", gF_PauseVelocity[client]);
			GetEntPropVector(partner, Prop_Data, "m_vecAbsVelocity", gF_PauseVelocity[partner]);

			PauseTimer(client);
			PauseTimer(partner);

			Shavit_PrintToChat(client, "%T", "MessagePause", client, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
			Shavit_PrintToChat(partner, "%T", "MessagePause", partner, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
		}
	}
	
	return Plugin_Handled;
}

#if defined DEBUG
public Action Command_FinishTest(int client, int args)
{
	Shavit_FinishMap(client, gA_Timers[client].iTrack);

	return Plugin_Handled;
}
#endif

public Action Command_DeleteMap(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_deletemap <map>\nOnce a map is chosen, \"sm_deletemap confirm\" to run the deletion.");

		return Plugin_Handled;
	}

	char sArgs[160];
	GetCmdArgString(sArgs, 160);

	if(StrEqual(sArgs, "confirm") && strlen(gS_DeleteMap[client]) > 0)
	{
		if(gB_WR)
		{
			Shavit_WR_DeleteMap(gS_DeleteMap[client]);
			ReplyToCommand(client, "Deleted all records for %s.", gS_DeleteMap[client]);
		}

		if(gB_Zones)
		{
			Shavit_Zones_DeleteMap(gS_DeleteMap[client]);
			ReplyToCommand(client, "Deleted all zones for %s.", gS_DeleteMap[client]);
		}

		if(gB_Replay)
		{
			Shavit_Replay_DeleteMap(gS_DeleteMap[client]);
			ReplyToCommand(client, "Deleted all replay data for %s.", gS_DeleteMap[client]);
		}

		if(gB_Rankings)
		{
			Shavit_Rankings_DeleteMap(gS_DeleteMap[client]);
			ReplyToCommand(client, "Deleted all rankings for %s.", gS_DeleteMap[client]);
		}

		ReplyToCommand(client, "Finished deleting data for %s.", gS_DeleteMap[client]);
		strcopy(gS_DeleteMap[client], 160, "");
	}

	else
	{
		strcopy(gS_DeleteMap[client], 160, sArgs);
		ReplyToCommand(client, "Map to delete is now %s.\nRun \"sm_deletemap confirm\" to delete all data regarding the map %s.", gS_DeleteMap[client], gS_DeleteMap[client]);
	}

	return Plugin_Handled;
}

public Action Command_WipePlayer(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_wipeplayer <steamid3>\nAfter entering a SteamID, you will be prompted with a verification captcha.");

		return Plugin_Handled;
	}

	char sArgString[32];
	GetCmdArgString(sArgString, 32);

	if(strlen(gS_Verification[client]) == 0 || !StrEqual(sArgString, gS_Verification[client]))
	{
		ReplaceString(sArgString, 32, "[U:1:", "");
		ReplaceString(sArgString, 32, "]", "");

		gI_WipePlayerID[client] = StringToInt(sArgString);

		if(gI_WipePlayerID[client] <= 0)
		{
			Shavit_PrintToChat(client, "Entered SteamID ([U:1:%s]) is invalid. The range for valid SteamIDs is [U:1:1] to [U:1:2147483647].", sArgString);

			return Plugin_Handled;
		}

		char sAlphabet[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#";
		strcopy(gS_Verification[client], 8, "");

		for(int i = 0; i < 5; i++)
		{
			gS_Verification[client][i] = sAlphabet[GetRandomInt(0, sizeof(sAlphabet) - 1)];
		}

		Shavit_PrintToChat(client, "Preparing to delete all user data for SteamID %s[U:1:%d]%s. To confirm, enter %s!wipeplayer %s",
			gS_ChatStrings.sVariable, gI_WipePlayerID[client], gS_ChatStrings.sText, gS_ChatStrings.sVariable2, gS_Verification[client]);
	}

	else
	{
		Shavit_PrintToChat(client, "Deleting data for SteamID %s[U:1:%d]%s...",
			gS_ChatStrings.sVariable, gI_WipePlayerID[client], gS_ChatStrings.sText);

		DeleteUserData(client, gI_WipePlayerID[client]);

		strcopy(gS_Verification[client], 8, "");
		gI_WipePlayerID[client] = -1;
	}

	return Plugin_Handled;
}

void DeleteUserData(int client, const int iSteamID)
{
	if(gB_Replay)
	{
		char sQueryGetWorldRecords[256];
		FormatEx(sQueryGetWorldRecords, 256,
			"SELECT map, id, style, track FROM %splayertimes WHERE auth = %d;",
			gS_MySQLPrefix, iSteamID);

		DataPack hPack = new DataPack();
		hPack.WriteCell(client);
		hPack.WriteCell(iSteamID);

		gH_SQL.Query(SQL_DeleteUserData_GetRecords_Callback, sQueryGetWorldRecords, hPack, DBPrio_High);
	}

	else
	{
		char sQueryDeleteUserTimes[256];
		FormatEx(sQueryDeleteUserTimes, 256,
			"DELETE FROM %splayertimes WHERE auth = %d;",
			gS_MySQLPrefix, iSteamID);

		DataPack hSteamPack = new DataPack();
		hSteamPack.WriteCell(iSteamID);
		hSteamPack.WriteCell(client);

		gH_SQL.Query(SQL_DeleteUserTimes_Callback, sQueryDeleteUserTimes, hSteamPack, DBPrio_High);
	}
}

public void SQL_DeleteUserData_GetRecords_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack hPack = view_as<DataPack>(data);
	hPack.Reset();
	int client = hPack.ReadCell();
	int iSteamID = hPack.ReadCell();
	delete hPack;

	if(results == null)
	{
		LogError("Timer error! Failed to wipe user data (wipe | get player records). Reason: %s", error);

		return;
	}

	Transaction hTransaction = new Transaction();

	while(results.FetchRow())
	{
		char map[160];
		results.FetchString(0, map, 160);

		int id = results.FetchInt(1);
		int style = results.FetchInt(2);
		int track = results.FetchInt(3);

		char sQueryGetWorldRecordID[256];
		FormatEx(sQueryGetWorldRecordID, 256,
			"SELECT id FROM %splayertimes WHERE map = '%s' AND style = %d AND track = %d ORDER BY time LIMIT 1;",
			gS_MySQLPrefix, map, style, track);

		DataPack hTransPack = new DataPack();
		hTransPack.WriteString(map);
		hTransPack.WriteCell(id);
		hTransPack.WriteCell(style);
		hTransPack.WriteCell(track);

		hTransaction.AddQuery(sQueryGetWorldRecordID, hTransPack);
	}

	DataPack hSteamPack = new DataPack();
	hSteamPack.WriteCell(iSteamID);
	hSteamPack.WriteCell(client);

	gH_SQL.Execute(hTransaction, Trans_OnRecordCompare, INVALID_FUNCTION, hSteamPack, DBPrio_High);
}

public void Trans_OnRecordCompare(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	DataPack hPack = view_as<DataPack>(data);
	hPack.Reset();
	int iSteamID = hPack.ReadCell();

	for(int i = 0; i < numQueries; i++)
	{
		DataPack hQueryPack = view_as<DataPack>(queryData[i]);
		hQueryPack.Reset();
		char sMap[32];
		hQueryPack.ReadString(sMap, 32);

		int iRecordID = hQueryPack.ReadCell();
		int iStyle = hQueryPack.ReadCell();
		int iTrack = hQueryPack.ReadCell();
		delete hQueryPack;

		if(results[i] != null && results[i].FetchRow())
		{
			int iWR = results[i].FetchInt(0);

			if(iWR == iRecordID)
			{
				Shavit_DeleteReplay(sMap, iStyle, iTrack);
			}
		}
	}

	char sQueryDeleteUserTimes[256];
	FormatEx(sQueryDeleteUserTimes, 256,
		"DELETE FROM %splayertimes WHERE auth = %d;",
		gS_MySQLPrefix, iSteamID);

	gH_SQL.Query(SQL_DeleteUserTimes_Callback, sQueryDeleteUserTimes, hPack, DBPrio_High);
}

public void SQL_DeleteUserTimes_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack hPack = view_as<DataPack>(data);
	hPack.Reset();
	int iSteamID = hPack.ReadCell();

	if(results == null)
	{
		LogError("Timer error! Failed to wipe user data (wipe | delete user times). Reason: %s", error);

		delete hPack;

		return;
	}

	char sQueryDeleteUsers[256];
	FormatEx(sQueryDeleteUsers, 256, "DELETE FROM %susers WHERE auth = %d;",
		gS_MySQLPrefix, iSteamID);

	gH_SQL.Query(SQL_DeleteUserData_Callback, sQueryDeleteUsers, hPack, DBPrio_High);
}

public void SQL_DeleteUserData_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack hPack = view_as<DataPack>(data);
	hPack.Reset();
	int iSteamID = hPack.ReadCell();
	int client = hPack.ReadCell();
	delete hPack;

	if(results == null)
	{
		LogError("Timer error! Failed to wipe user data (wipe | delete user data, id [U:1:%d]). Reason: %s", error, iSteamID);

		return;
	}

	Shavit_LogMessage("%L - wiped user data for [U:1:%d].", client, iSteamID);
	Shavit_ReloadLeaderboards();
	Shavit_PrintToChat(client, "Finished wiping timer data for user %s[U:1:%d]%s.", gS_ChatStrings.sVariable, iSteamID, gS_ChatStrings.sText);
}

public Action Command_AutoBhop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gA_Timers[client].bAuto = !gA_Timers[client].bAuto;

	if(gA_Timers[client].bAuto)
	{
		Shavit_PrintToChat(client, "%T", "AutobhopEnabled", client, gS_ChatStrings.sVariable2, gS_ChatStrings.sText);
	}

	else
	{
		Shavit_PrintToChat(client, "%T", "AutobhopDisabled", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
	}

	char sAutoBhop[4];
	IntToString(view_as<int>(gA_Timers[client].bAuto), sAutoBhop, 4);
	SetClientCookie(client, gH_AutoBhopCookie, sAutoBhop);

	UpdateStyleSettings(client);

	return Plugin_Handled;
}

/*public Action Command_DoubleStep(int client, const char[] command, int args)
{
	gA_Timers[client].bDoubleSteps = (command[0] == '+');

	return Plugin_Handled;
}*/

public Action Command_Style(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(StyleMenu_Handler);
	menu.SetTitle("%T", "StyleMenuTitle", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		int iStyle = gI_OrderedStyles[i];

		// this logic will prevent the style from showing in !style menu if it's specifically inaccessible
		// or just completely disabled
		if((gA_StyleSettings[iStyle].bInaccessible && gA_StyleSettings[iStyle].iEnabled == 1) ||
			gA_StyleSettings[iStyle].iEnabled == -1)
		{
			continue;
		}

		char sInfo[8];
		IntToString(iStyle, sInfo, 8);

		char sDisplay[64];

		if(gA_StyleSettings[iStyle].bUnranked)
		{
			FormatEx(sDisplay, 64, "%T %s", "StyleUnranked", client, gS_StyleStrings[iStyle].sStyleName);
		}

		else
		{
			float time = 0.0;

			if(gB_WR)
			{
				time = Shavit_GetWorldRecord(iStyle, gA_Timers[client].iTrack);
			}

			if(time > 0.0)
			{
				char sTime[32];
				FormatSeconds(time, sTime, 32, false);

				char sWR[8];
				strcopy(sWR, 8, "WR");
				
				if(gA_Timers[client].iTrack == Track_Bonus)
				{
					strcopy(sWR, 8, "BWR");
				}

				FormatEx(sDisplay, 64, "%s - %s: %s", gS_StyleStrings[iStyle].sStyleName, sWR, sTime);
			}

			else
			{
				strcopy(sDisplay, 64, gS_StyleStrings[iStyle].sStyleName);
			}
		}

		menu.AddItem(sInfo, sDisplay, (gA_Timers[client].iStyle == iStyle || !Shavit_HasStyleAccess(client, iStyle))? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	}

	// should NEVER happen
	if(menu.ItemCount == 0)
	{
		menu.AddItem("-1", "Nothing");
	}

	else if(menu.ItemCount <= 9)
	{
		menu.Pagination = MENU_NO_PAGINATION;
	}

	menu.ExitButton = true;
	menu.Display(client, 20);

	return Plugin_Handled;
}

public int StyleMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param2, info, 16);

		int style = StringToInt(info);

		if(style == -1)
		{
			return 0;
		}

		ChangeClientStyle(param1, style, true);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void CallOnTrackChanged(int client, int oldtrack, int newtrack)
{
	Call_StartForward(gH_Forwards_OnTrackChanged);
	Call_PushCell(client);
	Call_PushCell(oldtrack);
	Call_PushCell(newtrack);	
	Call_Finish();
}

void CallOnStyleChanged(int client, int oldstyle, int newstyle, bool manual)
{
	Call_StartForward(gH_Forwards_OnStyleChanged);
	Call_PushCell(client);
	Call_PushCell(oldstyle);
	Call_PushCell(newstyle);
	Call_PushCell(gA_Timers[client].iTrack);
	Call_PushCell(manual);
	Call_Finish();

	gA_Timers[client].iStyle = newstyle;

	if(gA_Timers[client].fTimescale != -1.0)
	{
		CallOnTimescaleChanged(client, gA_Timers[client].fTimescale, -1.0);
		gA_Timers[client].fTimescale = -1.0;
	}

	UpdateStyleSettings(client);
	
	Shavit_UpdateClientWRs(client);
}

void CallOnTimescaleChanged(int client, float oldtimescale, float newtimescale)
{
	Call_StartForward(gH_Forwards_OnTimescaleChanged);
	Call_PushCell(client);
	Call_PushCell(oldtimescale);
	Call_PushCell(newtimescale);
	Call_Finish();
}

void ChangeClientStyle(int client, int style, bool manual)
{
	if(!IsValidClient(client))
	{
		return;
	}

	if(!Shavit_HasStyleAccess(client, style))
	{
		if(manual)
		{
			Shavit_PrintToChat(client, "%T", "StyleNoAccess", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
		}

		return;
	}

	if(manual)
	{
		if(!Shavit_StopTimer(client, false))
		{
			return;
		}
		
		Shavit_PrintToChat(client, "%T", "StyleSelection", client, gS_ChatStrings.sStyle, gS_StyleStrings[style].sStyleName, gS_ChatStrings.sText);
	}

	if(gA_StyleSettings[style].bUnranked)
	{
		Shavit_PrintToChat(client, "%T", "UnrankedWarning", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
	}

	//int aa_old = RoundToZero(gA_StyleSettings[gA_Timers[client].iStyle].fAiraccelerate);
	//int aa_new = RoundToZero(gA_StyleSettings[style].fAiraccelerate);

	//if(aa_old != aa_new)
	//{
	//	Shavit_PrintToChat(client, "%T", "NewAiraccelerate", client, aa_old, gS_ChatStrings.sVariable, aa_new, gS_ChatStrings.sText);
	//}

	CallOnStyleChanged(client, gA_Timers[client].iStyle, style, manual);

	if(gB_Zones && (Shavit_ZoneExists(Zone_Start, gA_Timers[client].iTrack)))
	{
		Call_StartForward(gH_Forwards_OnRestart);
		Call_PushCell(client);
		Call_PushCell(gA_Timers[client].iTrack);
		Call_Finish();
	}

	char sStyle[4];
	IntToString(style, sStyle, 4);
	SetClientCookie(client, gH_StyleCookie, sStyle);
	StopTimer(client);
}

// used as an alternative for games where player_jump isn't a thing, such as TF2
public void Bunnyhop_OnLeaveGround(int client, bool jumped, bool ladder)
{
	if(gB_HookedJump || !jumped || ladder)
	{
		return;
	}

	DoJump(client);
	gA_Timers[client].bJumped = true;
}

public void Player_Jump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	DoJump(client);
	gA_Timers[client].bJumped = true;
}

void DoJump(int client)
{
	if(gA_Timers[client].bEnabled)
	{
		gA_Timers[client].iJumps++;
	}

	// TF2 doesn't use stamina
	//if(gA_StyleSettings[gA_Timers[client].iStyle].bEasybhop || Shavit_InsideZone(client, Zone_Easybhop, gA_Timers[client].iTrack))
	if(Shavit_InsideZone(client, Zone_Easybhop, gA_Timers[client].iTrack))
	{
		SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	}

	RequestFrame(VelocityChanges, GetClientSerial(client));
}

void VelocityChanges(int data)
{
	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	if(gA_Timers[client].fTimescale != -1.0)
	{
		//SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fTimescale));
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", view_as<float>(gA_Timers[client].fTimescale));
	}

	else
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fSpeedMultiplier));
	}

	float fAbsVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

	float fSpeed = (SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0)));

	if(fSpeed != 0.0)
	{
		float fVelocityMultiplier = view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fVelocity);
		float fVelocityBonus = view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fBonusVelocity);
		float fMin = view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fMinVelocity);

		if(fVelocityMultiplier != 0.0)
		{
			fAbsVelocity[0] *= fVelocityMultiplier;
			fAbsVelocity[1] *= fVelocityMultiplier;
		}

		if(fVelocityBonus != 0.0)
		{
			float x = fSpeed / (fSpeed + fVelocityBonus);
			fAbsVelocity[0] /= x;
			fAbsVelocity[1] /= x;
		}

		if(fMin != 0.0 && fSpeed < fMin)
		{
			float x = (fSpeed / fMin);
			fAbsVelocity[0] /= x;
			fAbsVelocity[1] /= x;
		}
	}

	float fJumpMultiplier = gA_StyleSettings[gA_Timers[client].iStyle].fJumpMultiplier;
	float fJumpBonus = gA_StyleSettings[gA_Timers[client].iStyle].fJumpBonus;

	if(fJumpMultiplier != 0.0)
	{
		fAbsVelocity[2] *= fJumpMultiplier;
	}

	if(fJumpBonus != 0.0)
	{
		fAbsVelocity[2] += fJumpBonus;
	}


	if(!gCV_VelocityTeleport.BoolValue)
	{
		SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);
	}

	else
	{
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fAbsVelocity);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "flashbang_projectile") != -1)
	{
		SDKHook(entity, SDKHook_StartTouch, Projectile_StartTouch);
	}
}

public Action Projectile_StartTouch(int entity, int client)
{
	if(!IsValidClient(client, true) || !IsValidEntity(entity))
	{
		return Plugin_Continue;
	}
	
	int Thrower = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	gA_Timers[Thrower].iNades++;
	
	return Plugin_Continue;
}

public int Native_GetOrderedStyles(Handle handler, int numParams)
{
	return SetNativeArray(1, gI_OrderedStyles, GetNativeCell(2));
}

public int Native_GetDatabase(Handle handler, int numParams)
{
	return view_as<int>(CloneHandle(gH_SQL, handler));
}

public int Native_GetDB(Handle handler, int numParams)
{
	SetNativeCellRef(1, gH_SQL);
}

public int Native_GetTimer(Handle handler, int numParams)
{
	// 1 - client
	int client = GetNativeCell(1);

	// 2 - time
	SetNativeCellRef(2, gA_Timers[client].fTimer);
	SetNativeCellRef(3, gA_Timers[client].iJumps);
	SetNativeCellRef(4, gA_Timers[client].iStyle);
	SetNativeCellRef(5, gA_Timers[client].bEnabled);
}

public int Native_GetClientTime(Handle handler, int numParams)
{
	return view_as<int>(gA_Timers[GetNativeCell(1)].fTimer);
}

public int Native_GetClientTrack(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iTrack;
}

public int Native_GetClientJumps(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iJumps;
}

public int Native_GetBhopStyle(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iStyle;
}

public int Native_GetTimerStatus(Handle handler, int numParams)
{
	return GetTimerStatus(GetNativeCell(1));
}

public int Native_HasStyleAccess(Handle handler, int numParams)
{
	int style = GetNativeCell(2);

	if(gA_StyleSettings[style].bInaccessible || gA_StyleSettings[style].iEnabled <= 0)
	{
		return false;
	}

	return CheckCommandAccess(GetNativeCell(1), (strlen(gS_StyleOverride[style]) > 0)? gS_StyleOverride[style]:"<none>", gI_StyleFlag[style]);
}

public int Native_StartTimer(Handle handler, int numParams)
{
	StartTimer(GetNativeCell(1), GetNativeCell(2));
}

public int Native_StopTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool bBypass = (numParams < 2 || view_as<bool>(GetNativeCell(2)));

	if(!bBypass)
	{
		bool bResult = true;
		Call_StartForward(gH_Forwards_StopPre);
		Call_PushCell(client);
		Call_PushCell(gA_Timers[client].iTrack);
		Call_Finish(bResult);

		if(!bResult)
		{
			return false;
		}
	}

	StopTimer(client);

	Call_StartForward(gH_Forwards_Stop);
	Call_PushCell(client);
	Call_PushCell(gA_Timers[client].iTrack);
	Call_Finish();

	return true;
}

public int Native_CanPause(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int iFlags = 0;

	if(!gCV_Pause.BoolValue)
	{
		iFlags |= CPR_ByConVar;
	}

	if(!gA_Timers[client].bEnabled)
	{
		iFlags |= CPR_NoTimer;
	}

	if(Shavit_InsideZone(client, Zone_Start, gA_Timers[client].iTrack))
	{
		iFlags |= CPR_InStartZone;
	}

	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1 && GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		iFlags |= CPR_NotOnGround;
	}

	return iFlags;
}

public int Native_ChangeClientStyle(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int style = GetNativeCell(2);
	bool force = view_as<bool>(GetNativeCell(3));
	bool manual = view_as<bool>(GetNativeCell(4));
	bool noforward = view_as<bool>(GetNativeCell(5));

	if(force || Shavit_HasStyleAccess(client, style))
	{
		if(noforward)
		{
			gA_Timers[client].iStyle = style;
			
			if(gA_Timers[client].fTimescale != -1.0)
			{
				CallOnTimescaleChanged(client, gA_Timers[client].fTimescale, -1.0);
				gA_Timers[client].fTimescale = -1.0;
			}
			
			UpdateStyleSettings(client);
		}

		else
		{
			CallOnStyleChanged(client, gA_Timers[client].iStyle, style, manual);
		}

		return true;
	}

	return false;
}

public int Native_FinishMap(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	timer_snapshot_t snapshot;
	snapshot.bTimerEnabled = gA_Timers[client].bEnabled;
	snapshot.bClientPaused = gA_Timers[client].bPaused;
	snapshot.iJumps = gA_Timers[client].iJumps;
	snapshot.bsStyle = gA_Timers[client].iStyle;
	snapshot.iStrafes = gA_Timers[client].iStrafes;
	snapshot.iNades = gA_Timers[client].iNades;
	snapshot.iTotalMeasures = gA_Timers[client].iTotalMeasures;
	snapshot.iGoodGains = gA_Timers[client].iGoodGains;
	snapshot.fServerTime = GetEngineTime();
	snapshot.fCurrentTime = gA_Timers[client].fTimer;
	snapshot.iSHSWCombination = gA_Timers[client].iSHSWCombination;
	snapshot.iTimerTrack = gA_Timers[client].iTrack;
	snapshot.iMeasuredJumps = gA_Timers[client].iMeasuredJumps;
	snapshot.iPerfectJumps = gA_Timers[client].iPerfectJumps;

	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_FinishPre);
	Call_PushCell(client);
	Call_PushArrayEx(snapshot, sizeof(timer_snapshot_t), SM_PARAM_COPYBACK);
	Call_Finish(result);
	
	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return;
	}

	Call_StartForward(gH_Forwards_Finish);
	Call_PushCell(client);

	int style = 0;
	int track = Track_Main;
	float perfs = 100.0;

	if(result == Plugin_Continue)
	{
		Call_PushCell(style = gA_Timers[client].iStyle);
		Call_PushCell(gA_Timers[client].fTimer);
		Call_PushCell(gA_Timers[client].iJumps);
		Call_PushCell(gA_Timers[client].iStrafes);
		Call_PushCell(gA_Timers[client].iNades);
		Call_PushCell((gA_StyleSettings[gA_Timers[client].iStyle].bSync)? (gA_Timers[client].iGoodGains == 0)? 0.0:(gA_Timers[client].iGoodGains / float(gA_Timers[client].iTotalMeasures) * 100.0):-1.0);
		Call_PushCell(track = gA_Timers[client].iTrack);
		perfs = (gA_Timers[client].iMeasuredJumps == 0)? 100.0:(gA_Timers[client].iPerfectJumps / float(gA_Timers[client].iMeasuredJumps) * 100.0);
	}

	else
	{
		Call_PushCell(style = snapshot.bsStyle);
		Call_PushCell(snapshot.fCurrentTime);
		Call_PushCell(snapshot.iJumps);
		Call_PushCell(snapshot.iStrafes);
		Call_PushCell(snapshot.iNades);
		Call_PushCell((gA_StyleSettings[snapshot.bsStyle].bSync)? (snapshot.iGoodGains == 0)? 0.0:(snapshot.iGoodGains / float(snapshot.iTotalMeasures) * 100.0):-1.0);
		Call_PushCell(track = snapshot.iTimerTrack);
		perfs = (snapshot.iMeasuredJumps == 0)? 100.0:(snapshot.iPerfectJumps / float(snapshot.iMeasuredJumps) * 100.0);
	}

	float oldtime = 0.0;

	if(gB_WR)
	{
		oldtime = Shavit_GetClientPB(client, style, track);
	}

	Call_PushCell(oldtime);
	Call_PushCell(perfs);
	Call_Finish();

	StopTimer(client);
}

public int Native_PauseTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	GetClientAbsOrigin(client, gF_PauseOrigin[client]);
	GetClientEyeAngles(client, gF_PauseAngles[client]);
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", gF_PauseVelocity[client]);

	PauseTimer(client);
}

public int Native_ResumeTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	ResumeTimer(client);

	if(numParams >= 2 && view_as<bool>(GetNativeCell(2))) // teleport?
	{
		TeleportEntity(client, gF_PauseOrigin[client], gF_PauseAngles[client], gF_PauseVelocity[client]);
	}
}

public int Native_StopChatSound(Handle handler, int numParams)
{
	gB_StopChatSound = true;
}

public int Native_PrintToChat(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	static int iWritten = 0; // useless?

	char sBuffer[300];
	FormatNativeString(0, 2, 3, 300, iWritten, sBuffer);
	Format(sBuffer, 300, "%s %s%s", gS_ChatStrings.sPrefix, gS_ChatStrings.sText, sBuffer);

	if(client == 0)
	{
		PrintToServer("%s", sBuffer);

		return false;
	}

	if(!IsClientInGame(client))
	{
		gB_StopChatSound = false;
		
		return false;
	}

	Handle hSayText2 = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

	Protobuf pbmsg = UserMessageToProtobuf(hSayText2);
	pbmsg.SetInt("ent_idx", client);
	pbmsg.SetBool("chat", !(gB_StopChatSound || gCV_NoChatSound.BoolValue));
	pbmsg.SetString("msg_name", sBuffer);

	// needed to not crash
	for(int i = 1; i <= 4; i++)
	{
		pbmsg.AddString("params", "");
	}

	EndMessage();

	gB_StopChatSound = false;

	return true;
}

public int Native_RestartTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int track = GetNativeCell(2);

	Call_StartForward(gH_Forwards_OnRestart);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish();

	StartTimer(client, track);
}

public int Native_GetPerfectJumps(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	return view_as<int>((gA_Timers[client].iMeasuredJumps == 0)? 100.0:(gA_Timers[client].iPerfectJumps / float(gA_Timers[client].iMeasuredJumps) * 100.0));
}

public int Native_GetStrafeCount(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iStrafes;
}

public int Native_GetThrowedNadesCount(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iNades;
}

public int Native_GetSync(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	return view_as<int>((gA_StyleSettings[gA_Timers[client].iStyle].bSync)? (gA_Timers[client].iGoodGains == 0)? 0.0:(gA_Timers[client].iGoodGains / float(gA_Timers[client].iTotalMeasures) * 100.0):-1.0);
}

public int Native_GetStyleCount(Handle handler, int numParams)
{
	return (gI_Styles > 0)? gI_Styles:-1;
}

public int Native_GetStyleSettings(Handle handler, int numParams)
{
	return SetNativeArray(2, gA_StyleSettings[GetNativeCell(1)], sizeof(stylesettings_t));
}

public int Native_GetStyleStrings(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int type = GetNativeCell(2);
	int size = GetNativeCell(4);

	switch(type)
	{
		case sStyleName: return SetNativeString(3, gS_StyleStrings[style].sStyleName, size);
		case sShortName: return SetNativeString(3, gS_StyleStrings[style].sShortName, size);
		case sHTMLColor: return SetNativeString(3, gS_StyleStrings[style].sHTMLColor, size);
		case sChangeCommand: return SetNativeString(3, gS_StyleStrings[style].sChangeCommand, size);
		case sClanTag: return SetNativeString(3, gS_StyleStrings[style].sClanTag, size);
		case sSpecialString: return SetNativeString(3, gS_StyleStrings[style].sSpecialString, size);
		case sStylePermission: return SetNativeString(3, gS_StyleStrings[style].sStylePermission, size);
	}

	return -1;
}

public int Native_GetChatStrings(Handle handler, int numParams)
{
	int type = GetNativeCell(1);
	int size = GetNativeCell(3);

	switch(type)
	{
		case sMessagePrefix: return SetNativeString(2, gS_ChatStrings.sPrefix, size);
		case sMessageText: return SetNativeString(2, gS_ChatStrings.sText, size);
		case sMessageWarning: return SetNativeString(2, gS_ChatStrings.sWarning, size);
		case sMessageVariable: return SetNativeString(2, gS_ChatStrings.sVariable, size);
		case sMessageVariable2: return SetNativeString(2, gS_ChatStrings.sVariable2, size);
		case sMessageStyle: return SetNativeString(2, gS_ChatStrings.sStyle, size);
		case sMessageGreen: return SetNativeString(2, gS_ChatStrings.sGreen, size);
		case sMessageDimgray: return SetNativeString(2, gS_ChatStrings.sDimgray, size);
		case sMessageOrange: return SetNativeString(2, gS_ChatStrings.sOrange, size);
	}

	return -1;
}

public int Native_SetPracticeMode(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool practice = view_as<bool>(GetNativeCell(2));
	bool alert = view_as<bool>(GetNativeCell(3));

	if(alert && practice && !gA_Timers[client].bPracticeMode && (!gB_HUD || (Shavit_GetHUDSettings(client) & HUD_NOPRACALERT) == 0))
	{
		Shavit_PrintToChat(client, "%T", "PracticeModeAlert", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
	}

	gA_Timers[client].bPracticeMode = practice;
}

public int Native_IsPaused(Handle handler, int numParams)
{
	return view_as<int>(gA_Timers[GetNativeCell(1)].bPaused);
}

public int Native_IsPracticeMode(Handle handler, int numParams)
{
	return view_as<int>(gA_Timers[GetNativeCell(1)].bPracticeMode);
}

public int Native_SaveSnapshot(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	timer_snapshot_t snapshot;
	snapshot.bTimerEnabled = gA_Timers[client].bEnabled;
	snapshot.bClientPaused = gA_Timers[client].bPaused;
	snapshot.iJumps = gA_Timers[client].iJumps;
	snapshot.bsStyle = gA_Timers[client].iStyle;
	snapshot.iStrafes = gA_Timers[client].iStrafes;
	snapshot.iNades = gA_Timers[client].iNades;
	snapshot.iTotalMeasures = gA_Timers[client].iTotalMeasures;
	snapshot.iGoodGains = gA_Timers[client].iGoodGains;
	snapshot.fServerTime = GetEngineTime();
	snapshot.fCurrentTime = gA_Timers[client].fTimer;
	snapshot.iSHSWCombination = gA_Timers[client].iSHSWCombination;
	snapshot.iTimerTrack = gA_Timers[client].iTrack;
	snapshot.iMeasuredJumps = gA_Timers[client].iMeasuredJumps;
	snapshot.iPerfectJumps = gA_Timers[client].iPerfectJumps;

	return SetNativeArray(2, snapshot, sizeof(timer_snapshot_t));
}

public int Native_LoadSnapshot(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	timer_snapshot_t snapshot;
	GetNativeArray(2, snapshot, sizeof(timer_snapshot_t));

	if(gA_Timers[client].iTrack != snapshot.iTimerTrack)
	{
		CallOnTrackChanged(client, gA_Timers[client].iTrack, snapshot.iTimerTrack);
	}

	gA_Timers[client].iTrack = snapshot.iTimerTrack;

	if(gA_Timers[client].iStyle != snapshot.bsStyle && Shavit_HasStyleAccess(client, snapshot.bsStyle))
	{
		CallOnStyleChanged(client, gA_Timers[client].iStyle, snapshot.bsStyle, false);
	}

	gA_Timers[client].bEnabled = snapshot.bTimerEnabled;
	gA_Timers[client].bPaused = snapshot.bClientPaused;
	gA_Timers[client].iJumps = snapshot.iJumps;
	gA_Timers[client].iStyle = snapshot.bsStyle;
	gA_Timers[client].iStrafes = snapshot.iStrafes;
	gA_Timers[client].iNades = snapshot.iNades;
	gA_Timers[client].iTotalMeasures = snapshot.iTotalMeasures;
	gA_Timers[client].iGoodGains = snapshot.iGoodGains;
	gA_Timers[client].fTimer = snapshot.fCurrentTime;
	gA_Timers[client].iSHSWCombination = snapshot.iSHSWCombination;
	gA_Timers[client].iMeasuredJumps = snapshot.iMeasuredJumps;
	gA_Timers[client].iPerfectJumps = snapshot.iPerfectJumps;
}

public int Native_LogMessage(Handle plugin, int numParams)
{
	char sPlugin[32];

	if(!GetPluginInfo(plugin, PlInfo_Name, sPlugin, 32))
	{
		GetPluginFilename(plugin, sPlugin, 32);
	}

	static int iWritten = 0;

	char sBuffer[300];
	FormatNativeString(0, 1, 2, 300, iWritten, sBuffer);
	
	LogToFileEx(gS_LogPath, "[%s] %s", sPlugin, sBuffer);
}

public int Native_GetClientTimescale(Handle handler, int numParams)
{
	return view_as<int>(gA_Timers[GetNativeCell(1)].fTimescale);
}

public int Native_SetClientTimescale(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	float timescale = GetNativeCell(2);

	if(timescale != gA_Timers[client].fTimescale)
	{
		CallOnTimescaleChanged(client, gA_Timers[client].fTimescale, timescale);
		gA_Timers[client].fTimescale = timescale;
	}
}

public int Native_SetClientTrack(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int track = GetNativeCell(2);
	
	StopTimer(client);
	gA_Timers[client].iTrack = track;
}

int GetTimerStatus(int client)
{
	if(!gA_Timers[client].bEnabled)
	{
		return view_as<int>(Timer_Stopped);
	}

	else if(gA_Timers[client].bPaused)
	{
		return view_as<int>(Timer_Paused);
	}

	return view_as<int>(Timer_Running);
}

void StartTimer(int client, int track)
{
	if(!IsValidClient(client, true) || GetClientTeam(client) < 2 || IsFakeClient(client) || !gB_CookiesRetrieved[client])
	{
		return;
	}
	
	float fSpeed[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fSpeed);
	
	if(!(gCV_NoZAxisSpeed.BoolValue && Shavit_GetClientTrack(client) == Track_Solobonus && !(StrContains(gS_Map, "trikz_sakura_final", false) == 0)) ||
		gA_StyleSettings[gA_Timers[client].iStyle].iPrespeed == 1 ||
		(fSpeed[2] == 0.0 && (gA_StyleSettings[gA_Timers[client].iStyle].iPrespeed == 2 || SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)) <= 290.0)))
	{
		Action result = Plugin_Continue;
		Call_StartForward(gH_Forwards_Start);
		Call_PushCell(client);
		Call_PushCell(track);
		Call_Finish(result);

		if(result == Plugin_Continue)
		{
			gA_Timers[client].bPaused = false;
			gA_Timers[client].iStrafes = 0;
			gA_Timers[client].iJumps = 0;
			gA_Timers[client].iNades = 0;
			gA_Timers[client].iTotalMeasures = 0;
			gA_Timers[client].iGoodGains = 0;
			
			if(gA_Timers[client].iTrack != track)
			{
				CallOnTrackChanged(client, gA_Timers[client].iTrack, track);
			}

			gA_Timers[client].iTrack = track;
			gA_Timers[client].bEnabled = true;
			gA_Timers[client].iSHSWCombination = -1;
			gA_Timers[client].fTimer = 0.0;
			gA_Timers[client].bPracticeMode = false;
			gA_Timers[client].iMeasuredJumps = 0;
			gA_Timers[client].iPerfectJumps = 0;
			gA_Timers[client].bCanUseAllKeys = false;

			if(gA_Timers[client].fTimescale != -1.0)
			{
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", gA_Timers[client].fTimescale);
			}
			
			else
			{
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fSpeedMultiplier));
			}

			SetEntityGravity(client, view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fGravityMultiplier));
		}

		else if(result == Plugin_Handled || result == Plugin_Stop)
		{
			gA_Timers[client].bEnabled = false;
		}
	}
	
	else
	{
		if(!Trikz_LoadCP() && !(GetEntityMoveType(client) == MOVETYPE_NOCLIP))
		{
			//Shavit_Teleport(client, Track_Solobonus); //Teleport to sb start, if timer doesnt started.
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
			Shavit_PrintToChat(client, "%T", "VSStartZoneDisallowed", client, gS_ChatStrings.sVariable, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
		}
	}
}

void StopTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	gA_Timers[client].bEnabled = false;
	gA_Timers[client].iJumps = 0;
	gA_Timers[client].fTimer = 0.0;
	gA_Timers[client].bPaused = false;
	gA_Timers[client].iStrafes = 0;
	gA_Timers[client].iNades = 0;
	gA_Timers[client].iTotalMeasures = 0;
	gA_Timers[client].iGoodGains = 0;
	
	int iPartner = Trikz_FindPartner(client);
		
	if((iPartner != -1) && (Shavit_GetClientTrack(iPartner) != Track_Solobonus))
	{
		gA_Timers[iPartner].bEnabled = false;
		gA_Timers[iPartner].iJumps = 0;
		gA_Timers[iPartner].fTimer = 0.0;
		gA_Timers[iPartner].bPaused = false;
		gA_Timers[iPartner].iStrafes = 0;
		gA_Timers[iPartner].iNades = 0;
		gA_Timers[iPartner].iTotalMeasures = 0;
		gA_Timers[iPartner].iGoodGains = 0;
	}
}

void PauseTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	Call_StartForward(gH_Forwards_OnPause);
	Call_PushCell(client);
	Call_PushCell(gA_Timers[client].iTrack);
	Call_Finish();

	gA_Timers[client].bPaused = true;
}

void ResumeTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	Call_StartForward(gH_Forwards_OnResume);
	Call_PushCell(client);
	Call_PushCell(gA_Timers[client].iTrack);
	Call_Finish();

	gA_Timers[client].bPaused = false;
}

public void OnClientDisconnect(int client)
{
	RequestFrame(StopTimer, client);
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client) || !IsClientInGame(client))
	{
		return;
	}

	char sCookie[4];

	if(gH_AutoBhopCookie != null)
	{
		GetClientCookie(client, gH_AutoBhopCookie, sCookie, 4);
	}

	gA_Timers[client].bAuto = (strlen(sCookie) > 0)? view_as<bool>(StringToInt(sCookie)):true;

	int style = gI_DefaultStyle;

	if(gB_StyleCookies && gH_StyleCookie != null)
	{
		GetClientCookie(client, gH_StyleCookie, sCookie, 4);
		int newstyle = StringToInt(sCookie);
	
		if(0 <= newstyle < gI_Styles)
		{
			style = newstyle;
		}
	}

	if(Shavit_HasStyleAccess(client, style))
	{
		CallOnStyleChanged(client, gA_Timers[client].iStyle, style, false);
	}

	gB_CookiesRetrieved[client] = true;
}

public void OnClientPutInServer(int client)
{
	StopTimer(client);

	if(!IsClientConnected(client) || IsFakeClient(client))
	{
		return;
	}

	gA_Timers[client].bAuto = true;
	//gA_Timers[client].bDoubleSteps = false;
	gA_Timers[client].fStrafeWarning = 0.0;
	gA_Timers[client].bPracticeMode = false;
	gA_Timers[client].iSHSWCombination = -1;
	gA_Timers[client].iTrack = 0;
	gA_Timers[client].iStyle = 0;
	gA_Timers[client].fTimescale = -1.0;
	strcopy(gS_DeleteMap[client], 160, "");

	gB_CookiesRetrieved[client] = false;

	if(AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
	}

	// not adding style permission check here for obvious reasons
	else
	{
		CallOnStyleChanged(client, 0, gI_DefaultStyle, false);
	}

	SDKHook(client, SDKHook_PreThinkPost, PreThinkPost);

	int iSteamID = GetSteamAccountID(client);

	if(iSteamID == 0)
	{
		KickClient(client, "%T", "VerificationFailed", client);

		return;
	}

	char sName[MAX_NAME_LENGTH_SQL];
	GetClientName(client, sName, MAX_NAME_LENGTH_SQL);
	ReplaceString(sName, MAX_NAME_LENGTH_SQL, "#", "?"); // to avoid this: https://user-images.githubusercontent.com/3672466/28637962-0d324952-724c-11e7-8b27-15ff021f0a59.png

	int iLength = ((strlen(sName) * 2) + 1);
	char[] sEscapedName = new char[iLength];
	gH_SQL.Escape(sName, sEscapedName, iLength);

	char sIPAddress[64];
	GetClientIP(client, sIPAddress, 64);
	int iIPAddress = IPStringToAddress(sIPAddress);

	int iTime = GetTime();
	char sQuery[512];

	if(gB_MySQL)
	{			
		FormatEx(sQuery, 512,
			"INSERT INTO %susers (auth, name, ip, lastlogin) VALUES (%d, '%s', %d, %d) ON DUPLICATE KEY UPDATE name = '%s', ip = %d, lastlogin = %d;",
			gS_MySQLPrefix, iSteamID, sEscapedName, iIPAddress, iTime, sEscapedName, iIPAddress, iTime);
		
		gH_SQL.Query(SQL_InsertUser_Callback, sQuery, GetClientSerial(client));
		
		char sQueryFirst[512];
		FormatEx(sQueryFirst, 512, "SELECT firstlogin FROM %susers WHERE auth = %d;", gS_MySQLPrefix, iSteamID);
		
		gH_SQL.Query(SQL_InsertUserFirstLogin_Callback, sQueryFirst, GetClientSerial(client));
	}

	else
	{
		FormatEx(sQuery, 512,
			"REPLACE INTO %susers (auth, name, ip, lastlogin) VALUES (%d, '%s', %d, %d);",
			gS_MySQLPrefix, iSteamID, sEscapedName, iIPAddress, iTime);
			
		gH_SQL.Query(SQL_InsertUser_Callback, sQuery, GetClientSerial(client));
	}
}

public void SQL_InsertUser_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		int client = GetClientFromSerial(data);

		if(client == 0)
		{
			LogError("Timer error! Failed to insert a disconnected player's data to the table. Reason: %s", error);
		}

		else
		{
			LogError("Timer error! Failed to insert \"%N\"'s data to the table. Reason: %s", client, error);
		}

		return;
	}
}

public void SQL_InsertUserFirstLogin_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	
	if(results == null)
	{
		if(client == 0)
		{
			LogError("Timer error! Failed to insert a disconnected player's data (firstlogin) to the table. Reason: %s", error);
		}

		else
		{
			LogError("Timer error! Failed to insert \"%N\"'s data (firstlogin) to the table. Reason: %s", client, error);
		}

		return;
	}
	
	results.FetchRow();
	int iFirstLogin = results.FetchInt(0);
	char sQuery[512];
	
	int iSteamID = GetSteamAccountID(client);
	
	if(iFirstLogin == -1)
	{		
		FormatEx(sQuery, 512, "UPDATE %susers SET firstlogin = %d WHERE auth = %d;", gS_MySQLPrefix, GetTime(), iSteamID);
		
		gH_SQL.Query(SQL_InsertUser_Callback, sQuery, GetClientSerial(client));
	}
}

bool LoadStyles()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-styles.cfg");

	KeyValues kv = new KeyValues("shavit-styles");
	
	if(!kv.ImportFromFile(sPath) || !kv.GotoFirstSubKey())
	{
		delete kv;

		return false;
	}

	int i = 0;

	do
	{
		kv.GetString("name", gS_StyleStrings[i].sStyleName, sizeof(stylestrings_t::sStyleName), "<MISSING STYLE NAME>");
		kv.GetString("shortname", gS_StyleStrings[i].sShortName, sizeof(stylestrings_t::sShortName), "<MISSING SHORT STYLE NAME>");
		kv.GetString("htmlcolor", gS_StyleStrings[i].sHTMLColor, sizeof(stylestrings_t::sHTMLColor), "<MISSING STYLE HTML COLOR>");
		kv.GetString("command", gS_StyleStrings[i].sChangeCommand, sizeof(stylestrings_t::sChangeCommand), "");
		kv.GetString("clantag", gS_StyleStrings[i].sClanTag, sizeof(stylestrings_t::sClanTag), "<MISSING STYLE CLAN TAG>");
		kv.GetString("specialstring", gS_StyleStrings[i].sSpecialString, sizeof(stylestrings_t::sSpecialString), "");
		kv.GetString("permission", gS_StyleStrings[i].sStylePermission, sizeof(stylestrings_t::sStylePermission), "");

		gA_StyleSettings[i].bAutobhop = view_as<bool>(kv.GetNum("autobhop", 1));
		//gA_StyleSettings[i].bEasybhop = view_as<bool>(kv.GetNum("easybhop", 1));
		gA_StyleSettings[i].iPrespeed = view_as<bool>(kv.GetNum("prespeed", 0));
		gA_StyleSettings[i].fVelocityLimit = kv.GetFloat("velocity_limit", 0.0);
		//gA_StyleSettings[i].fAiraccelerate = kv.GetFloat("airaccelerate", 1000.0);
		//gA_StyleSettings[i].bEnableBunnyhopping = view_as<bool>(kv.GetNum("bunnyhopping", 1));
		gA_StyleSettings[i].fRunspeed = kv.GetFloat("runspeed", 250.00);
		gA_StyleSettings[i].fGravityMultiplier = kv.GetFloat("gravity", 0.9);
		gA_StyleSettings[i].fSpeedMultiplier = kv.GetFloat("speed", 1.0);
		gA_StyleSettings[i].fTimescale = view_as<bool>(kv.GetNum("halftime", 0))? 0.5:kv.GetFloat("timescale", 1.0); // backwards compat for old halftime settig
		gA_StyleSettings[i].fVelocity = kv.GetFloat("velocity", 1.0);
		gA_StyleSettings[i].fBonusVelocity = kv.GetFloat("bonus_velocity", 0.0);
		gA_StyleSettings[i].fMinVelocity = kv.GetFloat("min_velocity", 0.0);
		gA_StyleSettings[i].fJumpMultiplier = kv.GetFloat("jump_multiplier", 0.0);
		gA_StyleSettings[i].fJumpBonus = kv.GetFloat("jump_bonus", 0.0);
		gA_StyleSettings[i].bBlockW = view_as<bool>(kv.GetNum("block_w", 0));
		gA_StyleSettings[i].bBlockA = view_as<bool>(kv.GetNum("block_a", 0));
		gA_StyleSettings[i].bBlockS = view_as<bool>(kv.GetNum("block_s", 0));
		gA_StyleSettings[i].bBlockD = view_as<bool>(kv.GetNum("block_d", 0));
		gA_StyleSettings[i].bBlockUse = view_as<bool>(kv.GetNum("block_use", 0));
		gA_StyleSettings[i].iForceHSW = kv.GetNum("force_hsw", 0);
		gA_StyleSettings[i].iBlockPLeft = kv.GetNum("block_pleft", 0);
		gA_StyleSettings[i].iBlockPRight = kv.GetNum("block_pright", 0);
		gA_StyleSettings[i].iBlockPStrafe = kv.GetNum("block_pstrafe", 0);
		gA_StyleSettings[i].bUnranked = view_as<bool>(kv.GetNum("unranked", 0));
		gA_StyleSettings[i].bNoReplay = view_as<bool>(kv.GetNum("noreplay", 0));
		gA_StyleSettings[i].bSync = view_as<bool>(kv.GetNum("sync", 1));
		gA_StyleSettings[i].bStrafeCountW = view_as<bool>(kv.GetNum("strafe_count_w", false));
		gA_StyleSettings[i].bStrafeCountA = view_as<bool>(kv.GetNum("strafe_count_a", true));
		gA_StyleSettings[i].bStrafeCountS = view_as<bool>(kv.GetNum("strafe_count_s", false));
		gA_StyleSettings[i].bStrafeCountD = view_as<bool>(kv.GetNum("strafe_count_d", true));
		gA_StyleSettings[i].fRankingMultiplier = kv.GetFloat("rankingmultiplier", 1.00);
		gA_StyleSettings[i].iSpecial = kv.GetNum("special", 0);
		gA_StyleSettings[i].iOrdering = kv.GetNum("ordering", i);
		gA_StyleSettings[i].bInaccessible = view_as<bool>(kv.GetNum("inaccessible", false));
		gA_StyleSettings[i].iEnabled = kv.GetNum("enabled", 1);
		gA_StyleSettings[i].bForceKeysOnGround = view_as<bool>(kv.GetNum("force_groundkeys", 0));

		// if this style is disabled, we will force certain settings
		if(gA_StyleSettings[i].iEnabled <= 0)
		{
			gA_StyleSettings[i].bNoReplay = true;
			gA_StyleSettings[i].fRankingMultiplier = 0.0;
			gA_StyleSettings[i].bInaccessible = true;
		}

		if(!gB_Registered && strlen(gS_StyleStrings[i].sChangeCommand) > 0 && !gA_StyleSettings[i].bInaccessible)
		{
			char sStyleCommands[32][32];
			int iCommands = ExplodeString(gS_StyleStrings[i].sChangeCommand, ";", sStyleCommands, 32, 32, false);

			char sDescription[128];
			FormatEx(sDescription, 128, "Change style to %s.", gS_StyleStrings[i].sStyleName);

			for(int x = 0; x < iCommands; x++)
			{
				TrimString(sStyleCommands[x]);
				StripQuotes(sStyleCommands[x]);

				char sCommand[32];
				FormatEx(sCommand, 32, "sm_%s", sStyleCommands[x]);

				gSM_StyleCommands.SetValue(sCommand, i);

				RegConsoleCmd(sCommand, Command_StyleChange, sDescription);
			}
		}

		if(StrContains(gS_StyleStrings[i].sStylePermission, ";") != -1)
		{
			char sText[2][32];
			int iCount = ExplodeString(gS_StyleStrings[i].sStylePermission, ";", sText, 2, 32);

			AdminFlag flag = Admin_Reservation;

			if(FindFlagByChar(sText[0][0], flag))
			{
				gI_StyleFlag[i] = FlagToBit(flag);
			}

			strcopy(gS_StyleOverride[i], 32, (iCount >= 2)? sText[1]:"");
		}

		else if(strlen(gS_StyleStrings[i].sStylePermission) > 0)
		{
			AdminFlag flag = Admin_Reservation;

			if(FindFlagByChar(gS_StyleStrings[i].sStylePermission[0], flag))
			{
				gI_StyleFlag[i] = FlagToBit(flag);
			}
		}

		gI_OrderedStyles[i] = i++;
	}

	while(kv.GotoNextKey());

	delete kv;

	gI_Styles = i;
	gB_Registered = true;

	SortCustom1D(gI_OrderedStyles, gI_Styles, SortAscending_StyleOrder);

	Call_StartForward(gH_Forwards_OnStyleConfigLoaded);
	Call_PushCell(gI_Styles);
	Call_Finish();

	return true;
}

public int SortAscending_StyleOrder(int index1, int index2, const int[] array, any hndl)
{
	int iOrder1 = gA_StyleSettings[index1].iOrdering;
	int iOrder2 = gA_StyleSettings[index2].iOrdering;

	if(iOrder1 < iOrder2)
	{
		return -1;
	}

	else if(iOrder1 == iOrder2)
	{
		return 0;
	}

	else
	{
		return 1;
	}
}

public Action Command_StyleChange(int client, int args)
{
	char sCommand[128];
	GetCmdArg(0, sCommand, 128);

	int style = 0;

	if(gSM_StyleCommands.GetValue(sCommand, style))
	{
		if(IsPlayerAlive(client))
		{
			ChangeClientStyle(client, style, true);
		}
		
		else
		{
			Shavit_PrintToChat(client, "You must be alive to use this feature.");
		}

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void ReplaceColors(char[] string, int size)
{
	for(int x = 0; x < sizeof(gS_GlobalColorNames); x++)
	{
		ReplaceString(string, size, gS_GlobalColorNames[x], gS_GlobalColors[x]);
	}

	ReplaceString(string, size, "{RGB}", "\x07");
	ReplaceString(string, size, "{RGBA}", "\x08");
}

bool LoadMessages()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-messages.cfg");

	KeyValues kv = new KeyValues("shavit-messages");
	
	if(!kv.ImportFromFile(sPath))
	{
		delete kv;

		return false;
	}

	kv.GetString("prefix", gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix), "\x04[Timer]");
	kv.GetString("text", gS_ChatStrings.sText, sizeof(chatstrings_t::sText), "\x01");
	kv.GetString("warning", gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning), "\x02");
	kv.GetString("variable", gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable), "\x05");
	kv.GetString("variable2", gS_ChatStrings.sVariable2, sizeof(chatstrings_t::sVariable2), "\x05");
	kv.GetString("style", gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle), "\x0b");
	kv.GetString("green", gS_ChatStrings.sGreen, sizeof(chatstrings_t::sGreen), "\x04");
	kv.GetString("dimgray", gS_ChatStrings.sDimgray, sizeof(chatstrings_t::sDimgray), "\x08");
	kv.GetString("orange", gS_ChatStrings.sOrange, sizeof(chatstrings_t::sOrange), "\x10");

	delete kv;

	ReplaceColors(gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix));
	ReplaceColors(gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	ReplaceColors(gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
	ReplaceColors(gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
	ReplaceColors(gS_ChatStrings.sVariable2, sizeof(chatstrings_t::sVariable2));
	ReplaceColors(gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle));
	ReplaceColors(gS_ChatStrings.sGreen, sizeof(chatstrings_t::sGreen));
	ReplaceColors(gS_ChatStrings.sDimgray, sizeof(chatstrings_t::sDimgray));
	ReplaceColors(gS_ChatStrings.sOrange, sizeof(chatstrings_t::sOrange));

	Call_StartForward(gH_Forwards_OnChatConfigLoaded);
	Call_Finish();

	return true;
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle();
	gB_MySQL = IsMySQLDatabase(gH_SQL);

	// support unicode names
	if(!gH_SQL.SetCharset("utf8mb4"))
	{
		gH_SQL.SetCharset("utf8");
	}

	CreateUsersTable();
}

void CreateUsersTable()
{
	char sQuery[512];

	if(gB_MySQL)
	{
		FormatEx(sQuery, 512,
			"CREATE TABLE IF NOT EXISTS `%susers` (`auth` INT NOT NULL, `name` VARCHAR(32) COLLATE 'utf8mb4_general_ci', `ip` INT, `firstlogin` INT NOT NULL DEFAULT -1, `lastlogin` INT NOT NULL DEFAULT -1, `points` FLOAT NOT NULL DEFAULT 0, PRIMARY KEY (`auth`), INDEX `points` (`points`), INDEX `firstlogin` (`firstlogin`), INDEX `lastlogin` (`lastlogin`)) ENGINE=INNODB;",
			gS_MySQLPrefix);
	}

	else
	{
		FormatEx(sQuery, 512,
			"CREATE TABLE IF NOT EXISTS `%susers` (`auth` INT NOT NULL PRIMARY KEY, `name` VARCHAR(32), `ip` INT, `lastlogin` INTEGER NOT NULL DEFAULT -1, `points` FLOAT NOT NULL DEFAULT 0);",
			gS_MySQLPrefix);
	}

	gH_SQL.Query(SQL_CreateUsersTable_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_CreateUsersTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Users' data table creation failed. Reason: %s", error);

		return;
	}

	Call_StartForward(gH_Forwards_OnDatabaseLoaded);
	Call_Finish();
}

public void Shavit_OnEnterZone(int client, int type, int track, int id, int entity)
{
	/*if(type == Zone_Airaccelerate)
	{
		gF_ZoneAiraccelerate[client] = float(Shavit_GetZoneData(id));

		UpdateAiraccelerate(client, gF_ZoneAiraccelerate[client]);
	}*/

	if(type == Zone_CustomSpeedLimit)
	{
		gF_ZoneSpeedLimit[client] = float(Shavit_GetZoneData(id));
	}
}

public void Shavit_OnLeaveZone(int client, int type, int track, int id, int entity)
{
	/*if(type == Zone_Airaccelerate)
	{
		UpdateAiraccelerate(client, view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fAiraccelerate));
	}*/
}

public void PreThinkPost(int client)
{
	if(IsPlayerAlive(client))
	{
		/*if(!gB_Zones || !Shavit_InsideZone(client, Zone_Airaccelerate, -1))
		{
			sv_airaccelerate.FloatValue = view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fAiraccelerate);
		}

		else
		{
			sv_airaccelerate.FloatValue = gF_ZoneAiraccelerate[client];
		}

		if(sv_enablebunnyhopping != null)
		{
			sv_enablebunnyhopping.BoolValue = view_as<bool>(gA_StyleSettings[gA_Timers[client].iStyle].bEnableBunnyhopping);
		}*/

		MoveType mtMoveType = GetEntityMoveType(client);

		if(view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fGravityMultiplier) != 1.0 &&
			(mtMoveType == MOVETYPE_WALK || mtMoveType == MOVETYPE_ISOMETRIC) &&
			(gA_Timers[client].iMoveType == MOVETYPE_LADDER || GetEntityGravity(client) == 1.0))
		{
			SetEntityGravity(client, view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fGravityMultiplier));
		}

		gA_Timers[client].iMoveType = mtMoveType;
	}
}

public void OnGameFrame()
{
	gI_TickCount = GetGameTickCount();
	float frametime = GetGameFrameTime();

	for(int i = 1; i <= MaxClients; i++)
	{
		if(gA_Timers[i].bPaused || !gA_Timers[i].bEnabled)
		{
			continue;
		}

		float time;
		if(gA_Timers[i].fTimescale != -1.0)
		{
			time = frametime * gA_Timers[i].fTimescale;
		}

		else
		{
			time = frametime * view_as<float>(gA_StyleSettings[gA_Timers[i].iStyle].fTimescale);
		}

		timer_snapshot_t snapshot;
		snapshot.bTimerEnabled = gA_Timers[i].bEnabled;
		snapshot.bClientPaused = gA_Timers[i].bPaused;
		snapshot.iJumps = gA_Timers[i].iJumps;
		snapshot.bsStyle = gA_Timers[i].iStyle;
		snapshot.iStrafes = gA_Timers[i].iStrafes;
		snapshot.iNades = gA_Timers[i].iNades;
		snapshot.iTotalMeasures = gA_Timers[i].iTotalMeasures;
		snapshot.iGoodGains = gA_Timers[i].iGoodGains;
		snapshot.fServerTime = GetEngineTime();
		snapshot.fCurrentTime = gA_Timers[i].fTimer;
		snapshot.iSHSWCombination = gA_Timers[i].iSHSWCombination;
		snapshot.iTimerTrack = gA_Timers[i].iTrack;

		Call_StartForward(gH_Forwards_OnTimerIncrement);
		Call_PushCell(i);
		Call_PushArray(snapshot, sizeof(timer_snapshot_t));
		Call_PushCellRef(time);
		Call_PushArray(gA_StyleSettings[gA_Timers[i].iStyle], sizeof(stylesettings_t));
		Call_Finish();

		gA_Timers[i].fTimer += time;

		Call_StartForward(gH_Forwards_OnTimerIncrementPost);
		Call_PushCell(i);
		Call_PushCell(time);
		Call_PushArray(gA_StyleSettings[gA_Timers[i].iStyle], sizeof(stylesettings_t));
		Call_Finish();
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!IsPlayerAlive(client) || IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	int flags = GetEntityFlags(client);

	if(gA_Timers[client].bPaused)
	{
		buttons = 0;
		vel = view_as<float>({0.0, 0.0, 0.0});

		SetEntityFlags(client, (flags | FL_ATCONTROLS));

		return Plugin_Changed;
	}

	SetEntityFlags(client, (flags & ~FL_ATCONTROLS));

	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_OnUserCmdPre);
	Call_PushCell(client);
	Call_PushCellRef(buttons);
	Call_PushCellRef(impulse);
	Call_PushArrayEx(vel, 3, SM_PARAM_COPYBACK);
	Call_PushArrayEx(angles, 3, SM_PARAM_COPYBACK);
	Call_PushCell(GetTimerStatus(client));
	Call_PushCell(gA_Timers[client].iTrack);
	Call_PushCell(gA_Timers[client].iStyle);
	Call_PushArray(gA_StyleSettings[gA_Timers[client].iStyle], sizeof(stylesettings_t));
	Call_PushArrayEx(mouse, 2, SM_PARAM_COPYBACK);
	Call_Finish(result);
	
	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return result;
	}

	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	bool bInStart = Shavit_InsideZone(client, Zone_Start, gA_Timers[client].iTrack);

	if(gA_Timers[client].bEnabled && !gA_Timers[client].bPaused)
	{
		// +left/right block
		if(!gB_Zones || (!bInStart && ((gA_StyleSettings[gA_Timers[client].iStyle].iBlockPLeft > 0 &&
			(buttons & IN_LEFT) > 0) || (gA_StyleSettings[gA_Timers[client].iStyle].iBlockPRight > 0 && (buttons & IN_RIGHT) > 0))))
		{
			vel[0] = 0.0;
			vel[1] = 0.0;

			if(gA_StyleSettings[gA_Timers[client].iStyle].iBlockPRight >= 2)
			{
				char sCheatDetected[64];
				FormatEx(sCheatDetected, 64, "%T", "LeftRightCheat", client);
				StopTimer_Cheat(client, sCheatDetected);
			}
		}

		// +strafe block
		if(gA_StyleSettings[gA_Timers[client].iStyle].iBlockPStrafe > 0 &&
			((vel[0] > 0.0 && (buttons & IN_FORWARD) == 0) || (vel[0] < 0.0 && (buttons & IN_BACK) == 0) ||
			(vel[1] > 0.0 && (buttons & IN_MOVERIGHT) == 0) || (vel[1] < 0.0 && (buttons & IN_MOVELEFT) == 0)))
		{
			if(gA_Timers[client].fStrafeWarning < gA_Timers[client].fTimer)
			{
				if(gA_StyleSettings[gA_Timers[client].iStyle].iBlockPStrafe >= 2)
				{
					char sCheatDetected[64];
					FormatEx(sCheatDetected, 64, "%T", "Inconsistencies", client);
					StopTimer_Cheat(client, sCheatDetected);
				}

				vel[0] = 0.0;
				vel[1] = 0.0;

				return Plugin_Changed;
			}

			gA_Timers[client].fStrafeWarning = gA_Timers[client].fTimer + 0.3;
		}
	}

	#if defined DEBUG
	static int cycle = 0;

	if(++cycle % 50 == 0)
	{
		Shavit_StopChatSound();
		Shavit_PrintToChat(client, "vel[0]: %.01f | vel[1]: %.01f", vel[0], vel[1]);
	}
	#endif

	int iPButtons = buttons;

	if(gA_StyleSettings[gA_Timers[client].iStyle].bStrafeCountW && !gA_StyleSettings[gA_Timers[client].iStyle].bBlockW &&
		(gA_Timers[client].iLastButtons & IN_FORWARD) == 0 && (buttons & IN_FORWARD) > 0)
	{
		gA_Timers[client].iStrafes++;
	}

	if(gA_StyleSettings[gA_Timers[client].iStyle].bStrafeCountA && !gA_StyleSettings[gA_Timers[client].iStyle].bBlockA && (gA_Timers[client].iLastButtons & IN_MOVELEFT) == 0 &&
		(buttons & IN_MOVELEFT) > 0 && (gA_StyleSettings[gA_Timers[client].iStyle].iForceHSW > 0 || ((buttons & IN_FORWARD) == 0 && (buttons & IN_BACK) == 0)))
	{
		gA_Timers[client].iStrafes++;
	}

	if(gA_StyleSettings[gA_Timers[client].iStyle].bStrafeCountS && !gA_StyleSettings[gA_Timers[client].iStyle].bBlockS &&
		(gA_Timers[client].iLastButtons & IN_BACK) == 0 && (buttons & IN_BACK) > 0)
	{
		gA_Timers[client].iStrafes++;
	}

	if(gA_StyleSettings[gA_Timers[client].iStyle].bStrafeCountD && !gA_StyleSettings[gA_Timers[client].iStyle].bBlockD && (gA_Timers[client].iLastButtons & IN_MOVERIGHT) == 0 &&
		(buttons & IN_MOVERIGHT) > 0 && (gA_StyleSettings[gA_Timers[client].iStyle].iForceHSW > 0 || ((buttons & IN_FORWARD) == 0 && (buttons & IN_BACK) == 0)))
	{
		gA_Timers[client].iStrafes++;
	}

	MoveType mtMoveType = GetEntityMoveType(client);

	if(mtMoveType == MOVETYPE_LADDER && gCV_SimplerLadders.BoolValue)
	{
		gA_Timers[client].bCanUseAllKeys = true;
	}

	else if(iGroundEntity != -1)
	{
		gA_Timers[client].bCanUseAllKeys = false;
	}

	// key blocking
	if(!gA_Timers[client].bCanUseAllKeys && mtMoveType != MOVETYPE_NOCLIP && mtMoveType != MOVETYPE_LADDER && !Shavit_InsideZone(client, Zone_Freestyle, -1))
	{
		// block E
		if(gA_StyleSettings[gA_Timers[client].iStyle].bBlockUse && (buttons & IN_USE) > 0)
		{
			buttons &= ~IN_USE;
		}

		if(iGroundEntity == -1 || gA_StyleSettings[gA_Timers[client].iStyle].bForceKeysOnGround)
		{
			if(gA_StyleSettings[gA_Timers[client].iStyle].bBlockW && ((buttons & IN_FORWARD) > 0 || vel[0] > 0.0))
			{
				vel[0] = 0.0;
				buttons &= ~IN_FORWARD;
			}

			if(gA_StyleSettings[gA_Timers[client].iStyle].bBlockA && ((buttons & IN_MOVELEFT) > 0 || vel[1] < 0.0))
			{
				vel[1] = 0.0;
				buttons &= ~IN_MOVELEFT;
			}

			if(gA_StyleSettings[gA_Timers[client].iStyle].bBlockS && ((buttons & IN_BACK) > 0 || vel[0] < 0.0))
			{
				vel[0] = 0.0;
				buttons &= ~IN_BACK;
			}

			if(gA_StyleSettings[gA_Timers[client].iStyle].bBlockD && ((buttons & IN_MOVERIGHT) > 0 || vel[1] > 0.0))
			{
				vel[1] = 0.0;
				buttons &= ~IN_MOVERIGHT;
			}

			// HSW
			// Theory about blocking non-HSW strafes while playing HSW:
			// Block S and W without A or D.
			// Block A and D without S or W.
			if(gA_StyleSettings[gA_Timers[client].iStyle].iForceHSW > 0)
			{
				bool bSHSW = (gA_StyleSettings[gA_Timers[client].iStyle].iForceHSW == 2) && !bInStart; // don't decide on the first valid input until out of start zone!
				int iCombination = -1;

				bool bForward = ((buttons & IN_FORWARD) > 0 && vel[0] >= 100.0);
				bool bMoveLeft = ((buttons & IN_MOVELEFT) > 0 && vel[1] <= -100.0);
				bool bBack = ((buttons & IN_BACK) > 0 && vel[0] <= -100.0);
				bool bMoveRight = ((buttons & IN_MOVERIGHT) > 0 && vel[1] >= 100.0);

				if(bSHSW)
				{
					if((bForward && bMoveLeft) || (bBack && bMoveRight))
					{
						iCombination = 0;
					}

					else if((bForward && bMoveRight || bBack && bMoveLeft))
					{
						iCombination = 1;
					}

					// int gI_SHSW_FirstCombination[MAXPLAYERS+1]; // 0 - W/A S/D | 1 - W/D S/A
					if(gA_Timers[client].iSHSWCombination == -1 && iCombination != -1)
					{
						Shavit_PrintToChat(client, "%T", (iCombination == 0)? "SHSWCombination0":"SHSWCombination1", client, gS_ChatStrings.sVariable, gS_ChatStrings.sText);
						gA_Timers[client].iSHSWCombination = iCombination;
					}

					bool bStop = false;

					// W/A S/D
					if((gA_Timers[client].iSHSWCombination == 0 && iCombination != 0) ||
					// W/D S/A
						(gA_Timers[client].iSHSWCombination == 1 && iCombination != 1) ||
					// no valid combination & no valid input
						(gA_Timers[client].iSHSWCombination == -1 && iCombination == -1))
					{
						bStop = true;
					}

					if(bStop)
					{
						vel[0] = 0.0;
						vel[1] = 0.0;

						buttons &= ~IN_FORWARD;
						buttons &= ~IN_MOVELEFT;
						buttons &= ~IN_MOVERIGHT;
						buttons &= ~IN_BACK;
					}
				}

				else
				{
					if((bForward || bBack) && !(bMoveLeft || bMoveRight))
					{
						vel[0] = 0.0;

						buttons &= ~IN_FORWARD;
						buttons &= ~IN_BACK;
					}

					if((bMoveLeft || bMoveRight) && !(bForward || bBack))
					{
						vel[1] = 0.0;

						buttons &= ~IN_MOVELEFT;
						buttons &= ~IN_MOVERIGHT;
					}
				}
			}
		}
	}

	bool bInWater = (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2);

	if(gA_StyleSettings[gA_Timers[client].iStyle].bAutobhop && gA_Timers[client].bAuto && (buttons & IN_JUMP) > 0 && mtMoveType == MOVETYPE_WALK && !bInWater)
	{
		int iOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
		SetEntProp(client, Prop_Data, "m_nOldButtons", (iOldButtons & ~IN_JUMP));
	}

	// perf jump measuring
	bool bOnGround = (!bInWater && mtMoveType == MOVETYPE_WALK && iGroundEntity != -1);

	if(bOnGround && !gA_Timers[client].bOnGround)
	{
		gA_Timers[client].iLandingTick = gI_TickCount;
	}

	else if(!bOnGround && gA_Timers[client].bOnGround && gA_Timers[client].bJumped)
	{
		int iDifference = (gI_TickCount - gA_Timers[client].iLandingTick);

		if(1 <= iDifference <= 8)
		{
			gA_Timers[client].iMeasuredJumps++;

			if(iDifference == 1)
			{
				gA_Timers[client].iPerfectJumps++;
			}
		}
	}

	if(bInStart && gCV_BlockPreJump.BoolValue && gA_StyleSettings[gA_Timers[client].iStyle].iPrespeed == 0 && (vel[2] > 0 || (buttons & IN_JUMP) > 0))
	{
		vel[2] = 0.0;
		buttons &= ~IN_JUMP;
	}

	// velocity limit
	if(iGroundEntity != -1 && view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fVelocityLimit > 0.0))
	{
		float fSpeedLimit = view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fVelocityLimit);

		if(gB_Zones && Shavit_InsideZone(client, Zone_CustomSpeedLimit, -1))
		{
			fSpeedLimit = gF_ZoneSpeedLimit[client];
		}

		float fSpeed[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fSpeed);

		float fSpeed_New = (SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)));

		if(fSpeedLimit != 0.0 && fSpeed_New > 0.0)
		{
			float fScale = fSpeedLimit / fSpeed_New;

			if(fScale < 1.0)
			{
				ScaleVector(fSpeed, fScale);
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fSpeed); // maybe change this to SetEntPropVector some time?
			}
		}
	}

	float fAngle = (angles[1] - gA_Timers[client].fLastAngle);

	while(fAngle > 180.0)
	{
		fAngle -= 360.0;
	}

	while(fAngle < -180.0)
	{
		fAngle += 360.0;
	}

	if(iGroundEntity == -1 && (GetEntityFlags(client) & FL_INWATER) == 0 && fAngle != 0.0)
	{
		float fAbsVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

		if(SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0)) > 0.0)
		{
			float fTempAngle = angles[1];

			float fAngles[3];
			GetVectorAngles(fAbsVelocity, fAngles);

			if(fTempAngle < 0.0)
			{
				fTempAngle += 360.0;
			}

			TestAngles(client, (fTempAngle - fAngles[1]), fAngle, vel);
		}
	}

	gA_Timers[client].iLastButtons = iPButtons;
	gA_Timers[client].fLastAngle = angles[1];
	gA_Timers[client].bJumped = false;
	gA_Timers[client].bOnGround = bOnGround;

	return Plugin_Continue;
}

void TestAngles(int client, float dirangle, float yawdelta, float vel[3])
{
	if(dirangle < 0.0)
	{
		dirangle = -dirangle;
	}

	// normal
	if(dirangle < 22.5 || dirangle > 337.5)
	{
		gA_Timers[client].iTotalMeasures++;

		if((yawdelta > 0.0 && vel[1] <= -100.0) || (yawdelta < 0.0 && vel[1] >= 100.0))
		{
			gA_Timers[client].iGoodGains++;
		}
	}

	// hsw (thanks nairda!)
	else if((dirangle > 22.5 && dirangle < 67.5))
	{
		gA_Timers[client].iTotalMeasures++;

		if((yawdelta != 0.0) && (vel[0] >= 100.0 || vel[1] >= 100.0) && (vel[0] >= -100.0 || vel[1] >= -100.0))
		{
			gA_Timers[client].iGoodGains++;
		}
	}

	// sw
	else if((dirangle > 67.5 && dirangle < 112.5) || (dirangle > 247.5 && dirangle < 292.5))
	{
		gA_Timers[client].iTotalMeasures++;

		if(vel[0] <= -100.0 || vel[0] >= 100.0)
		{
			gA_Timers[client].iGoodGains++;
		}
	}
}

void StopTimer_Cheat(int client, const char[] message)
{
	StopTimer(client);
	Shavit_PrintToChat(client, "%T", "CheatTimerStop", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText, message);
}

/*void UpdateAiraccelerate(int client, float airaccelerate)
{
	char sAiraccelerate[8];
	FloatToString(airaccelerate, sAiraccelerate, 8);
	sv_airaccelerate.ReplicateToClient(client, sAiraccelerate);
}*/

void UpdateStyleSettings(int client)
{
	/*if(sv_autobunnyhopping != null)
	{
		sv_autobunnyhopping.ReplicateToClient(client, (gA_StyleSettings[gA_Timers[client].iStyle].bAutobhop && gA_Timers[client].bAuto)? "1":"0");
	}

	if(sv_enablebunnyhopping != null)
	{
		sv_enablebunnyhopping.ReplicateToClient(client, (gA_StyleSettings[gA_Timers[client].iStyle].bEnableBunnyhopping)? "1":"0");
	}*/

	//UpdateAiraccelerate(client, view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fAiraccelerate));

	SetEntityGravity(client, view_as<float>(gA_StyleSettings[gA_Timers[client].iStyle].fGravityMultiplier));
}

void GetTrackName(int client, int track, char[] output, int size)
{
	if(track < 0 || track >= TRACKS_SIZE)
	{
		FormatEx(output, size, "%T", "Track_Unknown", client);

		return;
	}

	static char sTrack[16];
	FormatEx(sTrack, 16, "Track_%d", track);
	FormatEx(output, size, "%T", sTrack, client);
}

int Native_Teleport(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int track = GetNativeCell(2);
	
	if(Shavit_ZoneExists(Zone_Start, track))
	{		
		if(IsPlayerAlive(client))
		{
			Call_StartForward(gH_Forwards_OnRestart);
			Call_PushCell(client);
			Call_PushCell(track);
			Call_Finish();
		}
	}
}
