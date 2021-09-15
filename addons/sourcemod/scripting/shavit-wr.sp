/*
 * shavit's Timer - World Records
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

#undef REQUIRE_PLUGIN
#include <shavit>
#include <trikz>
#include <colorvariables>
#include <adminmenu>

#pragma newdecls required
#pragma semicolon 1

// #define DEBUG

enum struct wrcache_t
{
	int iLastStyle;
	int iLastTrack;
	bool bPendingMenu;
	bool bLoadedCache;
	char sClientMap[128];
}

bool gB_Late = false;
bool gB_Rankings = false;
bool gB_Stats = false;

// forwards
Handle gH_OnWorldRecord = null;
Handle gH_OnFinish_Post = null;
Handle gH_OnWRDeleted = null;
Handle gH_OnWorstRecord = null;
Handle gH_OnFinishMessage = null;

// database handle
Database gH_SQL = null;
bool gB_Connected = false;
bool gB_MySQL = false;

// cache
wrcache_t gA_WRCache[MAXPLAYERS+1];

char gS_Map[160]; // blame workshop paths being so fucking long
ArrayList gA_ValidMaps = null;
int gI_ValidMaps = 1;

// current wr stats
float gF_WRTime[STYLE_LIMIT][TRACKS_SIZE];
int gI_WRRecordID[STYLE_LIMIT][TRACKS_SIZE];
char gS_WRName[STYLE_LIMIT][TRACKS_SIZE][MAX_NAME_LENGTH];
ArrayList gA_Leaderboard[STYLE_LIMIT][TRACKS_SIZE];
float gF_PlayerRecord[MAXPLAYERS+1][STYLE_LIMIT][TRACKS_SIZE];
float gF_PlayerRecordLocal[MAXPLAYERS+1][STYLE_LIMIT][TRACKS_SIZE];
char sDifferenceWR[32];
char sDifference[16];
int iRank;
int g_iRank[MAXPLAYERS + 1];
int g_iRecords[MAXPLAYERS + 1];
int g_iSteamID[MAXPLAYERS + 1];
int g_iPSteamID[MAXPLAYERS + 1];
int gI_id[MAXPLAYERS + 1];
bool gB_WorldRecord[MAXPLAYERS + 1];
bool gB_RecentRecords[MAXPLAYERS + 1];

// admin menu
TopMenu gH_AdminMenu = null;
TopMenuObject gH_TimerCommands = INVALID_TOPMENUOBJECT;

// table prefix
char gS_MySQLPrefix[32];

// cvars
ConVar gCV_RecordsLimit = null;
ConVar gCV_RecentLimit = null;

// timer settings
int gI_Styles = 0;
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
stylesettings_t gA_StyleSettings[STYLE_LIMIT];

// chat settings
chatstrings_t gS_ChatStrings;

public Plugin myinfo =
{
	name = "[shavit] World Records",
	author = "shavit, sejiya, Smesh",
	description = "World records for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// natives
	CreateNative("Shavit_GetClientPB", Native_GetClientPB);
	CreateNative("Shavit_GetPlayerPB", Native_GetPlayerPB);
	CreateNative("Shavit_GetRankForTime", Native_GetRankForTime);
	CreateNative("Shavit_GetRecordAmount", Native_GetRecordAmount);
	CreateNative("Shavit_GetTimeForRank", Native_GetTimeForRank);
	CreateNative("Shavit_GetWorldRecord", Native_GetWorldRecord);
	CreateNative("Shavit_GetWRName", Native_GetWRName);
	CreateNative("Shavit_GetWRRecordID", Native_GetWRRecordID);
	CreateNative("Shavit_GetWRTime", Native_GetWRTime);
	CreateNative("Shavit_ReloadLeaderboards", Native_ReloadLeaderboards);
	CreateNative("Shavit_WR_DeleteMap", Native_WR_DeleteMap);
	CreateNative("Shavit_UpdateWRCache", Native_UpdateWRCache);
	CreateNative("Shavit_UpdateLocalCache", Native_UpdateLocalCache);
	CreateNative("Shavit_UpdateLocalCacheSB", Native_UpdateLocalCacheSB);

	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit-wr");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-wr.phrases");

	#if defined DEBUG
	RegConsoleCmd("sm_junk", Command_Junk);
	RegConsoleCmd("sm_printleaderboards", Command_PrintLeaderboards);
	#endif

	// forwards
	gH_OnWorldRecord = CreateGlobalForward("Shavit_OnWorldRecord", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_OnFinish_Post = CreateGlobalForward("Shavit_OnFinish_Post", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_OnWRDeleted = CreateGlobalForward("Shavit_OnWRDeleted", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_OnWorstRecord = CreateGlobalForward("Shavit_OnWorstRecord", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_OnFinishMessage = CreateGlobalForward("Shavit_OnFinishMessage", ET_Event, Param_Cell, Param_CellByRef, Param_Array, Param_Cell, Param_Cell, Param_String, Param_Cell);

	// player commands
	RegConsoleCmd("sm_wr", Command_WorldRecord, "View the leaderboard of a map. Usage: sm_wr [map]");
	RegConsoleCmd("sm_worldrecord", Command_WorldRecord, "View the leaderboard of a map. Usage: sm_worldrecord [map]");

	RegConsoleCmd("sm_recent", Command_RecentRecords, "View the recent #1 times set.");
	RegConsoleCmd("sm_recentrecords", Command_RecentRecords, "View the recent #1 times set.");
	RegConsoleCmd("sm_rr", Command_RecentRecords, "View the recent #1 times set.");

	// delete records
	RegAdminCmd("sm_delete", Command_Delete, ADMFLAG_RCON, "Opens a record deletion menu interface.");
	RegAdminCmd("sm_deleterecord", Command_Delete, ADMFLAG_RCON, "Opens a record deletion menu interface.");
	RegAdminCmd("sm_deleterecords", Command_Delete, ADMFLAG_RCON, "Opens a record deletion menu interface.");
	RegAdminCmd("sm_deleteall", Command_DeleteAll, ADMFLAG_RCON, "Deletes all the records for this map.");

	// cvars
	gCV_RecordsLimit = CreateConVar("shavit_wr_recordlimit", "100", "Limit of records shown in the WR menu.\nAdvised to not set above 1,000 because scrolling through so many pages is useless.\n(And can also cause the command to take long time to run)", 0, true, 1.0);
	gCV_RecentLimit = CreateConVar("shavit_wr_recentlimit", "100", "Limit of records shown in the RR menu.", 0, true, 1.0);

	AutoExecConfig();

	// modules
	gB_Rankings = LibraryExists("shavit-rankings");
	gB_Stats = LibraryExists("shavit-stats");

	// cache
	gA_ValidMaps = new ArrayList(192);

	// database
	SQL_DBConnect();
}

public void OnAllPluginsLoaded()
{
	// admin menu
	if(LibraryExists("adminmenu") && ((gH_AdminMenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(gH_AdminMenu);
	}
}

public void OnAdminMenuCreated(Handle topmenu)
{
	if(gH_AdminMenu == null || (topmenu == gH_AdminMenu && gH_TimerCommands != INVALID_TOPMENUOBJECT))
	{
		return;
	}

	gH_TimerCommands = gH_AdminMenu.AddCategory("Timer Commands", CategoryHandler, "shavit_admin", ADMFLAG_RCON);
}

public void CategoryHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayTitle)
	{
		FormatEx(buffer, maxlength, "%T:", "TimerCommands", param);
	}

	else if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%T", "TimerCommands", param);
	}
}

public void OnAdminMenuReady(Handle topmenu)
{
	if((gH_AdminMenu = GetAdminTopMenu()) != null)
	{
		if(gH_TimerCommands == INVALID_TOPMENUOBJECT)
		{
			gH_TimerCommands = gH_AdminMenu.FindCategory("Timer Commands");

			if(gH_TimerCommands == INVALID_TOPMENUOBJECT)
			{
				OnAdminMenuCreated(topmenu);
			}
		}
		
		gH_AdminMenu.AddItem("sm_deleteall", AdminMenu_DeleteAll, gH_TimerCommands, "sm_deleteall", ADMFLAG_RCON);
		gH_AdminMenu.AddItem("sm_delete", AdminMenu_Delete, gH_TimerCommands, "sm_delete", ADMFLAG_RCON);
	}
}

public void AdminMenu_Delete(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%t", "DeleteSingleRecord");
	}

	else if(action == TopMenuAction_SelectOption)
	{
		Command_Delete(param, 0);
	}
}

public void AdminMenu_DeleteAll(Handle topmenu,  TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "%t", "DeleteAllRecords");
	}

	else if(action == TopMenuAction_SelectOption)
	{
		Command_DeleteAll(param, 0);
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = true;
	}

	else if(StrEqual(name, "shavit-stats"))
	{
		gB_Stats = true;
	}
	
	else if (StrEqual(name, "adminmenu"))
	{
		if ((gH_AdminMenu = GetAdminTopMenu()) != null)
		{
			OnAdminMenuReady(gH_AdminMenu);
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = false;
	}

	else if(StrEqual(name, "shavit-stats"))
	{
		gB_Stats = false;
	}

	else if (StrEqual(name, "adminmenu"))
	{
		gH_AdminMenu = null;
		gH_TimerCommands = INVALID_TOPMENUOBJECT;
	}
}

public void OnMapStart()
{
	if(!gB_Connected)
	{
		return;
	}

	GetCurrentMap(gS_Map, 160);
	GetMapDisplayName(gS_Map, gS_Map, 160);

	UpdateWRCache();

	char sLowerCase[160];
	strcopy(sLowerCase, 160, gS_Map);

	for(int i = 0; i < strlen(sLowerCase); i++)
	{
		if(!IsCharUpper(sLowerCase[i]))
		{
			sLowerCase[i] = CharToLower(sLowerCase[i]);
		}
	}

	gA_ValidMaps.Clear();
	gA_ValidMaps.PushString(sLowerCase);
	gI_ValidMaps = 1;

	char sQuery[128];
	FormatEx(sQuery, 128, "SELECT map FROM %smapzones GROUP BY map;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_UpdateMaps_Callback, sQuery, 0, DBPrio_Low);

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(-1);
		Shavit_OnChatConfigLoaded();
	}
}

public void SQL_UpdateMaps_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR maps cache update) SQL query failed. Reason: %s", error);

		return;
	}

	while(results.FetchRow())
	{
		char sMap[192];
		results.FetchString(0, sMap, 192);

		char sLowerCase[128];
		strcopy(sLowerCase, 128, sMap);

		for(int i = 0; i < strlen(sLowerCase); i++)
		{
			if(!IsCharUpper(sLowerCase[i]))
			{
				sLowerCase[i] = CharToLower(sLowerCase[i]);
			}
		}

		if(gA_ValidMaps.FindString(sLowerCase) == -1)
		{
			gA_ValidMaps.PushString(sLowerCase);
			gI_ValidMaps++;
		}
	}

	SortADTArray(gA_ValidMaps, Sort_Ascending, Sort_String);
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	if(styles == -1)
	{
		styles = Shavit_GetStyleCount();
	}

	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleSettings(i, gA_StyleSettings[i]);
		Shavit_GetStyleStrings(i, sStyleName, gS_StyleStrings[i].sStyleName, sizeof(stylestrings_t::sStyleName));
		Shavit_GetStyleStrings(i, sShortName, gS_StyleStrings[i].sShortName, sizeof(stylestrings_t::sShortName));
	}

	// arrays
	for(int i = 0; i < STYLE_LIMIT; i++)
	{
		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			if(i < styles)
			{
				if(gA_Leaderboard[i][j] == null)
				{
					gA_Leaderboard[i][j] = new ArrayList();
				}

				gA_Leaderboard[i][j].Clear();
			}

			else
			{
				delete gA_Leaderboard[i][j];
			}
		}
	}

	gI_Styles = styles;
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessagePrefix, gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix));
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	Shavit_GetChatStrings(sMessageWarning, gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
	Shavit_GetChatStrings(sMessageVariable2, gS_ChatStrings.sVariable2, sizeof(chatstrings_t::sVariable2));
	Shavit_GetChatStrings(sMessageStyle, gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle));
	Shavit_GetChatStrings(sMessageGreen, gS_ChatStrings.sGreen, sizeof(chatstrings_t::sGreen));
	Shavit_GetChatStrings(sMessageDimgray, gS_ChatStrings.sDimgray, sizeof(chatstrings_t::sDimgray));
	Shavit_GetChatStrings(sMessageOrange, gS_ChatStrings.sOrange, sizeof(chatstrings_t::sOrange));
}

public void OnClientPutInServer(int client)
{
	gA_WRCache[client].bPendingMenu = false;
	gA_WRCache[client].bLoadedCache = false;

	for(int i = 0; i < gI_Styles; i++)
	{
		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			gF_PlayerRecord[client][i][j] = 0.0;
			gF_PlayerRecordLocal[client][i][j] = 0.0;
		}
	}

	if(!IsClientConnected(client) || IsFakeClient(client))
	{
		return;
	}

	UpdateClientCache(client);
}

void UpdateClientCache(int client)
{	
	int iSteamID = GetSteamAccountID(client);
	
	if(iSteamID == 0)
	{
		return;
	}
	
	char sQuery[256];
	FormatEx(sQuery, 256, 
		"SELECT time, style, track FROM %splayertimes "...
		"WHERE map = '%s' AND (auth = %d OR partner = %d) "...
		"GROUP BY style, track ORDER BY time ASC;",
		gS_MySQLPrefix, gS_Map, iSteamID, iSteamID);
		
	gH_SQL.Query(SQL_UpdateCache_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_UpdateCache_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (PB cache update) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(1);
		int track = results.FetchInt(2);

		if(style >= gI_Styles || style < 0 || track >= TRACKS_SIZE)
		{
			continue;
		}

		gF_PlayerRecord[client][style][track] = results.FetchFloat(0);
	}

	gA_WRCache[client].bLoadedCache = true;
}

public int Native_UpdateLocalCache(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int iPartner = Trikz_FindPartner(client);
	
	char sQueryPartner[256];
	int iSteamID = GetSteamAccountID(client);
	int iPSteamID = GetSteamAccountID(iPartner);
	int iStyle = Shavit_GetBhopStyle(client);
	int iTrack = Shavit_GetClientTrack(client);
	
	if(iPartner != -1)
	{
		FormatEx(sQueryPartner, 256, 
			"SELECT time FROM %splayertimes "...
			"WHERE map = '%s' AND ((auth = %d AND partner = %d) OR (auth = %d AND partner = %d)) AND style = %d AND track = %d;",
			gS_MySQLPrefix, gS_Map, iSteamID, iPSteamID, iPSteamID, iSteamID, iStyle, iTrack);
			
		gH_SQL.Query(SQL_UpdateLocalCache_Callback, sQueryPartner, GetClientSerial(client), DBPrio_High);
	}
}

public int Native_UpdateLocalCacheSB(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	
	char sQuery[256];
	int iSteamID = GetSteamAccountID(client);
	int iStyle = Shavit_GetBhopStyle(client);
	int iTrack = Shavit_GetClientTrack(client);
	
	FormatEx(sQuery, 256, 
		"SELECT MIN(time) FROM %splayertimes "...
		"WHERE map = '%s' AND (auth = %d OR partner = %d) AND style = %d AND track = %d;",
		gS_MySQLPrefix, gS_Map, iSteamID, iSteamID, iStyle, iTrack);
		
	gH_SQL.Query(SQL_UpdateLocalCacheSB_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public int Native_UpdateWRCache(Handle handler, int numParams)
{
	UpdateWRCache();
}

void UpdateWRCache()
{
	char sQuery[512];
	
	if(gB_MySQL)
	{
		FormatEx(sQuery, 512,
			"SELECT p1.id, p1.style, p1.track, p1.time, u.name, p.name FROM %splayertimes p1 " ...
				"JOIN (SELECT style, track, MIN(time) time FROM %splayertimes WHERE map = '%s' GROUP BY style, track) p2 " ...
				"JOIN %susers u ON p1.style = p2.style AND p1.track = p2.track AND p1.time = p2.time AND u.auth = p1.auth " ...
				"JOIN %susers p ON p.auth = p1.partner WHERE p1.map = '%s';",
			gS_MySQLPrefix, gS_MySQLPrefix, gS_Map, gS_MySQLPrefix, gS_MySQLPrefix, gS_Map);
	}

	else
	{
		FormatEx(sQuery, 512,
			"SELECT p.id, p.style, p.track, s.time, u.name FROM %splayertimes p JOIN(SELECT style, MIN(time) time, map, track FROM %splayertimes WHERE map = '%s' GROUP BY style, track) s ON p.style = s.style AND p.time = s.time AND p.map = s.map AND s.track = p.track JOIN %susers u ON p.auth = u.auth GROUP BY p.style, p.track;",
			gS_MySQLPrefix, gS_MySQLPrefix, gS_Map, gS_MySQLPrefix);
	}

	gH_SQL.Query(SQL_UpdateWRCache_Callback, sQuery);
}

public void SQL_UpdateWRCache_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR cache update) SQL query failed. Reason: %s", error);

		return;
	}

	// reset cache
	for(int i = 0; i < gI_Styles; i++)
	{
		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			strcopy(gS_WRName[i][j], MAX_NAME_LENGTH, "invalid");
			gF_WRTime[i][j] = 0.0;
		}
	}

	// setup cache again, dynamically and not hardcoded
	while(results.FetchRow())
	{
		int iStyle = results.FetchInt(1);
		int iTrack = results.FetchInt(2);

		if(iStyle >= gI_Styles || iStyle < 0 || gA_StyleSettings[iStyle].bUnranked)
		{
			continue;
		}

		gI_WRRecordID[iStyle][iTrack] = results.FetchInt(0);
		gF_WRTime[iStyle][iTrack] = results.FetchFloat(3);
		
		if(iTrack == Track_Solobonus)
		{
			results.FetchString(4, gS_WRName[iStyle][iTrack], MAX_NAME_LENGTH);
			ReplaceString(gS_WRName[iStyle][iTrack], MAX_NAME_LENGTH, "#", "?");
		}
		
		else
		{
			char sNameFly[MAX_NAME_LENGTH];
			char sNameBooster[MAX_NAME_LENGTH];

			results.FetchString(4, sNameFly, MAX_NAME_LENGTH);
			
			if(strlen(sNameFly) > 10)
			{
				Format(sNameFly, 10, "%s", sNameFly);
				Format(sNameFly, MAX_NAME_LENGTH, "%s...", sNameFly);
			}
			
			ReplaceString(sNameFly, MAX_NAME_LENGTH, "#", "?");

			results.FetchString(5, sNameBooster, MAX_NAME_LENGTH);
			
			if(strlen(sNameBooster) > 10)
			{
				Format(sNameBooster, 10, "%s", sNameBooster);
				Format(sNameBooster, MAX_NAME_LENGTH, "%s...", sNameBooster);
			}
			
			ReplaceString(sNameBooster, MAX_NAME_LENGTH, "#", "?");
	
			FormatEx(gS_WRName[iStyle][iTrack], MAX_NAME_LENGTH * 2 + 5, "%s & %s", sNameFly, sNameBooster);
		}
	}

	UpdateLeaderboards();
}

public void SQL_UpdateLocalCache_Callback(Database db, DBResultSet results, const char[] error, any data)
{	
	if(results == null)
	{
		LogError("Timer (Record of partnership) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(data);
	
	if(client == 0)
	{
		return;
	}
	
	if(results.FetchRow())
	{
		float iTime = results.FetchFloat(0);
		int iTrack = Shavit_GetClientTrack(client);
		int iStyle = Shavit_GetBhopStyle(client);
		gF_PlayerRecordLocal[client][iStyle][iTrack] = iTime;
		
		int iPartner = Trikz_FindPartner(client);
		
		if(iPartner != -1)
		{
			gF_PlayerRecordLocal[iPartner][iStyle][iTrack] = iTime;
		}
		
		#if defined DEBUG
		PrintToChat(client, "gF_PlayerRecord: %f, gF_PlayerRecordLocal: %f", gF_PlayerRecord[client][iStyle][iTrack], gF_PlayerRecordLocal[client][iStyle][iTrack]);
		
		if(iPartner != -1)
		{
			PrintToChat(iPartner, "gF_PlayerRecord: %f, gF_PlayerRecordLocal: %f", gF_PlayerRecord[iPartner][iStyle][iTrack], gF_PlayerRecordLocal[iPartner][iStyle][iTrack]);
		}
		#endif
	}
	
	else
	{
		int iTrack = Shavit_GetClientTrack(client);
		int iStyle = Shavit_GetBhopStyle(client);
		gF_PlayerRecordLocal[client][iStyle][iTrack] = 0.0;
		
		int iPartner = Trikz_FindPartner(client);
		
		if(iPartner != -1)
		{
			gF_PlayerRecordLocal[iPartner][iStyle][iTrack] = 0.0;
		}
		
		#if defined DEBUG
		PrintToChat(client, "gF_PlayerRecord: %f, gF_PlayerRecordLocal: %f", gF_PlayerRecord[client][iStyle][iTrack], gF_PlayerRecordLocal[client][iStyle][iTrack]);
		
		if(iPartner != -1)
		{
			PrintToChat(iPartner, "gF_PlayerRecord: %f, gF_PlayerRecordLocal: %f", gF_PlayerRecord[iPartner][iStyle][iTrack], gF_PlayerRecordLocal[iPartner][iStyle][iTrack]);
		}
		#endif
	}
}

public void SQL_UpdateLocalCacheSB_Callback(Database db, DBResultSet results, const char[] error, any data)
{	
	if(results == null)
	{
		LogError("Timer (Record of solobonus) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(data);
	
	if(client == 0)
	{
		return;
	}
	
	if(results.FetchRow())
	{
		float iTime = results.FetchFloat(0);
		int iTrack = Shavit_GetClientTrack(client);
		int iStyle = Shavit_GetBhopStyle(client);
		gF_PlayerRecordLocal[client][iStyle][iTrack] = iTime;
		
		#if defined DEBUG
		PrintToChat(client, "SB gF_PlayerRecord: %f, SB gF_PlayerRecordLocal: %f", gF_PlayerRecord[client][iStyle][iTrack], gF_PlayerRecordLocal[client][iStyle][iTrack]);
		#endif
	}
	
	else
	{
		int iTrack = Shavit_GetClientTrack(client);
		int iStyle = Shavit_GetBhopStyle(client);
		gF_PlayerRecordLocal[client][iStyle][iTrack] = 0.0;
		
		#if defined DEBUG
		PrintToChat(client, "SB gF_PlayerRecord: %f, SB gF_PlayerRecordLocal: %f", gF_PlayerRecord[client][iStyle][iTrack], gF_PlayerRecordLocal[client][iStyle][iTrack]);
		#endif
	}
}

public int Native_GetWorldRecord(Handle handler, int numParams)
{
	return view_as<int>(gF_WRTime[GetNativeCell(1)][GetNativeCell(2)]);
}

public int Native_GetWRTime(Handle handler, int numParams)
{
	SetNativeCellRef(2, gF_WRTime[GetNativeCell(1)][GetNativeCell(3)]);
}

public int Native_ReloadLeaderboards(Handle handler, int numParams)
{
	UpdateLeaderboards();
	UpdateWRCache();
}

public int Native_GetWRRecordID(Handle handler, int numParams)
{
	SetNativeCellRef(2, gI_WRRecordID[GetNativeCell(1)][GetNativeCell(3)]);
}

public int Native_GetWRName(Handle handler, int numParams)
{
	SetNativeString(2, gS_WRName[GetNativeCell(1)][GetNativeCell(4)], GetNativeCell(3));
}

public int Native_GetClientPB(Handle handler, int numParams)
{
	return view_as<int>(gF_PlayerRecord[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)]);
}

public int Native_GetPlayerPB(Handle handler, int numParams)
{
	SetNativeCellRef(3, gF_PlayerRecord[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)]);
}

public int Native_GetRankForTime(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(3);

	if(gA_Leaderboard[style][track] == null || gA_Leaderboard[style][track].Length == 0)
	{
		return 1;
	}

	return GetRankForTime(style, GetNativeCell(2), track);
}

public int Native_GetRecordAmount(Handle handler, int numParams)
{
	return GetRecordAmount(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetTimeForRank(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int rank = GetNativeCell(2);
	int track = GetNativeCell(3);

	#if defined DEBUG
	Shavit_PrintToChatAll("style %d | rank %d | track %d | amount %d", style, rank, track, GetRecordAmount(style, track));
	#endif

	if(rank > GetRecordAmount(style, track))
	{
		return view_as<int>(0.0);
	}

	return view_as<int>(gA_Leaderboard[style][track].Get(rank - 1));
}

public int Native_WR_DeleteMap(Handle handler, int numParams)
{
	char sMap[160];
	GetNativeString(1, sMap, 160);

	char sQuery[256];
	FormatEx(sQuery, 256, "DELETE FROM %splayertimes WHERE map = '%s';", gS_MySQLPrefix, sMap);
	gH_SQL.Query(SQL_DeleteMap_Callback, sQuery, StrEqual(gS_Map, sMap, false), DBPrio_High);
}

public void SQL_DeleteMap_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR deletemap) SQL query failed. Reason: %s", error);

		return;
	}

	if(view_as<bool>(data))
	{
		OnMapStart();

		for(int i = 1; i <= MaxClients; i++)
		{
			OnClientPutInServer(i);
		}
	}
}

#if defined DEBUG
// debug
public Action Command_Junk(int client, int args)
{
	char sQuery[256];
	FormatEx(sQuery, 256,
		"INSERT INTO %splayertimes (auth, map, time, jumps, date, style, strafes, sync) VALUES (%d, '%s', %f, %d, %d, 0, %d, %.02f);",
		gS_MySQLPrefix, GetSteamAccountID(client), gS_Map, GetRandomFloat(10.0, 20.0), GetRandomInt(5, 15), GetTime(), GetRandomInt(5, 15), GetRandomFloat(50.0, 99.99));

	SQL_LockDatabase(gH_SQL);
	SQL_FastQuery(gH_SQL, sQuery);
	SQL_UnlockDatabase(gH_SQL);

	return Plugin_Handled;
}

public Action Command_PrintLeaderboards(int client, int args)
{
	char sArg[8];
	GetCmdArg(1, sArg, 8);

	int iStyle = StringToInt(sArg);
	int iRecords = GetRecordAmount(iStyle, Track_Main);

	ReplyToCommand(client, "Track: Main - Style: %d", iStyle);
	ReplyToCommand(client, "Current PB: %f", gF_PlayerRecord[client][iStyle][0]);
	ReplyToCommand(client, "Count: %d", iRecords);
	ReplyToCommand(client, "Rank: %d", Shavit_GetRankForTime(iStyle, gF_PlayerRecord[client][iStyle][0], iStyle));

	for(int i = 0; i < iRecords; i++)
	{
		ReplyToCommand(client, "#%d: %f", i, gA_Leaderboard[iStyle][0].Get(i));
	}

	return Plugin_Handled;
}
#endif

int GetTrackRecordCount(int track)
{
	int count = 0;

	for(int i = 0; i < gI_Styles; i++)
	{
		count += GetRecordAmount(i, track);
	}

	return count;
}

public Action Command_Delete(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(MenuHandler_Delete_First);
	menu.SetTitle("%T\n ", "DeleteTrackSingle", client);

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		if(i != Track_MainPartner && i != Track_BonusPartner)
		{
			char sInfo[8];
			IntToString(i, sInfo, 8);

			int records = GetTrackRecordCount(i);

			char sTrack[64];
			GetTrackName(client, i, sTrack, 64);

			if(records > 0)
			{
				Format(sTrack, 64, "%s (%T: %d)", sTrack, "WRRecord", client, records);
			}

			menu.AddItem(sInfo, sTrack, (records > 0)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		}
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int MenuHandler_Delete_First(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param2, info, 16);
		gA_WRCache[param1].iLastTrack = StringToInt(info);

		DeleteSubmenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void DeleteSubmenu(int client)
{
	Menu menu = new Menu(MenuHandler_Delete);
	menu.SetTitle("%T\n ", "DeleteMenuTitle", client);

	int[] styles = new int[gI_Styles];
	Shavit_GetOrderedStyles(styles, gI_Styles);

	for(int i = 0; i < gI_Styles; i++)
	{
		int iStyle = styles[i];

		if(gA_StyleSettings[iStyle].iEnabled == -1)
		{
			continue;
		}

		char sInfo[8];
		IntToString(iStyle, sInfo, 8);

		char sDisplay[64];
		FormatEx(sDisplay, 64, "%s (%T: %d)", gS_StyleStrings[iStyle].sStyleName, "WRRecord", client, GetRecordAmount(iStyle, gA_WRCache[client].iLastTrack));

		menu.AddItem(sInfo, sDisplay, (GetRecordAmount(iStyle, gA_WRCache[client].iLastTrack) > 0)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public Action Command_DeleteAll(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(MenuHandler_DeleteAll_First);
	menu.SetTitle("%T\n ", "DeleteTrackAll", client);

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		if(i != Track_MainPartner && i != Track_BonusPartner)
		{
			char sInfo[8];
			IntToString(i, sInfo, 8);

			int iRecords = GetTrackRecordCount(i);

			char sTrack[64];
			GetTrackName(client, i, sTrack, 64);

			if(iRecords > 0)
			{
				Format(sTrack, 64, "%s (%T: %d)", sTrack, "WRRecord", client, iRecords);
			}

			menu.AddItem(sInfo, sTrack, (iRecords > 0)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		}
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int MenuHandler_DeleteAll_First(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		int iTrack = gA_WRCache[param1].iLastTrack = StringToInt(sInfo);

		char sTrack[64];
		GetTrackName(param1, iTrack, sTrack, 64);

		Menu subMenu = new Menu(MenuHandler_DeleteAll_Second);
		subMenu.SetTitle("%T\n ", "DeleteTrackAllStyle", param1, sTrack);

		int[] styles = new int[gI_Styles];
		Shavit_GetOrderedStyles(styles, gI_Styles);

		for(int i = 0; i < gI_Styles; i++)
		{
			int iStyle = styles[i];

			if(gA_StyleSettings[iStyle].iEnabled == -1)
			{
				continue;
			}

			char sStyle[64];
			strcopy(sStyle, 64, gS_StyleStrings[iStyle].sStyleName);

			IntToString(iStyle, sInfo, 8);

			int iRecords = GetRecordAmount(iStyle, iTrack);

			if(iRecords > 0)
			{
				Format(sStyle, 64, "%s (%T: %d)", sStyle, "WRRecord", param1, iRecords);
			}

			subMenu.AddItem(sInfo, sStyle, (iRecords > 0)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		}

		subMenu.ExitButton = true;
		subMenu.Display(param1, MENU_TIME_FOREVER);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int MenuHandler_DeleteAll_Second(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		gA_WRCache[param1].iLastStyle = StringToInt(sInfo);

		DeleteAllSubmenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void DeleteAllSubmenu(int client)
{
	char sTrack[32];
	GetTrackName(client, gA_WRCache[client].iLastTrack, sTrack, 32);

	Menu menu = new Menu(MenuHandler_DeleteAll);
	menu.SetTitle("%T\n ", "DeleteAllRecordsMenuTitle", client, gS_Map, sTrack, gS_StyleStrings[gA_WRCache[client].iLastStyle].sStyleName);

	char sMenuItem[64];

	for(int i = 1; i <= GetRandomInt(1, 4); i++)
	{
		FormatEx(sMenuItem, 64, "%T", "MenuResponseNo", client);
		menu.AddItem("-1", sMenuItem);
	}

	FormatEx(sMenuItem, 64, "%T", "MenuResponseYes", client);
	menu.AddItem("yes", sMenuItem);

	for(int i = 1; i <= GetRandomInt(1, 3); i++)
	{
		FormatEx(sMenuItem, 64, "%T", "MenuResponseNo", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_DeleteAll(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param2, info, 16);

		if(StringToInt(info) == -1)
		{
			Shavit_PrintToChat(param1, "%T", "DeletionAborted", param1);

			return 0;
		}

		char sTrack[32];
		GetTrackName(LANG_SERVER, gA_WRCache[param1].iLastTrack, sTrack, 32);

		Shavit_LogMessage("%L - deleted all %s track and %s style records from map `%s`.",
			param1, sTrack, gS_StyleStrings[gA_WRCache[param1].iLastStyle].sStyleName, gS_Map);

		char sQuery[256];
		FormatEx(sQuery, 256, "DELETE FROM %splayertimes WHERE map = '%s' AND style = %d AND track = %d;",
			gS_MySQLPrefix, gS_Map, gA_WRCache[param1].iLastStyle, gA_WRCache[param1].iLastTrack);

		gH_SQL.Query(DeleteAll_Callback, sQuery, GetClientSerial(param1), DBPrio_High);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int MenuHandler_Delete(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param2, info, 16);
		gA_WRCache[param1].iLastStyle = StringToInt(info);

		OpenDelete(param1);

		UpdateLeaderboards();
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenDelete(int client)
{
	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT p.id, u.name, p.time, p.jumps FROM %splayertimes p JOIN %susers u ON p.auth = u.auth WHERE map = '%s' AND style = %d AND track = %d ORDER BY time ASC, date ASC LIMIT 1000;",
		gS_MySQLPrefix, gS_MySQLPrefix, gS_Map, gA_WRCache[client].iLastStyle, gA_WRCache[client].iLastTrack);

	gH_SQL.Query(SQL_OpenDelete_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_OpenDelete_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR OpenDelete) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	int iStyle = gA_WRCache[client].iLastStyle;

	Menu menu = new Menu(OpenDelete_Handler);
	menu.SetTitle("%t", "ListClientRecords", gS_Map, gS_StyleStrings[iStyle].sStyleName);

	int iCount = 0;

	while(results.FetchRow())
	{
		iCount++;

		// 0 - record id, for statistic purposes.
		int id = results.FetchInt(0);
		char sID[8];
		IntToString(id, sID, 8);

		// 1 - player name
		char sName[MAX_NAME_LENGTH];
		results.FetchString(1, sName, MAX_NAME_LENGTH);
		ReplaceString(sName, MAX_NAME_LENGTH, "#", "?");

		// 2 - time
		float time = results.FetchFloat(2);
		char sTime[16];
		FormatSeconds(time, sTime, 16);

		// 3 - jumps
		int jumps = results.FetchInt(3);

		char sDisplay[128];
		FormatEx(sDisplay, 128, "#%d - %s - %s (%d jump%s)", iCount, sName, sTime, jumps, (jumps != 1)? "s":"");
		menu.AddItem(sID, sDisplay);
	}

	if(iCount == 0)
	{
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%T", "WRMapNoRecords", client);
		menu.AddItem("-1", sNoRecords);
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenDelete_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		int id = StringToInt(sInfo);

		if(id != -1)
		{
			OpenDeleteMenu(param1, id);
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenDeleteMenu(int client, int id)
{
	char sMenuItem[64];

	Menu menu = new Menu(DeleteConfirm_Handler);
	menu.SetTitle("%T\n ", "DeleteConfirm", client);

	for(int i = 1; i <= GetRandomInt(1, 4); i++)
	{
		FormatEx(sMenuItem, 64, "%T", "MenuResponseNo", client);
		menu.AddItem("-1", sMenuItem);
	}

	FormatEx(sMenuItem, 64, "%T", "MenuResponseYesSingle", client);

	char sInfo[16];
	IntToString(id, sInfo, 16);
	menu.AddItem(sInfo, sMenuItem);

	for(int i = 1; i <= GetRandomInt(1, 3); i++)
	{
		FormatEx(sMenuItem, 64, "%T", "MenuResponseNo", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int DeleteConfirm_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		int iRecordID = StringToInt(sInfo);

		if(iRecordID == -1)
		{
			Shavit_PrintToChat(param1, "%T", "DeletionAborted", param1);

			return 0;
		}

		char sQuery[256];
		FormatEx(sQuery, 256, "SELECT u.auth, u.name, p.map, p.time, p.sync, p.perfs, p.jumps, p.strafes, p.id, p.date FROM %susers u LEFT JOIN %splayertimes p ON u.auth = p.auth WHERE p.id = %d;",
			gS_MySQLPrefix, gS_MySQLPrefix, iRecordID);

		gH_SQL.Query(GetRecordDetails_Callback, sQuery, GetClientSerial(param1), DBPrio_High);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void GetRecordDetails_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR GetRecordDetails) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	if(results.FetchRow())
	{
		int iSteamID = results.FetchInt(0);

		char sName[MAX_NAME_LENGTH];
		results.FetchString(1, sName, MAX_NAME_LENGTH);

		char sMap[160];
		results.FetchString(2, sMap, 160);

		float fTime = results.FetchFloat(3);
		float fSync = results.FetchFloat(4);
		float fPerfectJumps = results.FetchFloat(5);

		int iJumps = results.FetchInt(6);
		int iStrafes = results.FetchInt(7);
		int iRecordID = results.FetchInt(8);
		int iTimestamp = results.FetchInt(9);
		
		int iStyle = gA_WRCache[client].iLastStyle;
		int iTrack = gA_WRCache[client].iLastTrack;
		bool bWRDeleted = (gI_WRRecordID[iStyle][iTrack] == iRecordID);

		// that's a big datapack ya yeet
		DataPack hPack = new DataPack();
		hPack.WriteCell(GetClientSerial(client));
		hPack.WriteCell(iSteamID);
		hPack.WriteString(sName);
		hPack.WriteString(sMap);
		hPack.WriteCell(fTime);
		hPack.WriteCell(fSync);
		hPack.WriteCell(fPerfectJumps);
		hPack.WriteCell(iJumps);
		hPack.WriteCell(iStrafes);
		hPack.WriteCell(iRecordID);
		hPack.WriteCell(iTimestamp);
		hPack.WriteCell(iStyle);
		hPack.WriteCell(iTrack);
		hPack.WriteCell(bWRDeleted);

		char sQuery[256];
		FormatEx(sQuery, 256, "DELETE FROM %splayertimes WHERE id = %d;",
			gS_MySQLPrefix, iRecordID);

		gH_SQL.Query(DeleteConfirm_Callback, sQuery, hPack, DBPrio_High);
	}
}

public void DeleteConfirm_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack hPack = view_as<DataPack>(data);
	hPack.Reset();

	int iSerial = hPack.ReadCell();
	int iSteamID = hPack.ReadCell();

	char sName[MAX_NAME_LENGTH];
	hPack.ReadString(sName, MAX_NAME_LENGTH);

	char sMap[160];
	hPack.ReadString(sMap, 160);

	float fTime = view_as<float>(hPack.ReadCell());
	float fSync = view_as<float>(hPack.ReadCell());
	float fPerfectJumps = view_as<float>(hPack.ReadCell());

	int iJumps = hPack.ReadCell();
	int iStrafes = hPack.ReadCell();
	int iRecordID = hPack.ReadCell();
	int iTimestamp = hPack.ReadCell();
	int iStyle = hPack.ReadCell();
	int iTrack = hPack.ReadCell();

	bool bWRDeleted = view_as<bool>(hPack.ReadCell());
	delete hPack;

	if(results == null)
	{
		LogError("Timer (WR DeleteConfirm) SQL query failed. Reason: %s", error);

		return;
	}

	if(bWRDeleted)
	{
		Call_StartForward(gH_OnWRDeleted);
		Call_PushCell(iStyle);
		Call_PushCell(iRecordID);
		Call_PushCell(iTrack);
		Call_Finish();
	}

	UpdateWRCache();

	for(int i = 1; i <= MaxClients; i++)
	{
		OnClientPutInServer(i);
	}

	int client = GetClientFromSerial(iSerial);

	char sTrack[32];
	GetTrackName(LANG_SERVER, iTrack, sTrack, 32);

	char sDate[32];
	FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", iTimestamp);

	// above the client == 0 so log doesn't get lost if admin disconnects between deleting record and query execution
	Shavit_LogMessage("%L - deleted record. Runner: %s ([U:1:%d]) | Map: %s | Style: %s | Track: %s | Time: %.2f (%s) | Strafes: %d (%.1f%%) | Jumps: %d (%.1f%%) | Run date: %s | Record ID: %d",
		client, sName, iSteamID, sMap, gS_StyleStrings[iStyle].sStyleName, sTrack, fTime, (bWRDeleted)? "WR":"not WR", iStrafes, fSync, iJumps, fPerfectJumps, sDate, iRecordID);

	if(client == 0)
	{
		return;
	}

	Shavit_PrintToChat(client, "%T", "DeletedRecord", client);
}

public void DeleteAll_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR DeleteAll) SQL query failed. Reason: %s", error);

		return;
	}

	UpdateWRCache();

	for(int i = 1; i <= MaxClients; i++)
	{
		OnClientPutInServer(i);
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	Call_StartForward(gH_OnWRDeleted);
	Call_PushCell(gA_WRCache[client].iLastStyle);
	Call_PushCell(-1);
	Call_PushCell(gA_WRCache[client].iLastTrack);
	Call_Finish();

	Shavit_PrintToChat(client, "%T", "DeletedRecordsMap", client, gS_ChatStrings.sVariable, gS_Map, gS_ChatStrings.sText);
}

public Action Command_WorldRecord(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(args == 0)
	{
		strcopy(gA_WRCache[client].sClientMap, 128, gS_Map);
	}

	else
	{
		GetCmdArgString(gA_WRCache[client].sClientMap, 128);
		GuessBestMapName(gA_WRCache[client].sClientMap, gA_WRCache[client].sClientMap, 128);
	}
	
	ShowWRTrackMenu(client);
	
	gB_WorldRecord[client] = true;
	gB_RecentRecords[client] = false;

	return Plugin_Handled;
}

void ShowWRTrackMenu(int client)
{
	Menu menu = new Menu(MenuHandler_TrackChooser);
	menu.SetTitle("%T", "WRMenuTrackTitle", client);
	
	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		if(i == Track_MainPartner || i == Track_BonusPartner)
		{
			continue;
		}
		
		char sInfo[8];
		IntToString(i, sInfo, 8);
		
		char sTrack[32];
		GetTrackName(client, i, sTrack, 32);
		
		menu.AddItem(sInfo, sTrack);
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TrackChooser(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(!IsValidClient(param1))
		{
			return 0;
		}
		
		switch(param2)
		{
			case 0:
			{
				ShowWRStyleMenu(param1, Track_Main);
			}
			
			case 1:
			{
				ShowWRStyleMenu(param1, Track_Bonus);
			}
			
			case 2:
			{
				ShowWRStyleMenu(param1, Track_Solobonus);
			}
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

Action ShowWRStyleMenu(int client, int track)
{
	gA_WRCache[client].iLastTrack = track;

	Menu menu = new Menu(MenuHandler_StyleChooser);
	menu.SetTitle("%T", "WRMenuTitle", client);

	int[] styles = new int[gI_Styles];
	Shavit_GetOrderedStyles(styles, gI_Styles);

	for(int i = 0; i < gI_Styles; i++)
	{
		int iStyle = styles[i];

		if(gA_StyleSettings[iStyle].bUnranked || gA_StyleSettings[iStyle].iEnabled == -1)
		{
			continue;
		}

		char sInfo[8];
		IntToString(iStyle, sInfo, 8);

		char sDisplay[64];

		if(StrEqual(gA_WRCache[client].sClientMap, gS_Map) && gF_WRTime[iStyle][track] > 0.0)
		{
			char sTime[32];
			FormatSeconds(gF_WRTime[iStyle][track], sTime, 32, false);

			FormatEx(sDisplay, 64, "%s - WR: %s", gS_StyleStrings[iStyle].sStyleName, sTime);
		}

		else
		{
			strcopy(sDisplay, 64, gS_StyleStrings[iStyle].sStyleName);
		}

		menu.AddItem(sInfo, sDisplay, (GetRecordAmount(iStyle, track) > 0 || !StrEqual(gA_WRCache[client].sClientMap, gS_Map))? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	}

	// should NEVER happen
	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "WRStyleNothing", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int MenuHandler_StyleChooser(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(!IsValidClient(param1))
		{
			return 0;
		}

		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);

		int iStyle = StringToInt(sInfo);

		if(iStyle == -1)
		{
			Shavit_PrintToChat(param1, "%T", "NoStyles", param1, gS_ChatStrings.sWarning, gS_ChatStrings.sText);

			return 0;
		}

		gA_WRCache[param1].iLastStyle = iStyle;

		StartWRMenu(param1, gA_WRCache[param1].sClientMap, iStyle, gA_WRCache[param1].iLastTrack);
	}
	
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowWRTrackMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void StartWRMenu(int client, const char[] map, int style, int track)
{
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(track);
	dp.WriteString(map);

	int iLength = ((strlen(map) * 2) + 1);
	char[] sEscapedMap = new char[iLength];
	gH_SQL.Escape(map, sEscapedMap, iLength);

	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT p.id, u.name, p.time, p.jumps, p.auth, u2.name, p.partner "...
		"FROM %splayertimes p "...
		
		"JOIN %susers u "...
		"ON p.auth = u.auth "...
		
		"JOIN %susers u2 "...
		"ON p.partner = u2.auth "...
		
		"WHERE map = '%s' AND style = %d AND track = %d "...
		"ORDER BY time ASC, date ASC "...
		"LIMIT 100;", gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix, sEscapedMap, style, track);
	
	gH_SQL.Query(SQL_WR_Callback, sQuery, dp);
}

public void SQL_WR_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int serial = data.ReadCell();
	int track = data.ReadCell();

	char sMap[192];
	data.ReadString(sMap, 192);

	delete data;

	if(results == null)
	{
		LogError("Timer (WR SELECT) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(serial);

	if(client == 0)
	{
		return;
	}

	int iSteamID = GetSteamAccountID(client);

	Menu hMenu = new Menu(WRMenu_Handler);

	int iCount = 0;
	int iMyRank = 0;
	bool bBreakIfFoundFirstRecord = true;
	
	while(results.FetchRow())
	{
		if(++iCount <= gCV_RecordsLimit.IntValue)
		{
			// 0 - record id, for statistic purposes.
			int id = results.FetchInt(0);
			char sID[8];
			IntToString(id, sID, 8);

			// 1 - player name
			char sName[MAX_NAME_LENGTH];
			results.FetchString(1, sName, MAX_NAME_LENGTH);
			
			if(strlen(sName) > 10)
			{
				Format(sName, 10, "%s", sName);
				Format(sName, MAX_NAME_LENGTH, "%s...", sName);
			}

			// 2 - time
			float time = results.FetchFloat(2);
			char sTime[16];
			FormatSeconds(time, sTime, 16);

			// 3 - jumps
			int jumps = results.FetchInt(3);

			char sDisplay[128];
			
			if(track == Track_Solobonus)
			{
				FormatEx(sDisplay, 128, "#%d - %s - %s (%d %T)", iCount, sName, sTime, jumps, "WRJumps", client);
			}
			
			else
			{
				char sPName[MAX_NAME_LENGTH];
				results.FetchString(5, sPName, MAX_NAME_LENGTH);
				
				if(strlen(sPName) > 10)
				{
					Format(sPName, 10, "%s", sPName);
					Format(sPName, MAX_NAME_LENGTH, "%s...", sPName);
				}
				
				FormatEx(sDisplay, 128, "#%d - %s - %s & %s", iCount, sTime, sName, sPName, client);
			}
			
			hMenu.AddItem(sID, sDisplay);
		}

		// check if record exists in the map's top X
		int iQuerySteamID = results.FetchInt(4);
		int iQueryPSteamID = results.FetchInt(6);
		
		if(iQuerySteamID == iSteamID || iQueryPSteamID == iSteamID)
		{
			if(bBreakIfFoundFirstRecord)
			{
				iMyRank = iCount;
				bBreakIfFoundFirstRecord = false;
			}
		}
	}

	char sFormattedTitle[512];

	if(hMenu.ItemCount == 0)
	{
		hMenu.SetTitle("%T", "WRMap", client, sMap);
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%T", "WRMapNoRecords", client);

		hMenu.AddItem("-1", sNoRecords);
	}
	
	else
	{
		int iStyle = gA_WRCache[client].iLastStyle;
		int iRecords = results.RowCount;

		// [32] just in case there are 150k records on a map and you're ranked 100k or something
		char sRanks[32];

		if(gF_PlayerRecord[client][iStyle][track] == 0.0 || iMyRank == 0)
		{
			FormatEx(sRanks, 32, "(%d %T)", iRecords, "WRRecord", client);
		}

		else
		{
			FormatEx(sRanks, 32, "(#%d/%d)", iMyRank, iRecords);
		}

		char sTrack[32];
		GetTrackName(client, track, sTrack, 32);
		
		if(track == 2)
		{
			sTrack = "B";
		}
		
		if(track == 4)
		{
			sTrack = "SB";
		}
		
		char sStyle[8];
		
		if(gA_WRCache[client].iLastStyle == 1)
		{
			sStyle = "SW";
		}
		
		if(gA_WRCache[client].iLastStyle == 2)
		{
			sStyle = "W";
		}
		
		if(gA_WRCache[client].iLastStyle == 3)
		{
			sStyle = "HSW";
		}
		
		if(track == 0 && gA_WRCache[client].iLastStyle != 0)
		{
			FormatEx(sFormattedTitle, 512, "%T %s: [%s]\n%s", "WRRecordFor", client, sMap, sStyle, sRanks);
		}
		
		if(track != 0 && gA_WRCache[client].iLastStyle == 0)
		{
			FormatEx(sFormattedTitle, 512, "%T %s: [%s]\n%s", "WRRecordFor", client, sMap, sTrack, sRanks);
		}
		
		if(track != 0 && gA_WRCache[client].iLastStyle != 0)
		{
			FormatEx(sFormattedTitle, 512, "%T %s: [%s|%s]\n%s", "WRRecordFor", client, sMap, sTrack, sStyle, sRanks);
		}
		
		if(track == 0 && gA_WRCache[client].iLastStyle == 0)
		{
			FormatEx(sFormattedTitle, 512, "%T %s\n%s", "WRRecordFor", client, sMap, sRanks);
		}
		
		hMenu.SetTitle(sFormattedTitle);
	}

	hMenu.ExitBackButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int WRMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);
		int id = StringToInt(sInfo);

		if(id != -1)
		{
			OpenSubMenu(param1, id);
		}

		else
		{
			ShowWRStyleMenu(param1, gA_WRCache[param1].iLastTrack);
		}
	}

	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowWRStyleMenu(param1, gA_WRCache[param1].iLastTrack);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Command_RecentRecords(int client, int args)
{
	if(gA_WRCache[client].bPendingMenu || !IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sQuery[512];

	FormatEx(sQuery, 512,
			"SELECT a.id, a.map, u.name, a.time, a.style, a.track, u1.name FROM %splayertimes a " ...
			"JOIN (SELECT MIN(time) time, map, style, track FROM %splayertimes GROUP by map, style, track) b " ...
			"JOIN %susers u1 ON a.partner = u1.auth " ...
			"JOIN %susers u ON a.time = b.time AND a.auth = u.auth AND a.map = b.map AND a.style = b.style AND a.track = b.track " ...
			"ORDER BY a.date DESC " ...
			"LIMIT 100;",
			gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix);

	gH_SQL.Query(SQL_RR_Callback, sQuery, GetClientSerial(client), DBPrio_Low);

	gA_WRCache[client].bPendingMenu = true;
	
	gB_WorldRecord[client] = false;
	gB_RecentRecords[client] = true;

	return Plugin_Handled;
}

public void SQL_RR_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);

	gA_WRCache[client].bPendingMenu = false;

	if(results == null)
	{
		LogError("Timer (RR SELECT) SQL query failed. Reason: %s", error);

		return;
	}

	if(client == 0)
	{
		return;
	}

	Menu menu = new Menu(RRMenu_Handler);
	menu.SetTitle("%T:", "RecentRecords", client, gCV_RecentLimit.IntValue);

	while(results.FetchRow())
	{
		char sMap[192];
		results.FetchString(1, sMap, 192);
		
		char sName[MAX_NAME_LENGTH];
		results.FetchString(2, sName, MAX_NAME_LENGTH);
		
		if(strlen(sName) > 10)
		{
			Format(sName, 10, "%s", sName);
			Format(sName, MAX_NAME_LENGTH, "%s...", sName);
		}

		char sTime[16];
		float fTime = results.FetchFloat(3);
		FormatSeconds(fTime, sTime, 16);

		int iStyle = results.FetchInt(4);
		int iTrack = results.FetchInt(5);

		if(iStyle >= gI_Styles || iStyle < 0 || gA_StyleSettings[iStyle].bUnranked)
		{
			continue;
		}

		char sTrack[32];
		GetTrackName(client, results.FetchInt(5), sTrack, 32);

		char sDisplay[192];
		
		if(iTrack == Track_Solobonus)
		{
			FormatEx(sDisplay, 192, "[%s/%c] %s - %s @ %s", gS_StyleStrings[iStyle].sShortName, sTrack[0], sMap, sName, sTime);
		}
		
		else
		{
			char sPName[MAX_NAME_LENGTH];
			results.FetchString(6, sPName, MAX_NAME_LENGTH);
			
			if(strlen(sPName) > 10)
			{
				Format(sPName, 10, "%s", sPName);
				Format(sPName, MAX_NAME_LENGTH, "%s...", sPName);
			}
			
			FormatEx(sDisplay, 192, "[%s/%c] %s %s - %s & %s", gS_StyleStrings[iStyle].sShortName, sTrack[0], sMap, sTime, sName, sPName);
		}

		char sInfo[192];
		FormatEx(sInfo, 192, "%d;%s", results.FetchInt(0), sMap);

		menu.AddItem(sInfo, sDisplay);
	}

	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "WRMapNoRecords", client);
		menu.AddItem("-1", sMenuItem);
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int RRMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[128];
		menu.GetItem(param2, sInfo, 128);

		if(StringToInt(sInfo) != -1)
		{
			char sExploded[2][128];
			ExplodeString(sInfo, ";", sExploded, 2, 128, true);

			strcopy(gA_WRCache[param1].sClientMap, 128, sExploded[1]);
			
			OpenSubMenu(param1, StringToInt(sExploded[0]));
		}

		else
		{
			ShowWRStyleMenu(param1, gA_WRCache[param1].iLastTrack);
		}
	}

	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowWRStyleMenu(param1, gA_WRCache[param1].iLastTrack);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenSubMenu(int client, int id)
{
	gI_id[client] = id;
	
	char sQuery[512];
	FormatEx(sQuery, 512,
		"SELECT u.name, p.time, p.jumps, p.style, u.auth, p.date, p.map, p.strafes, p.sync, p.perfs, p.points, p.track, p.completions, u1.name, p.partner, p.nades FROM %splayertimes p JOIN %susers u ON p.auth = u.auth JOIN %susers u1 ON p.partner = u1.auth WHERE p.id = %d LIMIT 1;",
		gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix, id);
	
	gH_SQL.Query(SQL_SubMenuForRank_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_SubMenuForRank_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR SubMenuForRank) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(data);
	
	if(client == 0)
	{
		return;
	}
	
	if(results.FetchRow())
	{
		gA_WRCache[client].iLastStyle = results.FetchInt(3);
		g_iSteamID[client] = results.FetchInt(4);
		gA_WRCache[client].iLastTrack = results.FetchInt(11);
		g_iPSteamID[client] = results.FetchInt(14);
		
		char sQuery[512];
		FormatEx(sQuery, 512,
			"SELECT * FROM ("...
			"SELECT a.map, a.time, a.id, COUNT(b.map) + 1 rank, a.points "...
			"FROM %splayertimes a LEFT JOIN %splayertimes b ON a.time > b.time AND a.map = b.map "...
			"AND a.style = b.style AND a.track = b.track "...
			"WHERE (a.auth = %d AND a.partner = %d) AND a.style = %d AND a.track = %d AND a.map = '%s' "...
			"GROUP BY a.time, a.id "...
			"ORDER BY a.%s "...
			") t "...
			"GROUP BY map ORDER BY points;",
			gS_MySQLPrefix, gS_MySQLPrefix, g_iSteamID[client], g_iPSteamID[client], gA_WRCache[client].iLastStyle, gA_WRCache[client].iLastTrack, gA_WRCache[client].sClientMap, (gB_Rankings)? "points DESC":"map");
		
		gH_SQL.Query(PositionInRank_Callback, sQuery, GetClientSerial(client), DBPrio_High);
	}
}

public void PositionInRank_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR PositionInRank) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(data);
	
	if(client == 0)
	{
		return;
	}
	
	if(results.FetchRow())
	{
		g_iRank[client] = results.FetchInt(3);
		
		char sQuery[512];
		FormatEx(sQuery, 512,
			"SELECT * FROM playertimes "...
			"WHERE style = %d AND track = %d AND map = '%s'",
			gA_WRCache[client].iLastStyle, gA_WRCache[client].iLastTrack, gA_WRCache[client].sClientMap);
		
		gH_SQL.Query(AllRecords_Callback, sQuery, GetClientSerial(client), DBPrio_High);
	}
}

public void AllRecords_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR AllRecords) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(data);
	
	if(client == 0)
	{
		return;
	}
	
	g_iRecords[client] = results.RowCount;
	
	char sQuery[512];
	FormatEx(sQuery, 512,
		"SELECT u.name, p.time, p.jumps, p.style, u.auth, p.date, p.map, p.strafes, p.sync, p.perfs, p.points, p.track, p.completions, u1.name, p.partner, p.nades, p.firstdate FROM %splayertimes p JOIN %susers u ON p.auth = u.auth JOIN %susers u1 ON p.partner = u1.auth WHERE p.id = %d LIMIT 1;",
		gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix, gI_id[client]);
	
	gH_SQL.Query(SQL_SubMenu_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_SubMenu_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);

	if(results == null)
	{
		LogError("Timer (WR SUBMENU) SQL query failed. Reason: %s", error);

		return;
	}

	if(client == 0)
	{
		return;
	}

	Menu hMenu = new Menu(SubMenu_Handler);

	char sFormattedTitle[512];
	int iSteamID = 0;
	char sName[MAX_NAME_LENGTH];
	char sPName[MAX_NAME_LENGTH];
	int iPSteamID = 0;
	char sMap[192];
	int iTrack = -1;
	char sTrack[32];
	
	if(results.FetchRow())
	{
		iTrack = results.FetchInt(11);
		iSteamID = results.FetchInt(4);
		results.FetchString(0, sName, MAX_NAME_LENGTH);
		results.FetchString(13, sPName, MAX_NAME_LENGTH);
		iPSteamID = results.FetchInt(14);
		results.FetchString(6, sMap, 192);
		
		char sMenuItem[64];
		char sInfo[32];
		
		if(iTrack == Track_Solobonus)
		{
			FormatEx(sMenuItem, 64, "%T\n ", "WRPlayerStats", client);
			FormatEx(sInfo, 32, "0;%d", iSteamID);
			
			if(gB_Stats)
			{
				hMenu.AddItem(sInfo, sMenuItem);
			}
		}
		
		else
		{
			FormatEx(sMenuItem, 64, "%T", "WRTrikzStats", client, sName);
			FormatEx(sInfo, 32, "0;%d", iSteamID);
			
			if(gB_Stats)
			{
				hMenu.AddItem(sInfo, sMenuItem);
			}
			
			FormatEx(sMenuItem, 64, "%T\n ", "WRTrikzStats", client, sPName);
			FormatEx(sInfo, 32, "0;%d", iPSteamID);
			
			if(gB_Stats)
			{
				hMenu.AddItem(sInfo, sMenuItem);
			}
		}	

		if(CheckCommandAccess(client, "sm_delete", ADMFLAG_RCON))
		{
			FormatEx(sMenuItem, 64, "%T\n ", "WRDeleteRecord", client);
			FormatEx(sInfo, 32, "1;%d", gI_id[client]);
			hMenu.AddItem(sInfo, sMenuItem);
		}
		
		FormatEx(sInfo, 32, "2;%d", client);
		hMenu.AddItem(sInfo, "Back");
		
		GetTrackName(client, iTrack, sTrack, 32);
	}
	
	else
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "DatabaseError", client);
		hMenu.AddItem("-1", sMenuItem);
	}

	if(iTrack == Track_Solobonus)
	{
		if(strlen(sName) > 0)
		{
			char sFirstDate[32];
			results.FetchString(16, sFirstDate, 32);
			
			if(sFirstDate[4] != '-')
			{
				FormatTime(sFirstDate, 32, "%Y-%m-%d %H:%M:%S", StringToInt(sFirstDate));
			}
			
			char sDisplayFirstDate[128];
			FormatEx(sDisplayFirstDate, 128, "First %T: %s", "WRDate", client, sFirstDate);
			
			char sDate[32];
			results.FetchString(5, sDate, 32);
			
			if(sDate[4] != '-')
			{
				FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", StringToInt(sDate));
			}
			
			char sDisplayDate[128];
			FormatEx(sDisplayDate, 128, "Last %T: %s", "WRDate", client, sDate);
			
			char sRanks[16];
			FormatEx(sRanks, 16, "Rank: #%d/%d", g_iRank[client], g_iRecords[client]);
			
			float fPoints = results.FetchFloat(10);
			char sDisplayPoints[128];
			
			if(gB_Rankings && fPoints > 0.0)
			{
				FormatEx(sDisplayPoints, 128, "%T: %.03f", "WRPointsCap", client, fPoints);
			}
			
			float fTime = results.FetchFloat(1);
			char sTime[16];
			FormatSeconds(fTime, sTime, 16);
			char sDisplayTime[128];
			FormatEx(sDisplayTime, 128, "%T: %s", "WRTime", client, sTime);
			
			char sDisplayCompletions[128];
			FormatEx(sDisplayCompletions, 128, "%T: %d", "WRCompletions", client, results.FetchInt(12));
			
			char sDisplayStyle[128];
			int iStyle = results.FetchInt(3);
			FormatEx(sDisplayStyle, 128, "%T: %s", "WRStyle", client, gS_StyleStrings[iStyle].sStyleName);
			
			char sDisplayJumps[128];
			int iJumps = results.FetchInt(2);
			float fPerfs = results.FetchFloat(9);
			
			if(gA_StyleSettings[iStyle].bAutobhop)
			{
				FormatEx(sDisplayJumps, 128, "%T: %d", "WRJumps", client, iJumps);
			}

			else
			{
				FormatEx(sDisplayJumps, 128, "%T: %d (%.2f%%%%)", "WRJumps", client, iJumps, fPerfs);
			}
			
			char sDisplayStrafes[128];
			int strafes = results.FetchInt(7);
			float sync = results.FetchFloat(8);
			FormatEx(sDisplayStrafes, 128, (sync != -1.0)? "%T: %d (%.02f%%%%)":"%T: %d", "WRStrafes", client, strafes, sync);
			
			FormatEx(sFormattedTitle, 512, "%s [U:1:%d]\n--- %s: [%s]\n \n%s\n%s\n \n%s\n%s\n \n%s\n%s\n \n%s\n \n%s\n%s\n ", sName, iSteamID, sMap, sTrack, sDisplayFirstDate, sDisplayDate, sRanks, sDisplayPoints, sDisplayTime, sDisplayCompletions, sDisplayStyle, sDisplayJumps, sDisplayStrafes);
		}
		
		else
		{
			FormatEx(sFormattedTitle, 512, "%T", "Error", client);
		}
	}
	
	else
	{
		if(strlen(sName) > 0 && strlen(sPName) > 0)
		{
			char sFirstDate[32];
			results.FetchString(16, sFirstDate, 32);
			
			if(sFirstDate[4] != '-')
			{
				FormatTime(sFirstDate, 32, "%Y-%m-%d %H:%M:%S", StringToInt(sFirstDate));
			}
			
			char sDisplayFirstDate[128];
			FormatEx(sDisplayFirstDate, 128, "First %T: %s", "WRDate", client, sFirstDate);
			
			char sDate[32];
			results.FetchString(5, sDate, 32);
			
			if(sDate[4] != '-')
			{
				FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", StringToInt(sDate));
			}
			
			char sDisplayDate[128];
			FormatEx(sDisplayDate, 128, "Last %T: %s", "WRDate", client, sDate);
			
			char sRanks[16];
			FormatEx(sRanks, 16, "Rank: #%d/%d", g_iRank[client], g_iRecords[client]);
			
			float fPoints = results.FetchFloat(10);
			char sDisplayPoints[128];
			
			if(gB_Rankings && fPoints > 0.0)
			{
				FormatEx(sDisplayPoints, 128, "%T: %.03f", "WRPointsCap", client, fPoints);
			}
			
			float fTime = results.FetchFloat(1);
			char sTime[16];
			FormatSeconds(fTime, sTime, 16);
			char sDisplayTime[128];
			FormatEx(sDisplayTime, 128, "%T: %s", "WRTime", client, sTime);
			
			char sDisplayCompletions[128];
			FormatEx(sDisplayCompletions, 128, "%T: %d", "WRCompletions", client, results.FetchInt(12));
			
			char sDisplayStyle[128];
			int iStyle = results.FetchInt(3);
			FormatEx(sDisplayStyle, 128, "%T: %s", "WRStyle", client, gS_StyleStrings[iStyle].sStyleName);
			
			char sDisplayJumps[128];
			int iJumps = results.FetchInt(2);
			float fPerfs = results.FetchFloat(9);
			
			if(gA_StyleSettings[iStyle].bAutobhop)
			{
				FormatEx(sDisplayJumps, 128, "%T: %d", "WRJumps", client, iJumps);
			}

			else
			{
				FormatEx(sDisplayJumps, 128, "%T: %d (%.2f%%%%)", "WRJumps", client, iJumps, fPerfs);
			}
			
			char sDisplayStrafes[128];
			int strafes = results.FetchInt(7);
			float sync = results.FetchFloat(8);
			FormatEx(sDisplayStrafes, 128, (sync != -1.0)? "%T: %d (%.02f%%%%)":"%T: %d", "WRStrafes", client, strafes, sync);
			
			char sDisplayNades[128];
			int iNades = results.FetchInt(15);
			FormatEx(sDisplayNades, 128, "%T: %d", "WRNades", client, iNades);
			
			FormatEx(sFormattedTitle, 512, "%s & %s\n[U:1:%d] [U:1:%d]\n--- %s: [%s]\n \n%s\n%s\n \n%s\n%s\n \n%s\n%s\n \n%s\n \n%s\n%s\n%s\n ", sName, sPName, iSteamID, iPSteamID, sMap, sTrack, sDisplayFirstDate, sDisplayDate, sRanks, sDisplayPoints, sDisplayTime, sDisplayCompletions, sDisplayStyle, sDisplayJumps, sDisplayStrafes, sDisplayNades);
		}
		
		else
		{
			FormatEx(sFormattedTitle, 512, "%T", "Error", client);
		}
	}

	hMenu.SetTitle(sFormattedTitle);
	hMenu.Pagination = MENU_NO_PAGINATION;
	hMenu.ExitButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int SubMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, 32);

		if(gB_Stats && StringToInt(sInfo) != -1)
		{
			char sExploded[2][32];
			ExplodeString(sInfo, ";", sExploded, 2, 32, true);

			int first = StringToInt(sExploded[0]);

			switch(first)
			{
				case 0:
				{
					Shavit_OpenStatsMenu(param1, StringToInt(sExploded[1]));
				}

				case 1:
				{
					OpenDeleteMenu(param1, StringToInt(sExploded[1]));
				}
				
				case 2:
				{
					
					if(gB_WorldRecord[param1])
					{
						StartWRMenu(param1, gA_WRCache[param1].sClientMap, gA_WRCache[param1].iLastStyle, gA_WRCache[param1].iLastTrack);
					}
					
					if(gB_RecentRecords[param1])
					{
						FakeClientCommand(param1, "sm_recentrecords");
					}
				}
			}
		}

		else
		{
			if(gB_WorldRecord[param1])
			{
				StartWRMenu(param1, gA_WRCache[param1].sClientMap, gA_WRCache[param1].iLastStyle, gA_WRCache[param1].iLastTrack);
			}
			
			if(gB_RecentRecords[param1])
			{
				FakeClientCommand(param1, "sm_recentrecords");
			}
		}
	}

	if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle();
	gB_MySQL = IsMySQLDatabase(gH_SQL);

	char sQuery[1024];

	if(gB_MySQL)
	{
		FormatEx(sQuery, 1024,
			"CREATE TABLE IF NOT EXISTS `%splayertimes` (`id` INT NOT NULL AUTO_INCREMENT, `auth` INT, `partner` INT, `map` VARCHAR(128), `time` FLOAT, `jumps` INT, `style` TINYINT, `firstdate` INT, `date` INT, `strafes` INT, `nades` INT, `sync` FLOAT, `points` FLOAT NOT NULL DEFAULT 0, `track` TINYINT NOT NULL DEFAULT 0, `perfs` FLOAT DEFAULT 0, `completions` SMALLINT DEFAULT 0, PRIMARY KEY (`id`), INDEX `auth` (`auth`, `date`, `points`), INDEX `partner` (`partner`), INDEX `map` (`map`, `style`, `track`, `time`), INDEX `time` (`time`), CONSTRAINT `%spt_auth` FOREIGN KEY (`auth`) REFERENCES `%susers` (`auth`) ON UPDATE CASCADE ON DELETE CASCADE) ENGINE=INNODB;",
			gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix);
	}

	else
	{
		FormatEx(sQuery, 1024,
			"CREATE TABLE IF NOT EXISTS `%splayertimes` (`id` INTEGER PRIMARY KEY, `auth` INT, `partner` INT, `map` VARCHAR(128), `time` FLOAT, `jumps` INT, `style` TINYINT, `firstdate` INT, `date` INT, `strafes` INT, `nades` INT, `sync` FLOAT, `points` FLOAT NOT NULL DEFAULT 0, `track` TINYINT NOT NULL DEFAULT 0, `perfs` FLOAT DEFAULT 0, `completions` SMALLINT DEFAULT 0, CONSTRAINT `%spt_auth` FOREIGN KEY (`auth`) REFERENCES `%susers` (`auth`) ON UPDATE CASCADE ON DELETE CASCADE);",
			gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix);
	}

	gH_SQL.Query(SQL_CreateTable_Callback, sQuery);
}

public void SQL_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR module) error! Users' times table creation failed. Reason: %s", error);

		return;
	}

	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			OnClientPutInServer(i);
		}

		gB_Late = false;
	}

	gB_Connected = true;
	
	OnMapStart();
}

public void Shavit_OnFinish(int client, int style, float time, int jumps, int strafes, int nades, float sync, int track, float oldtime, float perfs)
{	
	// do not risk overwriting the player's data if their PB isn't loaded to cache yet
	if(!gA_WRCache[client].bLoadedCache)
	{
		return;
	}

	char sTime[32];
	FormatSeconds(time, sTime, 32);

	char sTrack[32];
	GetTrackName(LANG_SERVER, track, sTrack, 32);

	// 0 - no query
	// 1 - insert
	// 2 - update
	bool bIncrementCompletions = true;
	int iOverwrite = 0;
	
	if(gA_StyleSettings[style].bUnranked || Shavit_IsPracticeMode(client))
	{
		iOverwrite = 0; // ugly way of not writing to database
		bIncrementCompletions = false;
	}

	else if(gF_PlayerRecordLocal[client][style][track] == 0.0)
	{
		iOverwrite = 1;
	}
	
	else if(time < gF_PlayerRecordLocal[client][style][track])
	{
		iOverwrite = 2;
	}

	bool bEveryone = (iOverwrite > 0);
	char sMessage[255];
	char sMessage2[255];
	
	if(iOverwrite > 0 && (time < gF_WRTime[style][track] || gF_WRTime[style][track] == 0.0)) // WR?
	{
		float fOldWR = gF_WRTime[style][track];
		//gF_WRTime[style][track] = time;

		Call_StartForward(gH_OnWorldRecord);
		Call_PushCell(client);
		Call_PushCell(style);
		Call_PushCell(time);
		Call_PushCell(jumps);
		Call_PushCell(strafes);
		Call_PushCell(nades);
		Call_PushCell(sync);
		Call_PushCell(track);
		Call_PushCell(fOldWR);
		Call_PushCell(oldtime);
		Call_PushCell(perfs);
		Call_Finish();

		#if defined DEBUG
		Shavit_PrintToChat(client, "old: %.01f new: %.01f", fOldWR, time);
		#endif
		
		//Shavit_UpdateClientWRs(client);
	}

	iRank = GetRankForTime(style, time, track);

	if(iRank >= GetRecordAmount(style, track))
	{
		Call_StartForward(gH_OnWorstRecord);
		Call_PushCell(client);
		Call_PushCell(style);
		Call_PushCell(time);
		Call_PushCell(jumps);
		Call_PushCell(strafes);
		Call_PushCell(nades);
		Call_PushCell(sync);
		Call_PushCell(track);
		Call_PushCell(oldtime);
		Call_PushCell(perfs);
		Call_Finish();
	}
	
	float fDifferenceWR = (gF_WRTime[style][track] - time);
	
	if(fDifferenceWR < 0.0)
	{
		fDifferenceWR = -fDifferenceWR;
	}
	
	FormatSeconds(fDifferenceWR, sDifferenceWR, 32, true);
	
	if(iOverwrite != 0)
	{
		if(iOverwrite == 1 && gF_WRTime[style][track] == 0.0)
		{
			FormatEx(sDifferenceWR, 32, "");
		}
		
		if(iOverwrite == 1 && gF_WRTime[style][track] != 0.0 && gF_WRTime[style][track] > time)
		{
			Format(sDifferenceWR, 32, "%s-%s", gS_ChatStrings.sGreen, sDifferenceWR);
		}
		
		if(iOverwrite == 1 && gF_WRTime[style][track] != 0.0 && gF_WRTime[style][track] < time)
		{			
			Format(sDifferenceWR, 32, "%s+%s", gS_ChatStrings.sWarning, sDifferenceWR);
		}
		
		if(iOverwrite == 2 && gF_WRTime[style][track] > time)
		{
			Format(sDifferenceWR, 32, "%s-%s", gS_ChatStrings.sGreen, sDifferenceWR);
		}
		
		if(iOverwrite == 2 && gF_WRTime[style][track] < time)
		{
			Format(sDifferenceWR, 32, "%s+%s", gS_ChatStrings.sWarning, sDifferenceWR);
		}
		
		Shavit_UpdateClientWRs(client);
	}
	
	if(iOverwrite == 0 && gF_WRTime[style][track] < time)
	{
		Format(sDifferenceWR, 32, "%s+%s", gS_ChatStrings.sWarning, sDifferenceWR);
	}
	
	float fDifference = (gF_PlayerRecordLocal[client][style][track] - time);

	if(fDifference < 0.0)
	{
		fDifference = -fDifference;
	}
	
	FormatSeconds(fDifference, sDifference, 16, true);
	
	char sLowerCase[64];
	strcopy(sLowerCase, 64, gS_StyleStrings[style].sStyleName);

	for(int i = 0; i < strlen(sLowerCase); i++)
	{
		if(!IsCharLower(sLowerCase[i]))
		{
			sLowerCase[i] = CharToLower(sLowerCase[i]);
		}
	}

	char sSync[32]; // 32 because colors
	FormatEx(sSync, 32, (sync != 0)? " @ %s%.02f%s%%":"", gS_ChatStrings.sOrange, sync, gS_ChatStrings.sText);
	
	int partner = Trikz_FindPartner(client);
	int iSteamID = GetSteamAccountID(client);
	
	if(track == Track_Main)
	{
		if(iOverwrite > 0)
		{
			int iPSteamID = GetSteamAccountID(partner);
			int iJumpsPartner = Shavit_GetClientJumps(partner);
			int iStrafesPartner = Shavit_GetStrafeCount(partner);
			float iSyncPartner = Shavit_GetSync(partner);
			int iNades = Shavit_GetThrowedNadesCount(partner);
			float iPerfsPartner = Shavit_GetPerfectJumps(partner);
			
			char sQuery[512];		  
			FormatEx(sQuery, 512,
				"SELECT id, time "...
				"FROM %splayertimes "...
				"WHERE ((auth = %d AND partner = %d) OR (auth = %d AND partner = %d)) "...
				"AND style = %d AND track = %d AND map = '%s'",
				gS_MySQLPrefix, iSteamID, iPSteamID, iPSteamID, iSteamID, style, track, gS_Map);
			
			DataPack hPack = new DataPack();
			hPack.WriteCell(GetClientSerial(client));
			hPack.WriteCell(iSteamID);
			hPack.WriteCell(iPSteamID);
			hPack.WriteCell(jumps);
			hPack.WriteCell(strafes);
			hPack.WriteCell(nades);
			hPack.WriteCell(sync);
			hPack.WriteCell(style);
			hPack.WriteCell(track);
			hPack.WriteCell(perfs);
			hPack.WriteCell(time);
			hPack.WriteCell(iJumpsPartner);
			hPack.WriteCell(iStrafesPartner);
			hPack.WriteCell(iSyncPartner);
			hPack.WriteCell(iNades);
			hPack.WriteCell(iPerfsPartner);
			
			gH_SQL.Query(SQL_GetRecordWithPartner_Callback, sQuery, hPack, DBPrio_High);
			
			if(iOverwrite == 1) // insert
			{
				if(style != 0)
				{
					if(gF_WRTime[style][track] != 0.0)
					{
						FormatEx(sMessage, 255, "%s%T",
							gS_ChatStrings.sText, "FirstCompletionPartner", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
						
						FormatEx(sMessage2, 255, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
						
						#if defined DEBUG
						Shavit_PrintToChatAll("First completion. (Partner)");
						#endif
					}
					
					if(gF_WRTime[style][track] == 0.0)
					{
						FormatEx(sMessage, 255, "%s%T",
							gS_ChatStrings.sText, "VeryFirstCompletionPartner", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
						
						#if defined DEBUG
						Shavit_PrintToChatAll("Very first completion. (Partner)");
						#endif
					}
				}
				
				else
				{
					if(gF_WRTime[style][track] != 0.0)
					{
						FormatEx(sMessage, 255, "%s%T",
							gS_ChatStrings.sText, "FirstCompletionPartnerNoDefaultStyle", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
						
						FormatEx(sMessage2, 255, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
						
						#if defined DEBUG
						Shavit_PrintToChatAll("First completion. (Partner, no default style)");
						#endif
					}
					
					if(gF_WRTime[style][track] == 0.0)
					{
						FormatEx(sMessage, 255, "%s%T",
							gS_ChatStrings.sText, "VeryFirstCompletionPartnerNoDefaultStyle", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
						
						#if defined DEBUG
						Shavit_PrintToChatAll("Very first completion. (Partner, no default style)");
						#endif
					}
				}
			}

			else // update
			{
				if(style != 0)
				{
					FormatEx(sMessage, 255, "%s%T",
						gS_ChatStrings.sText, "NotFirstCompletionPartner", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Not first completion. (Partner)");
					#endif
				}
				
				else
				{
					FormatEx(sMessage, 255, "%s%T",
						gS_ChatStrings.sText, "NotFirstCompletionPartnerNoDefaultStyle", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Not first completion. (Partner, no default style)");
					#endif
				}
				
				FormatEx(sMessage2, 255, "%s(%sWR: %s%s)%s. Improved by %s-%s%s.", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sGreen, sDifference, gS_ChatStrings.sText);
			}
			
			Call_StartForward(gH_OnFinish_Post);
			Call_PushCell(client);
			Call_PushCell(style);
			Call_PushCell(time);
			Call_PushCell(jumps);
			Call_PushCell(strafes);
			Call_PushCell(nades);
			Call_PushCell(sync);
			Call_PushCell(iRank);
			Call_PushCell(iOverwrite);
			Call_PushCell(track);
			Call_PushCell(oldtime);
			Call_PushCell(perfs);
			Call_Finish();
		}
	}
	
	if(track == Track_Bonus)
	{		
		if(iOverwrite > 0)
		{
			int iPSteamID = GetSteamAccountID(partner);
			int iJumpsPartner = Shavit_GetClientJumps(partner);
			int iStrafesPartner = Shavit_GetStrafeCount(partner);
			float iSyncPartner = Shavit_GetSync(partner);
			int iNades = Shavit_GetThrowedNadesCount(partner);
			float iPerfsPartner = Shavit_GetPerfectJumps(partner);
			
			char sQuery[512];
			FormatEx(sQuery, 512,
				"SELECT id, time "...
				"FROM %splayertimes "...
				"WHERE ((auth = %d AND partner = %d) OR (auth = %d AND partner = %d)) "...
				"AND style = %d AND track = %d AND map = '%s';",
				gS_MySQLPrefix, iSteamID, iPSteamID, iPSteamID, iSteamID, style, track, gS_Map);
			
			DataPack hPack = new DataPack();
			hPack.WriteCell(GetClientSerial(client));
			hPack.WriteCell(iSteamID);
			hPack.WriteCell(iPSteamID);
			hPack.WriteCell(jumps);
			hPack.WriteCell(strafes);
			hPack.WriteCell(nades);
			hPack.WriteCell(sync);
			hPack.WriteCell(style);
			hPack.WriteCell(track);
			hPack.WriteCell(perfs);
			hPack.WriteCell(time);
			hPack.WriteCell(iJumpsPartner);
			hPack.WriteCell(iStrafesPartner);
			hPack.WriteCell(iSyncPartner);
			hPack.WriteCell(iNades);
			hPack.WriteCell(iPerfsPartner);
			
			gH_SQL.Query(SQL_GetRecordWithPartner_Callback, sQuery, hPack, DBPrio_High);
			
			if(iOverwrite == 1) // insert
			{
				if(style != 0)
				{
					if(gF_WRTime[style][track] != 0.0)
					{
						FormatEx(sMessage, 255, "%s%T",
							gS_ChatStrings.sText, "FirstCompletionPartnerBonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
						
						FormatEx(sMessage2, 255, "%s(%s#%s%d%s) (%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
						
						#if defined DEBUG
						Shavit_PrintToChatAll("First bonus completion. (Partner)");
						#endif
					}
					
					if(gF_WRTime[style][track] == 0.0)
					{
						FormatEx(sMessage, 255, "%s%T",
							gS_ChatStrings.sText, "VeryFirstCompletionPartnerBonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
						
						FormatEx(sMessage2, 255, "%s(%s#%s%d%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray);
						
						#if defined DEBUG
						Shavit_PrintToChatAll("Very first bonus completion. (Partner)");
						#endif
					}
				}
				
				else
				{
					if(gF_WRTime[style][track] != 0.0)
					{
						FormatEx(sMessage, 255, "%s%T",
							gS_ChatStrings.sText, "FirstCompletionPartnerNoDefaultStyleBonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
						
						FormatEx(sMessage2, 255, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
						
						#if defined DEBUG
						Shavit_PrintToChatAll("First bonus completion. (Partner, no default style)");
						#endif
					}
					
					if(gF_WRTime[style][track] == 0.0)
					{
						FormatEx(sMessage, 255, "%s%T",
							gS_ChatStrings.sText, "VeryFirstCompletionPartnerNoDefaultStyleBonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
						
						#if defined DEBUG
						Shavit_PrintToChatAll("Very first bonus completion. (Partner, no default style)");
						#endif
					}
				}
			}

			else // update
			{
				if(style != 0)
				{
					FormatEx(sMessage, 255, "%s%T",
						gS_ChatStrings.sText, "NotFirstCompletionPartnerBonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					
					FormatEx(sMessage2, 255, "%s(%s#%s%d%s) (%sWR: %s%s)%s. Improved by %s-%s%s.", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sGreen, sDifference, gS_ChatStrings.sText);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Not first bonus completion. (Partner)");
					#endif
				}
				
				else
				{
					FormatEx(sMessage, 255, "%s%T",
						gS_ChatStrings.sText, "NotFirstCompletionPartnerNoDefaultStyleBonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
					
					FormatEx(sMessage2, 255, "%s(%sWR: %s%s)%s. Improved by %s-%s%s.", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sGreen, sDifference, gS_ChatStrings.sText);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Not first bonus completion. (Partner, no default style)");
					#endif
				}
			}
			
			Call_StartForward(gH_OnFinish_Post);
			Call_PushCell(client);
			Call_PushCell(style);
			Call_PushCell(time);
			Call_PushCell(jumps);
			Call_PushCell(strafes);
			Call_PushCell(nades);
			Call_PushCell(sync);
			Call_PushCell(iRank);
			Call_PushCell(iOverwrite);
			Call_PushCell(track);
			Call_PushCell(oldtime);
			Call_PushCell(perfs);
			Call_Finish();
		}
	}
	
	if(track == Track_Solobonus)
	{
		if(iOverwrite > 0)
		{
			char sQuery[512];
			
			if(iOverwrite == 1) // insert
			{
				if(style != 0)
				{					
					if(gF_WRTime[style][track] != 0.0)
					{
						FormatEx(sMessage, 256, "%s%T",
							gS_ChatStrings.sText, "FirstCompletionSolobonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
						
						FormatEx(sMessage2, 255, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					}
					
					if(gF_WRTime[style][track] == 0.0)
					{
						FormatEx(sMessage, 256, "%s%T",
							gS_ChatStrings.sText, "VeryFirstCompletionSolobonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
					}
					
					#if defined DEBUG
					Shavit_PrintToChatAll("First solobonus completion.");
					#endif
				}
				
				else
				{
					if(gF_WRTime[style][track] != 0.0)
					{
						FormatEx(sMessage, 256, "%s%T",
							gS_ChatStrings.sText, "FirstCompletionNoDefaultStyleSolobonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
						
						FormatEx(sMessage2, 255, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					}
					
					if(gF_WRTime[style][track] == 0.0)
					{
						FormatEx(sMessage, 256, "%s%T",
							gS_ChatStrings.sText, "VeryFirstCompletionNoDefaultStyleSolobonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
					}
					
					#if defined DEBUG
					Shavit_PrintToChatAll("First solobonus completion. (No default style)");
					#endif
				}
				
				FormatEx(sQuery, 512,
									  "INSERT INTO %splayertimes (auth, map, time, jumps, date, style, strafes, nades, sync, points, track, perfs, partner, firstdate) "...
									  "VALUES (%d, '%s', %f, %d, %d, %d, %d, %d, %.2f, 0.0, %d, %.2f, %d, %d);",
									 gS_MySQLPrefix, iSteamID, gS_Map, time, jumps, GetTime(), style, strafes, nades, sync, track, perfs, iSteamID, GetTime());
				
				gH_SQL.Query(SQL_OnFinish_Callback, sQuery, GetClientSerial(client), DBPrio_High);
				
				#if defined DEBUG
				Shavit_PrintToChatAll("Inserted. (Solobonus)");
				#endif
			}

			else // update
			{
				if(style != 0)
				{
					FormatEx(sMessage, 255, "%s%T",
						gS_ChatStrings.sText, "NotFirstCompletionSolobonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
					
					FormatEx(sMessage2, 255, "%s(%sWR: %s%s)%s. Improved by %s-%s%s.", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sGreen, sDifference, gS_ChatStrings.sText);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Not first solobonus completion.");
					#endif
				}
				
				else
				{
					FormatEx(sMessage, 255, "%s%T",
						gS_ChatStrings.sText, "NotFirstCompletionNoDefaultStyleSolobonus", LANG_SERVER, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iRank, gS_ChatStrings.sDimgray, gS_ChatStrings.sText);
					
					FormatEx(sMessage2, 255, "%s(%sWR: %s%s)%s. Improved by %s-%s%s.", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sGreen, sDifference, gS_ChatStrings.sText);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Not first solobonus completion. (No default style)");
					#endif
				}
				
				FormatEx(sQuery, 512,
					"UPDATE %splayertimes SET time = %f, jumps = %d, date = %d, strafes = %d, nades = %d, sync = %.2f, points = 0.0, perfs = %.2f "...
					"WHERE map = '%s' AND auth = %d AND style = %d AND track = %d;",
					gS_MySQLPrefix, time, jumps, GetTime(), strafes, nades, sync, perfs, gS_Map, iSteamID, style, track);
				
				gH_SQL.Query(SQL_OnFinish_Callback, sQuery, GetClientSerial(client), DBPrio_High);
				
				#if defined DEBUG
				Shavit_PrintToChatAll("Updated. (Solobonus)");
				#endif
			}

			Call_StartForward(gH_OnFinish_Post);
			Call_PushCell(client);
			Call_PushCell(style);
			Call_PushCell(time);
			Call_PushCell(jumps);
			Call_PushCell(strafes);
			Call_PushCell(nades);
			Call_PushCell(sync);
			Call_PushCell(iRank);
			Call_PushCell(iOverwrite);
			Call_PushCell(track);
			Call_PushCell(oldtime);
			Call_PushCell(perfs);
			Call_Finish();
		}
	}

	if(bIncrementCompletions)
	{
		char sQuery[256];
		
		FormatEx(sQuery, 256,
			"UPDATE %splayertimes "...
			"SET completions = completions + 1 "...
			"WHERE map = '%s' AND (auth = %d OR partner = %d) AND style = %d AND track = %d;",
			gS_MySQLPrefix, gS_Map, iSteamID, iSteamID, style, track);

		gH_SQL.Query(SQL_OnIncrementCompletions_Callback, sQuery, 0, DBPrio_Low);
		
		if(style != 0)
		{
			if(track == Track_Main)
			{
				if(iOverwrite == 0 && !gA_StyleSettings[style].bUnranked)
				{
					Shavit_PrintToChat(client, "%s%T", gS_ChatStrings.sText, "WorseTimePartner", client, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					Shavit_PrintToChat(partner, "%s%T", gS_ChatStrings.sText, "WorseTimePartner", partner, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					
					CPrintToChat(client, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					CPrintToChat(partner, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Worse time. (Partner)");
					#endif
				}
			}
			
			if(track == Track_Bonus)
			{
				if(iOverwrite == 0 && !gA_StyleSettings[style].bUnranked)
				{
					Shavit_PrintToChat(client, "%s%T", gS_ChatStrings.sText, "WorseTimePartnerBonus", client, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					Shavit_PrintToChat(partner, "%s%T", gS_ChatStrings.sText, "WorseTimePartnerBonus", partner, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					
					CPrintToChat(client, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					CPrintToChat(partner, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Worse bonus time. (Partner)");
					#endif
				}
			}
			
			if(track == Track_Solobonus)
			{
				if(iOverwrite == 0 && !gA_StyleSettings[style].bUnranked)
				{
					FormatEx(sMessage, 255, "%s%T",
						gS_ChatStrings.sText, "WorseTimeSolobonus", client, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					
					FormatEx(sMessage2, 255, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Worse solobonus time.");
					#endif
				}
			}
		}
		
		else
		{
			if(track == Track_Main)
			{
				if(iOverwrite == 0 && !gA_StyleSettings[style].bUnranked)
				{
					Shavit_PrintToChat(client, "%s%T", gS_ChatStrings.sText, "WorseTimePartnerNoDefaultStyle", client, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					Shavit_PrintToChat(partner, "%s%T", gS_ChatStrings.sText, "WorseTimePartnerNoDefaultStyle", partner, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					
					CPrintToChat(client, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					CPrintToChat(partner, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Worse time. (Partner, no default style)");
					#endif
				}
			}
			
			if(track == Track_Bonus)
			{
				if(iOverwrite == 0 && !gA_StyleSettings[style].bUnranked)
				{
					Shavit_PrintToChat(client, "%s%T", gS_ChatStrings.sText, "WorseTimePartnerNoDefaultStyleBonus", client, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					Shavit_PrintToChat(partner, "%s%T", gS_ChatStrings.sText, "WorseTimePartnerNoDefaultStyleBonus", partner, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					
					CPrintToChat(client, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					CPrintToChat(partner, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Worse bonus time. (Partner, no default style)");
					#endif
				}
			}
			
			if(track == Track_Solobonus)
			{
				if(iOverwrite == 0 && !gA_StyleSettings[style].bUnranked)
				{
					FormatEx(sMessage, 255, "%s%T",
						gS_ChatStrings.sText, "WorseTimeNoDefaultStyleSolobonus", client, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
					
					FormatEx(sMessage2, 255, "%s(%sWR: %s%s)", gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sDifferenceWR, gS_ChatStrings.sDimgray);
					
					#if defined DEBUG
					Shavit_PrintToChatAll("Worse solobonus time. (No default style)");
					#endif
				}
			}
		}
	}

	else
	{
		if(style != 0)
		{
			if(track == Track_Main)
			{				
				Shavit_PrintToChat(client, "%s%T", gS_ChatStrings.sText, "UnrankedTimePartner", client, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
				Shavit_PrintToChat(partner, "%s%T", gS_ChatStrings.sText, "UnrankedTimePartner", partner, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
				
				#if defined DEBUG
				Shavit_PrintToChatAll("Unranked time. (Partner)");
				#endif
			}
			
			if(track == Track_Bonus)
			{
				Shavit_PrintToChat(client, "%s%T", gS_ChatStrings.sText, "UnrankedTimePartnerBonus", client, gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
				Shavit_PrintToChat(partner, "%s%T", gS_ChatStrings.sText, "UnrankedTimePartnerBonus", partner, gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
				
				#if defined DEBUG
				Shavit_PrintToChatAll("Unranked bonus time. (Partner)");
				#endif
			}
			
			if(track == Track_Solobonus)
			{
				FormatEx(sMessage, 255, "%s%T",
					gS_ChatStrings.sText, "UnrankedTimeSolobonus", client, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, sLowerCase, gS_ChatStrings.sDimgray, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
				
				#if defined DEBUG
				Shavit_PrintToChatAll("Unranked solobonus time.");
				#endif
			}
		}
		
		else
		{
			if(track == Track_Main)
			{
				Shavit_PrintToChat(client, "%s%T", gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
				Shavit_PrintToChat(partner, "%s%T", gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
				
				#if defined DEBUG
				Shavit_PrintToChatAll("Unranked time. (Partner, no default style)");
				#endif
			}
			
			if(track == Track_Bonus)
			{
				Shavit_PrintToChat(client, "%s%T", gS_ChatStrings.sOrange, partner, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
				Shavit_PrintToChat(partner, "%s%T", gS_ChatStrings.sOrange, client, gS_ChatStrings.sText, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
				
				#if defined DEBUG
				Shavit_PrintToChatAll("Unranked bonus time. (Partner, no default style)");
				#endif
			}
			
			if(track == Track_Solobonus)
			{
				FormatEx(sMessage, 255, "%s%T",
					gS_ChatStrings.sText, "UnrankedTimeNoDefaultStyleSolobonus", client, gS_ChatStrings.sOrange, sTime, gS_ChatStrings.sText);
				
				#if defined DEBUG
				Shavit_PrintToChatAll("Unranked solobonus time. (No default style)");
				#endif
			}
		}
	}

	timer_snapshot_t aSnapshot;
	Shavit_SaveSnapshot(client, aSnapshot);

	Action aResult = Plugin_Continue;
	Call_StartForward(gH_OnFinishMessage);
	Call_PushCell(client);
	Call_PushCellRef(bEveryone);
	Call_PushArrayEx(aSnapshot, sizeof(timer_snapshot_t), SM_PARAM_COPYBACK);
	Call_PushCell(iOverwrite);
	Call_PushCell(iRank);
	Call_PushStringEx(sMessage, 255, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(255);
	Call_Finish(aResult);

	if(aResult < Plugin_Handled)
	{
		if(bEveryone)
		{
			Shavit_PrintToChatAll("%s", sMessage);
			CPrintToChatAll("%s", sMessage2);
		}

		else
		{
			if(track == Track_Solobonus)
			{
				Shavit_PrintToChat(client, "%s", sMessage);
				CPrintToChat(client, "%s", sMessage2);
			}
		}
	}

	// update pb cache only after sending the message so we can grab the old one inside the Shavit_OnFinishMessage forward
	if(iOverwrite > 0)
	{
		gF_PlayerRecordLocal[client][style][track] = time;
	}
}

public void SQL_GetRecordWithPartner_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack hPack = data;
	hPack.Reset();
	int iSerial = hPack.ReadCell();
	int iSteamID = hPack.ReadCell();
	int iPSteamID = hPack.ReadCell();
	int iJumps = hPack.ReadCell();
	int iStrafes = hPack.ReadCell();
	int iNades = hPack.ReadCell();
	float iSync = hPack.ReadCell();
	int iStyle = hPack.ReadCell();
	int iTrack = hPack.ReadCell();
	float iPerfs = hPack.ReadCell();
	float fTime = hPack.ReadCell();
	int iJumpsPartner = hPack.ReadCell();
	int iStrafesPartner = hPack.ReadCell();
	float iSyncPartner = hPack.ReadCell();
	int iNadesPartner = hPack.ReadCell();
	float iPerfsPartner = hPack.ReadCell();
	delete hPack;
	
	if(results == null)
	{
		LogError("Timer (WR GetRecordWithPartner) SQL query failed. Reason: %s", error);

		return;
	}
	
	#if defined DEBUG
	Shavit_PrintToChatAll("Selected. (Partner)");
	#endif
	
	int count = results.RowCount;
	char sQuery[512];
	
	if(count == 0)
	{
		FormatEx(sQuery, 512,
			"INSERT INTO %splayertimes (auth, map, time, jumps, date, style, strafes, nades, sync, points, track, perfs, partner, firstdate) "...
			"VALUES (%d, '%s', %f, %d, %d, %d, %d, %d, %.2f, 0.0, %d, %.2f, %d, %d);",
			gS_MySQLPrefix, iSteamID, gS_Map, fTime, iJumps + iJumpsPartner, GetTime(), iStyle, iStrafes + iStrafesPartner, iNades + iNadesPartner, (iSync + iSyncPartner) / 2, iTrack, (iPerfs + iPerfsPartner) / 2, iPSteamID, GetTime());
		
		gH_SQL.Query(SQL_OnFinish_Callback, sQuery, iSerial, DBPrio_High);
		
		#if defined DEBUG
		Shavit_PrintToChatAll("Inserted. (Partner)");
		#endif
	}
	
	else
	{
		results.FetchRow();
		int MYSQL_ID = results.FetchInt(0);
		float fOldTime = results.FetchFloat(1);
		
		if(fTime < fOldTime)
		{
			FormatEx(sQuery, 512,
				"UPDATE %splayertimes SET time = %f, date = %d, jumps = %d, strafes = %d, nades = %d, sync = %.2f, points = 0.0, perfs = %.2f "...
				"WHERE map = '%s' AND ((auth = %d AND partner = %d) OR (auth = %d AND partner = %d)) AND id = %d;",
				gS_MySQLPrefix, fTime, GetTime(), iJumps + iJumpsPartner, iStrafes + iStrafesPartner, iNades + iNadesPartner, (iSync + iSyncPartner) / 2, (iPerfs + iPerfsPartner) / 2, gS_Map, iSteamID, iPSteamID, iPSteamID, iSteamID, MYSQL_ID);
			
			gH_SQL.Query(SQL_OnFinish_Callback, sQuery, iSerial, DBPrio_High);
			
			#if defined DEBUG
			Shavit_PrintToChatAll("Updated. (Partner)");
			Shavit_PrintToChatAll("Old time: %f, new time: %f", fOldTime, fTime);
			#endif
		}
	}
}

public void SQL_OnIncrementCompletions_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR OnIncrementCompletions) SQL query failed. Reason: %s", error);

		return;
	}
}

public void SQL_OnFinish_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR OnFinish) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	UpdateWRCache();
	UpdateClientCache(client);
	
	int partner = Trikz_FindPartner(client);
	
	if(partner != -1)
	{
		UpdateClientCache(partner);
	}
	
	ServerCommand("sm_recalcmap");
}

void UpdateLeaderboards()
{
	char sQuery[192];
	FormatEx(sQuery, 192, "SELECT style, track, time FROM %splayertimes WHERE map = '%s' ORDER BY time ASC, date ASC;", gS_MySQLPrefix, gS_Map);
	gH_SQL.Query(SQL_UpdateLeaderboards_Callback, sQuery);
}

public void SQL_UpdateLeaderboards_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR UpdateLeaderboards) SQL query failed. Reason: %s", error);

		return;
	}

	for(int i = 0; i < gI_Styles; i++)
	{
		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			gA_Leaderboard[i][j].Clear();
		}
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int track = results.FetchInt(1);

		if(style >= gI_Styles || gA_StyleSettings[style].bUnranked || track >= TRACKS_SIZE)
		{
			continue;
		}

		gA_Leaderboard[style][track].Push(results.FetchFloat(2));
	}

	for(int i = 0; i < gI_Styles; i++)
	{
		if(i >= gI_Styles || gA_StyleSettings[i].bUnranked)
		{
			continue;
		}

		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			SortADTArray(gA_Leaderboard[i][j], Sort_Ascending, Sort_Float);
		}
	}
}

int GetRecordAmount(int style, int track)
{
	if(gA_Leaderboard[style][track] == null)
	{
		return 0;
	}

	return gA_Leaderboard[style][track].Length;
}

int GetRankForTime(int style, float time, int track)
{
	int iRecords = GetRecordAmount(style, track);

	if(time <= gF_WRTime[style][track] || iRecords <= 0)
	{
		return 1;
	}

	if(gA_Leaderboard[style][track] != null && gA_Leaderboard[style][track].Length > 0)
	{
		for(int i = 0; i < iRecords; i++)
		{
			if(time <= gA_Leaderboard[style][track].Get(i))
			{
				return ++i;
			}
		}
	}

	return (iRecords + 1);
}

void GuessBestMapName(const char[] input, char[] output, int size)
{
	if(gA_ValidMaps.FindString(input) != -1)
	{
		strcopy(output, size, input);

		return;
	}

	char sCache[128];

	for(int i = 0; i < gI_ValidMaps; i++)
	{
		gA_ValidMaps.GetString(i, sCache, 128);

		if(StrContains(sCache, input) != -1)
		{
			strcopy(output, size, sCache);

			return;
		}
	}
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
