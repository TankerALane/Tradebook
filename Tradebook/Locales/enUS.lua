-- Locales/enUS.lua
-- PURE. Every user-facing string goes through this table. Missing keys fall back to the key.

local _, ns = ...
local L = ns.L

-- General
L.ADDON_TITLE = "Tradebook"
L.UNSUPPORTED = "Tradebook only runs on WoW Forever. It is disabled on this client."
L.LOADED = "loaded. Type /tb for options."
L.DEBUG_ON = "Debug output on."
L.DEBUG_OFF = "Debug output off."
L.HELP_HEADER = "Commands:"
L.HELP_LINES = {
    "/tb - open or close Tradebook",
    "/tb camp - open the Camp tab",
    "/tb chars - open the Characters view",
    "/tb search <text> - who can craft it?",
    "/tb default - use the default Professions window this time",
    "/tb options - open settings",
    "/tb debug - toggle diagnostics",
}

-- Window
L.DEFAULT_UI = "Default UI"
L.DEFAULT_UI_TIP = "Close Tradebook and open the default Professions window."
L.OPEN_TRADEBOOK = "Tradebook"
L.OPEN_TRADEBOOK_TIP = "Switch to the Tradebook window."
L.SEARCH = "Search"
L.SEARCH_ALL = "Who can craft...?"
L.SEARCH_RECIPES = "Search recipes"
L.STARRED = "Starred"
L.PINNED = "Pinned"
L.FILTER = "Filter"
L.FILTER_LEARNED = "Learned"
L.FILTER_UNLEARNED = "Not learned"
L.FILTER_CRAFTABLE = "Have materials"
L.FILTER_SKILLUP = "Gives skill-ups"
L.FILTER_SOD = "Show Season of Discovery recipes"
L.NO_RECIPES = "No recipes match."
L.NOT_SCANNED = "Open %s once on this character so Tradebook can read its recipes."
L.QUICK_SCANNED = "Recipes found in the spellbook. Open %s once for categories and unlearned recipes."
L.OPEN_PROFESSION = "Open %s"
L.VIEWING_ALT = "Viewing %s's saved recipes (read only)."
L.VIEW_AS = "Character"
L.SKILL_RANK = "%d / %d"
L.LAST_SCANNED = "Saved %s"

-- Details
L.REAGENTS = "Reagents"
L.MAKES = "Makes %d"
L.MAKES_RANGE = "Makes %d-%d"
L.HAVE_NEED = "%d/%d"
L.IN_BAGS = "Bags: %d"
L.IN_BANK = "Bank: %d"
L.CHAR_HAS = "%s: %d"
L.BANK_FETCH = "In the bank. Fetch it first (Forever can't craft from the bank)."
L.MADE_BY = "Made by %s"
L.CRAFT = "Craft"
L.CRAFT_ALL = "Craft All"
L.OPEN_IN_DEFAULT = "Open in default window"
L.CRAFT_NEED_OPEN = "Open %s to craft."
L.CRAFT_OTHER_CHAR = "Only %s can craft this right now (log in to craft)."
L.CRAFT_NOT_LEARNED = "You haven't learned this recipe."
L.CRAFT_MISSING = "Missing reagents."
L.CRAFT_COMBAT = "Can't craft in combat."
L.PIN = "Pin"
L.UNPIN = "Unpin"
L.UNPIN_TIP = "Pinned (click to unpin)"
L.UNSTAR_TIP = "Starred (click to remove the star)"
L.FAVORITE = "Star this recipe"
L.UNFAVORITE = "Remove star"
L.SHOPPING_LIST = "Shopping list"
L.SHOPPING_PINNED = "Shopping list (pinned)"
L.SHOPPING_EMPTY = "You have everything you need."
L.WHO_CAN_CRAFT = "Who can craft this"
L.KNOWN_BY = "Known by"
L.NOBODY = "No saved character knows this."
L.SOURCE = "Source"
L.SOURCE_UNCONFIRMED = "Source data is from classic and unconfirmed for Forever."
L.SOURCE_TRAINER = "Trainer"
L.SOURCE_VENDOR = "Vendor"
L.SOURCE_DROP = "Drop"
L.SOURCE_QUEST = "Quest"
L.SOURCE_CONTAINER = "Container"
L.SOURCE_OTHER = "Other"
L.SOURCE_UNKNOWN = "Unknown source."
L.SOURCE_AUTO = "Learned automatically with the profession"
L.SOURCE_LOCATIONS = "%d locations"
L.SOURCE_MORE = "(+%d more)"
L.SKILLUP_LABEL = "Skill-up:"
L.SKILLUP_UNTIL = "%s until %d"
L.SKILLUP_COLORS = { "orange", "yellow", "green" }
L.REQUIRES_SKILL = "Requires %s (%d)"
L.SKILLUP_TIP = "Skill-ups: %d"
L.DIFF_OPTIMAL = "Orange: always gives a skill-up"
L.DIFF_MEDIUM = "Yellow: usually gives a skill-up"
L.DIFF_EASY = "Green: sometimes gives a skill-up"
L.DIFF_TRIVIAL = "Grey: no skill-up"

