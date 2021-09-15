/*
 * shavit's Timer - HUD
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

#undef REQUIRE_PLUGIN
#include <shavit>
#include <trikz>
#include <bhopstats>

#pragma newdecls required
#pragma semicolon 1

// HUD2 - these settings will *disable* elements for the main hud
#define HUD2_TIME				(1 << 0)
#define HUD2_SPEED				(1 << 1)
#define HUD2_STYLE				(1 << 2)
#define HUD2_RANK				(1 << 3)
#define HUD2_TRACK				(1 << 4)
#define HUD2_MAPTIER			(1 << 5)

#define HUD_DEFAULT				(HUD_MASTER|HUD_CENTER|HUD_ZONEHUD|HUD_OBSERVE|HUD_TOPLEFT|HUD_STYLE|HUD_JUMPS|HUD_STRAFES|HUD_NADES|HUD_SYNC|HUD_TRACK|HUD_TIMELEFT|HUD_SPECTATORS)
#define HUD_DEFAULT2			0

#define MAX_HINT_SIZE 225

enum ZoneHUD
{
	ZoneHUD_None,
	ZoneHUD_Start,
	ZoneHUD_End
};

enum struct huddata_t
{
	int iTarget;
	float fTime;
	int iSpeed;
	int iStyle;
	int iTrack;
	int iJumps;
	int iStrafes;
	int iNades;
	int iRank;
	float fSync;
	float fPB;
	float fWR;
	bool bReplay;
	bool bPractice;
	TimerStatus iTimerStatus;
	ZoneHUD iZoneHUD;
}

enum struct color_t
{
	int r;
	int g;
	int b;
}

// forwards
Handle gH_Forwards_OnTopLeftHUD = null;

// modules
bool gB_Replay = false;
bool gB_Zones = false;
bool gB_Sounds = false;
bool gB_Rankings = false;
bool gB_BhopStats = false;

// cache
int gI_Cycle = 0;
color_t gI_Gradient;
int gI_GradientDirection = -1;
int gI_Styles = 0;
char gS_Map[160];
char sTopLeft[256];

Handle gH_HUDCookie = null;
Handle gH_HUDCookieMain = null;
int gI_HUDSettings[MAXPLAYERS+1];
int gI_HUD2Settings[MAXPLAYERS+1];
int gI_LastScrollCount[MAXPLAYERS+1];
int gI_ScrollCount[MAXPLAYERS+1];
int gI_Buttons[MAXPLAYERS+1];
int gI_PreviousSpeed[MAXPLAYERS+1];
int gI_ZoneSpeedLimit[MAXPLAYERS+1];

bool gB_Late = false;

bool gB_namefirstOwn[MAXPLAYERS + 1];
bool gB_namefirstPartner[MAXPLAYERS + 1];

// plugin cvars
ConVar gCV_GradientStepSize = null;
ConVar gCV_TicksPerUpdate = null;
ConVar gCV_SpectatorList = null;

// timer settings
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
stylesettings_t gA_StyleSettings[STYLE_LIMIT];
chatstrings_t gS_ChatStrings;

// table prefix
char gS_MySQLPrefix[32];

// database handle
Database gH_SQL = null;

public Plugin myinfo =
{
	name = "[shavit] HUD",
	author = "shavit, sejiya, Smesh",
	description = "HUD for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// forwards
	gH_Forwards_OnTopLeftHUD = CreateGlobalForward("Shavit_OnTopLeftHUD", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	
	// natives
	CreateNative("Shavit_ForceHUDUpdate", Native_ForceHUDUpdate);
	CreateNative("Shavit_GetHUDSettings", Native_GetHUDSettings);

	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit-hud");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-common.phrases");
	LoadTranslations("shavit-hud.phrases");

	// prevent errors in case the replay bot isn't loaded
	gB_Replay = LibraryExists("shavit-replay");
	gB_Zones = LibraryExists("shavit-zones");
	gB_Sounds = LibraryExists("shavit-sounds");
	gB_Rankings = LibraryExists("shavit-rankings");
	gB_BhopStats = LibraryExists("bhopstats");

	// plugin convars
	gCV_GradientStepSize = CreateConVar("shavit_hud_gradientstepsize", "15", "How fast should the start/end HUD gradient be?\nThe number is the amount of color change per 0.1 seconds.\nThe higher the number the faster the gradient.", 0, true, 1.0, true, 255.0);
	gCV_TicksPerUpdate = CreateConVar("shavit_hud_ticksperupdate", "5", "How often (in ticks) should the HUD update?\nPlay around with this value until you find the best for your server.\nThe maximum value is your tickrate.", 0, true, 1.0, true, (1.0 / GetTickInterval()));
	gCV_SpectatorList = CreateConVar("shavit_hud_speclist", "0", "Who to show in the specators list?\n0 - everyone\n1 - all admins (admin_speclisthide override to bypass)\n2 - players you can target", 0, true, 0.0, true, 2.0);

	AutoExecConfig();

	// commands
	RegConsoleCmd("sm_hud", Command_HUD, "Opens the HUD settings menu.");
	RegConsoleCmd("sm_options", Command_HUD, "Opens the HUD settings menu. (alias for sm_hud)");

	// hud togglers
	RegConsoleCmd("sm_keys", Command_Keys, "Toggles key display.");
	RegConsoleCmd("sm_showkeys", Command_Keys, "Toggles key display. (alias for sm_keys)");
	RegConsoleCmd("sm_showmykeys", Command_Keys, "Toggles key display. (alias for sm_keys)");

	RegConsoleCmd("sm_master", Command_Master, "Toggles HUD.");
	RegConsoleCmd("sm_masterhud", Command_Master, "Toggles HUD. (alias for sm_master)");

	RegConsoleCmd("sm_center", Command_Center, "Toggles center text HUD.");
	RegConsoleCmd("sm_centerhud", Command_Center, "Toggles center text HUD. (alias for sm_center)");

	RegConsoleCmd("sm_zonehud", Command_ZoneHUD, "Toggles zone HUD.");

	RegConsoleCmd("sm_hideweapon", Command_HideWeapon, "Toggles weapon hiding.");
	RegConsoleCmd("sm_hideweap", Command_HideWeapon, "Toggles weapon hiding. (alias for sm_hideweapon)");
	RegConsoleCmd("sm_hidewep", Command_HideWeapon, "Toggles weapon hiding. (alias for sm_hideweapon)");
	RegConsoleCmd("sm_vm", Command_HideWeapon, "Toggles weapon hiding. (alias for sm_vm)");
	RegConsoleCmd("sm_viewmodel", Command_HideWeapon, "Toggles weapon hiding. (alias for sm_viewmodel)");
	
	// cookies
	gH_HUDCookie = RegClientCookie("shavit_hud_setting", "HUD settings", CookieAccess_Protected);
	gH_HUDCookieMain = RegClientCookie("shavit_hud_settingmain", "HUD settings for hint text.", CookieAccess_Protected);

	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);

				if(AreClientCookiesCached(i) && !IsFakeClient(i))
				{
					OnClientCookiesCached(i);
				}
			}
		}
	}
	
	SQL_DBConnect();
}

public void OnMapStart()
{
	GetCurrentMap(gS_Map, 160);
	GetMapDisplayName(gS_Map, gS_Map, 160);

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(-1);
		Shavit_OnChatConfigLoaded();
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-replay"))
	{
		gB_Replay = true;
	}

	else if(StrEqual(name, "shavit-zones"))
	{
		gB_Zones = true;
	}

	else if(StrEqual(name, "shavit-sounds"))
	{
		gB_Sounds = true;
	}

	else if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = true;
	}

	else if(StrEqual(name, "bhopstats"))
	{
		gB_BhopStats = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-replay"))
	{
		gB_Replay = false;
	}

	else if(StrEqual(name, "shavit-zones"))
	{
		gB_Zones = false;
	}

	else if(StrEqual(name, "shavit-sounds"))
	{
		gB_Sounds = false;
	}

	else if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = false;
	}

	else if(StrEqual(name, "bhopstats"))
	{
		gB_BhopStats = false;
	}
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	if(styles == -1)
	{
		styles = Shavit_GetStyleCount();
	}

	gI_Styles = styles;

	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleSettings(i, gA_StyleSettings[i]);
		Shavit_GetStyleStrings(i, sStyleName, gS_StyleStrings[i].sStyleName, sizeof(stylestrings_t::sStyleName));
		Shavit_GetStyleStrings(i, sHTMLColor, gS_StyleStrings[i].sHTMLColor, sizeof(stylestrings_t::sHTMLColor));
	}
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style, stylesettings_t stylsettings)
{
	gI_Buttons[client] = buttons;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(i == client || (IsValidClient(i) && GetHUDTarget(i) == client))
		{
			TriggerHUDUpdate(i, true);
		}
	}

	return Plugin_Continue;
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
	gI_LastScrollCount[client] = 0;
	gI_ScrollCount[client] = 0;

	if(IsFakeClient(client))
	{
		SDKHook(client, SDKHook_PostThinkPost, PostThinkPost);
	}
}

public void PostThinkPost(int client)
{
	int buttons = GetClientButtons(client);

	if(gI_Buttons[client] != buttons)
	{
		gI_Buttons[client] = buttons;

		for(int i = 1; i <= MaxClients; i++)
		{
			if(i != client && (IsValidClient(i) && GetHUDTarget(i) == client))
			{
				TriggerHUDUpdate(i, true);
			}
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sHUDSettings[8];
	GetClientCookie(client, gH_HUDCookie, sHUDSettings, 8);

	if(strlen(sHUDSettings) == 0)
	{
		IntToString(HUD_DEFAULT, sHUDSettings, 8);

		SetClientCookie(client, gH_HUDCookie, sHUDSettings);
		gI_HUDSettings[client] = HUD_DEFAULT;
	}

	else
	{
		gI_HUDSettings[client] = StringToInt(sHUDSettings);
	}

	GetClientCookie(client, gH_HUDCookieMain, sHUDSettings, 8);

	if(strlen(sHUDSettings) == 0)
	{
		IntToString(HUD_DEFAULT2, sHUDSettings, 8);

		SetClientCookie(client, gH_HUDCookieMain, sHUDSettings);
		gI_HUD2Settings[client] = HUD_DEFAULT2;
	}

	else
	{
		gI_HUD2Settings[client] = StringToInt(sHUDSettings);
	}
}

void ToggleHUD(int client, int hud, bool chat)
{
	if(!(1 <= client <= MaxClients))
	{
		return;
	}

	char sCookie[16];
	gI_HUDSettings[client] ^= hud;
	IntToString(gI_HUDSettings[client], sCookie, 16);
	SetClientCookie(client, gH_HUDCookie, sCookie);

	if(chat)
	{
		char sHUDSetting[64];

		switch(hud)
		{
			case HUD_MASTER: FormatEx(sHUDSetting, 64, "%T", "HudMaster", client);
			case HUD_CENTER: FormatEx(sHUDSetting, 64, "%T", "HudCenter", client);
			case HUD_ZONEHUD: FormatEx(sHUDSetting, 64, "%T", "HudZoneHud", client);
			case HUD_OBSERVE: FormatEx(sHUDSetting, 64, "%T", "HudObserve", client);
			case HUD_SPECTATORS: FormatEx(sHUDSetting, 64, "%T", "HudSpectators", client);
			case HUD_KEYOVERLAY: FormatEx(sHUDSetting, 64, "%T", "HudKeyOverlay", client);
			case HUD_HIDEWEAPON: FormatEx(sHUDSetting, 64, "%T", "HudHideWeapon", client);
			case HUD_TOPLEFT: FormatEx(sHUDSetting, 64, "%T", "HudTopLeft", client);
			case HUD_SYNC: FormatEx(sHUDSetting, 64, "%T", "HudSync", client);
			case HUD_TIMELEFT: FormatEx(sHUDSetting, 64, "%T", "HudTimeLeft", client);
			case HUD_NOSOUNDS: FormatEx(sHUDSetting, 64, "%T", "HudNoRecordSounds", client);
			case HUD_NOPRACALERT: FormatEx(sHUDSetting, 64, "%T", "HudPracticeModeAlert", client);
		}

		if((gI_HUDSettings[client] & hud) > 0)
		{
			Shavit_PrintToChat(client, "%T", "HudEnabledComponent", client,
				gS_ChatStrings.sVariable, sHUDSetting, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, gS_ChatStrings.sText);
		}

		else
		{
			Shavit_PrintToChat(client, "%T", "HudDisabledComponent", client,
				gS_ChatStrings.sVariable, sHUDSetting, gS_ChatStrings.sText, gS_ChatStrings.sWarning, gS_ChatStrings.sText);
		}
	}
}

public Action Command_Master(int client, int args)
{
	ToggleHUD(client, HUD_MASTER, true);

	return Plugin_Handled;
}

public Action Command_Center(int client, int args)
{
	ToggleHUD(client, HUD_CENTER, true);

	return Plugin_Handled;
}

public Action Command_ZoneHUD(int client, int args)
{
	ToggleHUD(client, HUD_ZONEHUD, true);

	return Plugin_Handled;
}

public Action Command_HideWeapon(int client, int args)
{
	ToggleHUD(client, HUD_HIDEWEAPON, true);

	return Plugin_Handled;
}

public Action Command_Keys(int client, int args)
{
	ToggleHUD(client, HUD_KEYOVERLAY, true);

	return Plugin_Handled;
}

public Action Command_HUD(int client, int args)
{
	return ShowHUDMenu(client, 0);
}

Action ShowHUDMenu(int client, int item)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(MenuHandler_HUD, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
	menu.SetTitle("%T", "HUDMenuTitle", client);

	char sInfo[16];
	char sHudItem[64];
	FormatEx(sInfo, 16, "!%d", HUD_MASTER);
	FormatEx(sHudItem, 64, "%T", "HudMaster", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_CENTER);
	FormatEx(sHudItem, 64, "%T", "HudCenter", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_ZONEHUD);
	FormatEx(sHudItem, 64, "%T", "HudZoneHud", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_OBSERVE);
	FormatEx(sHudItem, 64, "%T", "HudObserve", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_SPECTATORS);
	FormatEx(sHudItem, 64, "%T", "HudSpectators", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_KEYOVERLAY);
	FormatEx(sHudItem, 64, "%T", "HudKeyOverlay", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_HIDEWEAPON);
	FormatEx(sHudItem, 64, "%T", "HudHideWeapon", client);
	menu.AddItem(sInfo, sHudItem);
	
	FormatEx(sInfo, 16, "!%d", HUD_TOPLEFT);
	FormatEx(sHudItem, 64, "%T", "HudTopLeft", client);
	menu.AddItem(sInfo, sHudItem);
	
	FormatEx(sInfo, 16, "!@%d", HUD_STYLE);
	FormatEx(sHudItem, 64, "%T", "HudStyleText", client);
	menu.AddItem(sInfo, sHudItem);
	
	FormatEx(sInfo, 16, "!@%d", HUD_JUMPS);
	FormatEx(sHudItem, 64, "%T", "HudJumpsText", client);
	menu.AddItem(sInfo, sHudItem);
	
	FormatEx(sInfo, 16, "!@%d", HUD_STRAFES);
	FormatEx(sHudItem, 64, "%T", "HudStrafeText", client);
	menu.AddItem(sInfo, sHudItem);
	
	FormatEx(sInfo, 16, "!@%d", HUD_NADES);
	FormatEx(sHudItem, 64, "%T", "HudNadesText", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_SYNC);
	FormatEx(sHudItem, 64, "%T", "HudSync", client);
	menu.AddItem(sInfo, sHudItem);
	
	FormatEx(sInfo, 16, "!@%d", HUD_TRACK);
	FormatEx(sHudItem, 64, "%T", "HudTrackText", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "!%d", HUD_TIMELEFT);
	FormatEx(sHudItem, 64, "%T", "HudTimeLeft", client);
	menu.AddItem(sInfo, sHudItem);

	if(gB_Sounds)
	{
		FormatEx(sInfo, 16, "!%d", HUD_NOSOUNDS);
		FormatEx(sHudItem, 64, "%T", "HudNoRecordSounds", client);
		menu.AddItem(sInfo, sHudItem);
	}

	FormatEx(sInfo, 16, "!%d", HUD_NOPRACALERT);
	FormatEx(sHudItem, 64, "%T", "HudPracticeModeAlert", client);
	menu.AddItem(sInfo, sHudItem);

	// HUD2 - disables selected elements
	FormatEx(sInfo, 16, "@%d", HUD2_TIME);
	FormatEx(sHudItem, 64, "%T", "HudTimeText", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "@%d", HUD2_SPEED);
	FormatEx(sHudItem, 64, "%T", "HudSpeedText", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "@%d", HUD2_RANK);
	FormatEx(sHudItem, 64, "%T", "HudRankText", client);
	menu.AddItem(sInfo, sHudItem);

	if(gB_Rankings)
	{
		FormatEx(sInfo, 16, "@%d", HUD2_MAPTIER);
		FormatEx(sHudItem, 64, "%T", "HudMapTierText", client);
		menu.AddItem(sInfo, sHudItem);
	}

	menu.ExitButton = true;
	menu.DisplayAt(client, item, 60);

	return Plugin_Handled;
}

public int MenuHandler_HUD(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sCookie[16];
		menu.GetItem(param2, sCookie, 16);

		int type = (sCookie[0] == '!')? 1:2;
		ReplaceString(sCookie, 16, "!", "");
		ReplaceString(sCookie, 16, "@", "");

		int iSelection = StringToInt(sCookie);

		if(type == 1)
		{
			gI_HUDSettings[param1] ^= iSelection;
			IntToString(gI_HUDSettings[param1], sCookie, 16);
			SetClientCookie(param1, gH_HUDCookie, sCookie);
		}

		else
		{
			gI_HUD2Settings[param1] ^= iSelection;
			IntToString(gI_HUD2Settings[param1], sCookie, 16);
			SetClientCookie(param1, gH_HUDCookieMain, sCookie);
		}

		ShowHUDMenu(param1, GetMenuSelectionPosition());
	}

	else if(action == MenuAction_DisplayItem)
	{
		char sInfo[16];
		char sDisplay[64];
		int style = 0;
		menu.GetItem(param2, sInfo, 16, style, sDisplay, 64);

		int type = (sInfo[0] == '!')? 1:2;
		ReplaceString(sInfo, 16, "!", "");
		ReplaceString(sInfo, 16, "@", "");

		if(type == 1)
		{
			Format(sDisplay, 64, "[%s] %s", ((gI_HUDSettings[param1] & StringToInt(sInfo)) > 0)? "＋":"－", sDisplay);
		}

		else
		{
			Format(sDisplay, 64, "[%s] %s", ((gI_HUD2Settings[param1] & StringToInt(sInfo)) == 0)? "＋":"－", sDisplay);
		}

		return RedrawMenuItem(sDisplay);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void OnGameFrame()
{
	if((GetGameTickCount() % gCV_TicksPerUpdate.IntValue) == 0)
	{
		Cron();
	}
}

void Cron()
{
	if(++gI_Cycle >= 65535)
	{
		gI_Cycle = 0;
	}

	switch(gI_GradientDirection)
	{
		case 0:
		{
			gI_Gradient.b += gCV_GradientStepSize.IntValue;

			if(gI_Gradient.b >= 255)
			{
				gI_Gradient.b = 255;
				gI_GradientDirection = 1;
			}
		}

		case 1:
		{
			gI_Gradient.r -= gCV_GradientStepSize.IntValue;

			if(gI_Gradient.r <= 0)
			{
				gI_Gradient.r = 0;
				gI_GradientDirection = 2;
			}
		}

		case 2:
		{
			gI_Gradient.g += gCV_GradientStepSize.IntValue;

			if(gI_Gradient.g >= 255)
			{
				gI_Gradient.g = 255;
				gI_GradientDirection = 3;
			}
		}

		case 3:
		{
			gI_Gradient.b -= gCV_GradientStepSize.IntValue;

			if(gI_Gradient.b <= 0)
			{
				gI_Gradient.b = 0;
				gI_GradientDirection = 4;
			}
		}

		case 4:
		{
			gI_Gradient.r += gCV_GradientStepSize.IntValue;

			if(gI_Gradient.r >= 255)
			{
				gI_Gradient.r = 255;
				gI_GradientDirection = 5;
			}
		}

		case 5:
		{
			gI_Gradient.g -= gCV_GradientStepSize.IntValue;

			if(gI_Gradient.g <= 0)
			{
				gI_Gradient.g = 0;
				gI_GradientDirection = 0;
			}
		}

		default:
		{
			gI_Gradient.r = 255;
			gI_GradientDirection = 0;
		}
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || IsFakeClient(i) || (gI_HUDSettings[i] & HUD_MASTER) == 0)
		{
			continue;
		}

		if((gI_Cycle % 50) == 0)
		{
			float fSpeed[3];
			GetEntPropVector(GetHUDTarget(i), Prop_Data, "m_vecVelocity", fSpeed);
			gI_PreviousSpeed[i] = RoundToNearest(SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)));
		}

		TriggerHUDUpdate(i);
	}
}

void TriggerHUDUpdate(int client, bool keysonly = false) // keysonly because CS:S lags when you send too many usermessages
{
	if(!keysonly)
	{
		UpdateMainHUD(client);
		SetEntProp(client, Prop_Data, "m_bDrawViewmodel", ((gI_HUDSettings[client] & HUD_HIDEWEAPON) > 0)? 0:1);
		UpdateTopLeftHUD(client, true);
		
		UpdateKeyHint(client);
	}

	UpdateCenterKeys(client);
}

void AddHUDLine(char[] buffer, int maxlen, const char[] line, int lines)
{
	if(lines > 0)
	{
		Format(buffer, maxlen, "%s\n%s", buffer, line);
	}
	else
	{
		StrCat(buffer, maxlen, line);
	}
}

public void Shavit_OnEnterZone(int client, int type, int track, int id, int entity)
{
	if(type == Zone_CustomSpeedLimit)
	{
		gI_ZoneSpeedLimit[client] = Shavit_GetZoneData(id);
	}
}

int AddHUDToBuffer_Source2013(int client, huddata_t data, char[] buffer, int maxlen)
{
	int iLines = 0;
	char sLine[256];

	if(data.bReplay)
	{
		if(data.iStyle != -1 && data.fTime > 0.0 && data.fTime <= data.fWR && Shavit_IsReplayDataLoaded(data.iStyle, data.iTrack))
		{
			char sTrack[128];
			char sPlayerName[MAX_NAME_LENGTH];
			Shavit_GetReplayName(data.iStyle, data.iTrack, sPlayerName, MAX_NAME_LENGTH);
			
			if((data.iTrack == Track_Main || data.iTrack == Track_MainPartner) && (gI_HUDSettings[client] & HUD_TRACK) > 0)
			{
				sTrack[127] = Track_Main;
				Format(sTrack, 128, "%s [Normal]", sPlayerName, client);
				AddHUDLine(buffer, maxlen, sTrack, iLines);
				iLines++;
			}
			
			if((data.iTrack == Track_Bonus || data.iTrack == Track_BonusPartner) && (gI_HUDSettings[client] & HUD_TRACK) > 0)
			{
				sTrack[127] = Track_Bonus;
				Format(sTrack, 128, "%s [Bonus]", sPlayerName, client);
				AddHUDLine(buffer, maxlen, sTrack, iLines);
				iLines++;
			}
			
			if(data.iTrack == Track_Solobonus && (gI_HUDSettings[client] & HUD_TRACK) > 0)
			{
				Format(sTrack, 128, "%s [Solo]", sPlayerName, client);
				AddHUDLine(buffer, maxlen, sTrack, iLines);
				iLines++;
			}
			
			if(data.iStyle != 0 && (gI_HUDSettings[client] & HUD_STYLE) > 0)
			{
				FormatEx(sLine, 256, "%s", gS_StyleStrings[data.iStyle].sStyleName);
				AddHUDLine(buffer, maxlen, sLine, iLines);
				iLines++;
			}

			if((gI_HUD2Settings[client] & HUD2_TIME) == 0)
			{
				char sTime[32];
				FormatSeconds(data.fTime, sTime, 32, false);

				char sWR[32];
				FormatSeconds(data.fWR, sWR, 32, false);

				FormatEx(sLine, 256, "%s - %s (%.1f%%%)", sTime, sWR, ((data.fTime < 0.0 ? 0.0 : data.fTime / data.fWR) * 100));
				AddHUDLine(buffer, maxlen, sLine, iLines);
				iLines++;
			}

			if((gI_HUD2Settings[client] & HUD2_SPEED) == 0)
			{
				FormatEx(sLine, 256, "%d U/S", data.iSpeed);
				AddHUDLine(buffer, maxlen, sLine, iLines);
				iLines++;
			}
		}

		else
		{
			FormatEx(sLine, 256, "%T", "NoReplayData", client);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}

		return iLines;
	}
	
	int target = GetHUDTarget(client);

	if((gI_HUDSettings[client] & HUD_ZONEHUD) > 0 && data.iZoneHUD != ZoneHUD_None)
	{
		if(gB_Rankings && (gI_HUD2Settings[client] & HUD2_MAPTIER) == 0 && data.iTimerStatus == Timer_Stopped)
		{
			FormatEx(sLine, 128, "%T ", "HudZoneTier", client, Shavit_GetMapTier(gS_Map));
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
		
		if(data.iTimerStatus == Timer_Stopped && Shavit_InsideZone(target, Zone_Start, Track_Main))
		{
			FormatEx(sLine, 128, "%T ", "HudInStartZone", client, data.iSpeed);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
		
		if(data.iTimerStatus == Timer_Stopped && Shavit_InsideZone(target, Zone_Start, Track_Bonus))
		{
			FormatEx(sLine, 128, "%T ", "HudInBonusStartZone", client, data.iSpeed);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
		
		if(data.iTimerStatus == Timer_Stopped && Shavit_InsideZone(target, Zone_Start, Track_Solobonus))
		{
			FormatEx(sLine, 128, "%T ", "HudInSolobonusStartZone", client, data.iSpeed);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}

		if(data.iTimerStatus == Timer_Stopped && Shavit_InsideZone(target, Zone_End, Track_Main))
		{
			FormatEx(sLine, 128, "%T ", "HudInEndZone", client, data.iSpeed);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
		
		if(data.iTimerStatus == Timer_Stopped && Shavit_InsideZone(target, Zone_End, Track_Bonus) && !Shavit_InsideZone(target, Zone_End, Track_Main))
		{
			FormatEx(sLine, 128, "%T ", "HudInBonusEndZone", client, data.iSpeed);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
		
		if(data.iTimerStatus == Timer_Stopped && Shavit_InsideZone(target, Zone_End, Track_Solobonus) && !Shavit_InsideZone(target, Zone_End, Track_Main))
		{
			FormatEx(sLine, 128, "%T ", "HudInSolobonusEndZone", client, data.iSpeed);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
	}

	if(data.iTimerStatus == Timer_Running || data.iTimerStatus == Timer_Paused)
	{
		if(data.bPractice || data.iTimerStatus == Timer_Paused)
		{
			FormatEx(sLine, 128, "%T", (data.iTimerStatus == Timer_Paused)? "HudPaused":"HudPracticeMode", client);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
		
		if((data.iTrack == Track_Main && Shavit_InsideZone(target, Zone_End, Track_Main)) || (data.iTrack == Track_Bonus && Shavit_InsideZone(target, Zone_End, Track_Bonus)))
		{
			FormatEx(sLine, 128, "%T ", "HudAwaitingForYourPartner", client);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
		
		/*if(data.iStyle != 0 && (gI_HUD2Settings[client] & HUD2_STYLE) == 0)
		{
			AddHUDLine(buffer, maxlen, gS_StyleStrings[data.iStyle].sStyleName, iLines);
			iLines++;
		}*/

		if((gI_HUD2Settings[client] & HUD2_TIME) == 0)
		{
			char sTime[32];
			FormatSeconds(data.fTime, sTime, 32, false);

			if((gI_HUD2Settings[client] & HUD2_RANK) == 0 && data.iRank > 1)
			{
				FormatEx(sLine, 128, "%T: %s (#%d)", "HudTimeText", client, sTime, data.iRank);
			}

			else
			{
				FormatEx(sLine, 128, "%T: %s", "HudTimeText", client, sTime);
			}
			
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
		
		/*if((gI_HUD2Settings[client] & HUD2_JUMPS) == 0)
		{
			FormatEx(sLine, 128, "%T: %d", "HudJumpsText", client, data.iJumps);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}*/

		/*if((gI_HUD2Settings[client] & HUD2_STRAFES) == 0)
		{
			FormatEx(sLine, 128, "%T: %d", "HudStrafeText", client, data.iStrafes);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}*/
		
		/*if(data.iTrack != Track_Solobonus && (gI_HUD2Settings[client] & HUD2_NADES) == 0)
		{
			FormatEx(sLine, 128, "%T: %d", "HudNadesText", client, data.iNades);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}*/
	}

	if((gI_HUD2Settings[client] & HUD2_SPEED) == 0)
	{
		// timer: Speed: %d
		// no timer: straight up number
		if(data.iTimerStatus != Timer_Stopped && (data.iZoneHUD == ZoneHUD_None || data.iZoneHUD == ZoneHUD_Start || data.iZoneHUD == ZoneHUD_End))
		{
			FormatEx(sLine, 128, "%T: %d", "HudSpeedText", client, data.iSpeed);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
		
		else if(data.iTimerStatus == Timer_Stopped && data.iZoneHUD == ZoneHUD_None)
		{
			IntToString(data.iSpeed, sLine, 128);
			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}

		if(gA_StyleSettings[data.iStyle].fVelocityLimit > 0.0 && Shavit_InsideZone(data.iTarget, Zone_CustomSpeedLimit, -1))
		{
			if(gI_ZoneSpeedLimit[data.iTarget] == 0)
			{
				FormatEx(sLine, 128, "%T", "HudNoSpeedLimit", data.iTarget);
			}

			else
			{
				FormatEx(sLine, 128, "%T", "HudCustomSpeedLimit", client, gI_ZoneSpeedLimit[data.iTarget]);
			}

			AddHUDLine(buffer, maxlen, sLine, iLines);
			iLines++;
		}
	}

	/*if(data.iTimerStatus != Timer_Stopped && data.iTrack != Track_Main && (gI_HUD2Settings[client] & HUD2_TRACK) == 0)
	{
		char sTrack[32];
		GetTrackName(client, data.iTrack, sTrack, 32);

		AddHUDLine(buffer, maxlen, sTrack, iLines);
		iLines++;
	}*/

	return iLines;
}

