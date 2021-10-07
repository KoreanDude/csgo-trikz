#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <trikz>

Handle gH_FlashColor = INVALID_HANDLE
int gI_FlashColor[MAXPLAYERS + 1]

public Plugin myinfo = 
{
	name =			"Flash Color",
	author = 		"SHIM",
	description =	"",
	version =		"0.1",
	url =			""
}

public void OnPluginStart()
{
	gH_FlashColor = RegClientCookie("Trikz_FlashColor", "Trikz_FlashColor", CookieAccess_Private);
	
	RegConsoleCmd("sm_fb", Command_FlashMenu);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(AreClientCookiesCached(i))
				OnClientCookiesCached(i);
			else
				gI_FlashColor[i] = 4;
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
	int iPartner = Trikz_FindPartner(Owner);
	
	if(iPartner != -1)
	{
		if(gI_FlashColor[iPartner] <= 1) SetEntityModel(entity, "models/weapons/w_eq_smokegrenade_thrown.mdl");
		else SetEntityModel(entity, "models/yatta/smokegrenade_trikz.mdl");
		
		if(gI_FlashColor[iPartner] == 2) SetEntityRenderColor(entity, 255, 255, 255, 255);
		else if(gI_FlashColor[iPartner] == 3) SetEntityRenderColor(entity, 255, 0, 0, 255);
		else if(gI_FlashColor[iPartner] == 4) SetEntityRenderColor(entity, 0, 255, 0, 255);
		else if(gI_FlashColor[iPartner] == 5) SetEntityRenderColor(entity, 0, 250, 250, 255);
		else if(gI_FlashColor[iPartner] == 6) SetEntityRenderColor(entity, 255, 255, 0, 255);
	}
	else SetEntityModel(entity, "models/weapons/w_eq_smokegrenade_thrown.mdl");
}

public void OnClientCookiesCached(int client)
{
	char sCookie[12]
	GetClientCookie(client, gH_FlashColor, sCookie, sizeof(sCookie))
	if (StringToInt(sCookie) == 0)
	{
		gI_FlashColor[client] = 4;
		return;
	}
	gI_FlashColor[client] = StringToInt(sCookie)
}

Action Command_FlashMenu(int client, int args)
{
	FlashMenu(client)
	
	char sCookie[12]
	Format(sCookie, sizeof(sCookie), "%i", gI_FlashColor[client])
	SetClientCookie(client, gH_FlashColor, sCookie)
	
	return Plugin_Handled
}

public FlashMenu(client)
{
	new Handle:MenuHandle = CreateMenu(MenuHandler_FlashMenu);

	new String:Title[512];
	Format(Title, sizeof(Title), "Set Partner's FB Color\n ");
	SetMenuTitle(MenuHandle, Title);

	AddMenuItem(MenuHandle, "None", "None");
	AddMenuItem(MenuHandle, "White", "White");
	AddMenuItem(MenuHandle, "Red", "Red");
	AddMenuItem(MenuHandle, "Green", "Green");
	AddMenuItem(MenuHandle, "Blue", "Blue");
	AddMenuItem(MenuHandle, "Yellow", "Yellow");
	
	SetMenuExitBackButton(MenuHandle, true);
	SetMenuExitButton(MenuHandle, true);

	DisplayMenu(MenuHandle, client, MENU_TIME_FOREVER);
}

public MenuHandler_FlashMenu(Handle:menu, MenuAction:action, client, select)
{
	if(action == MenuAction_Select)
	{
		new String:MenuItem[256];
		GetMenuItem(menu, select, MenuItem, sizeof(MenuItem));

		if(StrEqual(MenuItem, "None", false)) gI_FlashColor[client] = 1;
		else if(StrEqual(MenuItem, "White", false)) gI_FlashColor[client] = 2;
		else if(StrEqual(MenuItem, "Red", false)) gI_FlashColor[client] = 3;
		else if(StrEqual(MenuItem, "Green", false)) gI_FlashColor[client] = 4;
		else if(StrEqual(MenuItem, "Blue", false)) gI_FlashColor[client] = 5;
		else if(StrEqual(MenuItem, "Yellow", false)) gI_FlashColor[client] = 6;
		
		char sCookie[12]
		Format(sCookie, sizeof(sCookie), "%i", gI_FlashColor[client]);
		SetClientCookie(client, gH_FlashColor, sCookie);
		
		FlashMenu(client);
	}
	
	
	if(action == MenuAction_Cancel && select == MenuCancel_ExitBack)
		FakeClientCommand(client, "sm_c");
	
	if(action == MenuAction_End)
		CloseHandle(menu);
}