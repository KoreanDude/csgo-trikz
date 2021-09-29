#pragma semicolon 1
#pragma tabsize 0

int g_iMapCount = 0;
bool g_bStartup = true;

ConVar mcr_delete_offical_map;
ConVar mcr_generate_mapcycle;
ConVar mcr_generate_mapgroup;

public Plugin myinfo =
{
	name = "[CS:GO] Maplister",
	author = "Kxnrl, Modified by. SHIM",
	description = "",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
    mcr_delete_offical_map = CreateConVar("mcr_delete_offical_map", "1", "auto-delete offical maps", _, true, 0.0, true, 1.0);
    mcr_generate_mapcycle  = CreateConVar("mcr_generate_mapcycle",  "1", "auto-generate map list in mapcycle.txt", _, true, 0.0, true, 1.0);
    mcr_generate_mapgroup  = CreateConVar("mcr_generate_mapgroup",  "1", "auto-generate map group in gamemodes_server.txt", _, true, 0.0, true, 1.0);

    AutoExecConfig(true);

    g_iMapCount = GetMapCount();

    CreateTimer(600.0, Timer_Detected, _, TIMER_REPEAT);
}

public Action Timer_Detected(Handle timer)
{
    int count = GetMapCount();
    if(count != g_iMapCount)
    {
        LogMessage("Detected: Map count was changed! last check: %d  current: %d", g_iMapCount, count);
        IloveSaSuSi_but_Idontlikeheranymore_DeleteMap();
        IloveSaSuSi_but_Idontlikeheranymore_MapCycle();
        IloveSaSuSi_but_Idontlikeheranymore_MapGroup();
    }
    return Plugin_Continue;
}

public void OnConfigsExecuted()
{
    if (g_bStartup)
    {
        g_bStartup = false;
        IloveSaSuSi_but_Idontlikeheranymore_DeleteMap();
        IloveSaSuSi_but_Idontlikeheranymore_MapCycle();
        IloveSaSuSi_but_Idontlikeheranymore_MapGroup();
    }
}

static int GetMapCount()
{
    DirectoryListing dir = OpenDirectory("maps");
    if(dir == null)
        ThrowError("Failed to open maps.");

    int count = 0;
    
    FileType type = FileType_Unknown;
    char map[128];
    while(dir.GetNext(map, 128, type))
    {
        if(type != FileType_File || StrContains(map, ".bsp", false) == -1)
            continue;

        count++;
    }
    delete dir;

    return count;
}

static void IloveSaSuSi_but_Idontlikeheranymore_DeleteMap()
{
    if(!mcr_delete_offical_map.BoolValue)
        return;
    
    LogMessage("Process delete offical maps ...");

    DirectoryListing dir = OpenDirectory("maps");
    if(dir == null)
    {
        LogError("IloveSaSuSi_but_Idontlikeheranymore_DeleteMap -> Failed to open maps");
        return;
    }
    
    g_iMapCount = 0;

    FileType type = FileType_Unknown;
    char map[128];
    while(dir.GetNext(map, 128, type))
    {
        if(type != FileType_File || StrContains(map, ".bsp", false) == -1)
            continue;
        
        int c = FindCharInString(map, '.', true);
        map[c] = '\0';
        
        if(!IsOfficalMap(map))
        {
            g_iMapCount++;
            continue;
        }

        Format(map, 128, "maps/%s.bsp", map);
        
        LogMessage("%s delete offical map [%s]", DeleteFile(map) ? "Successful" : "Failed", map);
    }
    delete dir;
}

static void IloveSaSuSi_but_Idontlikeheranymore_MapCycle()
{
    if(!mcr_generate_mapcycle.BoolValue)
        return;
    
    LogMessage("Process generate mapcycle ...");

    File file = OpenFile("mapcycle.txt", "w+");
    if(file == null)
    {
        LogError("IloveSaSuSi_but_Idontlikeheranymore_MapCycle -> Failed to open mapcycle.txt");
        return;
    }
    
    DirectoryListing dir = OpenDirectory("maps");
    if(dir == null)
    {
        LogError("IloveSaSuSi_but_Idontlikeheranymore_MapCycle -> Failed to open maps");
        return;
    }

    FileType type = FileType_Unknown;
    char map[128];
    while(dir.GetNext(map, 128, type))
    {
        if(type != FileType_File || StrContains(map, ".bsp", false) == -1)
            continue;
        
        int c = FindCharInString(map, '.', true);
        map[c] = '\0';
        
        file.WriteLine(map);
    }
    delete dir;
    file.Close();
}

