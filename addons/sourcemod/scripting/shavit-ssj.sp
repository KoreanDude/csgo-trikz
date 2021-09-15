#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "SSJ: Advanced",
	author = "AlkATraZ",
	description = "Strafe gains/efficiency etc. // Edited by Nairda to work with shavit's timer",
	version = SHAVIT_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=287039"
}

#define BHOP_FRAMES 10

Handle g_hCookieEnabled = null;
Handle g_hCookieUsageMode = null;
Handle g_hCookieUsageRepeat = null;
Handle g_hCookieCurrentSpeed = null;
Handle g_hCookieFirstJump = null;
Handle g_hCookieHeightDiff = null;
Handle g_hCookieGainStats = null;
Handle g_hCookieEfficiency = null;
Handle g_hCookieTime = null;
Handle g_hCookieDeltaTime = null;
Handle g_hCookieStrafeCount = null;
Handle g_hCookieStrafeSync = null;
Handle g_hCookieDefaultsSet = null;

bool g_bUsageRepeat[MAXPLAYERS + 1];
bool g_bEnabled[MAXPLAYERS + 1] =  { true, ... };
bool g_bCurrentSpeed[MAXPLAYERS + 1] =  { true, ... };
bool g_bFirstJump[MAXPLAYERS + 1] =  { true, ... };
bool g_bHeightDiff[MAXPLAYERS + 1];
bool g_bGainStats[MAXPLAYERS + 1] =  { true, ... };
bool g_bEfficiency[MAXPLAYERS + 1];
bool g_bTime[MAXPLAYERS + 1];
bool g_bStrafeSync[MAXPLAYERS + 1];
bool g_bTouchesWall[MAXPLAYERS + 1];
bool g_bStrafeCount[MAXPLAYERS + 1];

int g_iUsageMode[MAXPLAYERS + 1];
int g_iTicksOnGround[MAXPLAYERS + 1];
int g_iTouchTicks[MAXPLAYERS + 1];
int g_iStrafeTick[MAXPLAYERS + 1];
int g_iSyncedTick[MAXPLAYERS + 1];
int g_iJump[MAXPLAYERS + 1];
int g_iOldSSJTarget[MAXPLAYERS + 1];
int g_iButtonCache[MAXPLAYERS + 1];
int g_iStrafeCount[MAXPLAYERS + 1];

float g_fInitialHeight[MAXPLAYERS + 1];
float g_fOldHeight[MAXPLAYERS + 1];
float g_fOldSpeed[MAXPLAYERS + 1];
float g_fRawGain[MAXPLAYERS + 1];
float g_fTrajectory[MAXPLAYERS + 1];
float g_fTraveledDistance[MAXPLAYERS + 1][3];
float g_fSpeedLoss[MAXPLAYERS + 1];
float g_fOldVelocity[MAXPLAYERS + 1];
float g_fTickrate = 0.01;

// misc settings
bool g_bLate = false;
bool g_bShavit = false;

