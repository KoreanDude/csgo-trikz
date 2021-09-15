/*
 * shavit's Timer - Miscellaneous
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
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#undef REQUIRE_EXTENSIONS
#include <dhooks>
#include <SteamWorks>
#include <cstrike>

#undef REQUIRE_PLUGIN
#include <shavit>
#include <trikz>

#pragma newdecls required
#pragma semicolon 1

bool gB_Late = false;
int gI_GroundEntity[MAXPLAYERS + 1];
char gS_CurrentMap[192];
int gI_Style[MAXPLAYERS + 1];
bool gB_GorundFirst[MAXPLAYERS + 1];
int gI_tick[MAXPLAYERS + 1];
int gI_movetype[MAXPLAYERS + 1];
float gF_speed[MAXPLAYERS + 1][3];
float gF_speedXY[MAXPLAYERS + 1];
bool gB_OnGround[MAXPLAYERS + 1];

// cvars
ConVar gCV_PreSpeed = null;
ConVar gCV_HideTeamChanges = null;
ConVar gCV_PrestrafeLimit = null;
ConVar gCV_Scoreboard = null;
ConVar gCV_StaticPrestrafe = null;
ConVar gCV_ClanTag = null;
ConVar gCV_ResetTargetname = null;
ConVar gCV_SpectatorList = null;
ConVar gCV_WRMessages = null;

// forwards
Handle gH_Forwards_OnClanTagChangePre = null;
Handle gH_Forwards_OnClanTagChangePost = null;

// dhooks
Handle gH_GetPlayerMaxSpeed = null;

// modules
bool gB_Rankings = false;
bool gB_Replay = false;

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
stylesettings_t gA_StyleSettings[STYLE_LIMIT];

// chat settings
chatstrings_t gS_ChatStrings;

// #define DEBUG

// Avoid solobonus exploits
bool g_groundBoost[MAXPLAYERS + 1];
bool g_bouncedOff[2048];

public Plugin myinfo =
{
	name = "[shavit] Miscellaneous",
	author = "shavit, sejiya, Smesh",
	description = "Miscellaneous features for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public void OnPluginStart()
{
	// forwards
	gH_Forwards_OnClanTagChangePre = CreateGlobalForward("Shavit_OnClanTagChangePre", ET_Event, Param_Cell, Param_String, Param_Cell);
	gH_Forwards_OnClanTagChangePost = CreateGlobalForward("Shavit_OnClanTagChangePost", ET_Event, Param_Cell, Param_String, Param_Cell);

	// spectator list
	RegConsoleCmd("sm_specs", Command_Specs, "Show a list of spectators.");
	RegConsoleCmd("sm_spectators", Command_Specs, "Show a list of spectators.");
	RegConsoleCmd("sm_nc", Command_Noclip, "Toggles noclip.");

	// hooks
	HookEvent("player_spawn", Player_Spawn);
	HookEvent("player_team", Player_Notifications, EventHookMode_Pre);
	HookEvent("player_death", Player_Notifications, EventHookMode_Pre);
	AddCommandListener(Command_Spec, "spectate");
	AddCommandListener(Listener_JoinClass, "joinclass");

	// phrases
	LoadTranslations("common.phrases");
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-misc.phrases");

	// cvars and stuff
	gCV_PreSpeed = CreateConVar("shavit_misc_prespeed", "3", "Stop prespeeding in the start zone?\n0 - Disabled, fully allow prespeeding.\n1 - Limit relatively to prestrafelimit.\n2 - Block bunnyhopping in startzone.\n3 - Limit to prestrafelimit and block bunnyhopping.\n4 - Limit to prestrafelimit but allow prespeeding. Combine with shavit_core_nozaxisspeed 1 for SourceCode timer's behavior.", 0, true, 0.0, true, 4.0);
	gCV_HideTeamChanges = CreateConVar("shavit_misc_hideteamchanges", "1", "Hide team changes in chat?\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_PrestrafeLimit = CreateConVar("shavit_misc_prestrafelimit", "30", "Prestrafe limitation in startzone.\nThe value used internally is style run speed + this.\ni.e. run speed of 250 can prestrafe up to 278 (+28) with regular settings.", 0, true, 0.0, false);
	gCV_Scoreboard = CreateConVar("shavit_misc_scoreboard", "1", "Manipulate scoreboard so score is -{time} and deaths are {rank})?\nDeaths part requires shavit-rankings.\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_StaticPrestrafe = CreateConVar("shavit_misc_staticprestrafe", "1", "Force prestrafe for every pistol.\n250 is the default value and some styles will have 260.\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_ClanTag = CreateConVar("shavit_misc_clantag", "{tr}{styletag} :: {time}", "Custom clantag for players.\n0 - Disabled\n{styletag} - style tag.\n{style} - style name.\n{time} - formatted time.\n{tr} - first letter of track.\n{rank} - player rank.", 0);
	gCV_ResetTargetname = CreateConVar("shavit_misc_resettargetname", "0", "Reset the player's targetname upon timer start?\nRecommended to leave disabled. Enable via per-map configs when necessary.\n0 - Disabled\n1 - Enabled", 0, true, 0.0, true, 1.0);
	gCV_SpectatorList = CreateConVar("shavit_misc_speclist", "1", "Who to show in !specs?\n0 - everyone\n1 - all admins (admin_speclisthide override to bypass)\n2 - players you can target", 0, true, 0.0, true, 2.0);
	gCV_WRMessages = CreateConVar("shavit_misc_wrmessages", "1", "How many \"NEW <style> WR!!!\" messages to print?\n0 - Disabled", 0,  true, 0.0, true, 100.0);

	AutoExecConfig();

	CreateTimer(1.0, Timer_Scoreboard, 0, TIMER_REPEAT);

	if(LibraryExists("dhooks"))
	{
		Handle hGameData = LoadGameConfigFile("shavit.games");

		if(hGameData != null)
		{
			int iOffset = GameConfGetOffset(hGameData, "CCSPlayer::GetPlayerMaxSpeed");

			if(iOffset != -1)
			{
				gH_GetPlayerMaxSpeed = DHookCreate(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, CCSPlayer__GetPlayerMaxSpeed);
			}

			else
			{
				SetFailState("Couldn't get the offset for \"CCSPlayer::GetPlayerMaxSpeed\" - make sure your gamedata is updated!");
			}
		}

		delete hGameData;
	}

	// late load
	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);

				if(AreClientCookiesCached(i))
				{
					OnClientCookiesCached(i);
				}
			}
		}
	}

	// modules
	gB_Rankings = LibraryExists("shavit-rankings");
	gB_Replay = LibraryExists("shavit-replay");
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}

	gI_Style[client] = Shavit_GetBhopStyle(client);
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
		Shavit_GetStyleStrings(i, sClanTag, gS_StyleStrings[i].sClanTag, sizeof(stylestrings_t::sClanTag));
		Shavit_GetStyleStrings(i, sSpecialString, gS_StyleStrings[i].sSpecialString, sizeof(stylestrings_t::sSpecialString));
	}
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessagePrefix, gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix));
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	Shavit_GetChatStrings(sMessageWarning, gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
	Shavit_GetChatStrings(sMessageVariable2, gS_ChatStrings.sVariable2, sizeof(chatstrings_t::sVariable2));
	Shavit_GetChatStrings(sMessageStyle, gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle));
	Shavit_GetChatStrings(sMessageOrange, gS_ChatStrings.sOrange, sizeof(chatstrings_t::sOrange));
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	gI_Style[client] = newstyle;
}

public void OnMapStart()
{
	GetCurrentMap(gS_CurrentMap, 192);

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(-1);
		Shavit_OnChatConfigLoaded();
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = true;
	}

	else if(StrEqual(name, "shavit-replay"))
	{
		gB_Replay = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = false;
	}

	else if(StrEqual(name, "shavit-replay"))
	{
		gB_Replay = false;
	}
}
/*
public MRESReturn CCSPlayer__GetPlayerMaxSpeed(int pThis, DHookReturn hReturn)
{
	if(!gCV_StaticPrestrafe.BoolValue || !IsValidClient(pThis, true))
	{
		return MRES_Ignored;
	}
	
	float fSpeed[3];
	GetEntPropVector(pThis, Prop_Data, "m_vecVelocity", fSpeed);
	float fxyspeed = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));
	
	if(fxyspeed > 250.000000)
	{
		DHookSetReturn(hReturn, view_as<float>(gA_StyleSettings[gI_Style[pThis]].fRunspeed));
		
		return MRES_Override;
	}

	return MRES_Ignored;
}
*/
public MRESReturn CCSPlayer__GetPlayerMaxSpeed(int pThis, DHookReturn hReturn)
{
	if(!gCV_StaticPrestrafe.BoolValue || !IsValidClient(pThis, true))
	{
		return MRES_Ignored;
	}

	DHookSetReturn(hReturn, view_as<float>(gA_StyleSettings[gI_Style[pThis]].fRunspeed));

	return MRES_Override;
}

