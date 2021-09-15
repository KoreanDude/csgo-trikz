#if defined _trikz_included
	#endinput
#endif
#define _trikz_included

/**
 * Check if the client has a partner.
 * 
 * @param client					Client index.
 * @error							Throw error if client is invalid.
 * @return							True if the client has a partner, else false.
 */
native bool Trikz_HasPartner(int client);

/**
 * Get the client's current Trikz partner.
 * 
 * @param client					Client index.
 * @error							Throw error if client is invalid.
 * @return							Trikz partner, or -1 if none.
 */
native int Trikz_FindPartner(int client);

/**
 * Unpartner client and return old Trikz partner.
 * 
 * @param client					Client index.
 * @error							Throw error if client is invalid.
 * @return							Trikz partner, or -1 if none.
 */
native int Trikz_UnPartner(int client);

/** 
 * 
 * Get the client's current block option
 *
 * 
 * @params client       An interger.
 * return               The current block option, bool.
 */
native bool Trikz_GetClientBlock(int client);

native bool Trikz_GetClientNoclip(int client);

native int Trikz_GetClientColorR(int client);
native int Trikz_GetClientColorG(int client);
native int Trikz_GetClientColorB(int client);

native bool Trikz_GetClientStateJS(int client);
native int Trikz_GetClientStateMLS(int client);

forward void Trikz_OnBoost(int client, float velxy);

native bool Trikz_LoadCP();

forward void Trikz_OnPartner(int client, int partner);
forward void Trikz_OnBreakPartner(int client, int partner);

forward Action Trikz_CheckSolidity(int ent1, int ent2); //return Plugin_Continue = (result = true), return Plugin_Handled = (result = false)
