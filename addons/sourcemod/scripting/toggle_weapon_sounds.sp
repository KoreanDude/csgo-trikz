#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
//#undef REQUIRE_PLUGIN
#include <clientprefs>
#include <colorvariables>
#include <trikz>

#define PLUGIN_NAME 	"Toggle Weapon Sounds clientprefs"
#define PLUGIN_VERSION 	"1.0.3 fix m_iWeaponID + new syntax"

//#define UPDATE_URL	"http://godtony.mooo.com/stopsound/stopsound.txt"

bool g_bDisableStopSound[MAXPLAYERS+1]; bool g_bHooked;

Handle g_hClientCookie = INVALID_HANDLE;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "GoD-Tony",
	description = "Allows clients to stop hearing weapon sounds",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public OnPluginStart()
{
	g_hClientCookie = RegClientCookie("WeaponSounds", "Toggle hearing weapon sounds", CookieAccess_Private);
	//SetCookiePrefabMenu(g_hClientCookie, CookieMenu_OnOff_Int, "Toggle Weapon Sounds", StopSoundCookieHandler);

	// Detect game and hook appropriate tempent.
	char sGame[32];
	GetGameFolderName(sGame, sizeof(sGame));

	if (StrEqual(sGame, "cstrike") || StrEqual(sGame, "csgo"))
		AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
	else if (StrEqual(sGame, "dod"))
		AddTempEntHook("FireBullets", DODS_Hook_FireBullets);
	
	// TF2/HL2:DM and misc weapon sounds will be caught here.
	AddNormalSoundHook(Hook_NormalSound);
	
	CreateConVar("sm_stopsound_version", PLUGIN_VERSION, "Toggle Weapon Sounds", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	RegConsoleCmd("sm_stopsound", Command_StopSound, "Toggle hearing weapon sounds");
	RegConsoleCmd("sm_weaponsound", Command_StopSound, "Toggle hearing weapon sounds");
	
	// Updater.
	//if (LibraryExists("updater"))
	//{
	//	Updater_AddPlugin(UPDATE_URL);
	//}

	for (new i = 1; i <= MaxClients; ++i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		
		OnClientCookiesCached(i);
	}
}

/*
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}
*/

public OnClientCookiesCached(client)
{
	char sValue[8];
	GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));
	
	g_bDisableStopSound[client] = (sValue[0] != '\0' && StringToInt(sValue));
	CheckHooks();
}

public Action Command_StopSound(client, args)
{
	// Prevent this command from being spammed.
	if (!IsClientInGame(client) || !client)
		return Plugin_Handled;
		
	if (!g_bDisableStopSound[client])
	{
		g_bDisableStopSound[client] = true;
		char sCookieValue[12];
		IntToString(1, sCookieValue, sizeof(sCookieValue));
		SetClientCookie(client, g_hClientCookie, sCookieValue);
		CPrintToChat(client, "{green}[SM]{lightgreen} Weapon Sound is {blue}Enabled{default}.");
	}
	else
	{
		g_bDisableStopSound[client] = false;
		char sCookieValue[12];
		IntToString(0, sCookieValue, sizeof(sCookieValue));
		SetClientCookie(client, g_hClientCookie, sCookieValue);
		CPrintToChat(client, "{green}[SM]{lightgreen} Weapon Sound is {red}Disabled{default}.");
	}
	return Plugin_Handled;
}

public OnClientPutInServer(client)
{
	if (!AreClientCookiesCached(client))
	{
		g_bDisableStopSound[client] = false;
	}
}

public OnClientDisconnect_Post(client)
{
	g_bDisableStopSound[client] = false;
	CheckHooks();
}

CheckHooks()
{
	bool bShouldHook = false;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_bDisableStopSound[i])
		{
			bShouldHook = true;
			break;
		}
	}
	
	// Fake (un)hook because toggling actual hooks will cause server instability.
	g_bHooked = bShouldHook;
}

public Action Hook_NormalSound(clients[64], &numClients, char sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	//new client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	// Ignore non-weapon sounds.
	if (!g_bHooked || !(strncmp(sample, "weapons", 7) == 0 || strncmp(sample[1], "weapons", 7) == 0))
		return Plugin_Continue;
	
	int i, j;
	
	for (i = 0; i < numClients; i++)
	{
		if (g_bDisableStopSound[clients[i]])
		{
			// Remove the client from the array.
			for (j = i; j < numClients-1; j++)
			{
				clients[j] = clients[j+1];
			}
			
			numClients--;
			i--;
		}
	}
	
	return (numClients > 0) ? Plugin_Changed : Plugin_Stop;
}

public Action CSS_Hook_ShotgunShot(const char []te_name, const Players[], numClients, float delay)
{
	if (!g_bHooked)
		return Plugin_Continue;
	
	// Check which clients need to be excluded.
	decl newClients[MaxClients], client, i;
	int newTotal = 0;
	
	for (i = 0; i < numClients; i++)
	{
		client = Players[i];
		
		if (!g_bDisableStopSound[client])
		{
			newClients[newTotal++] = client;
		}
	}
	
	// No clients were excluded.
	if (newTotal == numClients)
		return Plugin_Continue;
	
	// All clients were excluded and there is no need to broadcast.
	else if (newTotal == 0)
		return Plugin_Stop;
	
	// Re-broadcast to clients that still need it.
	float vTemp[3];
	TE_Start("Shotgun Shot");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_Send(newClients, newTotal, delay);
	
	return Plugin_Stop;
}

public Action DODS_Hook_FireBullets(const char []te_name, const Players[], numClients, float delay)
{
	if (!g_bHooked)
		return Plugin_Continue;
	
	// Check which clients need to be excluded.
	decl newClients[MaxClients], client, i;
	int newTotal = 0;
	
	for (i = 0; i < numClients; i++)
	{
		client = Players[i];
		
		if (!g_bDisableStopSound[client])
		{
			newClients[newTotal++] = client;
		}
	}
	
	// No clients were excluded.
	if (newTotal == numClients)
		return Plugin_Continue;
	
	// All clients were excluded and there is no need to broadcast.
	else if (newTotal == 0)
		return Plugin_Stop;
	
	// Re-broadcast to clients that still need it.
	float vTemp[3];
	TE_Start("FireBullets");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_flSpread", TE_ReadFloat("m_flSpread"));
	TE_Send(newClients, newTotal, delay);
	
	return Plugin_Stop;
}