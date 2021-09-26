#include <sourcemod>

public void OnPluginStart()
{
	RegConsoleCmd("sm_set", Command_TrikzStats);
}

public Action Command_TrikzStats(int client, int args)
{
	DisplayMenu_TrikzStats(client);
}

public DisplayMenu_TrikzStats(Client)
{
	new Handle:MenuHandle = CreateMenu(MenuHandler_TrikzStats);

	new String:Title[512];
	Format(Title, sizeof(Title), "Trikz Statistics\n ");	
	SetMenuTitle(MenuHandle, Title);

	AddMenuItem(MenuHandle, "AS", "Angle");
	AddMenuItem(MenuHandle, "SBS", "Skyboost");
	AddMenuItem(MenuHandle, "RBS", "Runboost");
	AddMenuItem(MenuHandle, "MLS", "Mega Long");
	AddMenuItem(MenuHandle, "SSJ", "Six Jump");
	AddMenuItem(MenuHandle, "LJS", "Long Jump");
	AddMenuItem(MenuHandle, "Button", "Button");
	AddMenuItem(MenuHandle, "Turn Around", "Turn Around");
	SetMenuPagination(MenuHandle, MENU_NO_PAGINATION);
	SetMenuExitButton(MenuHandle, true);

	DisplayMenu(MenuHandle, Client, MENU_TIME_FOREVER);
}

public MenuHandler_TrikzStats(Handle:menu, MenuAction:action, client, select)
{
	if(action == MenuAction_Select)
	{
		new String:MenuItem[256];
		GetMenuItem(menu, select, MenuItem, sizeof(MenuItem));

		if(StrEqual(MenuItem, "AS", false))
		{
			FakeClientCommandEx(client, "say !ac");
		}
		if(StrEqual(MenuItem, "SBS", false))
		{
			FakeClientCommandEx(client, "say !sbs");
		}
		if(StrEqual(MenuItem, "RBS", false))
		{
			FakeClientCommandEx(client, "say !rbs");
		}
		if(StrEqual(MenuItem, "MLS", false))
		{
			FakeClientCommandEx(client, "say !mls");
		}
		if(StrEqual(MenuItem, "SSJ", false))
		{
			FakeClientCommandEx(client, "say !ssj");
		}
		if(StrEqual(MenuItem, "LJS", false))
		{
			FakeClientCommandEx(client, "say !lj");
		}
		if(StrEqual(MenuItem, "Button", false))
		{
			FakeClientCommandEx(client, "say !button");
		}
		if(StrEqual(MenuItem, "Turn Around", false))
		{
			FakeClientCommandEx(client, "say !ta");
		}
		DisplayMenu_TrikzStats(client);
	}
	
	if(action == MenuAction_End)
		CloseHandle(menu);
}