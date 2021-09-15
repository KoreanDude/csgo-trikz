/*  SM Unlimited Reserve Ammo
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#define DATA "1.0"

public Plugin:myinfo =
{
	name = "SM Unlimited Reserve Ammo",
	author = "Franc1sco franug",
	description = "",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
};

new Handle:trie_armas;

public OnPluginStart()
{
	
	trie_armas = CreateTrie();
	
	HookEvent("weapon_fire", ClientWeaponReload);
	
	for(new i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
}

public ClientWeaponReload(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event,  "userid"));
    Darm(client);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, EventItemPickup2);
}

Darm(client)
{
	if(IsPlayerAlive(client))
	{
		new weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if(weapon > 0 && (weapon == GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) || weapon == GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY)))
		{
			new warray;
			decl String:classname[4];
			//GetEdictClassname(weapon, classname, sizeof(classname));
			Format(classname, 4, "%i", GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"));
			
			if(GetTrieValue(trie_armas, classname, warray))
			{
				//PrintToChat(client, "municion fijado a %i",warray[1]);
				if(GetReserveAmmo(weapon) != warray) SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", warray);
			}
		}
	}
}

stock GetReserveAmmo(weapon)
{
    return GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
}

public Action:EventItemPickup2(client, weapon)
{
	if(weapon == GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) || weapon == GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY))
	{
		new warray;
		decl String:classname[4];
		//GetEdictClassname(weapon, classname, sizeof(classname));
		Format(classname, 4, "%i", GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"));
	
		if(!GetTrieValue(trie_armas, classname, warray))
		{
			warray = GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
		
			SetTrieValue(trie_armas, classname, warray);
		}
	}
}