EngineVersion gEV_Type = Engine_Unknown;
chatstrings_t gS_ChatStrings;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_ssj", Command_SSJ, "Open the Speed @ Sixth Jump menu.");

	g_hCookieEnabled = RegClientCookie("ssj_enable", "ssj_enabled", CookieAccess_Public);
	g_hCookieUsageMode = RegClientCookie("ssj_displaymode", "ssj_displaymode", CookieAccess_Public);
	g_hCookieUsageRepeat = RegClientCookie("ssj_displayrepeat", "ssj_displayrepeat", CookieAccess_Public);
	g_hCookieCurrentSpeed = RegClientCookie("ssj_currentspeed", "ssj_currentspeed", CookieAccess_Public);
	g_hCookieFirstJump = RegClientCookie("ssj_firstjump", "ssj_firstjump", CookieAccess_Public);
	g_hCookieHeightDiff = RegClientCookie("ssj_heightdiff", "ssj_heightdiff", CookieAccess_Public);
	g_hCookieGainStats = RegClientCookie("ssj_gainstats", "ssj_gainstats", CookieAccess_Public);
	g_hCookieEfficiency = RegClientCookie("ssj_efficiency", "ssj_efficiency", CookieAccess_Public);
	g_hCookieTime = RegClientCookie("ssj_time", "ssj_time", CookieAccess_Public);
	g_hCookieDeltaTime = RegClientCookie("ssj_deltatime", "ssj_deltatime", CookieAccess_Public);
	g_hCookieStrafeCount = RegClientCookie("ssj_strafecount", "ssj_strafecount", CookieAccess_Public);
	g_hCookieStrafeSync = RegClientCookie("ssj_strafesync", "ssj_strafesync", CookieAccess_Public);
	g_hCookieDefaultsSet = RegClientCookie("ssj_defaults", "ssj_defaults", CookieAccess_Public);

	HookEvent("player_jump", Player_Jump);

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
			OnClientCookiesCached(i);
		}
	}

	if(g_bLate)
	{
		Shavit_OnChatConfigLoaded();
	}

	g_bShavit = LibraryExists("shavit");
	gEV_Type = GetEngineVersion();
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit"))
	{
		g_bShavit = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit"))
	{
		g_bShavit = false;
	}
}

