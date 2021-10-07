#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <trikz>
#include <shavit>
#include <colorvariables>
#include <collisionhook>
#include <customplayerskins>
#include <clientprefs>

Handle gH_GlowStyle = INVALID_HANDLE
int gI_GlowStyle[MAXPLAYERS + 1]
Handle gH_GlowColor = INVALID_HANDLE
int gI_GlowColor[MAXPLAYERS + 1]
Handle gH_HideSetting = INVALID_HANDLE
int gI_HideSetting[MAXPLAYERS + 1]

public Plugin myinfo = 
{
	name = "Player collision, Glow",
	author = "Smesh, Modified by. SHIM",
	description = "",
	version = "0.1",
	url = "http://www.sourcemod.net/"
}

public void OnPluginStart()
{
	gH_GlowStyle = RegClientCookie("Trikz_GlowStyle_TEST", "Trikz_GlowStyle", CookieAccess_Private);
	gH_GlowColor = RegClientCookie("Trikz_GlowColor_TEST", "Trikz_GlowColor", CookieAccess_Private);
	gH_HideSetting = RegClientCookie("Trikz_HideSetting_TEST", "Trikz_HideSetting", CookieAccess_Private);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);

	RegConsoleCmd("sm_glow", Command_GlowMenu)
	RegConsoleCmd("sm_hide", Command_Hide)
	RegConsoleCmd("sm_gg", Command_gg)
	
	RegConsoleCmd("jointeam", Command_JoinTeam)
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			OnClientPutInServer(i)
		
			if(AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i)
			}
			else
			{
				gI_GlowStyle[i] = 0
				gI_GlowColor[i] = 4
				gI_HideSetting[i] = 2
			}
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sCookie[12]
	
	GetClientCookie(client, gH_GlowStyle, sCookie, sizeof(sCookie))
	gI_GlowStyle[client] = StringToInt(sCookie)
	
	GetClientCookie(client, gH_GlowColor, sCookie, sizeof(sCookie))
	if (StringToInt(sCookie) == 0) gI_GlowColor[client] = 4;
	else gI_GlowColor[client] = StringToInt(sCookie)
	
	GetClientCookie(client, gH_HideSetting, sCookie, sizeof(sCookie))
	if (StringToInt(sCookie) == 0) gI_HideSetting[client] = 2;
	else gI_HideSetting[client] = StringToInt(sCookie)
}

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
	{
		SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmitHide)
		SDKHook(client, SDKHook_SpawnPost, SpawnPostClient)
	}
}

Action Command_GlowMenu(int client, int args)
{
	GlowMenu(client)
	
	return Plugin_Handled
}

public GlowMenu(Client)
{
	new Handle:MenuHandle = CreateMenu(MenuHandler_GlowMenu);

	new String:Title[512];
	Format(Title, sizeof(Title), "Set Partner's Glow\n ");
	SetMenuTitle(MenuHandle, Title);

	AddMenuItem(MenuHandle, "Style", "Style");
	AddMenuItem(MenuHandle, "Color", "Color");
	
	SetMenuExitBackButton(MenuHandle, true);
	SetMenuExitButton(MenuHandle, true);
	DisplayMenu(MenuHandle, Client, MENU_TIME_FOREVER);
}

public MenuHandler_GlowMenu(Handle:menu, MenuAction:action, client, select)
{
	if(action == MenuAction_Select)
	{
		new String:MenuItem[256];
		GetMenuItem(menu, select, MenuItem, sizeof(MenuItem));

		if(StrEqual(MenuItem, "Style", false)) GlowStyleMenu(client);
		else if(StrEqual(MenuItem, "Color", false)) GlowColorMenu(client);
	}
	
	if(action == MenuAction_End)
		CloseHandle(menu);
	
	if(action == MenuAction_Cancel && select == MenuCancel_ExitBack)
		FakeClientCommand(client, "sm_c");
}

public GlowStyleMenu(Client)
{
	new Handle:MenuHandle = CreateMenu(MenuHandler_GlowStyleMenu);

	new String:Title[512];
	Format(Title, sizeof(Title), "Partner's Glow Style\n ");
	SetMenuTitle(MenuHandle, Title);

	AddMenuItem(MenuHandle, "1", "1");
	AddMenuItem(MenuHandle, "2", "2");
	AddMenuItem(MenuHandle, "3", "3");
	AddMenuItem(MenuHandle, "4", "4");
	
	SetMenuExitBackButton(MenuHandle, true);
	SetMenuExitButton(MenuHandle, true);
	DisplayMenu(MenuHandle, Client, MENU_TIME_FOREVER);
}

