/*
 * shavit's Timer - Player Stats
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
#include <geoip>

#undef REQUIRE_PLUGIN
#include <shavit>

#undef REQUIRE_EXTENSIONS
#include <cstrike>

#pragma newdecls required
#pragma semicolon 1

// macros
#define MAPSDONE 0
#define MAPSLEFT 1

// modules
bool gB_Rankings = false;
bool gB_Stats = false;

// database handle
Database gH_SQL = null;
char gS_MySQLPrefix[32];

// cache
bool gB_CanOpenMenu[MAXPLAYERS+1];
int gI_Style[MAXPLAYERS+1];
int gI_Track[MAXPLAYERS+1];
int gI_TargetSteamID[MAXPLAYERS+1];
char gS_TargetName[MAXPLAYERS+1][MAX_NAME_LENGTH];
int gI_WRAmount[MAXPLAYERS+1];
char gS_map[192];
int gI_rank[MAXPLAYERS + 1];
int gI_records[MAXPLAYERS + 1];
int gI_id[MAXPLAYERS + 1];
char sClearString[MAXPLAYERS + 1][128];
int gI_clears[MAXPLAYERS + 1];
int gI_TotalMaps[MAXPLAYERS + 1];
bool gB_MyWorldRecordsQuery[MAXPLAYERS + 1];
bool gB_OpenStatsMenuMC[MAXPLAYERS + 1];
bool gB_ShowMapsLeft[MAXPLAYERS + 1];

// fowards
Handle gH_OnWRDeleted = null;

bool gB_Late = false;

// cvars
ConVar gCV_MVPRankOnes = null;

// timer settings
int gI_Styles = 0;
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
stylesettings_t gA_StyleSettings[STYLE_LIMIT];

// chat settings
chatstrings_t gS_ChatStrings;

public Plugin myinfo =
{
	name = "[shavit] Player Stats",
	author = "shavit, sejiya, Smesh",
	description = "Player stats for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// natives
	CreateNative("Shavit_OpenStatsMenu", Native_OpenStatsMenu);
	CreateNative("Shavit_GetWRCount", Native_GetWRCount);
	CreateNative("Shavit_UpdateClientWRs", Native_UpdateClientWRs);

	RegPluginLibrary("shavit-stats");

	gB_Late = late;

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("shavit-wr"))
	{
		SetFailState("shavit-wr is required for the plugin to work.");
	}
}

public void OnPluginStart()
{
	gH_OnWRDeleted = CreateGlobalForward("Shavit_OnWRDeleted", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	
	// player commands
	RegConsoleCmd("sm_profile", Command_Profile, "Show the player's profile. Usage: sm_profile [target]");
	RegConsoleCmd("sm_stats", Command_Profile, "Show the player's profile. Usage: sm_profile [target]");
	RegConsoleCmd("sm_mywr", Command_MyWorldRecords);
	RegConsoleCmd("sm_myworldrecords", Command_MyWorldRecords);
	RegConsoleCmd("sm_mc", Command_MapCompletions, "Show maps that the player has finished. Usage: sm_mapsdone [target]");
	RegConsoleCmd("sm_mapcompletions", Command_MapCompletions, "Show maps that the player has finished. Usage: sm_mapsdone [target]");
	RegConsoleCmd("sm_mapsleft", Command_MapsLeft, "Show maps that the player has not finished yet. Usage: sm_mapsleft [target]");

	// translations
	LoadTranslations("common.phrases");
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-stats.phrases");
	LoadTranslations("shavit-wr.phrases");

	// hooks
	HookEvent("player_spawn", Player_Event);
	HookEvent("player_team", Player_Event);

	// cvars
	gCV_MVPRankOnes = CreateConVar("shavit_stats_mvprankones", "1", "Set the players' amount of MVPs to the amount of #1 times they have.\n0 - Disabled\n1 - Enabled, for all styles and tracks.", 0, true, 0.0, true, 1.0);

	AutoExecConfig();

	gB_Rankings = LibraryExists("shavit-rankings");
	gB_Stats = LibraryExists("shavit-stats");

	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientConnected(i) && IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}

	// database
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle();
}

public void OnMapStart()
{
	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(-1);
		Shavit_OnChatConfigLoaded();
	}
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
}

public void OnClientPutInServer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	gB_CanOpenMenu[client] = true;
	gI_WRAmount[client] = 0;
	UpdateWRs(client);
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
}

public Action Player_Event(Event event, const char[] name, bool dontBroadcast)
{
	if(gCV_MVPRankOnes.IntValue == 0)
	{
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client) && !IsFakeClient(client))
	{
		CS_SetMVPCount(client, gI_WRAmount[client]);
	}
	
	return Plugin_Continue;
}

public int Native_UpdateClientWRs(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
	
    UpdateWRs(client);
}

void UpdateWRs(int client)
{
	int iSteamID = 0;

	if((iSteamID = GetSteamAccountID(client)) != 0)
	{
		char sQuery[512];
		int style = Shavit_GetBhopStyle(client);
		int track = Shavit_GetClientTrack(client);

		if(gCV_MVPRankOnes.IntValue == 1)
		{
			FormatEx(sQuery, 512,
				"SELECT COUNT(*) "...
				"FROM %splayertimes a "...
				"JOIN (SELECT MIN(time) time, map "...
				"FROM %splayertimes "...
				"WHERE style = %i AND track = %i GROUP by map, track) b ON a.time = b.time AND a.map = b.map AND style = %i AND track = %i AND (auth = %d OR partner = %d);",
				gS_MySQLPrefix, gS_MySQLPrefix, style, track, style, track, iSteamID, iSteamID);
		}

		gH_SQL.Query(SQL_GetWRs_Callback, sQuery, GetClientSerial(client));
	}
}

public void SQL_GetWRs_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (get WR amount) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0 || !results.FetchRow())
	{
		gI_WRAmount[client] = 0;
		
		return;
	}

	int iWRs = results.FetchInt(0);

	if(gCV_MVPRankOnes.IntValue > 0)
	{
		CS_SetMVPCount(client, iWRs);
	}

	gI_WRAmount[client] = iWRs;
}

public Action Command_Profile(int client, int args)
{
	if(client == 0)
	{
		return Plugin_Handled;
	}

	int target = client;

	if(args > 0)
	{
		char sArgs[64];
		GetCmdArgString(sArgs, 64);

		target = FindTarget(client, sArgs, true, false);

		if(target == -1)
		{
			return Plugin_Handled;
		}
	}
	
	gI_TargetSteamID[client] = GetSteamAccountID(target);

	return OpenStatsMenu(client, gI_TargetSteamID[client]);
}

Action Command_MyWorldRecords(int client, int args)
{
	if(client == 0)
	{
		return Plugin_Handled;
	}

	int target = client;

	if(args > 0)
	{
		char sArgs[64];
		GetCmdArgString(sArgs, 64);

		target = FindTarget(client, sArgs, true, false);

		if(target == -1)
		{
			return Plugin_Handled;
		}
	}

	gI_TargetSteamID[client] = GetSteamAccountID(target);

	return OpenStatsMenuMYWR(client);
}

Action Command_MapCompletions(int client, int args)
{
	if(client == 0)
	{
		return Plugin_Handled;
	}

	int target = client;

	if(args > 0)
	{
		char sArgs[64];
		GetCmdArgString(sArgs, 64);

		target = FindTarget(client, sArgs, true, false);

		if(target == -1)
		{
			return Plugin_Handled;
		}
	}

	gI_TargetSteamID[client] = GetSteamAccountID(target);
	
	gB_MyWorldRecordsQuery[client] = false;
	gB_OpenStatsMenuMC[client] = true;
	gB_ShowMapsLeft[client] = false;
	
	TrackMenu(client);
	
	return Plugin_Handled;
}

Action Command_MapsLeft(int client, int args)
{
	if(client == 0)
	{
		return Plugin_Handled;
	}

	int target = client;

	if(args > 0)
	{
		char sArgs[64];
		GetCmdArgString(sArgs, 64);

		target = FindTarget(client, sArgs, true, false);

		if(target == -1)
		{
			return Plugin_Handled;
		}
	}

	gI_TargetSteamID[client] = GetSteamAccountID(target);
	
	gB_MyWorldRecordsQuery[client] = false;
	gB_OpenStatsMenuMC[client] = false;
	gB_ShowMapsLeft[client] = true;

	TrackMenu(client);
	
	return Plugin_Handled;
}

Action OpenStatsMenu(int client, int steamid)
{
	// no spam please
	if(!gB_CanOpenMenu[client])
	{
		//return Plugin_Handled;
	}

	// big ass query, looking for optimizations
	char sQuery[2048];
	
	if(gB_Rankings)
	{		
		FormatEx(sQuery, 2048, "SELECT d.name, d.ip, d.firstlogin, d.lastlogin, d.points, e.rank FROM " ...
				"(SELECT name, ip, firstlogin, lastlogin, FORMAT(points, 2) points FROM %susers WHERE auth = %d) d " ...
				"JOIN (SELECT COUNT(*) rank FROM %susers as u1 JOIN (SELECT points FROM %susers WHERE auth = %d) u2 WHERE u1.points >= u2.points) e " ...
				"LIMIT 1;", gS_MySQLPrefix, steamid, gS_MySQLPrefix, gS_MySQLPrefix, steamid);
	}

	else
	{
		FormatEx(sQuery, 2048, "SELECT a.clears, b.maps, c.wrs, d.name, d.ip, d.firstlogin, d.lastlogin FROM " ...
				"(SELECT COUNT(*) clears FROM (SELECT map FROM %splayertimes WHERE (auth = %d OR partner = %d) AND track = 0 GROUP BY map) s) a " ...
				"JOIN (SELECT COUNT(*) maps FROM (SELECT map FROM %smapzones WHERE track = 0 AND type = 0 GROUP BY map) s) b " ...
				"JOIN (SELECT COUNT(*) wrs FROM %splayertimes a JOIN (SELECT MIN(time) time, map FROM %splayertimes WHERE style = 0 AND track = 0 GROUP by map, style, track) b ON a.time = b.time AND a.map = b.map AND track = 0 AND style = 0 WHERE auth = %d) c " ...
				"JOIN (SELECT name, ip, firstlogin, lastlogin FROM %susers WHERE auth = %d) d " ...
				"LIMIT 1;", gS_MySQLPrefix, steamid, steamid, gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix, steamid, gS_MySQLPrefix, steamid);
	}

	gB_CanOpenMenu[client] = false;
	gH_SQL.Query(OpenStatsMenuCallback, sQuery, GetClientSerial(client), DBPrio_Low);

	return Plugin_Handled;
}

public void OpenStatsMenuCallback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	gB_CanOpenMenu[client] = true;

	if(results == null)
	{
		LogError("Timer (statsmenu) SQL query failed. Reason: %s", error);

		return;
	}

	if(client == 0)
	{
		return;
	}

	if(results.FetchRow())
	{
		// create variables
		results.FetchString(0, gS_TargetName[client], MAX_NAME_LENGTH);
		ReplaceString(gS_TargetName[client], MAX_NAME_LENGTH, "#", "?");

		/*int iIPAddress = results.FetchInt(1);
		char sIPAddress[32];
		IPAddressToString(iIPAddress, sIPAddress, 32);

		char sCountry[64];

		if(!GeoipCountry(sIPAddress, sCountry, 64))
		{
			strcopy(sCountry, 64, "Local Area Network");
		}*/
		
		int iFirstLogin = results.FetchInt(2);
		char sFirstLogin[33];
		FormatTime(sFirstLogin, 33, "%Y-%m-%d %H:%M:%S", iFirstLogin);
		Format(sFirstLogin, 33, "%T: %s", "FirstLogin", client, (iFirstLogin != -1)? sFirstLogin:"N/A");

		int iLastLogin = results.FetchInt(3);
		char sLastLogin[32];
		FormatTime(sLastLogin, 32, "%Y-%m-%d %H:%M:%S", iLastLogin);
		Format(sLastLogin, 32, "%T: %s", "LastLogin", client, (iLastLogin != -1)? sLastLogin:"N/A");

		char sPoints[16];
		char sRank[16];

		if(gB_Rankings)
		{
			results.FetchString(4, sPoints, 16);
			results.FetchString(5, sRank, 16);
		}

		char sRankingString[64];

		if(gB_Rankings)
		{
			if(StringToInt(sRank) > 0 && StringToInt(sPoints) > 0)
			{
				FormatEx(sRankingString, 64, "\n%T: #%s/%d\n%T: %s", "Rank", client, sRank, Shavit_GetRankedPlayers(), "Points", client, sPoints);
			}

			else
			{
				FormatEx(sRankingString, 64, "\n%T: %T", "Rank", client, "PointsUnranked", client);
			}
		}
		
		Menu menu = new Menu(MenuHandler_ProfileHandler);
		//menu.SetTitle("%s's %T. [U:1:%d]\n \n%T: %s\n \n%s\n%s\n %s\n ",
		//	gS_TargetName[client], "Profile", client, gI_TargetSteamID[client], "Country", client, sCountry, sFirstLogin, sLastLogin, sRankingString);
		menu.SetTitle("%s's %T. [U:1:%d]\n \n%s\n%s\n %s\n ",
			gS_TargetName[client], "Profile", client, gI_TargetSteamID[client], sFirstLogin, sLastLogin, sRankingString);
		
		menu.AddItem("sm_mywr", "World records");
		menu.AddItem("sm_mc", "Map completions");
		menu.AddItem("sm_mapsleft", "Maps left");
		
		// should NEVER happen
		if(menu.ItemCount == 0)
		{
			char sMenuItem[64];
			FormatEx(sMenuItem, 64, "%T", "NoRecords", client);
			menu.AddItem("-1", sMenuItem);
		}

		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}

	else
	{
		Shavit_PrintToChat(client, "%T", "StatsMenuFailure", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
	}
}