public Action Timer_Scoreboard(Handle Timer)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || IsFakeClient(i))
		{
			continue;
		}

		if(gCV_Scoreboard.BoolValue)
		{
			UpdateScoreboard(i);
		}

		UpdateClanTag(i);
	}

	return Plugin_Continue;
}

void UpdateScoreboard(int client)
{
	SetEntProp(client, Prop_Data, "m_iFrags", 0);
	
	if(gB_Rankings)
	{
		SetEntProp(client, Prop_Data, "m_iDeaths", Shavit_GetRank(client));
	}
}

void UpdateClanTag(int client)
{
	// no clan tags in tf2
	char sTag[32];
	gCV_ClanTag.GetString(sTag, 32);

	if(StrEqual(sTag, "0"))
	{
		return;
	}

	char sTime[16];

	float fTime = Shavit_GetClientTime(client);

	if(Shavit_GetTimerStatus(client) == Timer_Stopped || fTime < 1.0)
	{
		strcopy(sTime, 16, "N/A");
	}

	else
	{
		int time = RoundToFloor(fTime);

		if(time < 60)
		{
			IntToString(time, sTime, 16);
		}

		else
		{
			int minutes = (time / 60);
			int seconds = (time % 60);

			if(time < 3600)
			{
				FormatEx(sTime, 16, "%d:%s%d", minutes, (seconds < 10)? "0":"", seconds);
			}

			else
			{
				minutes %= 60;

				FormatEx(sTime, 16, "%d:%s%d:%s%d", (time / 3600), (minutes < 10)? "0":"", minutes, (seconds < 10)? "0":"", seconds);
			}
		}
	}

	int track = Shavit_GetClientTrack(client);
	char sTrack[3];

	if(track != Track_Main)
	{
		GetTrackName(client, track, sTrack, 3);
	}

	char sRank[8];

	if(gB_Rankings)
	{
		IntToString(Shavit_GetRank(client), sRank, 8);
	}

	char sCustomTag[32];
	strcopy(sCustomTag, 32, sTag);
	ReplaceString(sCustomTag, 32, "{style}", gS_StyleStrings[gI_Style[client]].sStyleName);
	ReplaceString(sCustomTag, 32, "{styletag}", gS_StyleStrings[gI_Style[client]].sClanTag);
	ReplaceString(sCustomTag, 32, "{time}", sTime);
	ReplaceString(sCustomTag, 32, "{tr}", sTrack);
	ReplaceString(sCustomTag, 32, "{rank}", sRank);

	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_OnClanTagChangePre);
	Call_PushCell(client);
	Call_PushStringEx(sTag, 32, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(32);
	Call_Finish(result);
	
	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return;
	}

	CS_SetClientClanTag(client, sCustomTag);

	Call_StartForward(gH_Forwards_OnClanTagChangePost);
	Call_PushCell(client);
	Call_PushStringEx(sCustomTag, 32, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(32);
	Call_Finish();
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style, stylesettings_t stylesettings)
{
	int iPartner = Trikz_FindPartner(client);
	
	// i will not be adding a setting to toggle this off
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		Shavit_StopTimer(client);
	}
	
	if(iPartner != -1)
	{
		gB_OnGround[client] = view_as<bool>(GetEntityFlags(client) & FL_ONGROUND);
		
		if(!gB_OnGround[client])
		{
			gI_movetype[client] = view_as<int>(GetEntityMoveType(client));
			
			if(gI_movetype[client] == view_as<int>(MOVETYPE_NOCLIP) && !gB_GorundFirst[client])
			{			
				gB_GorundFirst[client] = true;
			}
			
			if(gI_movetype[client] == view_as<int>(MOVETYPE_WALK) 
				&& Shavit_InsideZone(client, Zone_Start, track) && Shavit_InsideZone(iPartner, Zone_Start, track) && gB_GorundFirst[client])
			{
				if(gI_tick[client] == 0)
				{
					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
					Shavit_PrintToChat(client, "%T", "NCStartZoneDisallowed", client, gS_ChatStrings.sVariable, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
					gI_tick[client]++;
				}
			}
		}
		
		else
		{
			if(gB_GorundFirst[client])
			{
				GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", gF_speed[client]);
				gF_speedXY[client] = (SquareRoot(Pow(gF_speed[client][0], 2.0) + Pow(gF_speed[client][1], 2.0)));
				
				if(gF_speedXY[client] <= 250.0)
				{
					gB_GorundFirst[client] = false;
				}
				
				gI_movetype[client] = view_as<int>(GetEntityMoveType(client));
				gI_tick[client] = 0;
			}
		}
	}

	/*int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");

	// prespeed
	//if(!bNoclip && gA_StyleSettings[gI_Style[client]].iPrespeed == 0 && Shavit_InsideZone(client, Zone_Start, track))
	if(!bNoclip && gA_StyleSettings[gI_Style[client]].iPrespeed == 0 && Shavit_InsideZone(client, Zone_Start, Track_Solobonus))
	{
		if((gCV_PreSpeed.IntValue == 2 || gCV_PreSpeed.IntValue == 3) && gI_GroundEntity[client] == -1 && iGroundEntity != -1 && (buttons & IN_JUMP) > 0)
		{
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
			Shavit_PrintToChat(client, "%T", "BHStartZoneDisallowed", client, gS_ChatStrings.sVariable, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);

			gI_GroundEntity[client] = iGroundEntity;

			return Plugin_Continue;
		}

		if(gCV_PreSpeed.IntValue == 1 || gCV_PreSpeed.IntValue >= 3)
		{
			float fSpeed[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fSpeed);

			float fLimit = (gA_StyleSettings[gI_Style[client]].fRunspeed + gCV_PrestrafeLimit.FloatValue);

			// if trying to jump, add a very low limit to stop prespeeding in an elegant way
			// otherwise, make sure nothing weird is happening (such as sliding at ridiculous speeds, at zone enter)
			if(gCV_PreSpeed.IntValue < 4 && fSpeed[2] > 0.0)
			{
				fLimit /= 3.0;
			}

			float fSpeedXY = (SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)));
			float fScale = (fLimit / fSpeedXY);

			if(fScale < 1.0)
			{
				ScaleVector(fSpeed, fScale);
			}

			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fSpeed);
		}
	}

	gI_GroundEntity[client] = iGroundEntity;*/

	return Plugin_Continue;
}