public MenuHandler_GlowStyleMenu(Handle:menu, MenuAction:action, client, select)
{
	if(action == MenuAction_Select)
	{
		new String:MenuItem[256];
		GetMenuItem(menu, select, MenuItem, sizeof(MenuItem));

		if(StrEqual(MenuItem, "1", false)) gI_GlowStyle[client] = 0;
		else if(StrEqual(MenuItem, "2", false)) gI_GlowStyle[client] = 1;
		else if(StrEqual(MenuItem, "3", false)) gI_GlowStyle[client] = 2;
		else if(StrEqual(MenuItem, "4", false)) gI_GlowStyle[client] = 3;
		
		char sCookie[12]
		Format(sCookie, sizeof(sCookie), "%i", gI_GlowStyle[client])
		SetClientCookie(client, gH_GlowStyle, sCookie)
	
		new iPartner = Trikz_FindPartner(client);

		if(iPartner != -1)
		{
			if(IsPlayerAlive(iPartner))
			{
				DeleteGlow(iPartner);
				SetSkin(iPartner);
			}
		}
		GlowStyleMenu(client);
	}
	
	if(action == MenuAction_Cancel && select == MenuCancel_ExitBack)
		GlowMenu(client);
	
	if(action == MenuAction_End)
		CloseHandle(menu);
}

public GlowColorMenu(Client)
{
	new Handle:MenuHandle = CreateMenu(MenuHandler_GlowColorMenu);

	new String:Title[512];
	Format(Title, sizeof(Title), "Partner's Glow Color\n ");
	SetMenuTitle(MenuHandle, Title);

	AddMenuItem(MenuHandle, "None", "None");
	AddMenuItem(MenuHandle, "White", "White");
	AddMenuItem(MenuHandle, "Red", "Red");
	AddMenuItem(MenuHandle, "Green", "Green");
	AddMenuItem(MenuHandle, "Blue", "Blue");
	AddMenuItem(MenuHandle, "Yellow", "Yellow");
	
	SetMenuExitBackButton(MenuHandle, true);
	SetMenuExitButton(MenuHandle, true);
	DisplayMenu(MenuHandle, Client, MENU_TIME_FOREVER);
}

public MenuHandler_GlowColorMenu(Handle:menu, MenuAction:action, client, select)
{
	if(action == MenuAction_Select)
	{
		new String:MenuItem[256];
		GetMenuItem(menu, select, MenuItem, sizeof(MenuItem));

		if(StrEqual(MenuItem, "None", false)) gI_GlowColor[client] = 1;
		else if(StrEqual(MenuItem, "White", false)) gI_GlowColor[client] = 2;
		else if(StrEqual(MenuItem, "Red", false)) gI_GlowColor[client] = 3;
		else if(StrEqual(MenuItem, "Green", false)) gI_GlowColor[client] = 4;
		else if(StrEqual(MenuItem, "Blue", false)) gI_GlowColor[client] = 5;
		else if(StrEqual(MenuItem, "Yellow", false)) gI_GlowColor[client] = 6;
		
		char sCookie[12]
		Format(sCookie, sizeof(sCookie), "%i", gI_GlowColor[client])
		SetClientCookie(client, gH_GlowColor, sCookie)
	
		new iPartner = Trikz_FindPartner(client);

		if(iPartner != -1)
		{
			if(IsPlayerAlive(iPartner))
			{
				DeleteGlow(iPartner);
				SetSkin(iPartner);
			}
		}
		GlowColorMenu(client);
	}
	
	if(action == MenuAction_Cancel && select == MenuCancel_ExitBack)
		GlowMenu(client);
	
	if(action == MenuAction_End)
		CloseHandle(menu);
}

Action Command_gg(int client, int args)
{
	CPrintToChat(client, "{green}[Trikz]{lightgreen} Style: %i Color: %i Hide: %i", gI_GlowStyle[client], gI_GlowColor[client], gI_HideSetting[client])
	
	return Plugin_Handled
}

