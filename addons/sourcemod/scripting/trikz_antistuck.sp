#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colorvariables>

#pragma newdecls required

int g_iTimeLimit;
int g_iCounter[MAXPLAYERS + 1];
int g_iStuckCheck[MAXPLAYERS + 1];
float g_fTime[MAXPLAYERS + 1];
float g_fHorizontalStep;
float g_fVerticalStep;
float g_fHorizontalRadius;
float g_fVerticalRadius;
float g_fOriginalPos[MAXPLAYERS + 1][3];
float g_fOriginalVel[MAXPLAYERS + 1][3];
Handle c_Limit = null;
Handle c_Countdown = null;
Handle c_HRadius = null;
Handle c_VRadius = null;
Handle c_HStep = null;
Handle c_VStep = null;
Handle c_Delay_H = null;
Handle DelayTimer[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Anti-Stuck",
	author = "Erreur 500, Wesker",
	description = "Optimized player anti-stuck, with ZR support",
	version = "1.8.1",
	url = "steam-gamers.net"
}

public void OnPluginStart()
{
	c_Limit = CreateConVar("sm_stuck_limit", "0", "How many times command can be used before cooldown (0 = no limit)", _, true, 0.0);
	c_Countdown = CreateConVar("sm_stuck_wait", "0", "How long the command cooldown is in seconds", _, true, 0.0, true, 1000.0);
	c_HRadius = CreateConVar("sm_stuck_horizontal_radius", "60", "Horizontal radius size to fix player position", _, true, 10.0);
	c_VRadius = CreateConVar("sm_stuck_vertical_radius", "190", "Vertical radius size to fix player position", _, true, 10.0);
	c_HStep = CreateConVar("sm_stuck_horizontal_step", "30", "Horizontal distance between each position tested (recommended default)", _, true, 10.0);
	c_VStep = CreateConVar("sm_stuck_vertical_step", "50", "Vertical distance between each position tested (recommended default)", _, true, 10.0);
	c_Delay_H = CreateConVar("sm_stuck_delay_h", "3", "How long to delay the command for a Human (in seconds), -1 to block", _, false, -1.0, true, 60.0);
	
	HookConVarChange(c_Countdown, OnConVarChange);
	HookConVarChange(c_HRadius, OnConVarChange);
	HookConVarChange(c_VRadius, OnConVarChange);
	HookConVarChange(c_HStep, OnConVarChange);
	HookConVarChange(c_VStep, OnConVarChange);
	
	g_iTimeLimit = GetConVarInt(c_Countdown);
	
	if(g_iTimeLimit < 0)
	{
		g_iTimeLimit = -g_iTimeLimit;
	}
		
	g_fHorizontalStep = float(GetConVarInt(c_HStep));
	
	g_fVerticalStep = float(GetConVarInt(c_VStep));
		
	g_fHorizontalRadius = float(GetConVarInt(c_HRadius));
		
	g_fVerticalRadius = float(GetConVarInt(c_VRadius));
	
	RegConsoleCmd("sm_stuck", StuckCmd, "Are you stuck ?");
	RegConsoleCmd("sm_unstuck", StuckCmd, "Are you stuck ?");
}

public void OnMapStart()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iCounter[i] = 0;
		g_iStuckCheck[i] = -1;
		g_fTime[i] = GetGameTime();
	}
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (DelayTimer[i] != null)
		{
			KillTimer(DelayTimer[i]);
			DelayTimer[i] = null;
		}
	}
}

void OnConVarChange(Handle cvar, const char[] oldVal, const char[] newVal)
{
	if(cvar == c_Countdown)
	{
		g_iTimeLimit = StringToInt(newVal);
		
		if(g_iTimeLimit < 0)
		{
			g_iTimeLimit = -g_iTimeLimit;
		}
	}
	
	else if(cvar == c_HRadius)
	{
		g_fHorizontalRadius = float(StringToInt(newVal));
		
		if(g_fHorizontalRadius < 10.0)
		{
			g_fHorizontalRadius = 10.0;
		}
	}
	
	else if(cvar == c_VRadius)
	{
		g_fVerticalRadius = float(StringToInt(newVal));
		
		if(g_fVerticalRadius < 10.0)
		{
			g_fVerticalRadius = 10.0;
		}
	}
	
	else if(cvar == c_HStep)
	{
		g_fHorizontalStep = float(StringToInt(newVal));
		
		if(g_fHorizontalStep < 1.0)
		{
			g_fHorizontalStep = 1.0;
		}
	}
	
	else if(cvar == c_VStep)
	{
		g_fVerticalStep = float(StringToInt(newVal));
		
		if(g_fVerticalStep < 1.0)
		{
			g_fVerticalStep = 1.0;
		}
	}
}

