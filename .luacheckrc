-- luacheck config for Tradebook (WoW Forever, Lua 5.1)
std = "lua51"
max_line_length = 140
codes = true
self = false

exclude_files = {
    "Tradebook/Libs/",
    "spikes/",
    ".release/",
    "scripts/lfs_shim/",
}

ignore = {
    "212/self",  -- unused self in methods
    "211/_.*",   -- unused locals starting with _
    "212/_.*",   -- unused args starting with _
    "213/_.*",
    "542",       -- empty if branch
}

-- Globals Tradebook defines
globals = {
    "TradebookDB",
    "SLASH_TRADEBOOK1",
    "SLASH_TRADEBOOK2",
    "SlashCmdList",
    "StaticPopupDialogs",
    "UISpecialFrames",
}

-- WoW API used (read-only)
read_globals = {
    "_G", "C_AddOns", "C_Bank", "C_ClassColor", "C_Container", "C_GameRules", "C_Item", "C_QuestLog", "C_Spell",
    "C_SpellBook", "C_Timer", "C_TradeSkillUI", "C_Traits", "CLASS_ICON_TCOORDS", "ChatEdit_InsertLink",
    "Constants", "CreateColor", "CreateDataProvider", "CreateFrame", "CreateScrollBoxListLinearView", "Enum",
    "EventRegistry", "GameTooltip", "GameTooltip_Hide", "GetProfessionInfo", "GetProfessions", "GetRealmID",
    "GetRealmName", "GetServerTime", "GetTime", "HIGHLIGHT_FONT_COLOR", "HideUIPanel", "ITEM_QUALITY_COLORS",
    "InCombatLockdown", "IsModifiedClick", "IsShiftKeyDown", "LEVEL", "LibStub", "MenuUtil", "NO",
    "NUM_BAG_SLOTS", "NUM_TOTAL_EQUIPPED_BAG_SLOTS", "OTHER", "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab",
    "PanelTemplates_TabResize", "PlaySound", "ProfessionsFrame", "ScrollBoxConstants", "ScrollUtil", "Settings",
    "SettingsPanel", "ShowProfessionsFrame", "SOUNDKIT", "StaticPopup_Show", "UIParent", "UnitClass",
    "UnitFactionGroup", "UnitFullName", "UnitGUID", "UnitLevel", "UnitRace", "YES", "date", "issecretvalue",
    "tinsert", "unpack", "UpdateUIPanelPositions", "hooksecurefunc", "Professions", "CreateVector2D", "UiMapPoint", "Screenshot", "time",
}

files["tests/run.lua"] = { std = "lua51" }
files["Tradebook/Data/SourceData.lua"] = { max_line_length = false } -- generated