Action OpenStatsMenuMYWR(int client)
{
	// no spam please
	if(!gB_CanOpenMenu[client])
	{
		//return Plugin_Handled;
	}
	
	gB_MyWorldRecordsQuery[client] = true;
	gB_OpenStatsMenuMC[client] = false;
	gB_ShowMapsLeft[client] = false;
	
	TrackMenu(client);

	gB_CanOpenMenu[client] = false;

	return Plugin_Handled;
}

void TrackMenu(int client)
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
	
	menu.ExitBackButton = true;
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
	
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenStatsMenu(param1, gI_TargetSteamID[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

Action ShowWRStyleMenu(int client, int track)
{
	gI_Track[client] = track;

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
		strcopy(sDisplay, 64, gS_StyleStrings[iStyle].sStyleName);

		menu.AddItem(sInfo, sDisplay);
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

		gI_Style[param1] = iStyle;
		
		if(gB_MyWorldRecordsQuery[param1])
		{
			MyWorldRecordsQuery(param1);
		}
		
		if(gB_OpenStatsMenuMC[param1])
		{
			OpenStatsMenuMC(param1);
		}
		
		if(gB_ShowMapsLeft[param1])
		{
			ShowMapsLeft(param1);
		}
	}
	
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		TrackMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void MyWorldRecordsQuery(int client)
{
	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT name "...
		"FROM %susers "...
		"WHERE auth = %d;",
		gS_MySQLPrefix, gI_TargetSteamID[client]);
		
	gH_SQL.Query(GetName_MyWorldRecordsCallback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void GetName_MyWorldRecordsCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (MyWorldRecordsQuery SELECT) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}
	
	if(results.FetchRow())
	{
		// create variables
		results.FetchString(0, gS_TargetName[client], MAX_NAME_LENGTH);
		ReplaceString(gS_TargetName[client], MAX_NAME_LENGTH, "#", "?");
		
		char sQuery[512];
		FormatEx(sQuery, 512,
			"SELECT * FROM ("...
			"SELECT a.map, a.time, a.jumps, a.id, COUNT(b.map) + 1 rank, a.points "...
			"FROM %splayertimes a LEFT JOIN %splayertimes b ON a.time > b.time AND a.map = b.map "...
			"AND a.style = b.style AND a.track = b.track "...
			"WHERE (a.auth = %d OR a.partner = %d) AND a.style = %d AND a.track = %d "...
			"GROUP BY a.map, a.time, a.jumps, a.id, a.points "...
			"ORDER BY a.%s "...
			") t "...
			"GROUP BY map ORDER BY points;",
			gS_MySQLPrefix, gS_MySQLPrefix, gI_TargetSteamID[client], gI_TargetSteamID[client], gI_Style[client], gI_Track[client], (gB_Rankings)? "points DESC":"map");
			
		gH_SQL.Query(MyWorldRecordsCallback, sQuery, GetClientSerial(client), DBPrio_High);
	}
}

public void MyWorldRecordsCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (MyWorldRecordsQuery SELECT) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	gB_CanOpenMenu[client] = true;

	char sTrack[32];
	GetTrackName(client, gI_Track[client], sTrack, 32);
	
	Menu menu = new Menu(MenuHandler_MyWorldRecords);
	
	int rank;
	int iWRs;
	
	while(results.FetchRow())
	{
		//char gS_map[192];
		results.FetchString(0, gS_map, 192);
		
		char sRecordID[192];
		char sDisplay[256];
		
		float time = results.FetchFloat(1);
		int jumps = results.FetchInt(2);
		rank = results.FetchInt(4);
		char sTime[32];
		FormatSeconds(time, sTime, 32);

		//float points = results.FetchFloat(5);
		
		/*if(gB_Rankings && points > 0.0)
		{
			FormatEx(sDisplay, 192, "[#%d] %s - %s (%.03f %T)", rank, gS_map, sTime, points, "MapsPoints", client);
		}

		else*/
		{
			if(gI_Track[client] == Track_Solobonus)
			{
				FormatEx(sDisplay, 192, "[#%d] %s - %s (%d %T)", rank, gS_map, sTime, jumps, "MapsJumps", client);
			}
			
			else
			{
				FormatEx(sDisplay, 192, "[#%d] %s - %s", rank, gS_map, sTime, client);
			}
		}

		int iRecordID = results.FetchInt(3);
		IntToString(iRecordID, sRecordID, 192);
		
		char sRecordID_gS_map[192];
		Format(sRecordID_gS_map, 192, "%s;%s", sRecordID, gS_map);
		
		if(rank == 1)
		{
			menu.AddItem(sRecordID_gS_map, sDisplay);
			iWRs++;
		}
	}

	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "NoResults", client);
		menu.AddItem("nope", sMenuItem, ITEMDRAW_DISABLED);
	}
	
	if(gI_Style[client] == 0 && gI_Track[client] == 0)
	{			
		FormatEx(sClearString[client], 128, "%T: %d", "WorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 0 && gI_Track[client] == 2)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "BonusWorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 0 && gI_Track[client] == 4)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "SolobonusWorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 1 && gI_Track[client] == 0)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "SWWorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 1 && gI_Track[client] == 2)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "BonusSWWorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 1 && gI_Track[client] == 4)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "SolobonusSWWorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 2 && gI_Track[client] == 0)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "WWorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 2 && gI_Track[client] == 2)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "BonusWWorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 2 && gI_Track[client] == 4)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "SolobonusWWorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 3 && gI_Track[client] == 0)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "HSWWorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 3 && gI_Track[client] == 2)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "BonusHSWWorldRecords", client, iWRs);
	}
	
	if(gI_Style[client] == 3 && gI_Track[client] == 4)
	{
		FormatEx(sClearString[client], 128, "%T: %d", "SolobonusHSWWorldRecords", client, iWRs);
	}
	
	menu.SetTitle("%s [U:1:%d]\n%s\n ", gS_TargetName[client], gI_TargetSteamID[client], sClearString[client]);	

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MyWorldRecords(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[192];
		menu.GetItem(param2, sInfo, 192);

		if(StrEqual(sInfo, "nope"))
		{	
			ShowWRStyleMenu(param1, gI_Track[param1]);

			return 0;
		}
		
		else
		{			
			char sExploded[2][128];
			ExplodeString(sInfo, ";", sExploded, 2, 128, true);
			gI_id[param1] = StringToInt(sExploded[0]);
			char sMap[192];
			Format(sMap, 192, "%s", sExploded[1]);
			
			char sQuery[512];
			FormatEx(sQuery, 512,
				"SELECT * FROM %splayertimes "...
				"WHERE style = %d AND track = %d AND map = '%s';",
				gS_MySQLPrefix, gI_Style[param1], gI_Track[param1], sMap);

			gH_SQL.Query(SQL_MyWorldRecords_AllRecords_Callback, sQuery, GetClientSerial(param1), DBPrio_High);
		}
	}

	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowWRStyleMenu(param1, gI_Track[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_MyWorldRecords_AllRecords_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (MyWorldRecords_AllRecords) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(data);
	
	if(client == 0)
	{
		return;
	}
	
	gI_records[client] = results.RowCount;
	
	char sQuery[512];
	FormatEx(sQuery, 512,
		"SELECT * FROM ("...
		"SELECT a.map, a.time, a.jumps, a.id, COUNT(b.map) + 1 rank, a.points "...
		"FROM %splayertimes a LEFT JOIN %splayertimes b ON a.time > b.time AND a.map = b.map "...
		"AND a.style = b.style AND a.track = b.track "...
		"WHERE (a.auth = %d OR a.partner = %d) AND a.style = %d AND a.track = %d AND a.id = %d "...
		"GROUP BY a.map, a.time, a.jumps, a.id, a.points "...
		"ORDER BY a.%s "...
		") t "...
		"GROUP BY map ORDER BY points;",
		gS_MySQLPrefix, gS_MySQLPrefix, gI_TargetSteamID[client], gI_TargetSteamID[client], gI_Style[client], gI_Track[client], gI_id[client], (gB_Rankings)? "points DESC":"map");

	gH_SQL.Query(MyWorldRecords_PositionInRank_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void MyWorldRecords_PositionInRank_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (MyWorldRecords_PositionInRank) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(data);
	
	if(client < 1)
	{
		return;
	}
	
	if(results.FetchRow())
	{
		gI_rank[client] = results.FetchInt(4);
		
		OpenRecordsDetails(client);
	}
}

void OpenRecordsDetails(int client)
{
	char sQuery[512];
	FormatEx(sQuery, 512,
		"SELECT u.name, p.time, p.jumps, p.style, u.auth, p.date, p.map, p.strafes, p.sync, p.perfs, p.points, p.track, p.completions, u1.name, p.partner, p.nades, p.firstdate FROM %splayertimes p JOIN %susers u ON p.auth = u.auth JOIN %susers u1 ON p.partner = u1.auth WHERE p.id = %d LIMIT 1;",
		gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix, gI_id[client]);

	gH_SQL.Query(SQL_RecordDetail_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_RecordDetail_Callback(Database db, DBResultSet results, const char[] error, any data)
{	
	if(results == null)
	{
		LogError("Timer (SQL_MyWorldRecords_Callback) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	Menu hMenu = new Menu(RecordDetail_Handler);

	char sFormattedTitle[512];
	int iSteamID = 0;
	char sName[MAX_NAME_LENGTH];
	char sPName[MAX_NAME_LENGTH];
	int iPSteamID = 0;
	//char gS_map[192];
	int iTrack = -1;
	char sTrack[32];
	
	if(results.FetchRow())
	{
		iTrack = results.FetchInt(11);
		iSteamID = results.FetchInt(4);
		results.FetchString(0, sName, MAX_NAME_LENGTH);
		results.FetchString(13, sPName, MAX_NAME_LENGTH);
		iPSteamID = results.FetchInt(14);
		results.FetchString(6, gS_map, 192);
		
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
			FormatEx(sRanks, 16, "Rank: #%d/%d", gI_rank[client], gI_records[client]);
			
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
			
			FormatEx(sFormattedTitle, 512, "%s [U:1:%d]\n--- %s: [%s]\n \n%s\n%s\n \n%s\n%s\n \n%s\n%s\n \n%s\n \n%s\n%s\n ", sName, iSteamID, gS_map, sTrack, sDisplayFirstDate, sDisplayDate, sRanks, sDisplayPoints, sDisplayTime, sDisplayCompletions, sDisplayStyle, sDisplayJumps, sDisplayStrafes);
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
			FormatEx(sRanks, 16, "Rank: #%d/%d", gI_rank[client], gI_records[client]);
			
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
			
			FormatEx(sFormattedTitle, 512, "%s & %s\n[U:1:%d] [U:1:%d]\n--- %s: [%s]\n \n%s\n%s\n \n%s\n%s\n \n%s\n%s\n \n%s\n \n%s\n%s\n%s\n ", sName, sPName, iSteamID, iPSteamID, gS_map, sTrack, sDisplayFirstDate, sDisplayDate, sRanks, sDisplayPoints, sDisplayTime, sDisplayCompletions, sDisplayStyle, sDisplayJumps, sDisplayStrafes, sDisplayNades);
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

public int RecordDetail_Handler(Menu menu, MenuAction action, int param1, int param2)
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
					OpenStatsMenu(param1, StringToInt(sExploded[1]));
				}

				case 1:
				{
					OpenDeleteMenu(param1, StringToInt(sExploded[1]));
				}
				
				case 2:
				{
					if(gB_MyWorldRecordsQuery[param1])
					{
						MyWorldRecordsQuery(param1);
					}
					
					if(gB_OpenStatsMenuMC[param1])
					{
						OpenStatsMenuMC(param1);
					}
					
					if(gB_ShowMapsLeft[param1])
					{
						ShowMapsLeft(param1);
					}
				}
			}
		}

		else
		{
			if(gB_MyWorldRecordsQuery[param1])
			{
				MyWorldRecordsQuery(param1);
			}
			
			if(gB_OpenStatsMenuMC[param1])
			{
				OpenStatsMenuMC(param1);
			}
			
			if(gB_ShowMapsLeft[param1])
			{
				ShowMapsLeft(param1);
			}
		}
	}

	if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenStatsMenuMC(int client)
{
	// no spam please
	if(!gB_CanOpenMenu[client])
	{
		//return Plugin_Handled;
	}
	
	gB_MyWorldRecordsQuery[client] = false;
	gB_OpenStatsMenuMC[client] = true;
	gB_ShowMapsLeft[client] = false;
	
	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT ax.clears, bx.maps FROM " ...
			"(SELECT COUNT(*) clears FROM (SELECT map FROM %splayertimes WHERE (auth = %d OR partner = %d) AND style = %d AND track = %d GROUP BY map) sx) ax " ...
			"JOIN (SELECT COUNT(*) maps FROM (SELECT map FROM %smapzones WHERE track = %d AND type = 0 GROUP BY map) sx) bx "...
			"LIMIT 1;",
			gS_MySQLPrefix, gI_TargetSteamID[client], gI_TargetSteamID[client], gI_Style[client], gI_Track[client], gS_MySQLPrefix, gI_Track[client]);
	
	gH_SQL.Query(SQL_GetClearsOpenStatsMenuMC_Callback, sQuery, GetClientSerial(client), DBPrio_High);

	gB_CanOpenMenu[client] = false;
}

public void SQL_GetClearsOpenStatsMenuMC_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);

	if(results == null)
	{
		LogError("Timer (SQL_GetClearsOpenStatsMenuMC_Callback) SQL query failed. Reason: %s", error);

		return;
	}

	if(client == 0)
	{
		return;
	}
	
	if(results.FetchRow())
	{
		gI_clears[client] = results.FetchInt(0);
		gI_TotalMaps[client] = results.FetchInt(1);
		
		if(gI_clears[client] > gI_TotalMaps[client])
		{
			gI_clears[client] = gI_TotalMaps[client];
		}
		
		if(gI_Style[client] == 0 && gI_Track[client] == 0)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 0 && gI_Track[client] == 2)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapBonusCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 0 && gI_Track[client] == 4)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapSolobonusCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 1 && gI_Track[client] == 0)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapSWCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 1 && gI_Track[client] == 2)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapBonusSWCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 1 && gI_Track[client] == 4)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapSolobonusSWCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 2 && gI_Track[client] == 0)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapWCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 2 && gI_Track[client] == 2)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapBonusWCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 2 && gI_Track[client] == 4)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapSolobonusWCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 3 && gI_Track[client] == 0)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapHSWCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 3 && gI_Track[client] == 2)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapBonusHSWCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		if(gI_Style[client] == 3 && gI_Track[client] == 4)
		{
			FormatEx(sClearString[client], 128, "%T: %d/%d (%.01f%%)", "MapSolobonusHSWCompletions", client, gI_clears[client], gI_TotalMaps[client], ((float(gI_clears[client]) / gI_TotalMaps[client]) * 100.0));
		}
		
		char sQuery[2048];
		FormatEx(sQuery, 2048,
			"SELECT * FROM ("...
			"SELECT a.map, a.time, a.jumps, a.id, COUNT(b.map) + 1 rank, a.points "...
			"FROM %splayertimes a LEFT JOIN %splayertimes b ON a.time > b.time AND a.map = b.map "...
			"AND a.style = b.style AND a.track = b.track "...
			"WHERE (a.auth = %d OR a.partner = %d) AND a.style = %d AND a.track = %d "...
			"GROUP BY a.map, a.time, a.jumps, a.id, a.points "...
			"ORDER BY a.%s "...
			") t "...
			"GROUP BY map;",
			gS_MySQLPrefix, gS_MySQLPrefix, gI_TargetSteamID[client], gI_TargetSteamID[client], gI_Style[client], gI_Track[client], (gB_Rankings)? "points DESC":"map");
			
		gH_SQL.Query(SQL_OpenStatsMenuMC_Callback, sQuery, GetClientSerial(client), DBPrio_High);
	}
}