public void OnMapStart()
{
	g_fTickrate = GetTickInterval();
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

public void OnClientCookiesCached(int client)
{
	char sCookie[8];

	GetClientCookie(client, g_hCookieDefaultsSet, sCookie, 8);

	if(StringToInt(sCookie) == 0)
	{
		SetCookie(client, g_hCookieEnabled, false);
		SetCookie(client, g_hCookieUsageMode, 6);
		SetCookie(client, g_hCookieUsageRepeat, false);
		SetCookie(client, g_hCookieCurrentSpeed, true);
		SetCookie(client, g_hCookieFirstJump, true);
		SetCookie(client, g_hCookieHeightDiff, false);
		SetCookie(client, g_hCookieGainStats, true);
		SetCookie(client, g_hCookieEfficiency, false);
		SetCookie(client, g_hCookieTime, false);
		SetCookie(client, g_hCookieDeltaTime, false);
		SetCookie(client, g_hCookieStrafeCount, false);
		SetCookie(client, g_hCookieStrafeSync, false);
		SetCookie(client, g_hCookieDefaultsSet, true);
	}

	GetClientCookie(client, g_hCookieEnabled, sCookie, 8);
	g_bEnabled[client] = view_as<bool>(StringToInt(sCookie));

	GetClientCookie(client, g_hCookieUsageMode, sCookie, 8);
	g_iUsageMode[client] = StringToInt(sCookie);

	GetClientCookie(client, g_hCookieUsageRepeat, sCookie, 8);
	g_bUsageRepeat[client] = view_as<bool>(StringToInt(sCookie));

	GetClientCookie(client, g_hCookieCurrentSpeed, sCookie, 8);
	g_bCurrentSpeed[client] = view_as<bool>(StringToInt(sCookie));

	GetClientCookie(client, g_hCookieFirstJump, sCookie, 8);
	g_bFirstJump[client] = view_as<bool>(StringToInt(sCookie));

	GetClientCookie(client, g_hCookieHeightDiff, sCookie, 8);
	g_bHeightDiff[client] = view_as<bool>(StringToInt(sCookie));

	GetClientCookie(client, g_hCookieGainStats, sCookie, 8);
	g_bGainStats[client] = view_as<bool>(StringToInt(sCookie));

	GetClientCookie(client, g_hCookieEfficiency, sCookie, 8);
	g_bEfficiency[client] = view_as<bool>(StringToInt(sCookie));

	GetClientCookie(client, g_hCookieTime, sCookie, 8);
	g_bTime[client] = view_as<bool>(StringToInt(sCookie));

	GetClientCookie(client, g_hCookieStrafeCount, sCookie, 8);
	g_bStrafeCount[client] = view_as<bool>(StringToInt(sCookie));

	GetClientCookie(client, g_hCookieStrafeSync, sCookie, 8);
	g_bStrafeSync[client] = view_as<bool>(StringToInt(sCookie));
}

public void OnClientPutInServer(int client)
{
	g_iJump[client] = 0;
	g_iStrafeTick[client] = 0;
	g_iSyncedTick[client] = 0;
	g_fRawGain[client] = 0.0;
	g_fOldHeight[client] = 0.0;
	g_fOldSpeed[client] = 0.0;
	g_fTrajectory[client] = 0.0;
	g_fTraveledDistance[client] = NULL_VECTOR;
	g_iTicksOnGround[client] = 0;
	g_iStrafeCount[client] = 0;
	g_iOldSSJTarget[client] = 0;

	SDKHook(client, SDKHook_Touch, OnTouch);
}

public Action OnTouch(int client, int entity)
{
	if ((GetEntProp(entity, Prop_Data, "m_usSolidFlags") & 12) == 0)
	{
		g_bTouchesWall[client] = true;
	}
}

int GetHUDTarget(int client)
{
	int target = client;

	if(IsValidClient(client))
	{
		int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if(3 < iObserverMode < 7)
		{
			int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if(IsValidClient(iTarget))
			{
				target = iTarget;
			}
		}
	}

	return target;
}

void UpdateStats(int client)
{
	int target = client; //GetHUDTarget(client);

	float velocity[3];
	GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", velocity);
	velocity[2] = 0.0;

	float origin[3];
	GetClientAbsOrigin(target, origin);

	g_fRawGain[client] = 0.0;
	g_iStrafeTick[client] = 0;
	g_iSyncedTick[client] = 0;
	g_iStrafeCount[client] = 0;
	g_fSpeedLoss[client] = 0.0;
	g_fOldHeight[client] = origin[2];
	g_fOldSpeed[client] = GetVectorLength(velocity);
	g_fTrajectory[client] = 0.0;
	g_fTraveledDistance[client] = NULL_VECTOR;
}

public void Player_Jump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsFakeClient(client) || (g_iJump[client] > 0 && g_iStrafeTick[client] == 0))
	{
		return;
	}

	g_iJump[client]++;

	//bool shouldUpdateStats = false;
	//bool printedStats = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!g_bEnabled[i])
		{
			continue;
		}

		if(!IsValidClient(i))
		{
			continue;
		}

		if(GetHUDTarget(i) != client)
		{
			continue;
		}

		SSJ_PrintStats(i, client);
	}

	UpdateStats(client);
}

public Action Command_SSJ(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "[SM] This command can only be used in-game.");

		return Plugin_Handled;
	}

	return ShowSSJMenu(client);
}

Action ShowSSJMenu(int client, int item = 0)
{
	Menu menu = new Menu(SSJ_MenuHandler);
	menu.SetTitle("Speed @ Sixth Jump\n ");

	menu.AddItem("usage", (g_bEnabled[client]) ? "[x] Enabled":"[ ] Enabled");

	char sMenu[64];
	FormatEx(sMenu, 64, "[%d] Jump", g_iUsageMode[client]);

	menu.AddItem("mode", sMenu);
	menu.AddItem("repeat", (g_bUsageRepeat[client]) ? "[x] Repeat":"[ ] Repeat");
	menu.AddItem("curspeed", (g_bCurrentSpeed[client]) ? "[x] Current speed":"[ ] Current speed");
	menu.AddItem("firstjump", (g_bFirstJump[client]) ? "[x] First jump":"[ ] First jump");
	menu.AddItem("height", (g_bHeightDiff[client]) ? "[x] Height difference":"[ ] Height difference");
	menu.AddItem("gain", (g_bGainStats[client]) ? "[x] Gain percentage":"[ ] Gain percentage");
	menu.AddItem("efficiency", (g_bEfficiency[client]) ? "[x] Strafe efficiency":"[ ] Strafe efficiency");
	menu.AddItem("time", (g_bTime[client]) ? "[x] Time counter":"[ ] Time counter");
	menu.AddItem("strafe", (g_bStrafeCount[client]) ? "[x] Strafe":"[ ] Strafe");
	menu.AddItem("sync", (g_bStrafeSync[client]) ? "[x] Synchronization":"[ ] Synchronization");

	menu.ExitButton = true;
	menu.DisplayAt(client, item, 0);

	return Plugin_Handled;
}

