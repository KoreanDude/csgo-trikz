#include <sourcemod>

public void OnPluginStart()
{
	RegConsoleCmd("sm_c", Command_ColorSet);
	RegConsoleCmd("sm_color", Command_ColorSet);
}

public Action Command_ColorSet(int client, int args)
{
	DisplayMenu_ColorSet(client);
}

public DisplayMenu_ColorSet(Client)
{
	new Handle:MenuHandle = CreateMenu(MenuHandler_ColorSet);

	new String:Title[512];
	Format(Title, sizeof(Title), "Set Partner's Preference\n ");	
	SetMenuTitle(MenuHandle, Title);

	AddMenuItem(MenuHandle, "FB", "Flash");
	AddMenuItem(MenuHandle, "TRAIL", "Trail");
	AddMenuItem(MenuHandle, "GLOW", "Glow");
	SetMenuExitButton(MenuHandle, true);

	DisplayMenu(MenuHandle, Client, MENU_TIME_FOREVER);
}

public MenuHandler_ColorSet(Handle:menu, MenuAction:action, client, select)
{
	if(action == MenuAction_Select)
	{
		new String:MenuItem[256];
		GetMenuItem(menu, select, MenuItem, sizeof(MenuItem));

		if(StrEqual(MenuItem, "FB", false))
		{
			FakeClientCommandEx(client, "say !fb");
		}
		if(StrEqual(MenuItem, "TRAIL", false))
		{
			FakeClientCommandEx(client, "say !trail");
		}
		if(StrEqual(MenuItem, "GLOW", false))
		{
			FakeClientCommandEx(client, "say !glow");
		}
		DisplayMenu_ColorSet(client);
	}
	
	if(action == MenuAction_End)
		CloseHandle(menu);
}