public void SQL_OpenStatsMenuMC_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);

	if(results == null)
	{
		LogError("Timer (SQL_MC) SQL query failed. Reason: %s", error);

		return;
	}

	if(client == 0)
	{
		return;
	}
	
	Menu menu = new Menu(MenuHandler_MC);
	menu.SetTitle("%s [U:1:%d]\n%s\n ", gS_TargetName[client], gI_TargetSteamID[client], sClearString[client]);

	while(results.FetchRow())
	{		
		int id = results.FetchInt(3);
		results.FetchString(0, gS_map, 192);
		
		char sID[16];
		IntToString(id, sID, 16);
		
		// 2 - time
		float time = results.FetchFloat(1);
		char sTime[16];
		FormatSeconds(time, sTime, 16);
		
		// 3 - jumps
		int jumps = results.FetchInt(2);
		
		int rank = results.FetchInt(4);
		char sRank[16];
		IntToString(rank, sRank, 16);
		
		//float points = results.FetchFloat(5);
		
		char sDisplay[128];
		
		if(gI_Track[client] == 4)
		{
			//FormatEx(sDisplay, 128, "[#%d] %s - %s (%d %T) (%.03f %T)", rank, gS_map, sTime, jumps, "WRJumps", client, points, "MapsPoints", client);
			FormatEx(sDisplay, 128, "[#%d] %s - %s (%d %T)", rank, gS_map, sTime, jumps, "WRJumps", client);
		}
		
		else
		{
			//FormatEx(sDisplay, 128, "[#%d] %s - %s (%.03f %T)", rank, gS_map, sTime, points, "MapsPoints", client);
			FormatEx(sDisplay, 128, "[#%d] %s - %s", rank, gS_map, sTime);
		}
		
		char sID_sRank_gS_map[192];
		Format(sID_sRank_gS_map, 192, "%s;%s;%s", sID, sRank, gS_map);
		
		menu.AddItem(sID_sRank_gS_map, sDisplay);
	}
	
	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "NoResults", client);
		menu.AddItem("nope", sMenuItem, ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MC(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, 32);
		
		if(StrEqual(sInfo, "nope"))
		{	
			ShowWRStyleMenu(param1, gI_Track[param1]);

			return 0;
		}
		
		else
		{			
			if(gI_id[param1] != -1)
			{
				char sExploded[3][192];
				ExplodeString(sInfo, ";", sExploded, 3, 192, true);
				gI_id[param1] = StringToInt(sExploded[0]);
				gI_rank[param1] = StringToInt(sExploded[1]);
				
				char sMap[192];
				Format(sMap, 192, "%s", sExploded[2]);
				
				char sQuery[512];
				FormatEx(sQuery, 512,
					"SELECT * FROM %splayertimes "...
					"WHERE style = %d AND track = %d AND map = '%s';",
					gS_MySQLPrefix, gI_Style[param1], gI_Track[param1], sMap);
				
				gH_SQL.Query(SQL_OpenStatsMenuMC_AllRecords_Callback, sQuery, GetClientSerial(param1), DBPrio_High);
			}
		}
	}
	
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowWRStyleMenu(param1, gI_Track[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_OpenStatsMenuMC_AllRecords_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (SQL_OpenStatsMenuMC_AllRecords_Callback) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(data);
	
	if(client == 0)
	{
		return;
	}
	
	gI_records[client] = results.RowCount;
	
	OpenRecordsDetails(client);
}

void ShowMapsLeft(int client)
{
	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT ax.clears, bx.maps FROM " ...
			"(SELECT COUNT(*) clears FROM (SELECT map FROM %splayertimes WHERE (auth = %d OR partner = %d) AND style = %d AND track = %d GROUP BY map) sx) ax " ...
			"JOIN (SELECT COUNT(*) maps FROM (SELECT map FROM %smapzones WHERE track = %d AND type = 0 GROUP BY map) sx) bx "...
			"LIMIT 1;",
			gS_MySQLPrefix, gI_TargetSteamID[client], gI_TargetSteamID[client], gI_Style[client], gI_Track[client], gS_MySQLPrefix, gI_Track[client]);
	
	gH_SQL.Query(SQL_GetTotalMaps_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_GetTotalMaps_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (SQL_GetTotalMaps_Callback SELECT) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}
	
	if(results.FetchRow())
	{
		gI_clears[client] = results.FetchInt(0);
		gI_TotalMaps[client] = results.FetchInt(1);
		
		if(gI_clears[client] > gI_TotalMaps[client])
		{
			gI_clears[client] = gI_TotalMaps[client];
		}
		
		ShowMapsLeft2(client);
	}
}
		