Action Command_Hide(int client, int args)
{
	if(gI_HideSetting[client] == 1)
	{
		gI_HideSetting[client] = 2;
		CPrintToChat(client, "{green}[Trikz]{lightgreen} The players are now hidden.")
	}
	else
	{
		gI_HideSetting[client] = 1;
		CPrintToChat(client, "{green}[Trikz]{lightgreen} The players are now visible.")
	}
	
	char sCookie[12]
	Format(sCookie, sizeof(sCookie), "%i", gI_HideSetting[client])
	SetClientCookie(client, gH_HideSetting, sCookie)
	
	return Plugin_Handled
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(IsValidEntity(entity) && StrContains(classname, "_projectile") != -1)
	{
		SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitHideNade)
	}
}

void SpawnPostClient(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
	SetEntityRenderMode(client, RENDER_NORMAL);
	
	if(GetEntData(client, (FindDataMapInfo(client, "m_iAmmo") + (15 * 4))) == 0)
	{
		GivePlayerItem(client, "weapon_flashbang");
		SetEntData(client, FindDataMapInfo(client, "m_iAmmo") + 15 * 4, 2);
	}
	
	if(GetEntData(client, (FindDataMapInfo(client, "m_iAmmo") + (15 * 4))) == 1)
	{
		SetEntData(client, FindDataMapInfo(client, "m_iAmmo") + 15 * 4, 2);
	}
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:broadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Continue;
		
	CreateTimer(0.1, Timer_SetModel, client);

	return Plugin_Continue;
}

public Action:Command_JoinTeam(client, args)
{
	DeleteGlow(client);
	
	int iPartner = Trikz_FindPartner(client);
	
	if(iPartner != -1)
		DeleteGlow(iPartner);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:broadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;
		
	DeleteGlow(client);
	
	int iPartner = Trikz_FindPartner(client);
	
	if(iPartner != -1)
		DeleteGlow(iPartner);

	return Plugin_Continue;
}

public Action Timer_SetModel(Handle timer, any client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client) && !IsFakeClient(client))
	{
		int RandSkin = GetRandomInt(1, 4);
		if(RandSkin == 1) SetEntityModel(client, "models/player/custom_player/eminem/css/ct_gign.mdl");
		else if(RandSkin == 2) SetEntityModel(client, "models/player/custom_player/eminem/css/ct_gsg9.mdl");
		else if(RandSkin == 3) SetEntityModel(client, "models/player/custom_player/eminem/css/ct_sas.mdl");
		else if(RandSkin == 4) SetEntityModel(client, "models/player/custom_player/eminem/css/ct_urban.mdl");
	}
}

public Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data)
{
	if((type == Zone_Start || type == Zone_End) && track != Track_Solobonus)
	{
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
		SetEntityRenderMode(client, RENDER_NORMAL);
	}
}

public Shavit_OnEnterZonePartnerMode(int client, int type, int track, int id, int entity, int data)
{
	if((type == Zone_Start || type == Zone_End) && track != Track_Solobonus)
	{
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
		SetEntityRenderMode(client, RENDER_NORMAL);
	}
}

public Trikz_OnPartner(int client, int partner)
{
	if(IsClientInGame(client) && IsPlayerAlive(client) && !IsFakeClient(client) && IsClientInGame(partner) && IsPlayerAlive(partner) && !IsFakeClient(partner))
	{
		DeleteGlow(client)
		DeleteGlow(partner)
		SetSkin(client)
		SetSkin(partner)
	}
}

public Trikz_OnBreakPartner(int client, int partner)
{
	if(IsClientInGame(client) && IsPlayerAlive(client) && !IsFakeClient(client) && IsClientInGame(partner) && IsPlayerAlive(partner) && !IsFakeClient(partner))
	{
		DeleteGlow(client)
		DeleteGlow(partner)
	}
}

Action Hook_SetTransmitHide(int entity, int client) //entity - me, client - loop all clients
{
	if((client != entity) && (0 < entity <= MaxClients) && gI_HideSetting[client] == 2 && IsPlayerAlive(client))
	{
		if(Shavit_GetClientTrack(entity) != Track_Solobonus)
		{
			if(Trikz_FindPartner(entity) == client) //make visible partner
				return Plugin_Continue
			if((Trikz_FindPartner(entity) == -1) && (Trikz_FindPartner(client) == -1)) //make visible no mates for no mate
				return Plugin_Continue
			return Plugin_Handled
		}
		else //make invisible all players
			return Plugin_Handled
	}
	return Plugin_Continue
}

