-- Locales/enUS.lua
-- PURE. Every user-facing string goes through this table. Missing keys fall back to the key.

local _, ns = ...
local L = ns.L

-- General
L.ADDON_TITLE = "Tradebook"
L.LOADED = "loaded. Type /tb for options."
L.DEBUG_ON = "Debug output on."
L.DEBUG_OFF = "Debug output off."
L.FAKE_ON = "Made-up characters on (for screenshots). Nothing is saved; /tb fake or /reload to go back."
L.FAKE_OFF = "Back to your real characters."
L.FAKE_BANNER = "(made-up data)"
L.SHOTS_START = "Taking %d screenshots. Don't move the mouse over the window until it's done."
L.SHOTS_DONE = "Done: %d screenshots in your Screenshots folder. Run scripts/crop_shots.py to crop them."
L.SHOTS_COMBAT = "Can't take screenshots in combat."
L.HELP_HEADER = "Commands:"
L.HELP_LINES = {
    "/tb - open or close Tradebook",
    "/tb camp - open the Camp tab",
    "/tb chars - open the Characters view",
    "/tb search <text> - who can craft it?",
    "/tb default - use the default Professions window this time",
    "/tb options - open settings",
    "/tb debug - toggle diagnostics",
    "/tb fake - made-up characters for screenshots (on/off; never saved)",
    "/tb shots - take the screenshots for the addon page",
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
L.FILTER_NEAREST = "Nearest first"
L.FILTER_LEARNABLE = "Learnable now"
L.FILTER_FROM_TRAINER = "From a trainer"
L.FILTER_FROM_RECIPE = "From a recipe"
L.NEAREST_TO_LEARN = "Nearest to learn"
L.FILTER_CRAFTABLE = "Have materials"
L.FILTER_SKILLUP = "Gives skill-ups"
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

-- Where to get materials (QuestieDB)
L.SOLD_BY = "Sold by"
L.LEARN_FROM = "Nearest to learn from"
L.KIND_TRAINER = "Trainer"
L.KIND_VENDOR = "Vendor"
L.KIND_VENDOR_UNCONFIRMED = "Vendor, unconfirmed"
L.DROPPED_BY = "Dropped by"
L.GATHERED_FROM = "Gathered from"
L.PLACE = "%s (%d, %d)"
L.LEVEL_RANGE = "level %d-%d"
L.LEVEL_ONE = "level %d"
L.WHERE_NO_POSITION = "Your position isn't available here; showing vendors by name."
L.WAYPOINT_CLICK = "Click to set a waypoint."
L.WAYPOINT_TARGET_CLICK = "Click to set a waypoint, and target and mark it if it's nearby."
L.WAYPOINT_SET = "Waypoint set: %s (%d, %d)"
L.WAYPOINT_NONE = "Can't set a waypoint for that zone."
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

-- Prices (Auctionator)
L.PRICE_PURCHASE_FROM = "Purchase from:"
L.PRICE_AUCTION = "Auction"
L.PRICE_VENDOR = "Vendor"
L.PRICE_AGE = "(%d |4day:days; old)"
L.PRICE_NONE = "No price yet. Scan the auction house with Auctionator."
L.COST = "Cost"
L.COST_TO_CRAFT = "Cost to craft"
L.COST_UNPRICED = "%d |4material:materials; without a price"
L.COST_SELLS_FOR = "Sells for (after the auction house cut)"
L.COST_PROFIT = "Profit"
L.COST_TIP = "Each material at its cheapest known price: vendor (seen by Auctionator at a merchant) or the last auction house scan."
L.COST_NO_DATA = "No prices yet. Scan the auction house with Auctionator."
L.SHOPPING_COST = "Cost: %s"
L.SHOPPING_EXPORT = "Send to Auctionator"
L.SHOPPING_VENDOR = "Buy from a vendor"
L.SHOPPING_AUCTION = "Buy at the auction house"
L.SHOPPING_EXPORT_TIP = "Create a shopping list named \"%s\" in Auctionator with the auction house items and amounts"
    .. " (replaces one with the same name). Open the auction house to search it."
L.SHOPPING_EXPORTED = "Sent %d |4item:items; to the Auctionator shopping list \"%s\"."
L.SHOPPING_EXPORT_FAILED = "Couldn't create the Auctionator shopping list."
L.SHOPPING_LIST_NAME = "Tradebook"
L.WHO_CAN_CRAFT = "Who can craft this"
L.KNOWN_BY = "Known by"
L.NOBODY = "No saved character knows this."
L.BROWSE_SHOW = "Show all recipes"
L.BROWSE_TIP = "List every recipe of this profession, to look up what it makes, the materials and what they cost."
L.BROWSE_NOTE = "None of your characters have %s. Showing all its recipes."
L.BROWSE_BACK = "Back to the guide"
L.BROWSE_NONE = "The game didn't return any recipes for this profession."
L.COULD_LEARN = "Could learn it:"
L.COULD_LEARN_WHO = "%s could learn it:"
L.COULD_NOW = "Learnable now"
L.COULD_MORE = "%d more skill (%d)"
L.COULD_TRAIN = "Train %s first (%d)"
L.COULD_NEEDS = "Needs %d"
L.COULD_UNKNOWN = "Required skill unknown"
L.SOURCE = "Source"
L.SOURCE_UNCONFIRMED = "Source data is from classic and unconfirmed for Forever."
L.SOURCE_TRAINER = "Trainer"
L.SOURCE_VENDOR = "Vendor"
L.SOURCE_VENDOR_UNCONFIRMED = "Vendor (unconfirmed)"
L.SOURCE_NOT_YET = "The recipe doesn't seem to be in WoW Forever yet."
L.SOURCE_DISPUTED = "Sources disagree on how to get this in WoW Forever."
L.SOURCE_PARTLY_CHECKED = "Vendors are checked for Forever; the other sources are from classic and unconfirmed."
L.SOURCE_DROP = "Drop"
L.SOURCE_QUEST = "Quest"
L.SOURCE_CONTAINER = "Container"
L.SOURCE_OTHER = "Other"
L.SOURCE_UNKNOWN = "Unknown source."
L.SOURCE_AUTO = "Learned automatically with the profession"
L.SOURCE_LOCATIONS = "%d locations"
L.SOURCE_MORE = "(+%d more)"
L.SKILLUP_LABEL = "Skill-ups"
L.SKILLUP_YOUR_RANK = "Your skill: %d"
L.SKILLUP_RANGE = "%d - %d"
L.SKILLUP_UNTIL = "until %d"
L.SKILLUP_FROM = "from %d"
L.SKILLUP_NOW = "now"
L.SKILLUP_COLORS = { "Orange", "Yellow", "Green", "Grey" }
L.SKILLUP_CHANCE = { "always", "usually", "sometimes", "never" }
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
L.FRIENDS_HEADER = "Friends (Fellowship Ledger)"
L.FRIENDS_BUTTON = "Friends (%d)"
L.FRIENDS_NOTE = "Shared through Fellowship Ledger. Friends on a different play type can't trade with you."
L.GUIDE_LEARN = "Learn %s from a trainer (most major cities have one)."
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
L.CLOSEST_RANKUP = "%s  %d/%d  -  %d to %s"
L.READY_TO_TRAIN = "%s  %d/%d  -  train %s"
L.RANK_NAMES = { Apprentice = "Apprentice", Journeyman = "Journeyman", Expert = "Expert", Artisan = "Artisan" }
L.BROWSE_GROUP = "%s (%d-%d)"

-- Rank-up pop-up
L.RANKUP_BUTTON = "Train %s"

-- Leveling planner
L.PLAN_BUTTON = "Leveling plan"
L.PLAN_OPEN_TIP = "The cheapest way to raise this skill to the cap, with the materials and a shopping list."
L.PLAN_TITLE = "Leveling plan: %s"
L.PLAN_FOR = "%s: %s %d to %d"
L.PLAN_AT_CAP = "At the cap: train the next rank first."
L.PLAN_TRAINER = "Include trainer recipes not learned yet"
L.PLAN_OWNED = "Use materials in my bags and bank first"
L.PLAN_NO_PRICES = "Auctionator isn't installed: only vendor prices are known. Recipes using your own materials"
    .. " and vendor goods come first, then those needing the fewest other materials."
L.PLAN_STEPS = "Steps"
L.PLAN_STEP = "%d-%d  craft about %d x %s"
L.PLAN_LEARN = "(learn from a trainer)"
L.PLAN_PRICE_UNKNOWN = "price unknown"
L.PLAN_STEP_TIP = "Click to open this recipe."
L.PLAN_STUCK = "No recipe gives skill-ups from %d. Learn new recipes (or include trainer recipes)."
L.PLAN_SOME_UNPRICED = "Some materials have no price yet: scan the auction house with Auctionator."
L.PLAN_MATERIALS = "Materials"
L.PLAN_NEED_HAVE = "need %d, have %d"
L.PLAN_BUY = "buy %d"
L.PLAN_SHOPPING = "Shopping list (leveling plan)"
L.PLAN_NOTE = "Estimates: skill-ups are random. Yellow and green use the usual chance formula."
L.RANKBAR_CLICK = "Click for how to train the next rank and specializations."
L.RANKUP_ALL_DONE = "%s has trained every %s rank."
L.SPEC_HEADER = "Specialization"
L.SPEC_PICK_ONE = "Choose one, through its quest. Quest details from Questie's database."
L.SPEC_CHOSEN = "%s is a %s."
L.SPEC_THEN = "Then: %s"
L.SPEC_NO_QUEST = "Its quest isn't in Questie's database."
L.RANKUP_TITLE = "Train %s %s"
L.RANKUP_RAISES = "Raises %s's maximum %s skill to %d."
L.RANKUP_REQUIREMENTS = "Requirements"
L.RANKUP_LEVEL = "Requires level %d"
L.RANKUP_YOU = "You: %s"
L.RANKUP_NOT_YET = "Not yet: raise your skill first."
L.RANKUP_COST = "Training cost"
L.RANKUP_GUESS = "(unconfirmed)"
L.RANKUP_UNCONFIRMED = "Unconfirmed trainers are a guess from recipe data."
    .. " Open a trainer's window once and Tradebook remembers what they teach."
L.RANKUP_COST_BOOK = "Book cost"
L.RANKUP_COST_BASE = "(before reputation discounts)"
L.RANKUP_NOTHING = "There's no rank to train next."
L.RANKUP_BY_TRAINER = "Train it at a trainer"
L.RANKUP_ANY_TRAINER = "Any %s trainer who teaches %s."
L.RANKUP_NEED_QUESTIE = "Install Questie to see where."
L.RANKUP_BY_BOOK = "Learn it from a book"
L.RANKUP_YOU_HAVE = "You have one"
L.RANKUP_BY_QUEST = "Complete a quest"
L.RANKUP_QUEST_NAME = "Quest: %s"
L.RANKUP_QUEST_DONE = "Done"
L.RANKUP_QUEST_NOT_DONE = "Not done"
L.RANKUP_REP = "Requires %s with %s"
L.RANKUP_PREREQ = "First complete: %s"
L.RANKUP_GIVER = "Quest giver:"
L.PLAYTYPE = {
    normal = "Normal",
    pvp = "PvP",
    rp = "Role-Playing",
    rppvp = "Role-Playing PvP",
    unknown = "Unknown",
}
L.MISSING_FOR = "%d not learned"

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