void ShowMapsLeft2(int client)
{
	char sQuery[512];
	
	if(gB_Rankings)
	{
		FormatEx(sQuery, 512,
			"SELECT DISTINCT m.map, t.tier FROM %smapzones m LEFT JOIN %smaptiers t ON m.map = t.map WHERE m.type = 0 AND m.track = %d AND m.map NOT IN (SELECT DISTINCT map FROM %splayertimes WHERE (auth = %d OR partner = %d) AND style = %d AND track = %d) ORDER BY m.map;",
			gS_MySQLPrefix, gS_MySQLPrefix, gI_Track[client], gS_MySQLPrefix, gI_TargetSteamID[client], gI_TargetSteamID[client], gI_Style[client], gI_Track[client]);
	}

	else
	{
		FormatEx(sQuery, 512,
			"SELECT DISTINCT map FROM %smapzones WHERE type = 0 AND track = %d AND map NOT IN (SELECT DISTINCT map FROM %splayertimes WHERE (auth = %d OR partner = %d) AND style = %d AND track = %d) ORDER BY map;",
			gS_MySQLPrefix, gI_Track[client], gS_MySQLPrefix, gI_TargetSteamID[client], gI_TargetSteamID[client], gI_Style[client], gI_Track[client]);
	}
	
	gH_SQL.Query(ShowMapsLeftCallback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void ShowMapsLeftCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (ShowMapsLeft SELECT) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	gB_CanOpenMenu[client] = true;

	int rows = results.RowCount;

	char sTrack[32];
	GetTrackName(client, gI_Track[client], sTrack, 32);

	Menu menu = new Menu(MenuHandler_ShowMapsLeft);
	
	if(gI_Style[client] == 0 && gI_Track[client] == 0)
	{
		Format(sClearString[client], 128, "Maps left: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 1 && gI_Track[client] == 0)
	{
		Format(sClearString[client], 128, "Maps left sideways: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 2 && gI_Track[client] == 0)
	{
		FormatEx(sClearString[client], 128, "Maps left w-only: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 3 && gI_Track[client] == 0)
	{
		FormatEx(sClearString[client], 128, "Maps left half-sideways: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 0 && gI_Track[client] == 2)
	{
		FormatEx(sClearString[client], 128, "Maps left bonus: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 1 && gI_Track[client] == 2)
	{
		FormatEx(sClearString[client], 128, "Maps left bonus sideways: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 2 && gI_Track[client] == 2)
	{
		FormatEx(sClearString[client], 128, "Maps left bonus w-only: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 3 && gI_Track[client] == 2)
	{
		FormatEx(sClearString[client], 128, "Maps left bonus half-sideways: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 0 && gI_Track[client] == 4)
	{
		FormatEx(sClearString[client], 128, "Maps left solobonus: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 1 && gI_Track[client] == 4)
	{
		FormatEx(sClearString[client], 128, "Maps left solobonus sideways: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 2 && gI_Track[client] == 4)
	{
		FormatEx(sClearString[client], 128, "Maps left solobonus w-only: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	if(gI_Style[client] == 3 && gI_Track[client] == 4)
	{
		FormatEx(sClearString[client], 128, "Maps left solobonus half-sideways: %i/%i (%.01f%%)", rows, gI_TotalMaps[client], ((float(rows) / gI_TotalMaps[client]) * 100.0));
	}
	
	menu.SetTitle("%s [U:1:%d]\n%s\n ", gS_TargetName[client], gI_TargetSteamID[client], sClearString[client]);

	while(results.FetchRow())
	{
		//char gS_map[192];
		results.FetchString(0, gS_map, 192);

		char sRecordID[192];
		char sDisplay[256];

		strcopy(sDisplay, 192, gS_map);

		if(gB_Rankings)
		{
			int iTier = results.FetchInt(1);

			if(results.IsFieldNull(1) || iTier == 0)
			{
				iTier = 1;
			}

			Format(sDisplay, 192, "%s (Tier %d)", gS_map, iTier);
		}

		strcopy(sRecordID, 192, gS_map);

		menu.AddItem(sRecordID, sDisplay);
	}

	if(menu.ItemCount == 0)
	{
		char sMenuItem[64];
		FormatEx(sMenuItem, 64, "%T", "NoResults", client);
		menu.AddItem("nope", sMenuItem, ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ShowMapsLeft(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[192];
		menu.GetItem(param2, sInfo, 192);

		if(StrEqual(sInfo, "nope"))
		{	
			ShowWRStyleMenu(param1, gI_Track[param1]);

			return 0;
		}

		else if(StringToInt(sInfo) == 0)
		{
			FakeClientCommand(param1, "sm_nominate %s", sInfo);

			return 0;
		}
	}

	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		ShowWRStyleMenu(param1, gI_Track[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public int MenuHandler_ProfileHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];

		menu.GetItem(param2, sInfo, 32);
		
		gI_Style[param1] = StringToInt(sInfo);
		
		if(StrEqual(sInfo, "sm_mywr"))
		{
			gB_MyWorldRecordsQuery[param1] = true;
			gB_OpenStatsMenuMC[param1] = false;
			gB_ShowMapsLeft[param1] = false;
			TrackMenu(param1);
		}
		
		if(StrEqual(sInfo, "sm_mc"))
		{
			gB_MyWorldRecordsQuery[param1] = false;
			gB_OpenStatsMenuMC[param1] = true;
			gB_ShowMapsLeft[param1] = false;
			TrackMenu(param1);
		}
		
		if(StrEqual(sInfo, "sm_mapsleft"))
		{
			gB_MyWorldRecordsQuery[param1] = false;
			gB_OpenStatsMenuMC[param1] = false;
			gB_ShowMapsLeft[param1] = true;
			TrackMenu(param1);
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

		//char gS_map[160];
		results.FetchString(2, gS_map, 160);

		float fTime = results.FetchFloat(3);
		float fSync = results.FetchFloat(4);
		float fPerfectJumps = results.FetchFloat(5);

		int iJumps = results.FetchInt(6);
		int iStrafes = results.FetchInt(7);
		int iRecordID = results.FetchInt(8);
		int iTimestamp = results.FetchInt(9);
		
		int iStyle = gI_Style[client];
		int iTrack = gI_Track[client];
		bool bWRDeleted = Shavit_GetWRRecordID(iStyle, iRecordID, iTrack);

		// that's a big datapack ya yeet
		DataPack hPack = new DataPack();
		hPack.WriteCell(GetClientSerial(client));
		hPack.WriteCell(iSteamID);
		hPack.WriteString(sName);
		hPack.WriteString(gS_map);
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

public void DeleteConfirm_Callback(Database db, DBResultSet results, const char[] error, DataPack hPack)
{
	hPack.Reset();

	int client = GetClientFromSerial(hPack.ReadCell());
	int iSteamID = hPack.ReadCell();

	char sName[MAX_NAME_LENGTH];
	hPack.ReadString(sName, MAX_NAME_LENGTH);

	//char gS_map[160];
	hPack.ReadString(gS_map, 160);

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

	Shavit_UpdateWRCache();
	
	for(int i = 1; i <= MaxClients; i++)
	{
		OnClientPutInServer(i);
	}
	
	char sTrack[32];
	GetTrackName(LANG_SERVER, iTrack, sTrack, 32);

	char sDate[32];
	FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", iTimestamp);

	// above the client == 0 so log doesn't get lost if admin disconnects between deleting record and query execution
	Shavit_LogMessage("%L - deleted record. Runner: %s ([U:1:%d]) | Map: %s | Style: %s | Track: %s | Time: %.2f (%s) | Strafes: %d (%.1f%%) | Jumps: %d (%.1f%%) | Run date: %s | Record ID: %d",
		client, sName, iSteamID, gS_map, gS_StyleStrings[iStyle].sStyleName, sTrack, fTime, (bWRDeleted)? "WR":"not WR", iStrafes, fSync, iJumps, fPerfectJumps, sDate, iRecordID);

	if(client == 0)
	{
		return;
	}

	Shavit_PrintToChat(client, "%T", "DeletedRecord", client);
}

public int Native_OpenStatsMenu(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	gI_TargetSteamID[client] = GetNativeCell(2);

	OpenStatsMenu(client, gI_TargetSteamID[client]);
}

public int Native_GetWRCount(Handle handler, int numParams)
{
	return gI_WRAmount[GetNativeCell(1)];
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
