#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colorvariables>
#include <clientprefs>

#pragma newdecls required
#pragma semicolon 1

int g_iTicksMain[MAXPLAYERS + 1] = {-1, ...};
int g_iTicksRepeat[MAXPLAYERS + 1] = {-1, ...};
int g_bFBMacroType[MAXPLAYERS + 1];
Handle gH_MacroTypeCookie = null;

public void OnPluginStart()
{
	RegConsoleCmd("sm_macro", Command_Macro);
	RegConsoleCmd("sm_macros", Command_Macro);
	
	gH_MacroTypeCookie = RegClientCookie("FlashMacro", "Macro", CookieAccess_Protected);
}

Action Command_Macro(int client, int args)
{
	if(g_bFBMacroType[client] == 0)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Macro is on.");
		CPrintToChat(client, "{green}[Trikz]{yellow} If you press and hold right mouse button to use it, please use bind key, Because flash boost speed is reduced.");
		g_bFBMacroType[client] = 1;
	}
	else
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Macro is off.");
		g_bFBMacroType[client] = 0;
	}
	
	char sCookie[12];
	Format(sCookie, sizeof(sCookie), "%i", g_bFBMacroType[client]);
	SetClientCookie(client, gH_MacroTypeCookie, sCookie);
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	//Boosting macro
	if(!IsPlayerAlive(client))
	{
		return;
	}
	
	char sWeapon[32];
	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if(IsValidEntity(iWeapon))
	{
		GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));
	}
	
	if(!StrEqual(sWeapon, "weapon_flashbang"))
	{
		return;
	}
	
	if(g_bFBMacroType[client] == 1)
	{
		if(buttons & IN_ATTACK2)
		{
			buttons |= IN_ATTACK;
		}
		
		else if(GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_ATTACK)
		{
			g_iTicksMain[client] = 10;
		}
				
		if(g_iTicksMain[client] != -1)
		{
			buttons &= ~IN_ATTACK;
			
			if(!g_iTicksMain[client])
			{
				buttons |= IN_JUMP;
				
				g_iTicksRepeat[client] = 12; //12? 80?
			}
			
			--g_iTicksMain[client];
		}
		
		if(g_iTicksRepeat[client] != -1)
		{
			buttons &= ~IN_ATTACK;
			
			if(!g_iTicksRepeat[client] && !g_iTicksMain[client])
			{
				buttons |= IN_JUMP;
			}
			
			--g_iTicksRepeat[client];
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sCookie[12];
	GetClientCookie(client, gH_MacroTypeCookie, sCookie, sizeof(sCookie));
	
	if (StringToInt(sCookie) == 0)
	{
		g_bFBMacroType[client] = 0;
		return;
	}
	g_bFBMacroType[client] = StringToInt(sCookie);
}