public void Shavit_OnLeaveZone(int client, int type, int track, int id, int entity, int data)
{
	bool bNoclip = (GetEntityMoveType(client) == MOVETYPE_NOCLIP);
	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");

	// prespeed
	if(!bNoclip && gA_StyleSettings[gI_Style[client]].iPrespeed == 0 && type == Zone_Start && track == Track_Solobonus)
	{
		if((gCV_PreSpeed.IntValue == 2 || gCV_PreSpeed.IntValue == 3) && gI_GroundEntity[client] == -1 && iGroundEntity != -1 && (GetClientButtons(client) & IN_JUMP) > 0)
		{
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
			Shavit_PrintToChat(client, "%T", "BHStartZoneDisallowed", client, gS_ChatStrings.sVariable, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);

			gI_GroundEntity[client] = iGroundEntity;
		}

		if(gCV_PreSpeed.IntValue == 1 || gCV_PreSpeed.IntValue >= 3)
		{
			float fSpeed[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fSpeed);

			float fLimit = (gA_StyleSettings[gI_Style[client]].fRunspeed + gCV_PrestrafeLimit.FloatValue);

			// if trying to jump, add a very low limit to stop prespeeding in an elegant way
			// otherwise, make sure nothing weird is happening (such as sliding at ridiculous speeds, at zone enter)
			if(gCV_PreSpeed.IntValue < 4 && fSpeed[2] > 0.0)
			{
				fLimit /= 3.0;
			}

			float fSpeedXY = (SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)));
			float fScale = (fLimit / fSpeedXY);

			if(fScale < 1.0)
			{
				ScaleVector(fSpeed, fScale);
			}

			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fSpeed);
		}
	}

	gI_GroundEntity[client] = iGroundEntity;
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}

	if(!AreClientCookiesCached(client))
	{
		gI_Style[client] = Shavit_GetBhopStyle(client);
	}

	if(gH_GetPlayerMaxSpeed != null)
	{
		DHookEntity(gH_GetPlayerMaxSpeed, true, client);
	}
}