-- Tabs and views
L.TAB_CAMP = "Camp"
L.TAB_CHARACTERS = "Characters"
L.TAB_MISSING = "Missing recipes"
L.TAB_LEGACY = "Legacy"
L.TAB_COUNT = "%d characters"
L.TAB_NOBODY = "No character on this account has %s."
L.TAB_YOU = "You have this profession."
L.TAB_ALTS = "Known by: %s"
L.GUIDE_TITLE = "About %s"
L.GUIDE_LEARN = "Learn it from a %s trainer (most major cities have one)."
L.GUIDE_RANKS = "Ranks: Apprentice (1-75), Journeyman (to 150), Expert (to 225), Artisan (to 300)."
L.GUIDE_SECONDARY = "Secondary profession: every character can learn it alongside two primary professions."
L.GUIDE_PRIMARY = "Primary profession: a character can have two."
L.PROF_DESC = {
    [171] = "Brew potions, elixirs and flasks, and transmute metals.",
    [164] = "Forge weapons, mail and plate armor, and smithing tools.",
    [333] = "Enchant gear and disenchant items into enchanting materials.",
    [202] = "Build gadgets, explosives, scopes and engineering gear.",
    [182] = "Gather herbs from the world. Used by Alchemy.",
    [165] = "Craft leather and mail armor, armor kits and bags.",
    [186] = "Mine ore and smelt bars. Used by Blacksmithing, Engineering and more.",
    [393] = "Skin beasts for leather and hides. Used by Leatherworking.",
    [197] = "Sew cloth armor, bags and shirts.",
    [185] = "Cook food that restores health and gives buffs.",
    [129] = "Make bandages to heal yourself and others.",
    [356] = "Catch fish for cooking and other rewards.",
}

-- Time
L.AGO_MINUTES = "%d min ago"
L.AGO_HOURS = "%d h ago"
L.AGO_DAYS = "%d days ago"

-- Characters
L.CHARACTERS = "Characters"
L.LAST_SEEN = "Last seen %s"
L.NOW_ONLINE = "Online now"
L.STALE = "Not seen for %d days. Data may be out of date."
L.HIDE = "Hide"
L.UNHIDE = "Show"
L.DELETE = "Delete"
L.DELETE_CONFIRM = "Delete all saved data for %s?"
L.SHOW_HIDDEN = "Show hidden characters"
L.NEXT_RANKUP = "Next rank-up"
L.CLOSEST_RANKUP = "%s  %d/%d  (%d to go), then %s"
L.READY_TO_TRAIN = "%s  ready to train %s"
L.RANK_NAMES = { Journeyman = "Journeyman", Expert = "Expert", Artisan = "Artisan" }
L.PLAYTYPE = {
    normal = "Normal",
    pvp = "PvP",
    rp = "Role-Playing",
    rppvp = "Role-Playing PvP",
    unknown = "Unknown",
}
L.MISSING_FOR = "%d recipes %s hasn't learned"

-- Camp
L.CAMP_TITLE = "Campsite recipes"
L.CAMP_BY_PROFESSION = "By profession"
L.CAMP_BY_CHARACTER = "By character"
L.CAMP_CAN_MAKE = "Can make: %s"
L.CAMP_KNOWS = "Knows recipe: %s"
L.CAMP_NONE = "No campsite recipes saved yet. Open each profession once on each character."
L.CAMP_HAVE_ALL = "You have the materials"
L.CAMP_MISSING = "Missing materials"

-- Legacy
L.LEGACY_TITLE = "Legacy: Professions"
L.LEGACY_POINTS = "Unspent points: %d"
L.LEGACY_UNAVAILABLE = "Legacy data isn't available."

-- Settings
L.SETTINGS = "Settings"
L.OPT_REPLACE = "Use Tradebook instead of the default Professions window"
L.OPT_MINIMAP = "Show minimap button"
L.OPT_GATHERING = "Show gathering profession tabs (Herbalism, Mining, Skinning)"
L.OPT_SCALE = "Window scale"
L.OPT_STALE = "Warn when a character hasn't been seen for (days)"
L.OPT_DELETE = "Delete saved characters"
L.OPT_CREDITS = "Developed by Decoupled Lane Studio. Recipe source data adapted from LibProfessionDB (MIT)."

-- Minimap / broker
L.MINIMAP_LEFT = "Left-click: open Tradebook"
L.MINIMAP_RIGHT = "Right-click: settings"
L.MINIMAP_SHIFT = "Shift-click: Camp tab"
L.MINIMAP_NONE = "No professions saved yet."
