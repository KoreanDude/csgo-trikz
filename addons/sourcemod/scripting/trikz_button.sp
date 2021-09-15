#include <sdktools>
#include <trikz>
#include <shavit>
#include <colorvariables>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

Handle gH_Button = INVALID_HANDLE;
int gI_Button[MAXPLAYERS + 1];
int gI_SpectatorTarget[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name        = "Button announcer",
	author      = "selja, Smesh, Modified by. SHIM",
	description = "Make able to see button activation.",
	version     = "14.01.2021",
	url         = "https://steamcommunity.com/id/smesh292/"
};

public void OnPluginStart()
{
	gH_Button = RegClientCookie("Button", "Button", CookieAccess_Private);
	
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i)) 
		{
			OnClientPutInServer(i);
		
			if(AreClientCookiesCached(i))
				OnClientCookiesCached(i);
			else
				gI_Button[i] = 0;
		}
	}
	
	RegConsoleCmd("sm_button", Command_Button);
	
	HookEntityOutput("func_button", "OnPressed", UseButton);
}

public void OnClientPutInServer(int client)
{
	gI_SpectatorTarget[client] = -1;
}

public void OnClientCookiesCached(int client)
{
	char sCookie[12];
	GetClientCookie(client, gH_Button, sCookie, sizeof(sCookie));
	
	if (StringToInt(sCookie) == 0)
	{
		gI_Button[client] = 0;
		return;
	}
	gI_Button[client] = StringToInt(sCookie);
}


Action Command_Button(int client, int args)
{	
	if(gI_Button[client] == 0)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Button Announcer is on.");
		gI_Button[client] = 1;
	}
	else
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Button Announcer is off.");
		gI_Button[client] = 0;
	}
	
	char sCookie[12];
	Format(sCookie, sizeof(sCookie), "%i", gI_Button[client]);
	SetClientCookie(client, gH_Button, sCookie);
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	SpectatorCheck(client);
}

void UseButton(const char[] output, int caller, int activator, float delay)
{
	if(IsValidClient(activator) && GetClientButtons(activator) & IN_USE)
	{
		int iPartner = Trikz_FindPartner(activator);
		
		if(gI_Button[activator] == 1)
		{
			CPrintToChat(activator, "{green}[Trikz]{lightgreen} You have pressed a button.");
		}
		
		if(iPartner != -1)
		{
			if(gI_Button[iPartner] == 1)
			{
				CPrintToChat(iPartner, "{green}[Trikz]{lightgreen} Partner have pressed a button.");
			}
		}
		
		if(iPartner == -1)
		{
			SpectatorCheck(activator);
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || !IsPlayerAlive(i)) && gI_Button[i] == 1)
				{
					if(gI_SpectatorTarget[i] == activator)
					{
						CPrintToChat(i, "{green}[Trikz]{teamcolor} %N {lightgreen}have pressed a button.", activator);
					}
				}
			}
		}
		
		else
		{
			SpectatorCheck(iPartner);
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || !IsPlayerAlive(i)) && gI_Button[i] == 1)
				{
					if(gI_SpectatorTarget[i] == activator || gI_SpectatorTarget[i] == iPartner)
					{
						CPrintToChat(i, "{green}[Trikz]{teamcolor} %N {lightgreen}have pressed a button.", activator);
					}
				}
			}
		}
	}
}

void SpectatorCheck(int client)
{
	//Manage spectators
	if(!IsClientObserver(client))
	{
		return;
	}

	int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
	
	if(3 < iObserverMode < 7)
	{
		int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		
		if(gI_SpectatorTarget[client] != iTarget)
		{
			gI_SpectatorTarget[client] = iTarget;
		}
	}
	
	else
	{
		if(gI_SpectatorTarget[client] != -1)
		{
			gI_SpectatorTarget[client] = -1;
		}
	}
}