Action Hook_SetTransmitHideGlow(int entity, int client) //entity - glow, client - loop all clients
{
	new Owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if((client != Owner) && (0 < Owner <= MaxClients) && IsPlayerAlive(client) && gI_GlowColor[client] > 1)
	{
		if(Trikz_FindPartner(Owner) == client) //make visible partner
			return Plugin_Continue
		else return Plugin_Handled
	}
	return Plugin_Handled
}

Action Hook_SetTransmitHideNade(int entity, int client) //entity - nade, client - loop all clients
{
	int iEntOwner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")
	if(!IsValidClient(iEntOwner))
		return Plugin_Handled
	int iPartner = Trikz_FindPartner(iEntOwner)
	if(gI_HideSetting[client] == 2 && IsPlayerAlive(client))
	{		
		if(iEntOwner == client) //make visible own nade
			return Plugin_Continue
		if(iPartner == client) //make visible partner
			return Plugin_Continue
		if((iPartner == -1) && (Trikz_FindPartner(client) == -1)) //make visible nade only for no mates
			return Plugin_Continue
		return Plugin_Handled
	}
	return Plugin_Continue
}

public Action CH_PassFilter(int ent1, int ent2, bool &result)
{
	int iPartnerEnt1
	int iPartnerEnt2
	int iEntOwner
	int iPartnetEntOwner
	
	if((0 < ent1 <= MaxClients) && (0 < ent2 <= MaxClients) && IsFakeClient(ent1) && IsFakeClient(ent2)) //make no collide with bot
		return Plugin_Handled //result = false
	
	char sClassname[32]
	GetEntityClassname(ent1, sClassname, 32)
	int iPreventNadeBoostAndFallThroughBrush
	
	if(StrContains(sClassname, "projectile") != -1)
		iPreventNadeBoostAndFallThroughBrush = GetMaxEntities()
	else
		iPreventNadeBoostAndFallThroughBrush = MaxClients
	
	if(0 < ent1 <= iPreventNadeBoostAndFallThroughBrush)
	{
		if(IsValidClient(ent2) && !IsFakeClient(ent2))
			iPartnerEnt2 = Trikz_FindPartner(ent2)
		
		iEntOwner = GetEntPropEnt(ent1, Prop_Send, "m_hOwnerEntity")
		
		if(IsValidClient(iEntOwner) && !IsFakeClient(iEntOwner))
			iPartnetEntOwner = Trikz_FindPartner(iEntOwner)
		
		GetEntityClassname(ent1, sClassname, 32)
		if(StrContains(sClassname, "projectile") != -1)
		{
			if((iPartnetEntOwner == -1))
			{
				return Plugin_Handled
			}
			
			//make nade collide for all nomates.
			if((iPartnetEntOwner == -1) && (iPartnerEnt2 == -1))
			{
				//make nade no collide for owner.
				if(iEntOwner == ent2)
					return Plugin_Handled
				
				return Plugin_Continue
			}
			
			//make nade no colide if target is not mate.
			if(iEntOwner != iPartnerEnt2)
				return Plugin_Handled
			
			//make nade collide for mate.
			if((iPartnetEntOwner != -1) && (iPartnetEntOwner == ent2))
			{
				//make nade no collide for owner.
				if(iEntOwner == ent2)
					return Plugin_Handled
				
				return Plugin_Continue
			}
		}
		
		GetEntityClassname(ent2, sClassname, 32)
		if(StrContains(sClassname, "projectile") != -1)
		{
			if(IsValidClient(ent1) && !IsFakeClient(ent1))
				iPartnerEnt1 = Trikz_FindPartner(ent1)
			
			iEntOwner = GetEntPropEnt(ent2, Prop_Send, "m_hOwnerEntity")
			
			if(IsValidClient(iEntOwner) && !IsFakeClient(iEntOwner))
				iPartnetEntOwner = Trikz_FindPartner(iEntOwner)
				
			if((iPartnetEntOwner == -1))
			{
				return Plugin_Handled
			}
			
			//make nade collide for all nomates.
			if((iPartnetEntOwner == -1) && (iPartnerEnt1 == -1))
			{
				//make nade no collide for owner.
				if(iEntOwner == ent1)
					return Plugin_Handled
				
				return Plugin_Continue
			}
			//make nade no colide if target is not mate.
			if(iEntOwner != iPartnerEnt1)
				return Plugin_Handled
			
			//make nade collide for mate.
			if((iPartnetEntOwner != -1) && (iPartnetEntOwner == ent1))
			{
				//make nade no collide for owner.
				if(iEntOwner == ent1)
					return Plugin_Handled
				
				return Plugin_Continue
			}
		}
	}
	if((0 < ent1 <= MaxClients) && (0 < ent2 <= MaxClients))
	{
		//make collide for mate.
		//make able for nomate to collide with nomate.

		if(iPartnerEnt2 != ent1 && iPartnerEnt1 != ent2 || iPartnerEnt1 == -1 && iPartnerEnt2 == -1)
			return Plugin_Handled
			
		//make no collide with all players.
		if(GetEntProp(ent2, Prop_Data, "m_CollisionGroup") == 2)
			return Plugin_Handled
	}
	return Plugin_Continue
}