public int SSJ_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				g_bEnabled[param1] = !g_bEnabled[param1];
				SetCookie(param1, g_hCookieEnabled, g_bEnabled[param1]);
			}

			case 1:
			{
				g_iUsageMode[param1] = (g_iUsageMode[param1] % 9) + 1;
				SetCookie(param1, g_hCookieUsageMode, g_iUsageMode[param1]);
			}

			case 2:
			{
				g_bUsageRepeat[param1] = !g_bUsageRepeat[param1];
				SetCookie(param1, g_hCookieUsageRepeat, g_bUsageRepeat[param1]);
			}

			case 3:
			{
				g_bCurrentSpeed[param1] = !g_bCurrentSpeed[param1];
				SetCookie(param1, g_hCookieCurrentSpeed, g_bCurrentSpeed[param1]);
			}

			case 4:
			{
				g_bFirstJump[param1] = !g_bFirstJump[param1];
				SetCookie(param1, g_hCookieFirstJump, g_bFirstJump[param1]);
			}

			case 5:
			{
				g_bHeightDiff[param1] = !g_bHeightDiff[param1];
				SetCookie(param1, g_hCookieHeightDiff, g_bHeightDiff[param1]);
			}

			case 6:
			{
				g_bGainStats[param1] = !g_bGainStats[param1];
				SetCookie(param1, g_hCookieGainStats, g_bGainStats[param1]);
			}

			case 7:
			{
				g_bEfficiency[param1] = !g_bEfficiency[param1];
				SetCookie(param1, g_hCookieEfficiency, g_bEfficiency[param1]);
			}

			case 8:
			{
				g_bTime[param1] = !g_bTime[param1];
				SetCookie(param1, g_hCookieTime, g_bTime[param1]);
			}

			case 9:
			{
				g_bStrafeCount[param1] = !g_bStrafeCount[param1];
				SetCookie(param1, g_hCookieStrafeCount, g_bStrafeCount[param1]);
			}

			case 10:
			{
				g_bStrafeSync[param1] = !g_bStrafeSync[param1];
				SetCookie(param1, g_hCookieStrafeSync, g_bStrafeSync[param1]);
			}

		}

		ShowSSJMenu(param1, GetMenuSelectionPosition());
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void SSJ_GetStats(int client, float vel[3], float angles[3])
{
	float velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);

	g_iStrafeTick[client]++;

	float speedmulti = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");

	g_fTraveledDistance[client][0] += velocity[0] * g_fTickrate * speedmulti;
	g_fTraveledDistance[client][1] += velocity[1] * g_fTickrate * speedmulti;
	velocity[2] = 0.0;

	g_fTrajectory[client] += GetVectorLength(velocity) * g_fTickrate * speedmulti;

	float fore[3];
	float side[3];
	GetAngleVectors(angles, fore, side, NULL_VECTOR);

	fore[2] = 0.0;
	NormalizeVector(fore, fore);

	side[2] = 0.0;
	NormalizeVector(side, side);

	float wishvel[3];
	float wishdir[3];

	for (int i = 0; i < 2; i++)
	{
		wishvel[i] = fore[i] * vel[0] + side[i] * vel[1];
	}

	float wishspeed = NormalizeVector(wishvel, wishdir);
	float maxspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");

	if(maxspeed != 0.0 && wishspeed > maxspeed)
	{
		wishspeed = maxspeed;
	}

	if(wishspeed > 0.0)
	{
		float wishspd = (wishspeed > 30.0) ? 30.0:wishspeed;
		float currentgain = GetVectorDotProduct(velocity, wishdir);
		float gaincoeff = 0.0;

		if(currentgain < 30.0)
		{
			g_iSyncedTick[client]++;
			gaincoeff = (wishspd - FloatAbs(currentgain)) / wishspd;
		}

		if(g_bTouchesWall[client] && g_iTouchTicks[client] && gaincoeff > 0.5)
		{
			gaincoeff -= 1.0;
			gaincoeff = FloatAbs(gaincoeff);
		}

		g_fRawGain[client] += gaincoeff;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	int flags = GetEntityFlags(client);
	float speed = GetClientVelocity(client);

	if(flags & FL_ONGROUND != FL_ONGROUND)
	{
		if ((g_iButtonCache[client] & IN_FORWARD) != IN_FORWARD && (buttons & IN_FORWARD) == IN_FORWARD)
		{
			g_iStrafeCount[client]++;
		}

		if ((g_iButtonCache[client] & IN_MOVELEFT) != IN_MOVELEFT && (buttons & IN_MOVELEFT) == IN_MOVELEFT)
		{
			g_iStrafeCount[client]++;
		}

		if ((g_iButtonCache[client] & IN_BACK) != IN_BACK && (buttons & IN_BACK) == IN_BACK)
		{
			g_iStrafeCount[client]++;
		}

		if ((g_iButtonCache[client] & IN_MOVERIGHT) != IN_MOVERIGHT && (buttons & IN_MOVERIGHT) == IN_MOVERIGHT)
		{
			g_iStrafeCount[client]++;
		}
	}

	if(g_fOldVelocity[client] > speed)
	{
		g_fSpeedLoss[client] += (FloatAbs(speed - g_fOldVelocity[client]));
	}

	if(flags & FL_ONGROUND == FL_ONGROUND)
	{
		if(g_iTicksOnGround[client]++ > BHOP_FRAMES)
		{
			g_iJump[client] = 0;
			g_iStrafeTick[client] = 0;
			g_iSyncedTick[client] = 0;
			g_fRawGain[client] = 0.0;
			g_fTrajectory[client] = 0.0;
			g_iStrafeCount[client] = 0;
			g_fSpeedLoss[client] = 0.0;
			g_fTraveledDistance[client] = NULL_VECTOR;
		}

		if ((buttons & IN_JUMP) > 0 && g_iTicksOnGround[client] == 1)
		{
			SSJ_GetStats(client, vel, angles);
			g_iTicksOnGround[client] = 0;
		}
	}

	else
	{
		MoveType movetype = GetEntityMoveType(client);

		if(movetype != MOVETYPE_NONE && movetype != MOVETYPE_NOCLIP && movetype != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2)
		{
			SSJ_GetStats(client, vel, angles);
		}

		g_iTicksOnGround[client] = 0;
	}

	if(g_bTouchesWall[client])
	{
		g_iTouchTicks[client]++;
		g_bTouchesWall[client] = false;
	}

	else
	{
		g_iTouchTicks[client] = 0;
	}

	g_iButtonCache[client] = buttons;
	g_fOldVelocity[client] = speed;
	return Plugin_Continue;
}