public Action Command_Noclip(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}

	if(GetEntityMoveType(client) != MOVETYPE_NOCLIP)
	{
		Shavit_StopTimer(client);
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
	}

	else
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
	}

	return Plugin_Handled;
}

//public Action Command_Spec(int client, int args)
Action Command_Spec(int client, const char[] command, int argc)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	ChangeClientTeam(client, 1);

	int target = -1;
	int partner = Trikz_FindPartner(client);
	
	//if(args > 0)
	if(argc > 0)
	{
		char sArgs[MAX_TARGET_LENGTH];
		GetCmdArgString(sArgs, MAX_TARGET_LENGTH);

		target = FindTarget(client, sArgs, false, false);

		if(target == -1)
		{
			return Plugin_Handled;
		}
	}

	else if(gB_Replay && partner == -1)
	{
		//target = Shavit_GetReplayBotIndex(0);
		target = Shavit_GetReplayBotIndex(0, 0, Track_Main);
	}
	
	else if(partner != -1)
	{
		target = partner;
	}

	if(IsValidClient(target, true))
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
	}

	return Plugin_Handled;
}

Action Listener_JoinClass(int client, const char[] command, int argc)
{
	RequestFrame(Frame_Respawn, client);
}

void Frame_Respawn(int client)
{
	CS_RespawnPlayer(client);
	RequestFrame(Frame_DropSpeed, client);
}

