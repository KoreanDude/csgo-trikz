#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <trikz>

Handle gH_TrailColor = INVALID_HANDLE
int gI_TrailColor[MAXPLAYERS + 1]
int g_iBeamSprite

public Plugin myinfo = 
{
	name =			"Trail Color",
	author = 		"SHIM",
	description =	"",
	version =		"0.1",
	url =			""
}

public void OnPluginStart()
{
	gH_TrailColor = RegClientCookie("Trikz_TrailColor", "Trikz_TrailColor", CookieAccess_Private);
	
	RegConsoleCmd("sm_trail", Command_TrailMenu);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(AreClientCookiesCached(i))
				OnClientCookiesCached(i);
			else
				gI_TrailColor[i] = 4;
		}
	}
}

public void OnMapStart()
{
	g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
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
		if(gI_TrailColor[iPartner] != 1)
		{
			//TE_SetupBeamFollow(entity, g_iBeamSprite, 0, GetConVarFloat(g_TailTime), GetConVarFloat(g_TailWidth), GetConVarFloat(g_TailWidth), GetConVarInt(g_TailFadeTime), TempColorArray);

			if(gI_TrailColor[iPartner] == 2) TE_SetupBeamFollow(entity, g_iBeamSprite, 0, 2.0, 2.0, 1.0, 1, {255, 255, 255, 255});
			else if(gI_TrailColor[iPartner] == 3) TE_SetupBeamFollow(entity, g_iBeamSprite, 0, 2.0, 2.0, 1.0, 1, {255, 0, 0, 255});
			else if(gI_TrailColor[iPartner] == 4) TE_SetupBeamFollow(entity, g_iBeamSprite, 0, 2.0, 2.0, 1.0, 1, {0, 255, 0, 255});
			else if(gI_TrailColor[iPartner] == 5) TE_SetupBeamFollow(entity, g_iBeamSprite, 0, 2.0, 2.0, 1.0, 1, {0, 250, 250, 255});
			else if(gI_TrailColor[iPartner] == 6) TE_SetupBeamFollow(entity, g_iBeamSprite, 0, 2.0, 2.0, 1.0, 1, {255, 255, 0, 255});
			TE_SendToAll();
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sCookie[12]
	GetClientCookie(client, gH_TrailColor, sCookie, sizeof(sCookie))
	if (StringToInt(sCookie) == 0)
	{
		gI_TrailColor[client] = 4;
		return;
	}
	gI_TrailColor[client] = StringToInt(sCookie)
}

Action Command_TrailMenu(int client, int args)
{
	TrailMenu(client)
	
	char sCookie[12]
	Format(sCookie, sizeof(sCookie), "%i", gI_TrailColor[client])
	SetClientCookie(client, gH_TrailColor, sCookie)
	
	return Plugin_Handled
}

public TrailMenu(client)
{
	new Handle:MenuHandle = CreateMenu(MenuHandler_TrailMenu);

	new String:Title[512];
	Format(Title, sizeof(Title), "Set Partner's Trail Color\n ");
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

public MenuHandler_TrailMenu(Handle:menu, MenuAction:action, client, select)
{
	if(action == MenuAction_Select)
	{
		new String:MenuItem[256];
		GetMenuItem(menu, select, MenuItem, sizeof(MenuItem));

		if(StrEqual(MenuItem, "None", false)) gI_TrailColor[client] = 1;
		else if(StrEqual(MenuItem, "White", false)) gI_TrailColor[client] = 2;
		else if(StrEqual(MenuItem, "Red", false)) gI_TrailColor[client] = 3;
		else if(StrEqual(MenuItem, "Green", false)) gI_TrailColor[client] = 4;
		else if(StrEqual(MenuItem, "Blue", false)) gI_TrailColor[client] = 5;
		else if(StrEqual(MenuItem, "Yellow", false)) gI_TrailColor[client] = 6;
		
		char sCookie[12]
		Format(sCookie, sizeof(sCookie), "%i", gI_TrailColor[client]);
		SetClientCookie(client, gH_TrailColor, sCookie);
		
		TrailMenu(client);
	}
	
	if(action == MenuAction_Cancel && select == MenuCancel_ExitBack)
		FakeClientCommand(client, "sm_c");
	
	if(action == MenuAction_End)
		CloseHandle(menu);
}