bool SSJ_PrintStats(int client, int target)
{
	if(g_iJump[target] == 1)
	{
		if(!g_bFirstJump[client] && g_iUsageMode[client] != 1)
		{
			return false;
		}
	}

	else if(g_bUsageRepeat[client])
	{
		if(g_iJump[target] % g_iUsageMode[client] != 0)
		{
			return false;
		}
	}

	else if(g_iJump[target] != g_iUsageMode[client])
	{
		return false;
	}

	float velocity[3];
	GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", velocity);
	velocity[2] = 0.0;

	float origin[3];
	GetClientAbsOrigin(target, origin);

	float coeffsum = g_fRawGain[target];
	coeffsum /= g_iStrafeTick[target];
	coeffsum *= 100.0;

	float distance = GetVectorLength(g_fTraveledDistance[target]);

	if(distance > g_fTrajectory[target])
	{
		distance = g_fTrajectory[target];
	}

	float efficiency = 0.0;

	if(distance > 0.0)
	{
		efficiency = coeffsum * distance / g_fTrajectory[target];
	}

	coeffsum = RoundToFloor(coeffsum * 100.0 + 0.5) / 100.0;
	efficiency = RoundToFloor(efficiency * 100.0 + 0.5) / 100.0;

	char sMessage[192];
	FormatEx(sMessage, 192, "J: %s%i", gS_ChatStrings.sVariable, g_iJump[target]);

	float time = Shavit_GetClientTime(target);
	char sTime[32];

	if(g_bCurrentSpeed[client])
	{
		Format(sMessage, 192, "%s %s| Spd: %s%i", sMessage, gS_ChatStrings.sText, gS_ChatStrings.sVariable, RoundToFloor(GetVectorLength(velocity)));
	}

	if(g_iJump[target] > 1)
	{
		if(g_bHeightDiff[client])
		{
			Format(sMessage, 192, "%s %s| H Δ: %s%i", sMessage, gS_ChatStrings.sText, gS_ChatStrings.sVariable, RoundToFloor(origin[2]) - RoundToFloor(g_fInitialHeight[target]));
		}

		if(g_bGainStats[client])
		{
			Format(sMessage, 192, "%s %s| Gn: %s%.2f%%", sMessage, gS_ChatStrings.sText, gS_ChatStrings.sVariable, coeffsum);
		}

		if(g_bStrafeSync[client])
		{
			Format(sMessage, 192, "%s %s| Snc: %s%.2f%%", sMessage, gS_ChatStrings.sText, gS_ChatStrings.sVariable, 100.0 * g_iSyncedTick[target] / g_iStrafeTick[target]);
		}

		if(g_bEfficiency[client])
		{
			Format(sMessage, 192, "%s %s| Eff: %s%.2f%%", sMessage, gS_ChatStrings.sText, gS_ChatStrings.sVariable, efficiency);
		}

		if(g_bStrafeCount[client])
		{
			Format(sMessage, 192, "%s %s| Strf: %s%i", sMessage, gS_ChatStrings.sText, gS_ChatStrings.sVariable, g_iStrafeCount[target]);
		}

		if(g_bTime[client])
		{
			FormatSeconds(time, sTime, 32, true);
			Format(sMessage, 192, "%s %s| T: %s%s", sMessage, gS_ChatStrings.sText, gS_ChatStrings.sVariable, sTime);
		}
	}

	PrintToClient(client, "%s", sMessage);

	return true;
}

void PrintToClient(int client, const char[] message, any...)
{
	char buffer[300];
	VFormat(buffer, 300, message, 3);

	if(g_bShavit)
	{
		Shavit_StopChatSound();
		Shavit_PrintToChat(client, "%s", buffer); // Thank you, GAMMACASE
	}

	else
	{
		PrintToChat(client, "%s%s%s%s", (gEV_Type == Engine_CSGO) ? " ":"", gS_ChatStrings.sPrefix, gS_ChatStrings.sText, buffer);
	}
}

void SetCookie(int client, Handle hCookie, int n)
{
	char sCookie[8];
	IntToString(n, sCookie, 8);

	SetClientCookie(client, hCookie, sCookie);
}

float GetClientVelocity(int client)
{
	float vVel[3];

	vVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	vVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");

	return GetVectorLength(vVel);
}