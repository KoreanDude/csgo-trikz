#include <sourcemod>
#include <sdktools>

#define SOUND_NVGon "items/nvg_on.wav"
#define SOUND_NVGoff "items/nvg_off.wav"

public Plugin:myinfo = 
{
	name = "Green ruckus muckus",
	author = "Dickory Hickory Jones",
	description = "Undelas the tamales in Guadalajara",
	version = "1.0",
	url = "http://url.com/"
}

new Handle:g_Cvar_EmitSoundToAll = INVALID_HANDLE;
new bool:g_EmitSoundToAll = true;

public OnMapStart()
{
	PrecacheSound(SOUND_NVGon, true);
	PrecacheSound(SOUND_NVGoff, true);
}

public OnPluginStart()
{
	g_Cvar_EmitSoundToAll = CreateConVar("zr_EmitSoundToAll", "0", "Defines whether the nightvision sound is played locally.", 0, true, 0.0, true, 1.0);
	g_EmitSoundToAll = GetConVarBool(g_Cvar_EmitSoundToAll);

	HookConVarChange(g_Cvar_EmitSoundToAll, OnEmitSoundToAllChanged);

	RegConsoleCmd("sm_nv", NightVisionCmd);
	RegConsoleCmd("buyammo1", NightVisionCmd);
	
	AutoExecConfig();
}

public OnEmitSoundToAllChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_EmitSoundToAll = bool:StringToInt(newVal);
}

public Action:NightVisionCmd(client,args)
{
	if (client < 1 || !IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}

	if(GetEntProp(client, Prop_Send, "m_bNightVisionOn")==0)
	{
		if (g_EmitSoundToAll == true)
		{
			EmitSoundToAll(SOUND_NVGon, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);
		}
		else
		{
			ClientCommand(client, "playgamesound %s", SOUND_NVGon);
		}
		
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", 1);
	}
	else
	{
		if (g_EmitSoundToAll == true)
		{
			EmitSoundToAll(SOUND_NVGoff, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);
		}
		else
		{
			ClientCommand(client, "playgamesound %s", SOUND_NVGoff);
		}
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0);
	}
	return Plugin_Handled;
}