void Frame_DropSpeed(int client)
{
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
}

public Action Command_Specs(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client) && !IsClientObserver(client))
	{
		Shavit_PrintToChat(client, "%T", "SpectatorInvalid", client);

		return Plugin_Handled;
	}

	int iObserverTarget = client;

	if(IsClientObserver(client))
	{
		iObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	}

	if(args > 0)
	{
		char sTarget[MAX_TARGET_LENGTH];
		GetCmdArgString(sTarget, MAX_TARGET_LENGTH);

		int iNewTarget = FindTarget(client, sTarget, false, false);

		if(iNewTarget == -1)
		{
			return Plugin_Handled;
		}

		if(!IsPlayerAlive(iNewTarget))
		{
			Shavit_PrintToChat(client, "%T", "SpectateDead", client, gS_ChatStrings.sWarning, gS_ChatStrings.sText);

			return Plugin_Handled;
		}

		iObserverTarget = iNewTarget;
	}

	int iCount = 0;
	bool bIsAdmin = CheckCommandAccess(client, "admin_speclisthide", ADMFLAG_KICK);
	char sSpecs[192];

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || IsFakeClient(i) || !IsClientObserver(i) || GetClientTeam(i) < 1)
		{
			continue;
		}

		if((gCV_SpectatorList.IntValue == 1 && !bIsAdmin && CheckCommandAccess(i, "admin_speclisthide", ADMFLAG_KICK)) ||
			(gCV_SpectatorList.IntValue == 2 && !CanUserTarget(client, i)))
		{
			continue;
		}

		if(GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == iObserverTarget)
		{
			iCount++;

			if(iCount == 1)
			{
				FormatEx(sSpecs, 192, "%s%N", gS_ChatStrings.sOrange, i);
			}

			else
			{
				Format(sSpecs, 192, "%s%s, %s%N", sSpecs, gS_ChatStrings.sText, gS_ChatStrings.sOrange, i);
			}
		}
	}

	if(iCount > 0)
	{
		Shavit_PrintToChat(client, "%T", "SpectatorCount", client, gS_ChatStrings.sOrange, iObserverTarget, gS_ChatStrings.sText, gS_ChatStrings.sOrange, iCount, gS_ChatStrings.sText, sSpecs);
	}

	else
	{
		Shavit_PrintToChat(client, "%T", "SpectatorCountZero", client, gS_ChatStrings.sOrange, iObserverTarget, gS_ChatStrings.sText);
	}

	return Plugin_Handled;
}