static void IloveSaSuSi_but_Idontlikeheranymore_MapGroup()
{
    if(!mcr_generate_mapgroup.BoolValue)
        return;
    
    LogMessage("Process generate mapgroup ...");

    KeyValues kv = new KeyValues("GameModes_Server.txt");
    
    if(FileExists("gamemodes_server.txt"))
        kv.ImportFromFile("gamemodes_server.txt");
    
    kv.JumpToKey("mapgroups", true);
    
    if(kv.JumpToKey("custom_maps", false))
    {
        kv.GoBack();
        kv.DeleteKey("custom_maps");
    }
    
    kv.JumpToKey("custom_maps", true);
    
    kv.SetString("name", "custom_maps");
    
    kv.JumpToKey("maps", true);
    
    // foreach
    DirectoryListing dir = OpenDirectory("maps");
    if(dir == null)
    {
        LogError("IloveSaSuSi_but_Idontlikeheranymore_MapGroup -> Failed to open maps");
        delete kv;
        return;
    }
    FileType type = FileType_Unknown;
    char map[128];
    while(dir.GetNext(map, 128, type))
    {
        if(type != FileType_File || StrContains(map, ".bsp", false) == -1)
            continue;
        
        int c = FindCharInString(map, '.', true);
        map[c] = '\0';

        kv.SetString(map, " ");
    }
    delete dir;
    
    kv.Rewind();
    kv.ExportToFile("gamemodes_server.txt");
    
    delete kv;
}

static bool IsOfficalMap(const char[] map)
{
    static ArrayList officalmaps = null;
    if(officalmaps == null)
    {
        // create
        officalmaps = new ArrayList(ByteCountToCells(32));

        // input
		officalmaps.PushString("ar_baggage");
		officalmaps.PushString("ar_dizzy");
		officalmaps.PushString("ar_monastery");
		officalmaps.PushString("ar_shoots");
		officalmaps.PushString("cs_agency");
		officalmaps.PushString("cs_assault");
		officalmaps.PushString("cs_insertion");
		officalmaps.PushString("cs_italy");
		officalmaps.PushString("cs_militia");
		officalmaps.PushString("cs_office");
		officalmaps.PushString("de_austria");
		officalmaps.PushString("de_bank");
		officalmaps.PushString("de_cache");
		officalmaps.PushString("de_canals");
		officalmaps.PushString("de_cbble");
		officalmaps.PushString("de_dust2");
		officalmaps.PushString("de_inferno");
		officalmaps.PushString("de_lake");
		officalmaps.PushString("de_mirage");
		officalmaps.PushString("de_nuke");
		officalmaps.PushString("de_overpass");
		officalmaps.PushString("de_safehouse");
		officalmaps.PushString("de_shipped");
		officalmaps.PushString("de_shortdust");
		officalmaps.PushString("de_shortnuke");
		officalmaps.PushString("de_stmarc");
		officalmaps.PushString("de_sugarcane");
		officalmaps.PushString("de_train");
		officalmaps.PushString("dz_blacksite");
		officalmaps.PushString("gd_rialto");
		officalmaps.PushString("training1");
		officalmaps.PushString("de_abbey");
		officalmaps.PushString("de_biome");
		officalmaps.PushString("de_zoo");
		officalmaps.PushString("de_vertigo");
		officalmaps.PushString("de_ruby");
		officalmaps.PushString("cs_workout");
		officalmaps.PushString("dz_sirocco");
		officalmaps.PushString("de_breach");
		officalmaps.PushString("de_seaside");
		officalmaps.PushString("ar_lunacy");
		officalmaps.PushString("coop_kasbah");
		officalmaps.PushString("de_studio");
		officalmaps.PushString("de_swamp");
		officalmaps.PushString("gd_cbble");
		officalmaps.PushString("de_anubis");
		officalmaps.PushString("de_mutiny");
		officalmaps.PushString("coop_autumn");
		officalmaps.PushString("cs_apollo");
		officalmaps.PushString("de_ancient");
		officalmaps.PushString("de_elysion");
		officalmaps.PushString("de_engage");
		officalmaps.PushString("de_guard");
		officalmaps.PushString("dz_frostbite");
		officalmaps.PushString("de_calavera");
		officalmaps.PushString("de_grind");
		officalmaps.PushString("de_mocha");
		officalmaps.PushString("de_pitstop");
		officalmaps.PushString("lobby_mapveto");
		officalmaps.PushString("cs_insertion2");
		officalmaps.PushString("de_extraction");
		officalmaps.PushString("de_ravine");
		officalmaps.PushString("dz_county");
		officalmaps.PushString("de_basalt");
    }

    return (officalmaps.FindString(map) > -1);
}