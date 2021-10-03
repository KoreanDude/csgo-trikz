#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <colorvariables>

#define TICKS_TO_TIME(%1)	( GetTickInterval() * %1 )

bool attack[MAXPLAYERS] = {false, ...};
bool macro[MAXPLAYERS] = {false, ...};
bool set_time[MAXPLAYERS] = {false, ...};
float macro_time[MAXPLAYERS] = 0.0;
int ground_ticks[MAXPLAYERS] = 0;

int macro_repeat_delay[MAXPLAYERS] = 0;
Handle macro_delay_cookie;

public Plugin myinfo =
{
	name = "boost macro",
	author = "rumour",
	description = "server-side macro",
	version = "2.0",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("+macro", plus_macro, "Jumps after throwing the flashbang for max gainz.");
	RegConsoleCmd("-macro", minus_macro, "Jumps after throwing the flashbang for max gainz.");
	RegConsoleCmd("sm_macro_delay", sm_macro_delay, "Sets the delay of the repeat for the client.");
	
	macro_delay_cookie = RegClientCookie("macro_delay", "macro_delay", CookieAccess_Protected);
	
	// Late loading
	for(int i = 1; i <= MaxClients; i++)
	{
		if(AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client) && IsClientInGame(client))
	{
		CreateTimer(1.5, timer_join, client, TIMER_FLAG_NO_MAPCHANGE);
	}	
}

public void OnClientDisconnect(int client)
{
	macro_repeat_delay[client] = 0;
}

Action timer_join(Handle timer, any data)
{
	if(IsClientInGame(data))
	{
		CPrintToChat(data, "{green}[Trikz]{lightgreen} To use server-side macro bind any key to +macro.");
		CPrintToChat(data, "{green}[Trikz]{lightgreen} To set the repetition delay use !macro_delay #. (current: %d ticks)", macro_repeat_delay[data]);
		CPrintToChat(data, "{green}[Trikz]{lightgreen} The delay is the amount of ticks to wait upon landing on the ground (2-15) recommended.");
	}
	return Plugin_Stop
}

void SetCookie(int client, Handle cookie, int n)
{
	char[] buf = new char[8];
	IntToString(n, buf, 8);
	
	SetClientCookie(client, cookie, buf);
}

public void OnClientCookiesCached(int client)
{
	char buf[8];	
	GetClientCookie(client, macro_delay_cookie, buf, sizeof(buf));
	macro_repeat_delay[client] = StringToInt(buf);
}

public Action sm_macro_delay( int client, int args )
{
	if(args < 1)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Specify a number for the delay.");
		return Plugin_Handled;
	}
	
	char arg[255];
	GetCmdArg(1, arg, sizeof(arg));
	
	int delay = StringToInt(arg);
	
	if(delay < 2)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Macro delay has to be above 1 tick.");
		return Plugin_Handled;
	}
	
	macro_repeat_delay[client] = delay;
	
	SetCookie(client, macro_delay_cookie, macro_repeat_delay[client]);
	
	CPrintToChat(client, "{green}[Trikz]{lightgreen} Macro delay set to %d.", macro_repeat_delay[client]);
	
	return Plugin_Handled;
}

public Action plus_macro( int client, int args )
{
	attack[client] = true;
	macro[client] = true;
	
	return Plugin_Handled;
}

public Action minus_macro( int client, int args )
{
	macro[client] = false;
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client))
		return Plugin_Continue;
	
	if(macro_repeat_delay[client] < 2)
		macro_repeat_delay[client] = 2;
	
	int tick_base = GetEntProp(client, Prop_Send, "m_nTickBase");
	
	if(macro[client] && macro_time[client] == 0.0)
	{
		int flags = GetEntProp(client, Prop_Send, "m_fFlags");
		
		if(ground_ticks[client] == macro_repeat_delay[client])
		{
			attack[client] = true;
		}
		
		if(flags & FL_ONGROUND)
		{
			ground_ticks[client]++;
		}
	}
	
	if(set_time[client])
	{
		macro_time[client] = TICKS_TO_TIME(tick_base) + 0.1;
		set_time[client] = false;
	}
	
	if(attack[client])
	{
		attack[client] = false;
		char weapon_name[64];
		GetClientWeapon(client, weapon_name, sizeof(weapon_name));
		if(StrEqual(weapon_name, "weapon_flashbang"))
		{
			buttons |= IN_ATTACK;
			attack[client] = false;
			set_time[client] = true;
		}
	}
	
	if(macro_time[client] > 0.0)
	{
		if(TICKS_TO_TIME(tick_base) > macro_time[client])
		{
			buttons |= IN_JUMP;
			ground_ticks[client] = 0;
			macro_time[client] = 0.0;
		}
	}
	
	return Plugin_Continue;
}