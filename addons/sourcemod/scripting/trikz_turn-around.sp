#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <colorvariables>

Handle gH_TurnStats = INVALID_HANDLE;
bool gB_TurnStats[MAXPLAYERS + 1];
new bool:AccessKey[MAXPLAYERS+1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_ta", Command_TurnStats);
	
	gH_TurnStats = RegClientCookie("TurnStats", "TurnStats", CookieAccess_Private);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
		
		if(!AreClientCookiesCached(i))
		{
			continue;
		}
		
		OnClientCookiesCached(i);
	}
}

public void OnClientPutInServer(int client)
{
	if (!AreClientCookiesCached(client))
	{
		gB_TurnStats[client] = false;
	}
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	GetClientCookie(client, gH_TurnStats, sValue, sizeof(sValue));
	gB_TurnStats[client] = (sValue[0] != '\0' && StringToInt(sValue));
}

Action Command_TurnStats(int client, int args)
{
	if(!gB_TurnStats[client])
	{
		char sCookie[12];
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Turn Around is on.");
		gB_TurnStats[client] = true;
		IntToString(1, sCookie, sizeof(sCookie));
		SetClientCookie(client, gH_TurnStats, sCookie);
	}
	else
	{
		char sCookie[12];
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Turn Around is off.");
		gB_TurnStats[client] = false;
		IntToString(0, sCookie, sizeof(sCookie));
		SetClientCookie(client, gH_TurnStats, sCookie);
	}
	
	return Plugin_Handled;
}

public Action:OnPlayerRunCmd(Client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsClientInGame(Client) && IsPlayerAlive(Client))
	{
		if(gB_TurnStats[Client])
		{
			if(buttons & IN_RELOAD)
			{
				if(AccessKey[Client] == false)
				{
					AccessKey[Client] = true;
					decl Float:angle[3];
					GetClientEyeAngles(Client, angle);
					angle[1] -= 180.0;
					TeleportEntity(Client, NULL_VECTOR, angle, NULL_VECTOR);
				}
			}
			else
			{
				AccessKey[Client] = false;
			}
		}
	}
	return Plugin_Continue;
}