public void OnClientDisconnect(int client)
{
	if(DelayTimer[client] != null)
	{
		KillTimer(DelayTimer[client]);
		DelayTimer[client] = null;
	}
}

bool IsValidClient(int client)
{
	if(client <= 0)
	{
		return false;
	}
	
	if(client > MaxClients)
	{
		return false;
	}
	
	return IsClientInGame(client);
}

public Action StuckCmd(int client, any args)
{
	if(!IsValidClient(client))
	{
		return;
	}
	
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} You must be alive to use this feature!");
		
		return;
	}
	
	//Check if g_iCounter is enabled
	if(GetConVarInt(c_Limit) > 0)
	{
		//If g_iCounter is more than 0
		if(g_iCounter[client] > 0)
		{
			//If cooldown has past, reset the g_iCounter
			if(g_fTime[client] < GetGameTime())
			{
				g_iCounter[client] = 0;
			}
		}
		
		//First g_iCounter set the delay to current time + delay
		if(g_iCounter[client] == 0)
		{
			g_fTime[client] = GetGameTime() + float(g_iTimeLimit);
		}
		
		//Player g_iCounter is over the limit, block command
		if(g_iCounter[client] >= GetConVarInt(c_Limit))
		{
			CPrintToChat(client, "{green}[Trikz]{lightgreen} You must wait {lime}%i {lightgreen}seconds before use this feature again.", RoundFloat(g_fTime[client] - GetGameTime()));
			
			return;
		}
		
		//g_iCounter not yet reached limit, add to g_iCounter
		g_iCounter[client]++;
	}
	
	if(DelayTimer[client] != null || g_iStuckCheck[client] != -1)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Unstuck is already in progress, {lime}%i {lightgreen}checks completed so far.", g_iStuckCheck[client]);
		
		return;
	}
	
	if(GetConVarInt(c_Delay_H) > 0)
	{
		CPrintToChat(client, "{green}[Trikz]{lightgreen} Attempting unstuck in {lime}%i {lightgreen}seconds.", GetConVarInt(c_Delay_H));
		
		DelayTimer[client] = CreateTimer(GetConVarFloat(c_Delay_H), FDelayTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	else
	{
		g_iStuckCheck[client] = 0;
		StartStuckDetection(client);
	}
}


Action FDelayTimer(Handle timer, any client)
{
	g_iStuckCheck[client] = 0;
	DelayTimer[client] = null;
	StartStuckDetection(client);
}

void StartStuckDetection(int client)
{
	GetClientAbsOrigin(client, g_fOriginalPos[client]); //Save original pos
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", g_fOriginalVel[client]);
	
	//Disable player controls to prevent abuse / exploits
	int flags = GetEntityFlags(client) | FL_ATCONTROLS;
	SetEntityFlags(client, flags);
	
	g_iStuckCheck[client]++;
	CheckIfPlayerCanMove(client, 0, 500.0, 0.0, 0.0);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Ray Trace
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
stock float DistFromWall(int client, float direction[3])
{
	float fDist;
	float vecOrigin[3];
	float vecEnd[3];
	Handle ray;
	
	GetClientAbsOrigin(client, vecOrigin);
	vecOrigin[2] += 25.0; //Dont start from the feet
	ray = TR_TraceRayFilterEx(vecOrigin, direction, MASK_SOLID, RayType_Infinite, TraceEntitiesAndWorld);
	
	if(TR_DidHit(ray))
	{
		TR_GetEndPosition(vecEnd, ray);
		fDist = GetVectorDistance(vecOrigin, vecEnd, false);
		delete ray;
		
		return fDist;
	}
	
	delete ray;
	
	return -1.0;
}

bool TraceEntitiesAndWorld(int entity, int contentsMask)
{
	//Dont care about clients or physics props
	if(entity < 1 || entity > MaxClients)
	{
		if(IsValidEntity(entity))
		{
			char eClass[128];
			if(GetEntityClassname(entity, eClass, sizeof(eClass)))
			{
				if(StrContains(eClass, "prop_physics") != -1)
				{
					return false;
				}
			}
			
			return true;
		}
	}
	
	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									More Stuck Detection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void CheckIfPlayerCanMove(int client, int testID, float X = 0.0, float Y = 0.0, float Z = 0.0, float Radius = 1.0, float pos_Z = 1.0, float DegreeAngle = 1.0)	// In few case there are issues with IsPlayerStuck() like clip
{
	float vecVelo[3];
	float vecOrigin[3];
	GetClientAbsOrigin(client, vecOrigin);
	
	vecVelo[0] = X;
	vecVelo[1] = Y;
	vecVelo[2] = Z;
	
	SetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", vecVelo);
	
	DataPack TimerDataPack1;
	CreateDataTimer(0.01, TimerWait, TimerDataPack1, TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(TimerDataPack1, client);
	WritePackCell(TimerDataPack1, testID);
	WritePackFloat(TimerDataPack1, vecOrigin[0]);
	WritePackFloat(TimerDataPack1, vecOrigin[1]);
	WritePackFloat(TimerDataPack1, vecOrigin[2]);
	WritePackFloat(TimerDataPack1, Radius);
	WritePackFloat(TimerDataPack1, pos_Z);
	WritePackFloat(TimerDataPack1, DegreeAngle);
}

Action TimerWait(Handle timer, Handle data)
{	
	float vecOrigin[3];
	float vecOriginAfter[3];
	
	ResetPack(data, false);
	int client 			= ReadPackCell(data);
	int testID 			= ReadPackCell(data);
	vecOrigin[0]		= ReadPackFloat(data);
	vecOrigin[1]		= ReadPackFloat(data);
	vecOrigin[2]		= ReadPackFloat(data);
	float Radius		= ReadPackFloat(data);
	float pos_Z			= ReadPackFloat(data);
	float DegreeAngle	= ReadPackFloat(data);
	
	
	GetClientAbsOrigin(client, vecOriginAfter);
	
	if(GetVectorDistance(vecOrigin, vecOriginAfter, false) < 8.0) // Can't move
	{
		if(testID == 0)
		{
			CheckIfPlayerCanMove(client, 1, 0.0, 0.0, -500.0, Radius, pos_Z, DegreeAngle);	// Jump
		}
		
		else if(testID == 1)
		{
			CheckIfPlayerCanMove(client, 2, -500.0, 0.0, 0.0, Radius, pos_Z, DegreeAngle);
		}
		
		else if(testID == 2)
		{
			CheckIfPlayerCanMove(client, 3, 0.0, 500.0, 0.0, Radius, pos_Z, DegreeAngle);
		}
		
		else if(testID == 3)
		{
			CheckIfPlayerCanMove(client, 4, 0.0, -500.0, 0.0, Radius, pos_Z, DegreeAngle);
		}
		
		else if(testID == 4)
		{
			CheckIfPlayerCanMove(client, 5, 0.0, 0.0, 300.0, Radius, pos_Z, DegreeAngle);
		}
		
		else
		{
			if(Radius == 1.0 && pos_Z == 1.0 && DegreeAngle == 1.0)
			{
				g_iStuckCheck[client]++;
				TryFixPosition(client, g_fHorizontalStep, 0.0, -180.0); //First time settings
				
				return;
			}
			
			else
			{
				g_iStuckCheck[client]++;
				TryFixPosition(client, Radius, pos_Z, DegreeAngle); //Continue where we left off
				
				return;
			}
		}
	}
	
	else
	{
		if(g_iStuckCheck[client] < 2 && g_iStuckCheck[client] != -1)
		{
			CPrintToChat(client, "{green}[Trikz]{lightgreen} You do not appear to be stuck.");
			TeleportEntity(client, g_fOriginalPos[client], NULL_VECTOR, g_fOriginalVel[client]); //Reset to original pos / velocity
			//Enable controls
			int flags = GetEntityFlags(client) & ~FL_ATCONTROLS;
			SetEntityFlags(client, flags);
			g_iStuckCheck[client] = -1;
		}
		
		else
		{
			CPrintToChat(client, "{green}[Trikz]{lightgreen} Your position has been fixed, you should now be unstuck.");
			//Enable controls
			int flags = GetEntityFlags(client) & ~FL_ATCONTROLS;
			SetEntityFlags(client, flags);
			g_iStuckCheck[client] = -1;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Fix Position
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Action CheckWait(Handle timer, Handle data)
{	
	ResetPack(data, false);
	int client 		= ReadPackCell(data);
	float Radius		= ReadPackFloat(data);
	float pos_Z			= ReadPackFloat(data);
	float DegreeAngle	= ReadPackFloat(data);

	DelayTimer[client] = null;
	TryFixPosition(client, Radius, pos_Z, DegreeAngle);
}

void TryFixPosition(int client, float Radius, float pos_Z, float DegreeAngle)
{
	float vecPosition[3];
	float vecOrigin[3];
	float vecAngle[3];
	
	if(g_iStuckCheck[client] == -1)
	{
		CPrintToChat(client,"{green}[Trikz]{lightgreen} Something went wrong, if you are still stuck try /stuck again or call an admin.");
		if(DelayTimer[client] != null)
		{
			KillTimer(DelayTimer[client]);
			DelayTimer[client] = null;
		}
		
		return;
	}
		
	if(pos_Z <= g_fVerticalRadius)
	{
		if(Radius <= g_fHorizontalRadius)
		{
			GetClientAbsOrigin(client, vecOrigin);
			vecPosition[2] = vecOrigin[2] + pos_Z;
		
			if(DegreeAngle < 180.0)
			{
				vecPosition[0] = vecOrigin[0] + Radius * Cosine(DegreeAngle * FLOAT_PI / 180); // convert angle in radian
				vecPosition[1] = vecOrigin[1] + Radius * Sine(DegreeAngle * FLOAT_PI / 180);
				
				SubtractVectors(vecPosition, vecOrigin, vecAngle);
				
				//Get the distance to the warp location
				vecOrigin[2] += 25.0; //Match the raytrace
				float potentialDist = GetVectorDistance(vecPosition, vecOrigin, false);
				potentialDist += 10.0;
				DegreeAngle += 60.0; // start off next time +10
				
				//Allow only if player is already in wall, or if the wall is beyond the warp location
				float fDist = DistFromWall(client, vecAngle);
				
				if(fDist > 16.0 && fDist <= potentialDist)
				{
					DataPack TimerDataPack2;
					DelayTimer[client] = CreateDataTimer(0.0, CheckWait, TimerDataPack2, TIMER_FLAG_NO_MAPCHANGE);
					WritePackCell(TimerDataPack2, client);
					WritePackFloat(TimerDataPack2, Radius);
					WritePackFloat(TimerDataPack2, pos_Z);
					WritePackFloat(TimerDataPack2, DegreeAngle);
					
					return;
				}
				
				TeleportEntity(client, vecPosition, NULL_VECTOR, view_as<float>({0.0, 0.0, -300.0}));
				CheckIfPlayerCanMove(client, 0, 500.0, 0.0, 0.0, Radius, pos_Z, DegreeAngle);
				
				return;
			}
							
			DegreeAngle = -180.0; //Restart the degree loop
			Radius += g_fHorizontalStep; //Increase the radius
			
			if(DelayTimer[client] != null)
			{
				KillTimer(DelayTimer[client]);
				DelayTimer[client] = null;
			}
			
			DataPack TimerDataPack2;
			DelayTimer[client] = CreateDataTimer(GetRandomFloat(0.0, 0.5), CheckWait, TimerDataPack2, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(TimerDataPack2, client);
			WritePackFloat(TimerDataPack2, Radius);
			WritePackFloat(TimerDataPack2, pos_Z);
			WritePackFloat(TimerDataPack2, DegreeAngle);
			
			return;
		}
		
		if(pos_Z == 0.0)
		{
			//No point in flipping the first time
			pos_Z += g_fVerticalStep;
		}
		
		else
		{
			if(pos_Z < 0.0)
			{
				//Negative, flip back to positive and increase
				pos_Z = FloatAbs(pos_Z);
				pos_Z += g_fVerticalStep;
			}
			
			else if(pos_Z > 0.0)
			{
				//Positive, flip to negative and try again
				pos_Z *= -1.0;
			}	
		}
		
		Radius = g_fHorizontalStep; //Restart the radius loop
		DegreeAngle = -180.0; //Restart the degree loop
		
		if(DelayTimer[client] != null)
		{
			KillTimer(DelayTimer[client]);
			DelayTimer[client] = null;
		}
		
		DataPack TimerDataPack2;
		DelayTimer[client] = CreateDataTimer(GetRandomFloat(0.0, 2.0), CheckWait, TimerDataPack2, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(TimerDataPack2, client);
		WritePackFloat(TimerDataPack2, Radius);
		WritePackFloat(TimerDataPack2, pos_Z);
		WritePackFloat(TimerDataPack2, DegreeAngle);
		
		return;
	}

	//Probably safe to say you are stuck now
	CPrintToChat(client,"{green}[Trikz]{lightgreen} Unable to fix your position, please call for admin assistance.");
	TeleportEntity(client, g_fOriginalPos[client], NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0})); //Reset position to wherever they used the command
	//Enable controls
	
	int flags = GetEntityFlags(client) & ~FL_ATCONTROLS;
	SetEntityFlags(client, flags);
	g_iStuckCheck[client] = -1;
}
