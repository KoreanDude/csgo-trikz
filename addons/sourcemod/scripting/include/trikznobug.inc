/** Double-include prevention */
#if defined _trikznobug_included_
  #endinput
#endif
#define _trikznobug_included_
 
/**
 * Handles the SkyFix communication between the original script and the trikz menu.
 *
 * @param client  Client index.
 * @param state   Enable / disable boolean.
 * @noreturn
 */
native Trikz_SkyFix(client, bool:state);