void UpdateMainHUD(int client)
{
	int target = GetHUDTarget(client);

	if((gI_HUDSettings[client] & HUD_CENTER) == 0 || (gI_HUDSettings[client] & HUD_OBSERVE) == 0 && client != target)
	{
		return;
	}

	float fSpeed[3];
	GetEntPropVector(target, Prop_Data, "m_vecVelocity", fSpeed);

	float fSpeedHUD = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));
	bool bReplay = (gB_Replay && IsFakeClient(target));
	ZoneHUD iZoneHUD = ZoneHUD_None;
	int iReplayStyle = 0;
	int iReplayTrack = 0;
	float fReplayTime = 0.0;
	float fReplayLength = 0.0;

	if(!bReplay)
	{
		if(Shavit_InsideZone(target, Zone_Start, -1))
		{
			iZoneHUD = ZoneHUD_Start;
		}
		
		else if(Shavit_InsideZone(target, Zone_End, -1))
		{
			iZoneHUD = ZoneHUD_End;
		}
	}

	else
	{
		iReplayStyle = Shavit_GetReplayBotStyle(target);
		iReplayTrack = Shavit_GetReplayBotTrack(target);

		if(iReplayStyle != -1)
		{
			fReplayTime = Shavit_GetReplayTime(iReplayStyle, iReplayTrack);
			fReplayLength = Shavit_GetReplayLength(iReplayStyle, iReplayTrack);

			if(gA_StyleSettings[iReplayStyle].fSpeedMultiplier != 1.0)
			{
				fSpeedHUD /= gA_StyleSettings[iReplayStyle].fSpeedMultiplier;
			}
		}
	}

	huddata_t huddata;
	huddata.iTarget = target;
	huddata.iSpeed = RoundToNearest(fSpeedHUD);
	huddata.iZoneHUD = iZoneHUD;
	huddata.iStyle = (bReplay)? iReplayStyle:Shavit_GetBhopStyle(target);
	huddata.iTrack = (bReplay)? iReplayTrack:Shavit_GetClientTrack(target);
	huddata.fTime = (bReplay)? fReplayTime:Shavit_GetClientTime(target);
	huddata.iJumps = (bReplay)? 0:Shavit_GetClientJumps(target);
	huddata.iStrafes = (bReplay)? 0:Shavit_GetStrafeCount(target);
	huddata.iNades = (bReplay)? 0:Shavit_GetThrowedNadesCount(target);
	huddata.iRank = (bReplay)? 0:Shavit_GetRankForTime(huddata.iStyle, huddata.fTime, huddata.iTrack);
	huddata.fSync = (bReplay)? 0.0:Shavit_GetSync(target);
	huddata.fPB = (bReplay)? 0.0:Shavit_GetClientPB(target, huddata.iStyle, huddata.iTrack);
	huddata.fWR = (bReplay)? fReplayLength:Shavit_GetWorldRecord(huddata.iStyle, huddata.iTrack);
	huddata.iTimerStatus = (bReplay)? Timer_Running:Shavit_GetTimerStatus(target);
	huddata.bReplay = bReplay;
	huddata.bPractice = (bReplay)? false:Shavit_IsPracticeMode(target);

	char sBuffer[512];
	
	if(AddHUDToBuffer_Source2013(client, huddata, sBuffer, 512) > 0)
	{
		PrintHintText(client, "%s", sBuffer);
	}
}

