-- luacheck-Konfiguration: prüft auf Tippfehler, unbekannte Globals und
-- ungenutzte Variablen. Aufruf aus dem Repository-Ordner: luacheck .
std = "lua51"
max_line_length = 140
self = false -- Methoden ohne self-Nutzung sind hier Absicht

files["tests/**"] = { std = "max" }

-- "CrimeWarden" (Client 9.2.7)
files["CrimeWarden/**"] = {
    globals = {
        "CrimeWardenDB",
        "SLASH_CRIMEWARDEN1",
        "SLASH_CRIMEWARDEN2",
        "SlashCmdList",
    },
    read_globals = {
        -- Namespaces
        "AddOn_TotalRP3", "C_CVar", "C_Item", "C_Map", "C_NamePlate", "C_Timer", "Settings", "TRP3_API", "bit",
        -- Funktionen
        "Ambiguate", "ChatEdit_GetActiveWindow", "ChatFrame_OpenChat", "ChatFrame_SendTell", "CheckInteractDistance",
        "CombatLogGetCurrentEventInfo", "CreateVector2D", "GetNormalizedRealmName", "GetNumGroupMembers",
        "GetNumSubgroupMembers", "GetPlayerInfoByGUID", "hooksecurefunc", "IsInRaid", "UnitIsConnected",
        "UnitIsVisible", "UnitPosition",
        "CreateFrame", "GetAddOnMetadata", "GetCVar", "GetCursorPosition", "GetGuildInfo", "GetLocale", "GetTime",
        "GetUnitName", "InCombatLockdown", "InterfaceOptionsFrame_OpenToCategory", "InterfaceOptions_AddCategory",
        "GetItemInfo", "IsAddOnLoaded", "IsItemInRange", "IsShiftKeyDown", "PlaySound", "RaidNotice_AddMessage",
        "SetCVar", "UnitCanAttack", "UnitClass", "UnitExists", "UnitGUID", "UnitInParty", "UnitInRaid",
        "UnitIsFriend", "UnitIsPlayer", "UnitIsUnit", "UnitLevel", "UnitRace",
        -- Objekte und Konstanten
        "COMBATLOG_OBJECT_AFFILIATION_MINE", "COMBATLOG_OBJECT_REACTION_HOSTILE", "COMBATLOG_OBJECT_TYPE_PLAYER",
        "ChatTypeInfo", "DEFAULT_CHAT_FRAME", "GameTooltip", "RAID_CLASS_COLORS", "RaidWarningFrame", "SOUNDKIT",
        "UIParent", "UNKNOWNOBJECT",
    },
}