public Action Shavit_OnStart(int client)
{
	if(gA_StyleSettings[gI_Style[client]].iPrespeed == 0 && GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		return Plugin_Stop;
	}

	if(gCV_ResetTargetname.BoolValue || Shavit_IsPracticeMode(client)) // practice mode can be abused to break map triggers
	{
		DispatchKeyValue(client, "targetname", "");
		SetEntPropString(client, Prop_Data, "m_iClassname", "player");
	}

	return Plugin_Continue;
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

public void Shavit_OnWorldRecord(int client, int style, float time, int jumps, int strafes, int nades, float sync, int track)
{
	char sUpperCase[64];
	strcopy(sUpperCase, 64, gS_StyleStrings[style].sStyleName);

	for(int i = 0; i < strlen(sUpperCase); i++)
	{
		if(!IsCharUpper(sUpperCase[i]))
		{
			sUpperCase[i] = CharToUpper(sUpperCase[i]);
		}
	}

	char sTrack[32];
	GetTrackName(LANG_SERVER, track, sTrack, 32);

	for(int i = 1; i <= gCV_WRMessages.IntValue; i++)
	{
		if(style != 0)
		{
			if(track == Track_Main)
			{
				Shavit_PrintToChatAll("%t", "WRNotice", gS_ChatStrings.sWarning, sUpperCase);
			}

			if(track == Track_Bonus)
			{
				Shavit_PrintToChatAll("%t", "WRNoticeBonus", gS_ChatStrings.sWarning, sUpperCase);
			}
			
			if(track == Track_Solobonus)
			{
				Shavit_PrintToChatAll("%t", "WRNoticeSolobonus", gS_ChatStrings.sWarning, sUpperCase);
			}
		}
		
		else
		{
			if(track == Track_Main)
			{
				Shavit_PrintToChatAll("%t", "WRNoticeNoDefaultStyle", gS_ChatStrings.sWarning);
			}

			if(track == Track_Bonus)
			{
				Shavit_PrintToChatAll("%t", "WRNoticeNoDefaultStyleBonus", gS_ChatStrings.sWarning);
			}
			
			if(track == Track_Solobonus)
			{
				Shavit_PrintToChatAll("%t", "WRNoticeNoDefaultStyleSolobonus", gS_ChatStrings.sWarning);
			}
		}
	}
}

public void Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client) && !IsFakeClient(client))
	{
		if(gCV_Scoreboard.BoolValue)
		{
			UpdateScoreboard(client);
		}

		UpdateClanTag(client);
	}
}

public Action Player_Notifications(Event event, const char[] name, bool dontBroadcast)
{
	if(gCV_HideTeamChanges.BoolValue)
	{
		if(!event.GetBool("disconnect"))
		{
			event.SetBool("silent", true);
		}
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsFakeClient(client))
	{
		Shavit_StopTimer(client);
	}
	
	return Plugin_Continue;
}

public void Shavit_OnFinish(int client)
{
	if(!gCV_Scoreboard.BoolValue)
	{
		return;
	}

	UpdateScoreboard(client);
	UpdateClanTag(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	
	if(IsValidClient(iGroundEntity, true) && !IsFakeClient(iGroundEntity) && GetEntProp(iGroundEntity, Prop_Data, "m_CollisionGroup") == 5)
	{
		if(Shavit_GetTimerStatus(client) == Timer_Running && Shavit_GetClientTrack(client) == Track_Solobonus)
		{
			Shavit_StopTimer(client);
		}
		
		#if defined DEBUG
		PrintToChat(client, "Runboost?");
		#endif
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "_projectile") != -1)
	{
		g_bouncedOff[entity] = false;
		
		SDKHook(entity, SDKHook_Touch, Projectile_StartTouch);
		SDKHook(entity, SDKHook_EndTouch, Projectile_EndTouch);
	}
}

Action Projectile_StartTouch(int entity, int client)
{
	if(!IsValidClient(client, true))
	{
		return Plugin_Continue;
	}
	
	float entityOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityOrigin);

	float clientOrigin[3];
	GetClientAbsOrigin(client, clientOrigin);
	
	if(clientOrigin[2] - 3 <= entityOrigin[2] <= clientOrigin[2])
	{
		g_groundBoost[client] = g_bouncedOff[entity];
		
		if(Shavit_GetTimerStatus(client) == Timer_Running && Shavit_GetClientTrack(client) == Track_Solobonus)
		{
			Shavit_StopTimer(client);
		}
		
		#if defined DEBUG
		PrintToChat(client, "Flashbang boost?");
		#endif
	}

	return Plugin_Continue;
}

Action Projectile_EndTouch(int entity, int other)
{
	if(!other)
	{
		g_bouncedOff[entity] = true;
	}
}
