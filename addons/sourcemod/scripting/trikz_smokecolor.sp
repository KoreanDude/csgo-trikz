#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

Handle gH_SmokeSetting = INVALID_HANDLE
int gI_SmokeSetting[MAXPLAYERS + 1]

public Plugin myinfo = 
{
	name =			"Smoke(Flash) Color",
	author = 		"SHIM",
	description =	"",
	version =		"0.1",
	url =			""
}

public void OnPluginStart()
{
	gH_SmokeSetting = RegClientCookie("SmokeSetting", "SmokeSetting", CookieAccess_Private);
	
	RegConsoleCmd("sm_fb", Command_SmokeMenu);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(AreClientCookiesCached(i))
				OnClientCookiesCached(i);
			else
				gI_SmokeSetting[i] = 3;
		}
	}
}

public void OnMapStart()
{
	PrecacheModel("models/weapons/w_eq_smokegrenade_thrown.mdl");
	PrecacheModel("models/yatta/smokegrenade_trikz.mdl");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "flashbang_projectile"))
	{
		SDKHook(entity, SDKHook_SpawnPost, SpawnPostFlash);
	}
}

public Action SpawnPostFlash(int entity, int other)
{
	int Owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")
	
	if(gI_SmokeSetting[Owner] == 0)	SetEntityModel(entity, "models/weapons/w_eq_smokegrenade_thrown.mdl");
	if(gI_SmokeSetting[Owner] >= 1)
	{
		SetEntityModel(entity, "models/yatta/smokegrenade_trikz.mdl");
		
		if(gI_SmokeSetting[Owner] == 1) SetEntityRenderColor(entity, 255, 255, 255, 255);
		else if(gI_SmokeSetting[Owner] == 2) SetEntityRenderColor(entity, 255, 0, 0, 255);
		else if(gI_SmokeSetting[Owner] == 3) SetEntityRenderColor(entity, 0, 255, 0, 255);
		else if(gI_SmokeSetting[Owner] == 4) SetEntityRenderColor(entity, 0, 250, 250, 255);
		else if(gI_SmokeSetting[Owner] == 5) SetEntityRenderColor(entity, 255, 255, 0, 255);
	}
}

public void OnClientCookiesCached(int client)
{
	char sCookie[12]
	GetClientCookie(client, gH_SmokeSetting, sCookie, sizeof(sCookie))
	gI_SmokeSetting[client] = StringToInt(sCookie)
}

Action Command_SmokeMenu(int client, int args)
{
	SmokeMenu(client)
	
	char sCookie[12]
	Format(sCookie, sizeof(sCookie), "%i", gI_SmokeSetting[client])
	SetClientCookie(client, gH_SmokeSetting, sCookie)
	
	return Plugin_Handled
}

public SmokeMenu(client)
{
	new Handle:MenuHandle = CreateMenu(MenuHandler_SmokeMenu);

	new String:Title[512];
	Format(Title, sizeof(Title), "Set your fb colors\n ");
	SetMenuTitle(MenuHandle, Title);

	AddMenuItem(MenuHandle, "None", "None");
	AddMenuItem(MenuHandle, "White", "White");
	AddMenuItem(MenuHandle, "Red", "Red");
	AddMenuItem(MenuHandle, "Green", "Green");
	AddMenuItem(MenuHandle, "Blue", "Blue");
	AddMenuItem(MenuHandle, "Yellow", "Yellow");
	
	SetMenuPagination(MenuHandle, MENU_NO_PAGINATION);
	SetMenuExitButton(MenuHandle, true);

	DisplayMenu(MenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_SmokeMenu(Handle:menu, MenuAction:action, client, select)
{
	if(action == MenuAction_Select)
	{
		new String:MenuItem[256];
		GetMenuItem(menu, select, MenuItem, sizeof(MenuItem));

		if(StrEqual(MenuItem, "None", false)) gI_SmokeSetting[client] = 0;
		else if(StrEqual(MenuItem, "White", false)) gI_SmokeSetting[client] = 1;
		else if(StrEqual(MenuItem, "Red", false)) gI_SmokeSetting[client] = 2;
		else if(StrEqual(MenuItem, "Green", false)) gI_SmokeSetting[client] = 3;
		else if(StrEqual(MenuItem, "Blue", false)) gI_SmokeSetting[client] = 4;
		else if(StrEqual(MenuItem, "Yellow", false)) gI_SmokeSetting[client] = 5;
		
		char sCookie[12]
		Format(sCookie, sizeof(sCookie), "%i", gI_SmokeSetting[client]);
		SetClientCookie(client, gH_SmokeSetting, sCookie);
		
		SmokeMenu(client);
	}
	
	if(action == MenuAction_End)
		CloseHandle(menu);
}