public void Bunnyhop_OnTouchGround(int client)
{
	gI_LastScrollCount[client] = BunnyhopStats.GetScrollCount(client);
}

public void Bunnyhop_OnJumpPressed(int client)
{
	gI_ScrollCount[client] = BunnyhopStats.GetScrollCount(client);
}

void UpdateCenterKeys(int client)
{
	if((gI_HUDSettings[client] & HUD_KEYOVERLAY) == 0)
	{
		return;
	}

	int target = GetHUDTarget(client);

	if(((gI_HUDSettings[client] & HUD_OBSERVE) == 0 && client != target) || !IsValidClient(target) || IsClientObserver(target))
	{
		return;
	}

	int buttons = gI_Buttons[target];

	char sCenterText[64];
	FormatEx(sCenterText, 64, "　%s　　%s\n　　 %s\n%s　 %s 　%s", 
		(buttons & IN_JUMP) > 0? "Ｊ":"ｰ", (buttons & IN_DUCK) > 0? "Ｃ":"ｰ",
		(buttons & IN_FORWARD) > 0? "Ｗ":"ｰ", (buttons & IN_MOVELEFT) > 0? "Ａ":"ｰ",
		(buttons & IN_BACK) > 0? "Ｓ":"ｰ", (buttons & IN_MOVERIGHT) > 0? "Ｄ":"ｰ");

	int style = (IsFakeClient(target))? Shavit_GetReplayBotStyle(target):Shavit_GetBhopStyle(target);

	if(!(0 <= style < gI_Styles))
	{
		style = 0;
	}

	if(gB_BhopStats && !gA_StyleSettings[style].bAutobhop)
	{
		Format(sCenterText, 64, "%s\n　　%d　%d", sCenterText, gI_ScrollCount[target], gI_LastScrollCount[target]);
	}

	SetHudTextParams(0.46, 0.2, 1.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(client, 0, "%s", sCenterText);
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle();
}

void UpdateTopLeftHUDWRPart(int client)
{
	int target = GetHUDTarget(client);

	int track = 0;
	int style = 0;

	if(!IsFakeClient(target))
	{
		style = Shavit_GetBhopStyle(target);
		track = Shavit_GetClientTrack(target);
	}

	else
	{
		style = Shavit_GetReplayBotStyle(target);
		track = Shavit_GetReplayBotTrack(target);
	}

	if(!(0 <= style < gI_Styles) || !(0 <= track <= TRACKS_SIZE))
	{
		return;
	}
	
	if(track == Track_MainPartner)
	{
		track = Track_Main;
	}
	
	if(track == Track_BonusPartner)
	{
		track = Track_Bonus;
	}

	float fWRTime = Shavit_GetWorldRecord(style, track);

	if(fWRTime != 0.0)
	{
		char sWRTime[16];
		FormatSeconds(fWRTime, sWRTime, 16);
		char sWRName[MAX_NAME_LENGTH];
		Shavit_GetWRName(style, sWRName, MAX_NAME_LENGTH, track);
		
		if(track == Track_Main && style == 0)
		{
			Format(sTopLeft, 256, "WR: %s (%s)", sWRTime, sWRName);
		}
		
		if(track == Track_Main && style == 1)
		{
			Format(sTopLeft, 256, "SWWR: %s (%s)", sWRTime, sWRName);
		}
		
		if(track == Track_Main && style == 2)
		{
			Format(sTopLeft, 256, "WWR: %s (%s)", sWRTime, sWRName);
		}
		
		if(track == Track_Main && style == 3)
		{
			Format(sTopLeft, 256, "HSWWR: %s (%s)", sWRTime, sWRName);
		}
		
		if(track == Track_Bonus && style == 0)
		{
			Format(sTopLeft, 256, "BWR: %s (%s)", sWRTime, sWRName);
		}
		
		if(track == Track_Bonus && style == 1)
		{
			Format(sTopLeft, 256, "BSWWR: %s (%s)", sWRTime, sWRName);
		}
		
		if(track == Track_Bonus && style == 2)
		{
			Format(sTopLeft, 256, "BWWR: %s (%s)", sWRTime, sWRName);
		}
		
		if(track == Track_Bonus && style == 3)
		{
			Format(sTopLeft, 256, "BHSWWR: %s (%s)", sWRTime, sWRName);
		}
		
		float fPB = Shavit_GetClientPB(client, style, track);
		char sPB[64];
		FormatSeconds(fPB, sPB, 64);
		Format(sWRName, MAX_NAME_LENGTH, "(%s)", sWRName);
		
		if(track == Track_Solobonus && style == 0)
		{
			Format(sTopLeft, 256, "SBWR: %s %s", sWRTime, StrEqual(sPB, sWRTime) ? "" : sWRName);
		}
		
		if(track == Track_Solobonus && style == 1)
		{
			Format(sTopLeft, 256, "SBSWWR: %s %s", sWRTime, StrEqual(sPB, sWRTime) ? "" : sWRName);
		}
		
		if(track == Track_Solobonus && style == 2)
		{
			Format(sTopLeft, 256, "SBWWR: %s %s", sWRTime, StrEqual(sPB, sWRTime) ? "" : sWRName);
		}
		
		if(track == Track_Solobonus && style == 3)
		{
			Format(sTopLeft, 256, "SBHSWWR: %s %s", sWRTime, StrEqual(sPB, sWRTime) ? "" : sWRName);
		}
	}
	
	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_OnTopLeftHUD);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_PushStringEx(sTopLeft, 256, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(256);
	Call_Finish(result);
	
	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return;
	}
	
	SetHudTextParams(0.01, 0.01, 2.5, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(client, 2, "%s", sTopLeft);
}

void UpdateTopLeftHUD(int client, bool wait)
{
	if((!wait || gI_Cycle % 25 == 0) && (gI_HUDSettings[client] & HUD_TOPLEFT) > 0)
	{
		int target = GetHUDTarget(client);

		int track = 0;
		int style = 0;

		if(!IsFakeClient(target))
		{
			style = Shavit_GetBhopStyle(target);
			track = Shavit_GetClientTrack(target);
		}

		else
		{
			style = Shavit_GetReplayBotStyle(target);
			track = Shavit_GetReplayBotTrack(target);
		}

		if(!(0 <= style < gI_Styles) || !(0 <= track <= TRACKS_SIZE))
		{
			return;
		}
		
		if(track == Track_MainPartner)
		{
			track = Track_Main;
		}
		
		if(track == Track_BonusPartner)
		{
			track = Track_Bonus;
		}

		float fWRTime = Shavit_GetWorldRecord(style, track);

		if(fWRTime != 0.0)
		{
			char sQuery[512];
			
			if(IsPlayerAlive(client))
			{
				int iSteamID = GetSteamAccountID(client);
				FormatEx(sQuery, 512,
									  "SELECT MIN(time), auth, partner "...
									  "FROM %splayertimes "...
									  "WHERE map = '%s' AND (auth = %d OR partner = %d) "...
									  "AND style = %d AND track = %d;",
									  gS_MySQLPrefix, gS_Map, iSteamID, iSteamID, style, track);
				
				DataPack hPack = new DataPack();
				hPack.WriteCell(GetClientSerial(client));
				gH_SQL.Query(SQL_OnPersonalBest, sQuery, hPack);
			}
			
			if((IsPlayerAlive(target) && client != target) || IsFakeClient(target))
			{
				int iSteamIDTarget = GetSteamAccountID(target);
				
				if(IsFakeClient(target))
				{
					iSteamIDTarget = GetSteamAccountID(client);
				}
				
				FormatEx(sQuery, 512,
									  "SELECT MIN(time), auth, partner "...
									  "FROM %splayertimes "...
									  "WHERE map = '%s' AND (auth = %d OR partner = %d) "...
									  "AND style = %d AND track = %d;",
									  gS_MySQLPrefix, gS_Map, iSteamIDTarget, iSteamIDTarget, style, track);
			
				DataPack hPack = new DataPack();
				hPack.WriteCell(GetClientSerial(client));
				gH_SQL.Query(SQL_OnPersonalBestTarget, sQuery, hPack);
			}
		}
	}
}

public void SQL_OnPersonalBest(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack hPack = data;
	hPack.Reset();
	int iSerial = hPack.ReadCell();
	delete hPack;
	
	if(results == null)
	{
		LogError("Timer (On personal best) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(iSerial);

	if(client < 1)
	{
		return;
	}
	
	if(results.FetchRow())
	{
		int iClientID = results.FetchInt(1);
		int iPartnerID = results.FetchInt(2);
		char sGetID[32];
		GetClientAuthId(client, AuthId_Steam3, sGetID, 32);
		char sQuery[512];
		char sClientID[32];
		char sPartnerID[32];
		IntToString(iClientID, sClientID, 32);
		IntToString(iPartnerID, sPartnerID, 32);
		
		if(StrContains(sGetID, sClientID) != -1)
		{
			FormatEx(sQuery, 512,
								  "SELECT name "...
								  "FROM %susers "...
								  "WHERE auth = %d;",
								  gS_MySQLPrefix, iPartnerID);
			
			gB_namefirstOwn[client] = true;
			gB_namefirstPartner[client] = false;
		}
		
		else if(StrContains(sGetID, sPartnerID) != -1)
		{
			FormatEx(sQuery, 512,
								  "SELECT name "...
								  "FROM %susers "...
								  "WHERE auth = %d;",
								  gS_MySQLPrefix, iClientID);
			
			gB_namefirstOwn[client] = false;
			gB_namefirstPartner[client] = true;
		}
		
		gH_SQL.Query(SQL_OnPersonalBest2, sQuery, iSerial);
	}
}

public void SQL_OnPersonalBest2(Database db, DBResultSet results, const char[] error, any data)
{	
	int client = GetClientFromSerial(data);
	
	if(client < 1)
	{
		return;
	}
	
	if(results == null)
	{
		//LogError("Timer (On personal best2) SQL query failed. Reason: %s", error);
		UpdateTopLeftHUDWRPart(client);
		
		return;
	}
	
	UpdateTopLeftHUDWRPart(client);
	
	int target = GetHUDTarget(client);
	int track = 0;
	int style = 0;

	if(!IsFakeClient(target))
	{
		style = Shavit_GetBhopStyle(target);
		track = Shavit_GetClientTrack(target);
	}

	else
	{
		style = Shavit_GetReplayBotStyle(target);
		track = Shavit_GetReplayBotTrack(target);
	}

	if(!(0 <= style < gI_Styles) || !(0 <= track <= TRACKS_SIZE))
	{
		return;
	}
	
	if(track == Track_MainPartner)
	{
		track = Track_Main;
	}
	
	if(track == Track_BonusPartner)
	{
		track = Track_Bonus;
	}
	
	if(results.FetchRow())
	{
		char sPartnerName[MAX_NAME_LENGTH];
		results.FetchString(0, sPartnerName, MAX_NAME_LENGTH);
		
		if(strlen(sPartnerName) > 10)
		{
			Format(sPartnerName, 10, "%s", sPartnerName);
			Format(sPartnerName, MAX_NAME_LENGTH, "%s...", sPartnerName);
		}

		float fSelfPB = Shavit_GetClientPB(client, style, track);
		char sSelfPB[64];
		FormatSeconds(fSelfPB, sSelfPB, 64);
		Format(sSelfPB, 64, "%T: %s", "HudPersonalBestText", client, sSelfPB);
		char sClientName[MAX_NAME_LENGTH];
		Format(sClientName, MAX_NAME_LENGTH, "%N", client);
		
		if(strlen(sClientName) > 10)
		{
			Format(sClientName, 10, "%s", sClientName);
			Format(sClientName, MAX_NAME_LENGTH, "%s...", sClientName);
		}
		
		if(fSelfPB != 0.0)
		{
			if(track == Track_Solobonus)
			{
				Format(sTopLeft, 256, "\n%s (#%d)", sSelfPB, Shavit_GetRankForTime(style, fSelfPB, track));
			}
			
			else
			{
				if(gB_namefirstOwn[client])
				{
					Format(sTopLeft, 256, "\n%s (%s & %s) (#%d)", sSelfPB, sClientName, sPartnerName, Shavit_GetRankForTime(style, fSelfPB, track));
				}
				
				if(gB_namefirstPartner[client])
				{
					Format(sTopLeft, 256, "\n%s (%s & %s) (#%d)", sSelfPB, sPartnerName, sClientName, Shavit_GetRankForTime(style, fSelfPB, track));
				}
			}
		}
	}
	
	SetHudTextParams(0.01, 0.01, 2.5, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(client, 3, "%s", sTopLeft);
}

public void SQL_OnPersonalBestTarget(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack hPack = data;
	hPack.Reset();
	int iSerial = hPack.ReadCell();
	delete hPack;
	
	if(results == null)
	{
		LogError("Timer (On personal best target) SQL query failed. Reason: %s", error);

		return;
	}
	
	int client = GetClientFromSerial(iSerial);
	
	if(client < 1)
	{
		return;
	}
	
	int target = GetHUDTarget(client);
	
	if(IsFakeClient(target))
	{
		target = client;
	}
	
	if(results.FetchRow())
	{
		int iClientID = results.FetchInt(1);
		int iPartnerID = results.FetchInt(2);
		char sGetID[32];
		GetClientAuthId(target, AuthId_Steam3, sGetID, 32);
		char sQuery[512];
		char sClientID[32];
		char sPartnerID[32];
		IntToString(iClientID, sClientID, 32);
		IntToString(iPartnerID, sPartnerID, 32);
		
		if(StrContains(sGetID, sClientID) != -1)
		{
			FormatEx(sQuery, 512,
								  "SELECT name "...
								  "FROM %susers "...
								  "WHERE auth = %d;",
								  gS_MySQLPrefix, iPartnerID);
			
			gB_namefirstOwn[client] = true;
			gB_namefirstPartner[client] = false;
		}
		
		else if(StrContains(sGetID, sPartnerID) != -1)
		{
			FormatEx(sQuery, 512,
								  "SELECT name "...
								  "FROM %susers "...
								  "WHERE auth = %d;",
								  gS_MySQLPrefix, iClientID);
			
			gB_namefirstOwn[client] = false;
			gB_namefirstPartner[client] = true;
		}
		
		gH_SQL.Query(SQL_OnPersonalBestTarget2, sQuery, iSerial);
	}
}

public void SQL_OnPersonalBestTarget2(Database db, DBResultSet results, const char[] error, any data)
{		
	int client = GetClientFromSerial(data);
	
	if(client < 1)
	{
		return;
	}
	
	if(results == null)
	{
		//LogError("Timer (On personal best target2) SQL query failed. Reason: %s", error);
		UpdateTopLeftHUDWRPart(client);
		
		return;
	}
	
	UpdateTopLeftHUDWRPart(client);
	
	int target = GetHUDTarget(client);
	
	if(results.FetchRow())
	{
		char sName[MAX_NAME_LENGTH];
		results.FetchString(0, sName, MAX_NAME_LENGTH);
		
		if(strlen(sName) > 10)
		{
			Format(sName, 10, "%s", sName);
			Format(sName, MAX_NAME_LENGTH, "%s...", sName);
		}
		
		int style = Shavit_GetBhopStyle(target);
		int track = Shavit_GetClientTrack(target);
		float fTargetPB = Shavit_GetClientPB(target, style, track);
		char sTargetPB[64];
		FormatSeconds(fTargetPB, sTargetPB, 64);
		Format(sTargetPB, 64, "%T: %s", "HudPersonalBestText", client, sTargetPB);
		char sTarget[MAX_NAME_LENGTH];
		Format(sTarget, MAX_NAME_LENGTH, "%N", target);
		
		if(strlen(sTarget) > 10)
		{
			Format(sTarget, 10, "%s", sTarget);
			Format(sTarget, MAX_NAME_LENGTH, "%s...", sTarget);
		}
		
		if(fTargetPB != 0.0)
		{
			if(track == Track_Solobonus)
			{
				char sTName[MAX_NAME_LENGTH];
				Format(sTName, MAX_NAME_LENGTH, "%N", target);
				
				if(strlen(sTName) > 10)
				{
					Format(sTName, 10, "%s", sTName);
					Format(sTName, MAX_NAME_LENGTH, "%s...", sTName);
				}
				
				Format(sTopLeft, 256, "\n%s (#%d)", sTargetPB, Shavit_GetRankForTime(style, fTargetPB, track));
			}
			
			else
			{
				if(gB_namefirstOwn[client])
				{
					Format(sTopLeft, 256, "\n%s (%s & %s) (#%d)", sTargetPB, sName, sTarget, Shavit_GetRankForTime(style, fTargetPB, track));
				}
				
				if(gB_namefirstPartner[client])
				{
					Format(sTopLeft, 256, "\n%s (%s & %s) (#%d)", sTargetPB, sTarget, sName, Shavit_GetRankForTime(style, fTargetPB, track));
				}
			}
		}
	}
	
	SetHudTextParams(0.01, 0.01, 2.5, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(client, 3, "%s", sTopLeft);
}

void UpdateKeyHint(int client)
{
	if((gI_Cycle % 10) == 0)
	{
		char sMessage[256];
		int iTimeleft = -1;

		if((gI_HUDSettings[client] & HUD_TIMELEFT) > 0 && GetMapTimeLeft(iTimeleft) && iTimeleft > 0)
		{
			char sTimeleft[32];
			FormatSeconds(float(iTimeleft), sTimeleft, sizeof(sTimeleft));
			
			if(iTimeleft >= 36000)
			{
				Format(sTimeleft, 9, "%s", sTimeleft);
			}
			
			if(iTimeleft < 36000 && iTimeleft >= 3600)
			{
				Format(sTimeleft, 8, "%s", sTimeleft);
			}
			
			if(iTimeleft < 3600 && iTimeleft >= 300)
			{
				Format(sTimeleft, 6, "%s", sTimeleft);
			}
			
			if(iTimeleft < 600 && iTimeleft >= 80)
			{
				Format(sTimeleft, 5, "%s", sTimeleft);
			}
			
			if(iTimeleft < 60 && iTimeleft >= 10)
			{
				Format(sTimeleft, 3, "%s", sTimeleft);
			}
			
			if(iTimeleft < 10)
			{
				Format(sTimeleft, 2, "%s", sTimeleft);
			}
			
			//FormatEx(sMessage, 256, (iTimeleft > 60)? "%T: %d minutes\n\n":"%T: <1 minute\n\n", "HudTimeLeft", client, (iTimeleft / 60), "HudTimeLeft", client);
			Format(sMessage, 256, "%T: %s\n\n", "HudTimeLeft", client, sTimeleft);
		}

		int target = GetHUDTarget(client);

		if(IsValidClient(target) && (target == client || (gI_HUDSettings[client] & HUD_OBSERVE) > 0))
		{
			if(Shavit_GetTimerStatus(target) == Timer_Running)
			{
				if(Shavit_GetBhopStyle(target) != 0 && (gI_HUDSettings[client] & HUD2_STYLE) > 0)
				{
					FormatEx(sMessage, 128, "%s%s\n", sMessage, gS_StyleStrings[Shavit_GetBhopStyle(target)].sStyleName);
				}
				
				if((gI_HUDSettings[client] & HUD_JUMPS) > 0 && Shavit_GetClientJumps(target) > 0)
				{
					Format(sMessage, 128, "%s%T: %d\n", sMessage, "HudJumpsText", client, Shavit_GetClientJumps(target));
				}
				
				if((gI_HUDSettings[client] & HUD_STRAFES) > 0 && Shavit_GetStrafeCount(target) > 0)
				{
					Format(sMessage, 128, "%s%T: %d\n", sMessage, "HudStrafeText", client, Shavit_GetStrafeCount(target));
				}
			
				if(Shavit_GetClientTrack(target) != Track_Solobonus && (gI_HUDSettings[client] & HUD_NADES) > 0 && Shavit_GetThrowedNadesCount(target) > 0)
				{
					FormatEx(sMessage, 128, "%s%T: %d\n", sMessage, "HudNadesText", client, Shavit_GetThrowedNadesCount(target));
				}
				
				if((gI_HUDSettings[client] & HUD_SYNC) > 0 && gA_StyleSettings[Shavit_GetBhopStyle(target)].bSync && !IsFakeClient(target) && (!gB_Zones || !Shavit_InsideZone(target, Zone_Start, -1)))
				{
					if(gA_StyleSettings[Shavit_GetBhopStyle(target)].bAutobhop && Shavit_GetSync(target) > 0.0)
					{
						Format(sMessage, 256, (Shavit_GetClientTrack(target) == Track_Main) ? "%s%T: %.01f\n\n" : "%s%T: %.01f\n", sMessage, "HudSync", client, Shavit_GetSync(target));
					}
					
					if(!gA_StyleSettings[Shavit_GetBhopStyle(target)].bAutobhop && Shavit_GetPerfectJumps(target) > 0.0)
					{	
						Format(sMessage, 256, (Shavit_GetClientTrack(target) == Track_Main) ? "%s\n%T: %.1f\n\n" : "%s\n%T: %.1f\n", sMessage, "HudPerfs", client, Shavit_GetPerfectJumps(target));
					}
				}
				
				if(Shavit_GetClientTrack(target) != Track_Main && (gI_HUDSettings[client] & HUD_TRACK) > 0)
				{
					char sTrack[32];
					GetTrackName(client, Shavit_GetClientTrack(target), sTrack, 32);
					Format(sMessage, 128, "%s%s\n\n", sMessage, sTrack);
				}
			}

			if((gI_HUDSettings[client] & HUD_SPECTATORS) > 0)
			{
				int[] iSpectatorClients = new int[MaxClients];
				int iSpectators = 0;
				bool bIsAdmin = CheckCommandAccess(client, "admin_speclisthide", ADMFLAG_KICK);

				for(int i = 1; i <= MaxClients; i++)
				{
					if(i == client || !IsValidClient(i) || IsFakeClient(i) || !IsClientObserver(i) || GetClientTeam(i) < 1 || GetHUDTarget(i) != target)
					{
						continue;
					}

					if((gCV_SpectatorList.IntValue == 1 && !bIsAdmin && CheckCommandAccess(i, "admin_speclisthide", ADMFLAG_KICK)) ||
						(gCV_SpectatorList.IntValue == 2 && !CanUserTarget(client, i)))
					{
						continue;
					}

					iSpectatorClients[iSpectators++] = i;
				}

				if(iSpectators > 0)
				{
					Format(sMessage, 256, "%s%spectators (%d):", sMessage, (client == target)? "S":"Other S", iSpectators);

					for(int i = 0; i < iSpectators; i++)
					{
						if(i == 7)
						{
							Format(sMessage, 256, "%s\n...", sMessage);

							break;
						}

						char[] sName = new char[MAX_NAME_LENGTH];
						GetClientName(iSpectatorClients[i], sName, MAX_NAME_LENGTH);
						
						if(strlen(sName) > 10)
						{
							Format(sName, 10, "%s", sName);
							Format(sName, MAX_NAME_LENGTH, "%s...", sName);
						}
						
						ReplaceString(sName, MAX_NAME_LENGTH, "#", "?");
						Format(sMessage, 256, "%s\n%s", sMessage, sName);
					}
				}
			}
		}

		if(strlen(sMessage) > 0)
		{
			SetHudTextParams(0.01, 0.09, 1.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
			ShowHudText(client, 1, "%s", sMessage);
		}
	}
}

int GetHUDTarget(int client)
{
	int target = client;

	if(IsClientObserver(client))
	{
		int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if(3 < iObserverMode < 7)
		{
			int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if(IsValidClient(iTarget, true))
			{
				target = iTarget;
			}
		}
	}

	return target;
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	if(IsClientInGame(client))
	{
		UpdateTopLeftHUD(client, false);
	}
}

public int Native_ForceHUDUpdate(Handle handler, int numParams)
{
	int[] clients = new int[MaxClients];
	int count = 0;

	int client = GetNativeCell(1);

	if(client < 0 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(200, "Invalid client index %d", client);

		return -1;
	}

	clients[count++] = client;

	if(view_as<bool>(GetNativeCell(2)))
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(i == client || !IsValidClient(i) || GetHUDTarget(i) != client)
			{
				continue;
			}

			clients[count++] = client;
		}
	}

	for(int i = 0; i < count; i++)
	{
		TriggerHUDUpdate(clients[i]);
	}

	return count;
}

public int Native_GetHUDSettings(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	if(client < 0 || client > MaxClients)
	{
		ThrowNativeError(200, "Invalid client index %d", client);

		return -1;
	}

	return gI_HUDSettings[client];
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