stock SetSkin(client)
{
	new iPartner = Trikz_FindPartner(client);
	
	if(iPartner != -1)
	{
		new String:szModel[PLATFORM_MAX_PATH];
		GetClientModel(client, szModel, sizeof(szModel));
		
		new entity = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");

		// 기존의 클라이언트가 가지고 있는 모델을 삭제
		if(IsValidEdict(entity))
		{
			AcceptEntityInput(entity, "kill");
		}
		
		if(IsPlayerAlive(client))
		{
			// 그 다음에 스킨을 지정을 해주고
			SetEntityModel(client, szModel);

			// 글로우를 생성해야 됨.
			if(gI_GlowColor[iPartner] == 2) CreateGlow(client, 255, 255, 255, 255, gI_GlowStyle[iPartner]);
			else if(gI_GlowColor[iPartner] == 3) CreateGlow(client, 255, 0, 0, 255, gI_GlowStyle[iPartner]);
			else if(gI_GlowColor[iPartner] == 4) CreateGlow(client, 0, 255, 0, 255, gI_GlowStyle[iPartner]);
			else if(gI_GlowColor[iPartner] == 5) CreateGlow(client, 0, 250, 250, 255, gI_GlowStyle[iPartner]);
			else if(gI_GlowColor[iPartner] == 6) CreateGlow(client, 255, 255, 0, 255, gI_GlowStyle[iPartner]);
		}
	}
	// 이렇게 쌈박자가 맞아야 기존 레그돌 삭제 및 새로운 스킨에 글로우가 잘 적용됨.
}

// Create
stock CreateGlow(client, r, g, b, a, style)
{
	new String:szModel[PLATFORM_MAX_PATH];

	GetClientModel(client, szModel, sizeof(szModel));
    
	new skin = CPS_SetSkin(client, szModel, CPS_RENDER);

	new offset;

	if(SDKHookEx(skin, SDKHook_SetTransmit, Hook_SetTransmitHideGlow))
	{
		if((offset = GetEntSendPropOffs(skin, "m_clrGlow")) != -1)
		{
			SetEntProp(skin, Prop_Send, "m_bShouldGlow", true, true);
			SetEntProp(skin, Prop_Send, "m_nGlowStyle", style);
			SetEntPropFloat(skin, Prop_Send, "m_flGlowMaxDist", 10000000.0);
			SetEntPropEnt(skin, Prop_Send, "m_hOwnerEntity", client);	
            
			SetEntData(skin, offset, r, _, true);
			SetEntData(skin, offset + 1, g, _, true);
			SetEntData(skin, offset + 2, b, _, true);
			SetEntData(skin, offset + 3, a, _, true);
		}
	}
}

stock DeleteGlow(client)
{
	if (!CPS_HasSkin(client))
		return;
		
	int skin = EntRefToEntIndex(CPS_GetSkin(client));
	
	SDKUnhook(skin, SDKHook_SetTransmit, Hook_SetTransmitHideGlow);
	
	CPS_RemoveSkin(client);
}