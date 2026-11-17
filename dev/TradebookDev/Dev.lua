-- dev/TradebookDev/Dev.lua
-- Maintainer-only tools for Tradebook. Never packaged (.pkgmeta ignores dev/); linked into the
-- maintainer's AddOns folder only. Tradebook hands over its namespace at login
-- (Core/Init.lua: TradebookDev.Attach(ns)); without this addon nothing of it exists.
--
-- Unscanned window: every vendor Questie knows, plus the bundled recipe vendors
-- (Data/RecipeVendors.lua), that nobody has scanned yet (not in your scans, the community
-- data, or what other players shared in game), nearest first, with each vendor's faction.
-- Click a row for a waypoint, and to target and mark the vendor when it's nearby. It's its
-- own small window (moved, resized and closed on its own; position saved), so the Tradebook
-- window can stay closed. /tbdev opens or closes it. Distances refresh every 20 s while open.
--
-- Heard notifications: when Tradebook keeps data another player shared in game (its NET_HEARD
-- message, Core/Net.lua), a few seconds of it from one player become one notification: lines in
-- the heard window (its own window, opens by itself; /tbdev heard, /tbdev heard auto; copies in
-- chat when "Also in chat" is ticked), a message in the middle of the screen and a sound. Vendors and trainers not in your
-- scans or the community data are marked NEW. /tbdev notify turns it off and on. Players are
-- shown by character name when this addon saw them send (startNameWatcher), otherwise by number
-- this session (Tradebook itself keeps hashes, never names).
-- Since the last import: every notification is also logged (TradebookDevDB.heardLog), and the
-- totals since the maintainer's last "import npc data" are shown with each notification and
-- by /tbdev count. The import writes LastImport.lua (TradebookDevLastImport = time) into this
-- folder (scripts/research/mark_import.lua); it loads on the next /reload and older log
-- entries stop counting (and are dropped).

TradebookDev = {}
local Dev = TradebookDev

local ns -- Tradebook's namespace, from Attach
local View = {}
local BATCH = 60 -- vendors located per frame

-- Faction colours and labels (Questie's friendlyToFaction, via Questie.NpcFaction).
local FACTION_COLOR = { Alliance = "ff4a9eff", Horde = "ffff4040", Both = "ff40ff40", Neither = "ff999999" }
local FACTION_SHORT = { Alliance = "Alliance", Horde = "Horde", Both = "Both", Neither = "Hostile to both" }
local function factionText(f)
    if not f then return "|cff999999faction ?|r" end
    return "|c" .. FACTION_COLOR[f] .. FACTION_SHORT[f] .. "|r"
end

local function db()
    TradebookDevDB = TradebookDevDB or {}
    local d = TradebookDevDB
    if d.countHeard == nil then d.countHeard = true end
    d.checked = d.checked or {} -- [npcID] = { name, at, novendor = "auto"|"manual", missing = "manual" }
    -- (Earlier builds kept one mark per NPC: { how, reason }.)
    for _, e in pairs(d.checked) do
        if e.how or e.reason then
            e[e.reason or "novendor"] = e.how or "manual"
            e.how, e.reason = nil, nil
        end
    end
    if not d.factions then d.factions = Dev.DefaultFactions(UnitFactionGroup("player")) end
    return d
end

-- PURE. Factions shown by default: yours, Both and unknown.
function Dev.DefaultFactions(mine)
    return { Horde = mine ~= "Alliance", Alliance = mine == "Alliance", Both = true, Neither = false, Unknown = true }
end

-- PURE. Does row r pass filter settings f? (factions: [faction or "Unknown"] = shown;
-- within: yards or nil; recipeOnly; showChecked: also NPCs checked to have no vendor window.)
-- active: { [event name] = true } from the game's calendar, or nil when the calendar can't
-- be read. f.events: which world event NPCs (r.event) to show: "on" (default: only while
-- their event is on), "all" (all year) or "none" (world events off). A "not there" mark on an
-- event NPC doesn't count while its event is on (it's back then).
function Dev.Passes(r, f, active)
    if f.factions and f.factions[r.faction or "Unknown"] == false then return false end
    if f.recipeOnly and not r.recipe then return false end
    if f.within and not (r.distance and r.distance <= f.within) then return false end
    if r.event then
        local mode = f.events or "on"
        if mode == "none" then return false end
        if mode == "on" and active and not active[r.event] then return false end
    end
    if Dev.IsMarked(r, active) and not f.showChecked then return false end
    return true
end

-- PURE. Does a row count as marked? (A "not there" on an event NPC doesn't while its event is on.)
function Dev.IsMarked(r, active)
    local m = r.marks
    if not m then return false end
    if m.novendor then return true end
    if m.missing then return not (r.event and active and active[r.event]) end
    return false
end

-- World events, and words in an NPC's name or title that place it in one.
Dev.EVENTS = {
    { name = "Darkmoon Faire", words = { "Darkmoon" } },
    { name = "Lunar Festival", words = { "Lunar Festival" } },
    { name = "Love is in the Air", words = { "Love is in the Air" } },
    { name = "Noblegarden", words = { "Noblegarden" } },
    { name = "Children's Week", words = { "Children's Week" } },
    { name = "Midsummer Fire Festival", words = { "Midsummer" } },
    { name = "Brewfest", words = { "Brewfest" } },
    { name = "Hallow's End", words = { "Hallow's End" } },
    { name = "Harvest Festival", words = { "Harvest Festival" } },
    { name = "Pilgrim's Bounty", words = { "Pilgrim's Bounty" } },
    { name = "Day of the Dead", words = { "Day of the Dead" } },
    { name = "Feast of Winter Veil", words = { "Winter Veil", "Smokywood" } },
}

-- PURE. The world event an NPC belongs to, from its name and title, or nil.
function Dev.EventOf(name, sub)
    local text = ((name or "") .. " | " .. (sub or "")):lower()
    for _, e in ipairs(Dev.EVENTS) do
        for _, w in ipairs(e.words) do
            if text:find(w:lower(), 1, true) then return e.name end
        end
    end
end

-- PURE. Which events the calendar titles of today name: { [event name] = true }.
function Dev.EventsInTitles(titles)
    local out = {}
    for _, title in ipairs(titles) do
        local t = tostring(title):lower()
        for _, e in ipairs(Dev.EVENTS) do
            if t:find(e.name:lower(), 1, true) then out[e.name] = true end
            for _, w in ipairs(e.words) do
                if t:find(w:lower(), 1, true) then out[e.name] = true end
            end
        end
    end
    return out
end

local function say(msg) print("|cffd9a54aTradebook Dev|r: " .. msg) end

---------------------------------------------------------------------------
-- data
---------------------------------------------------------------------------

-- PURE. Vendor NPC IDs nobody has scanned: { [npcID] = { items = n, recipe = true|nil } }.
-- questieIndex: { { itemID, vendors = { npcID } } }; recipeVendors: Data/RecipeVendors.lua;
-- scanned: list of { [npcID] = entry } tables that count as scanned.
function Dev.Unscanned(questieIndex, recipeVendors, scanned)
    local out = {}
    for _, q in ipairs(questieIndex or {}) do
        for _, npc in ipairs(q.vendors or {}) do
            out[npc] = out[npc] or { items = 0 }
            out[npc].items = out[npc].items + 1
        end
    end
    for _, r in pairs(recipeVendors or {}) do
        for _, npc in ipairs(type(r.v) == "table" and r.v or {}) do
            out[npc] = out[npc] or { items = 0 }
            out[npc].recipe = true
        end
    end
    for _, list in ipairs(scanned) do
        for npc in pairs(list or {}) do out[npc] = nil end
    end
    return out
end

Dev.SORTS = { { key = "distance", text = "Distance" }, { key = "faction", text = "Faction" },
    { key = "name", text = "Name" }, { key = "zone", text = "Zone" } }

-- PURE. Sort rows in place. by: "distance" (nearest first, unknown last), "faction" (yours,
-- then Both, then the other faction, then hostile to both, then unknown; nearest first within
-- each), "name" or "zone" (then nearest first). myFaction: "Horde" / "Alliance".
function Dev.Sort(rows, by, myFaction)
    local function factionRank(f)
        if f == myFaction then return 1 end
        if f == "Both" then return 2 end
        if f == "Alliance" or f == "Horde" then return 3 end
        if f == "Neither" then return 4 end
        return 5
    end
    local function nearer(a, b)
        if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
        if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
        return a.npcID < b.npcID
    end
    local function text(v) return (v or "~"):lower() end -- unknown sorts last
    table.sort(rows, function(a, b)
        if by == "faction" then
            local ra, rb = factionRank(a.faction), factionRank(b.faction)
            if ra ~= rb then return ra < rb end
        elseif by == "name" or by == "zone" then
            local ta, tb = text(a[by]), text(b[by])
            if ta ~= tb then return ta < tb end
        end
        return nearer(a, b)
    end)
    return rows
end

---------------------------------------------------------------------------
-- world events: which NPCs belong to one (name / title, or giving that event's quests, via
-- Questie's QuestieEvent), and which events are on today (the game's calendar).
---------------------------------------------------------------------------

local questieEvent
local function eventModule()
    if questieEvent == nil then
        questieEvent = false
        local loader = _G.QuestieLoader
        if type(loader) == "table" and type(loader.ImportModule) == "function" then
            local ok, mod = pcall(loader.ImportModule, loader, "QuestieEvent")
            if ok and type(mod) == "table" and type(mod.GetEventNameFor) == "function" then questieEvent = mod end
        end
    end
    return questieEvent or nil
end

-- Event NPCs neither their name, title nor quests give away (docs/research/npc_checks.json).
Dev.EVENT_NPCS = {
    [14860] = "Darkmoon Faire", -- Flik: spawns beside the Faire vendors at both Faire sites
}

function Dev.NpcEvent(npc, name, sub)
    if Dev.EVENT_NPCS[npc] then return Dev.EVENT_NPCS[npc] end
    local e = Dev.EventOf(name, sub)
    if e then return e end
    local mod = eventModule()
    if not (mod and ns.Questie.NpcQuests) then return nil end
    local starts, ends = ns.Questie.NpcQuests(npc)
    for _, list in ipairs({ starts, ends }) do
        for _, q in ipairs(list) do
            local ok, ev = pcall(mod.GetEventNameFor, q)
            if ok and type(ev) == "string" and ev ~= "" then return ev end
        end
    end
end

local activeEvents -- { [event] = true }, or nil when the calendar couldn't be read
local function readCalendar()
    local C = _G.C_Calendar
    if type(C) ~= "table" or type(C.GetNumDayEvents) ~= "function" then return end
    local ok, now = pcall(C.GetCurrentCalendarTime or C.GetDate)
    if not (ok and type(now) == "table" and now.monthDay) then return end
    pcall(C.SetAbsMonth, now.month, now.year)
    local titles = {}
    local okN, n = pcall(C.GetNumDayEvents, 0, now.monthDay)
    for i = 1, okN and n or 0 do
        local okE, e = pcall(C.GetDayEvent, 0, now.monthDay, i)
        if okE and type(e) == "table" and e.title then titles[#titles + 1] = e.title end
    end
    activeEvents = Dev.EventsInTitles(titles)
    if View.frame then View:RefreshList() end
end

function Dev.ActiveEvents() return activeEvents end

-- The unscanned vendor set (Questie's vendor lists load in batches), then done(set).
local lastSet
local function candidates(done)
    ns.Questie.VendorItems(function(index)
        local d = db()
        local scanned = { ns.db.vendors, ns.CommunityVendors, ns.NotInForever }
        if d.countHeard and ns.Net then scanned[#scanned + 1] = ns.Net.HeardVendors() end
        lastSet = Dev.Unscanned(index, ns.RecipeVendors, scanned)
        done(lastSet)
    end)
end

-- Locate every candidate (a batch per frame), then call done(rows) (unsorted).
local building
local function build(done)
    if building then return end
    building = true
    candidates(function(set)
        local checked = db().checked
        local ids = {}
        for npc in pairs(set) do ids[#ids + 1] = npc end
        local rows, i = {}, 1
        local function step()
            for k = i, math.min(#ids, i + BATCH - 1) do
                local npc = ids[k]
                local place = ns.Questie.VendorPlace(npc)
                local info = set[npc]
                rows[#rows + 1] = { npcID = npc, items = info.items, recipe = info.recipe,
                    name = place and place.name or (ns.RecipeVendorNames and ns.RecipeVendorNames[npc]),
                    sub = place and place.sub, zone = place and place.zone, distance = place and place.distance,
                    friendly = place and place.friendly, place = place,
                    faction = ns.Questie.NpcFaction and ns.Questie.NpcFaction(npc), marks = checked[npc],
                    event = Dev.NpcEvent(npc, place and place.name or nil, place and place.sub) }
            end
            i = i + BATCH
            if i <= #ids then
                C_Timer.After(0, step)
                return
            end
            building = false
            done(rows)
        end
        step()
    end)
end

---------------------------------------------------------------------------
-- view
---------------------------------------------------------------------------

-- What a mark means (row text, tooltip, chat).
local MARK_TEXT = { novendor = "not a vendor", missing = "not there" }
local MARK_ICON = { novendor = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    missing = "Interface\\RaidFrame\\ReadyCheck-Waiting" }

local function waypoint(r)
    local p = r.place
    if p and p.areaID then ns.Waypoints.Set(p.areaID, p.x, p.y, r.name) end
end

local function tooltipFor(r)
    local W, L = ns.W, ns.L
    local lines = { r.name or ("NPC " .. r.npcID) }
    if r.sub then lines[#lines + 1] = "<" .. r.sub .. ">" end
    lines[#lines + 1] = ("NPC %d"):format(r.npcID)
    if r.items > 0 then lines[#lines + 1] = ("Questie lists %d items"):format(r.items) end
    if r.recipe then lines[#lines + 1] = W.ColorText(W.GOLD, "Sells recipes (bundled data)") end
    lines[#lines + 1] = "Faction: " .. factionText(r.faction)
    if r.event then
        local state = activeEvents == nil and "the calendar couldn't be read"
            or (activeEvents[r.event] and "on now" or "not on now")
        lines[#lines + 1] = "|cffc080ffWorld event: " .. r.event .. "|r (" .. state .. ")"
        if r.marks and r.marks.missing and activeEvents and activeEvents[r.event] then
            lines[#lines + 1] = W.ColorText(W.GREY, "Marked not there outside the event: shown again while it's on.")
        end
    end
    if r.friendly == false then lines[#lines + 1] = W.ColorText(W.RED, "Not friendly to you") end
    local c = r.marks or {}
    if c.missing then lines[#lines + 1] = W.ColorText(W.GREY, "Marked: not there (couldn't find it here)") end
    if c.novendor then
        lines[#lines + 1] = W.ColorText(W.GREY, "Marked: not a vendor (" .. (c.novendor == "auto"
            and "you talked to it and no window opened" or "marked by you") .. ")")
    end
    if r.place then lines[#lines + 1] = L.WAYPOINT_TARGET_CLICK end
    lines[#lines + 1] = "Box: not there.  Right-click: not a vendor."
    return lines
end

---------------------------------------------------------------------------
-- Marked NPCs (TradebookDevDB.checked[npcID] = { name, at, novendor, missing }): ones
-- Questie calls vendors that you checked in game. Two marks, kept apart (an NPC can have both):
--   missing  "not there": you couldn't find it at its marked location. The box at the left
--            of a row switches it.
--   novendor "not a vendor": talking to it opens no vendor or trainer window. A right-click
--            switches it; also set automatically ("auto") when you talk to an unscanned vendor
--            and nothing opens, and cleared again if it does open a window later.
-- Marked NPCs are hidden unless "Show marked NPCs" is ticked.
---------------------------------------------------------------------------

-- PURE. Set (how: "auto" / "manual") or clear (how nil) one mark ("novendor" / "missing") in
-- a marks table; an NPC with no marks left is removed. Returns the NPC's entry or nil.
function Dev.Mark(list, npc, name, kind, how, now)
    local e = list[npc] or { name = name }
    e[kind] = how
    e.at = now
    e.name = e.name or name
    if not (e.novendor or e.missing) then
        list[npc] = nil
        return nil
    end
    list[npc] = e
    return e
end

function Dev.SetMark(npc, name, kind, how)
    local e = Dev.Mark(db().checked, npc, name, kind, how, time())
    for _, r in ipairs(View.rows or {}) do
        if r.npcID == npc then r.marks = e end
    end
    View:RefreshList()
end

-- Switch one mark by hand (box: "missing", right-click: "novendor").
local function toggleMark(r, kind)
    local e = db().checked[r.npcID]
    local on = not (e and e[kind])
    Dev.SetMark(r.npcID, r.name, kind, on and "manual" or nil)
    say(("%s: %s %s."):format(r.name or ("NPC " .. r.npcID), MARK_TEXT[kind], on and "marked" or "unmarked"))
end

local function npcOf(unit)
    local guid = UnitGUID(unit)
    if not guid or (issecretvalue and issecretvalue(guid)) then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- Talking to an NPC: GOSSIP_SHOW. Choosing "Let me browse your goods" closes the gossip and
-- opens the vendor right after, so the check waits a moment after GOSSIP_CLOSED.
local talk
local function onTalkEvent(_, event)
    if not ns then return end
    if event == "GOSSIP_SHOW" then
        local id = npcOf("npc")
        if id and not (talk and talk.npc == id) then talk = { npc = id, name = UnitName("npc") } end
    elseif event == "MERCHANT_SHOW" or event == "TRAINER_SHOW" then
        local id = npcOf("npc")
        if talk and talk.npc == id then talk.opened = true end
        -- It does have a window after all: forget an automatic "not a vendor".
        local c = id and db().checked[id]
        if c and c.novendor == "auto" then Dev.SetMark(id, c.name, "novendor", nil) end
    elseif event == "GOSSIP_CLOSED" then
        local t = talk
        C_Timer.After(1.5, function()
            if talk ~= t then return end
            talk = nil
            local c = t and db().checked[t.npc]
            if not t or t.opened or (c and c.novendor) then return end
            candidates(function(set)
                if not set[t.npc] then return end -- not an unscanned vendor
                Dev.SetMark(t.npc, t.name, "novendor", "auto")
                say(("%s has no vendor window: marked not a vendor. Right-click it in /tbdev to undo."):format(
                    t.name or ("NPC " .. t.npc)))
            end)
        end)
    end
end

local function startWatcher()
    local watcher = CreateFrame("Frame")
    for _, e in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "MERCHANT_SHOW", "TRAINER_SHOW" }) do watcher:RegisterEvent(e) end
    watcher:SetScript("OnEvent", onTalkEvent)
end

local function createRow(row)
    local W = ns.W
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    -- name | place (shrinks, cut with "...") | faction  distance (always whole).
    -- The name takes up to 38% of the row, so a narrow window cuts the place first.
    -- The mark box (above the row's target button, so it gets its own clicks).
    row.box = CreateFrame("Button", nil, row)
    row.box:SetSize(16, 16)
    row.box:SetPoint("LEFT", 4, 0)
    row.box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    row.box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    row.box.mark = row.box:CreateTexture(nil, "OVERLAY")
    row.box.mark:SetPoint("CENTER")
    row.box.mark:SetSize(12, 12)
    row.box:SetScript("OnClick", function(self) toggleMark(self:GetParent().data, "missing") end)
    row.box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Not there", 1, 1, 1)
        GameTooltip:AddLine("Tick when you couldn't find this NPC at its marked location.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click the row: not a vendor (no vendor window).", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    -- Red X after the box when marked "not a vendor".
    row.nv = row:CreateTexture(nil, "OVERLAY")
    row.nv:SetSize(14, 14)
    row.nv:SetPoint("LEFT", row.box, "RIGHT", 2, 0)
    row.nv:SetTexture(MARK_ICON.novendor)
    row.box:SetScript("OnLeave", GameTooltip_Hide)
    row.name = W.Text(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", row.box, "RIGHT", 20, 0)
    row.name:SetWordWrap(false)
    row.mid = W.Text(row, "GameFontHighlightSmall")
    row.mid:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.mid:SetWordWrap(false)
    row.right = W.Text(row, "GameFontHighlightSmall", "RIGHT")
    row.right:SetPoint("RIGHT", -6, 0)
    row.right:SetWordWrap(false)
    row.mid:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
    row:SetScript("OnSizeChanged", function(self, w)
        self.name:SetWidth(math.max(60, math.min(240, (w or 0) * 0.38)))
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then toggleMark(self.data, "novendor") else waypoint(self.data) end
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for i, line in ipairs(tooltipFor(self.data)) do
            if i == 1 then GameTooltip:SetText(line, 1, 1, 1) else GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
end

local function initRow(row, r)
    local W = ns.W
    row.data = r
    ns.TargetButtons.Release(row)
    if r.name and r.place then
        ns.TargetButtons.Attach(row, row, r.name, function() waypoint(r) end, tooltipFor(r),
            function() toggleMark(r, "novendor") end)
    end
    row.box:SetFrameLevel(row:GetFrameLevel() + 10)
    local c = r.marks or {}
    row.box.mark:SetTexture(MARK_ICON.missing)
    row.box.mark:SetShown(c.missing ~= nil)
    row.nv:SetShown(c.novendor ~= nil)
    local name = r.name or ("NPC " .. r.npcID)
    local marked = Dev.IsMarked(r, activeEvents)
    row.name:SetText(marked and W.ColorText(W.GREY, name) or (r.recipe and W.ColorText(W.GOLD, name) or name))
    local parts = {}
    if c.missing then parts[#parts + 1] = W.ColorText(W.GREY, MARK_TEXT.missing) end
    if c.novendor then parts[#parts + 1] = W.ColorText(W.GREY, MARK_TEXT.novendor) end
    if r.event then
        local on = activeEvents and activeEvents[r.event]
        parts[#parts + 1] = "|cffc080ff" .. r.event .. (on and " (on now)" or "") .. "|r"
    end
    if r.sub then parts[#parts + 1] = W.ColorText(W.GREY, "<" .. r.sub .. ">") end
    if r.zone then parts[#parts + 1] = r.zone end
    if r.place and r.place.x then parts[#parts + 1] = ("(%.0f, %.0f)"):format(r.place.x, r.place.y) end
    row.mid:SetText(table.concat(parts, "  "))
    row.right:SetText(factionText(r.faction) .. "   " .. (ns.Locations.DistanceText(r.distance) or W.ColorText(W.GREY, "far")))
    local fs = row.right
    row.right:SetWidth(math.ceil(fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()) + 2)
    row.name:SetWidth(math.max(60, math.min(240, row:GetWidth() * 0.38)))
end

function View:Build(parent)
    local W = ns.W
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    -- One header row: status (cut with "..." when narrow) | Sort | Filter | Refresh.
    local refresh = W.Button(f, "Refresh", 70, 22)
    refresh:SetPoint("TOPRIGHT", -8, -4)
    refresh:SetScript("OnClick", function() View:Load() end)

    -- Filter dropdown (with a red X to reset when changed).
    local filter = CreateFrame("DropdownButton", nil, f, "WowStyle1FilterDropdownTemplate")
    filter:SetWidth(80)
    filter:SetPoint("RIGHT", refresh, "LEFT", -6, 0)
    local DEFAULTS = { recipeOnly = false, countHeard = true, showChecked = false }
    local FACTIONS = { { "Horde" }, { "Both" }, { "Alliance" }, { "Neither" }, { "Unknown" } }
    local WITHIN = { 250, 500, 1000, 2500, 5000, 10000 }
    filter:SetIsDefaultCallback(function()
        local d = db()
        for k, v in pairs(DEFAULTS) do if (d[k] or false) ~= v then return false end end
        if d.within or (d.events or "on") ~= "on" then return false end
        local def = Dev.DefaultFactions(UnitFactionGroup("player"))
        for k, v in pairs(def) do if (d.factions[k] ~= false) ~= v then return false end end
        return true
    end)
    filter:SetDefaultCallback(function()
        local d = db()
        for k, v in pairs(DEFAULTS) do d[k] = v end
        d.within, d.events = nil, nil
        d.factions = Dev.DefaultFactions(UnitFactionGroup("player"))
        View:Load()
    end)
    filter:SetupMenu(function(_, root)
        root:CreateTitle("Faction")
        for _, fct in ipairs(FACTIONS) do
            local label = fct[1] == "Unknown" and "Unknown" or factionText(fct[1])
            root:CreateCheckbox(label, function() return db().factions[fct[1]] ~= false end,
                function()
                    local list = db().factions
                    list[fct[1]] = list[fct[1]] == false
                    View:RefreshList()
                end)
        end
        root:CreateDivider()
        root:CreateTitle("Within")
        root:CreateRadio("Any distance", function() return db().within == nil end, function()
            db().within = nil
            View:RefreshList()
        end)
        for _, yards in ipairs(WITHIN) do
            root:CreateRadio(ns.Locations.DistanceText(yards), function() return db().within == yards end, function()
                db().within = yards
                View:RefreshList()
            end)
        end
        root:CreateDivider()
        local function add(text, key)
            root:CreateCheckbox(text, function() return db()[key] == true end, function()
                db()[key] = not db()[key]
                if key == "countHeard" then View:Load() else View:RefreshList() end
            end)
        end
        add("Recipe vendors only", "recipeOnly")
        add("Show marked NPCs (not a vendor / not there)", "showChecked")
        root:CreateDivider()
        root:CreateTitle("World event NPCs")
        for _, opt in ipairs({ { "on", "Only when their event is on" }, { "all", "Always" },
            { "none", "Never (world events off)" } }) do
            root:CreateRadio(opt[2], function() return (db().events or "on") == opt[1] end, function()
                db().events = opt[1] ~= "on" and opt[1] or nil
                View:RefreshList()
            end)
        end
        add("Players' shares count as scanned", "countHeard")
    end)
    self.filter = filter

    -- Sort dropdown: shows the current choice.
    local ok, sort = pcall(CreateFrame, "DropdownButton", nil, f, "WowStyle1DropdownTemplate")
    if not ok then sort = CreateFrame("DropdownButton", nil, f, "WowStyle1FilterDropdownTemplate") end
    sort:SetWidth(110)
    sort:SetPoint("RIGHT", filter, "LEFT", -6, 0)
    sort:SetupMenu(function(_, root)
        for _, s in ipairs(Dev.SORTS) do
            root:CreateRadio("Sort by " .. s.text:lower(), function() return (db().sort or "distance") == s.key end, function()
                db().sort = s.key
                View:RefreshList()
            end)
        end
    end)

    self.status = W.Text(f, "GameFontNormal")
    self.status:SetPoint("LEFT", f, "TOPLEFT", 10, -15)
    self.status:SetPoint("RIGHT", sort, "LEFT", -8, 0)
    self.status:SetWordWrap(false)
    self.list = W.List(f, 20, createRow, initRow)
    self.list:SetPoint("TOPLEFT", 4, -32)
    self.list:SetPoint("BOTTOMRIGHT", -22, 4)
end

function View:RefreshList()
    if not self.frame then return end
    local d = db()
    local shown = {}
    for _, r in ipairs(self.rows or {}) do
        if Dev.Passes(r, d, activeEvents) then shown[#shown + 1] = r end
    end
    Dev.Sort(shown, d.sort or "distance", UnitFactionGroup("player"))
    self.list:SetItems(shown)
    if self.filter.ValidateResetState then self.filter:ValidateResetState() end
    if not ns.Questie.Available() then
        self.status:SetText("Needs Questie for vendor positions.")
    else
        self.status:SetText(("%d unscanned (of %d)"):format(#shown, #(self.rows or {})))
    end
end

function View:Load()
    self.status:SetText("Finding unscanned vendors...")
    build(function(rows)
        View.rows = rows
        View:RefreshList()
    end)
end

---------------------------------------------------------------------------
-- the window
---------------------------------------------------------------------------

local win

local function savePosition()
    local point, _, rel, x, y = win:GetPoint()
    db().window = { point = point, rel = rel, x = x, y = y, w = win:GetWidth(), h = win:GetHeight() }
end

local function createWindow()
    win = CreateFrame("Frame", "TradebookDevFrame", UIParent, "BasicFrameTemplateWithInset")
    local pos = db().window
    win:SetSize(pos and pos.w or 640, pos and pos.h or 380)
    if pos and pos.point then
        win:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x, pos.y)
    else
        win:SetPoint("CENTER", 300, 0)
    end
    win:SetFrameStrata("MEDIUM")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:SetResizable(true)
    if win.SetResizeBounds then win:SetResizeBounds(460, 200, 1400, 1000) end
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        savePosition()
    end)
    if win.TitleText then win.TitleText:SetText("Tradebook Dev: unscanned vendors") end
    -- Resize grip, bottom right.
    local grip = CreateFrame("Button", nil, win)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        savePosition()
    end)
    local content = CreateFrame("Frame", nil, win)
    content:SetPoint("TOPLEFT", 8, -28)
    content:SetPoint("BOTTOMRIGHT", -6, 22)
    View:Build(content)
    -- Distances change as you move: rebuild every 20 s while open.
    local elapsed = 0
    win:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 20 then
            elapsed = 0
            if not building then View:Load() end
        end
    end)
    win:SetScript("OnShow", function()
        elapsed = 0
        View:Load()
    end)
    tinsert(UISpecialFrames, "TradebookDevFrame") -- ESC closes it
    win:Hide()
end

-- Open or close the window (show: true / false, or nil to switch).
function Dev.Toggle(show)
    if not ns then say("Tradebook isn't loaded.") return end
    if not win then createWindow() end
    if show == nil then show = not win:IsShown() end
    win:SetShown(show)
end

-- Heard notifications ----------------------------------------------------

-- Thank-you list (TradebookDevDB.helpers, local only, never committed; this addon is never
-- published): what each player sent you, all time, by Tradebook's hash of their name, with the
-- character name once this addon has seen them send (startNameWatcher).
-- PURE. Add one notification's counts { v, t, new, c, d } for `who` at time `now`.
function Dev.Credit(helpers, who, counts, now, name)
    local e = helpers[who]
    if not e then
        e = { first = now, reports = 0, vendors = 0, trainers = 0, new = 0, confirmed = 0, de = 0 }
        helpers[who] = e
    end
    e.reports = e.reports + 1
    e.vendors = e.vendors + (counts.v or 0)
    e.trainers = e.trainers + (counts.t or 0)
    e.new = e.new + (counts.new or 0)
    e.confirmed = e.confirmed + (counts.c or 0)
    e.de = e.de + (counts.d or 0)
    e.last = now
    if name then e.name = name end
    return e
end

-- PURE. Lines for /tbdev thanks: "Name (N)", N = everything they sent you (vendors, trainers,
-- confirmations, disenchant results), most first.
function Dev.ThanksLines(helpers)
    local rows = {}
    for who, e in pairs(helpers or {}) do
        rows[#rows + 1] = { who = tostring(who), name = e.name, via = e.via, full = e.full,
            n = (e.vendors or 0) + (e.trainers or 0) + (e.confirmed or 0) + (e.de or 0) }
    end
    table.sort(rows, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return (a.name or "~" .. a.who) < (b.name or "~" .. b.who)
    end)
    local lines = {}
    for _, r in ipairs(rows) do
        local unknown = "name not seen yet, " .. r.who .. (r.via and (", passed along by " .. r.via) or "")
        lines[#lines + 1] = ("%s (%d)%s"):format(r.name or unknown, r.n,
            (r.name and r.full and r.full ~= r.name) and (" [as the game sends it: " .. r.full .. "]") or "")
    end
    return lines
end

local heardPending = {} -- [who] = { vendors, trainers, confirmed, deBands } (see Dev.HeardLines)
local playerNumbers, playerCount = {}, 0
local senderNames = {} -- [hash] = character name, this session only (startNameWatcher)
local relayedBy = {} -- [original player's hash] = name of who last passed their data along

local GREEN_NEW, YELLOW_DIFFERS = "|cff40ff40NEW|r ", "|cffffd100DIFFERS|r "
local MAX_LIST = 6

local function size(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- A list cut to MAX_LIST entries ("..., +3 more").
local function joinList(items)
    table.sort(items)
    if #items > MAX_LIST then
        local more = #items - MAX_LIST
        for i = #items, MAX_LIST + 1, -1 do items[i] = nil end
        items[#items + 1] = "+" .. more .. " more"
    end
    return table.concat(items, ", ")
end

-- PURE. The notification, one line per kind of data, from what a player shared:
--   h = { vendors = { [npc] = { name, items, map } }, trainers = { [npc] = { name, skill, services } },
--         confirmed = { ["kind:npc"] = { kind, npc } }, deBands = { [band] = { n, mats } } }
--   ctx = { isNew(kind, npc), mapName(m), profName(skill), npcName(kind, npc), bandLabel(band),
--           deStatus(band, rec) -> { new = bool, differs = bool }, itemName(id) }
-- Returns a list of lines (the first is the header), or nil when nothing came in.
function Dev.HeardLines(label, h, ctx)
    local lines = {}
    local vendors = {}
    for npc, v in pairs(h.vendors or {}) do
        local where = v.map and ctx.mapName(v.map)
        vendors[#vendors + 1] = (ctx.isNew("vendor", npc) and GREEN_NEW or "") .. v.name
            .. (" (%d items%s)"):format(v.items or 0, where and (", " .. where) or "")
    end
    if #vendors > 0 then
        lines[#lines + 1] = ("  %d %s: %s"):format(#vendors, #vendors == 1 and "vendor" or "vendors", joinList(vendors))
    end
    local trainers = {}
    for npc, t in pairs(h.trainers or {}) do
        local prof = t.skill and ctx.profName(t.skill)
        trainers[#trainers + 1] = (ctx.isNew("trainer", npc) and GREEN_NEW or "") .. t.name
            .. (" (%s%d services)"):format(prof and (prof .. ", ") or "", t.services or 0)
    end
    if #trainers > 0 then
        lines[#lines + 1] = ("  %d %s: %s"):format(#trainers, #trainers == 1 and "trainer" or "trainers", joinList(trainers))
    end
    local confirmed = {}
    for _, c in pairs(h.confirmed or {}) do confirmed[#confirmed + 1] = ctx.npcName(c.kind, c.npc) end
    if #confirmed > 0 then lines[#lines + 1] = ("  %d confirmed again: %s"):format(#confirmed, joinList(confirmed)) end
    local bands = {}
    for band in pairs(h.deBands or {}) do bands[#bands + 1] = band end
    table.sort(bands)
    local de = {}
    for _, band in ipairs(bands) do
        local rec = h.deBands[band]
        local status = ctx.deStatus(band, rec)
        local mats = {}
        for id, m in pairs(rec.mats or {}) do
            mats[#mats + 1] = ("%s x%s"):format(ctx.itemName(id), m.lo == m.hi and m.lo or (m.lo .. "-" .. m.hi))
        end
        table.sort(mats)
        de[#de + 1] = (status.new and GREEN_NEW or "") .. (status.differs and YELLOW_DIFFERS or "")
            .. ("%s: %d (%s)"):format(ctx.bandLabel(band), rec.n, table.concat(mats, ", "))
    end
    if #de > 0 then
        if #de > MAX_LIST then
            local more = #de - MAX_LIST
            for i = #de, MAX_LIST + 1, -1 do de[i] = nil end
            de[#de + 1] = "+" .. more .. " more bands"
        end
        lines[#lines + 1] = ("  Disenchants, %d %s: %s"):format(#bands, #bands == 1 and "band" or "bands", table.concat(de, "; "))
    end
    if #lines == 0 then return nil end
    table.insert(lines, 1, label .. ":")
    return lines
end

-- PURE. What kinds of data came in, for the on-screen message: "2 vendors (1 new), disenchants".
function Dev.HeardKinds(h, newVendors, newTrainers, newBands)
    local kinds = {}
    local v, t, c = size(h.vendors), size(h.trainers), size(h.confirmed)
    local function new(n) return (n or 0) > 0 and (" (" .. n .. " new)") or "" end
    if v > 0 then kinds[#kinds + 1] = v .. (v == 1 and " vendor" or " vendors") .. new(newVendors) end
    if t > 0 then kinds[#kinds + 1] = t .. (t == 1 and " trainer" or " trainers") .. new(newTrainers) end
    if c > 0 then kinds[#kinds + 1] = c .. " confirmations" end
    local b = size(h.deBands)
    if b > 0 then kinds[#kinds + 1] = "disenchants for " .. b .. (b == 1 and " band" or " bands") .. new(newBands) end
    return table.concat(kinds, ", ")
end

local function isNew(kind, npc)
    if kind == "vendor" then
        return not ((ns.db.vendors and ns.db.vendors[npc]) or (ns.CommunityVendors and ns.CommunityVendors[npc]))
    end
    return not ((ns.db.trainers and ns.db.trainers[npc]) or (ns.CommunityTrainers and ns.CommunityTrainers[npc]))
end

local QUALITY = { [2] = "green", [3] = "blue", [4] = "purple" }
local function bandOf(id)
    for _, b in ipairs(ns.DisenchantBands or {}) do if b[7] == id then return b end end
    return nil
end

-- What the notification needs from Tradebook (names, places, disenchant bands).
local function context()
    return {
        isNew = isNew,
        mapName = function(m)
            local map = _G.C_Map
            local info = map and map.GetMapInfo and map.GetMapInfo(m)
            return info and info.name or nil
        end,
        profName = function(skill)
            local p = ns.Professions.Get(skill)
            return p and (ns.L[p.name] or p.name) or nil
        end,
        npcName = function(kind, npc)
            local e = kind == "vendor" and ((ns.db.vendors and ns.db.vendors[npc]) or (ns.CommunityVendors and ns.CommunityVendors[npc]))
                or ((ns.db.trainers and ns.db.trainers[npc]) or (ns.CommunityTrainers and ns.CommunityTrainers[npc]))
            return e and e.name or ("NPC " .. npc)
        end,
        bandLabel = function(band)
            local b = bandOf(band)
            if not b then return "band " .. band end
            return ("%s %s %d-%d"):format(QUALITY[b[2]] or "?", b[1] == 2 and "weapon" or "armor", b[3], b[4])
        end,
        -- NEW: nobody's results for this band yet (yours or the shipped database). DIFFERS: what
        -- this player got doesn't fit the classic table.
        deStatus = function(band, rec)
            local b = bandOf(band)
            local new = not ((ns.db.disenchants and ns.db.disenchants[band]) or (ns.CommunityDisenchants and ns.CommunityDisenchants[band]))
            local classic = b and ns.Disenchant.Classic(ns.DisenchantClassic, b[1], b[2], b[3])
            return { new = new, differs = classic ~= nil and not ns.Disenchant.Fits(classic, rec) }
        end,
        itemName = function(id) return ns.Compat.ItemInfo(id) or ("item " .. id) end,
    }
end

-- PURE. Totals of log entries after `since`: { vendors, newVendors, trainers, newTrainers,
-- confirms, disenchantPlayers, players, messages }.
function Dev.SinceImport(log, since)
    local out = { vendors = 0, newVendors = 0, trainers = 0, newTrainers = 0, confirms = 0,
        disenchantPlayers = 0, players = 0, messages = 0, newBands = 0, differs = 0 }
    local players, dePlayers = {}, {}
    for _, e in ipairs(log or {}) do
        if (e.at or 0) > (since or 0) then
            out.messages = out.messages + 1
            out.vendors, out.newVendors = out.vendors + (e.v or 0), out.newVendors + (e.vn or 0)
            out.trainers, out.newTrainers = out.trainers + (e.t or 0), out.newTrainers + (e.tn or 0)
            out.confirms = out.confirms + (e.c or 0)
            if e.who then players[e.who] = true end
            if (e.d or 0) > 0 and e.who then dePlayers[e.who] = true end
            out.newBands = out.newBands + (e.dn or 0)
            out.differs = out.differs + (e.dd or 0)
        end
    end
    for _ in pairs(players) do out.players = out.players + 1 end
    for _ in pairs(dePlayers) do out.disenchantPlayers = out.disenchantPlayers + 1 end
    return out
end

-- PURE. "Since the last import: 12 vendors (3 new), ..." or nil when nothing came in.
function Dev.SinceText(s, lastImport)
    if s.messages == 0 then return nil end
    local parts = {}
    if s.vendors > 0 then parts[#parts + 1] = ("%d vendors (%d new)"):format(s.vendors, s.newVendors) end
    if s.trainers > 0 then parts[#parts + 1] = ("%d trainers (%d new)"):format(s.trainers, s.newTrainers) end
    if s.confirms > 0 then parts[#parts + 1] = ("%d confirmations"):format(s.confirms) end
    if s.disenchantPlayers > 0 then
        local extra = {}
        if s.newBands > 0 then extra[#extra + 1] = s.newBands .. " new bands" end
        if s.differs > 0 then extra[#extra + 1] = s.differs .. " differing from classic" end
        parts[#parts + 1] = ("disenchants from %d players%s"):format(s.disenchantPlayers,
            #extra > 0 and (" (" .. table.concat(extra, ", ") .. ")") or "")
    end
    local when = lastImport and lastImport > 0 and date("%b %d %H:%M", lastImport) or "ever"
    return ("Since the last import (%s): %s, from %d players"):format(when, table.concat(parts, ", "), s.players)
end

local function lastImport() return tonumber(_G.TradebookDevLastImport) or 0 end

local function countText()
    return Dev.SinceText(Dev.SinceImport(db().heardLog, lastImport()), lastImport())
end

-- Keep what another player sent in the log (counted until the next import).
local function logHeard(who, h, ctx)
    local d = db()
    d.heardLog = d.heardLog or {}
    local function n(t, kind)
        local c, new = 0, 0
        for npc in pairs(t) do
            c = c + 1
            if isNew(kind, npc) then new = new + 1 end
        end
        return c, new
    end
    local v, vn = n(h.vendors, "vendor")
    local t, tn = n(h.trainers, "trainer")
    local dn, dd = 0, 0
    for band, rec in pairs(h.deBands) do
        local st = ctx.deStatus(band, rec)
        if st.new then dn = dn + 1 end
        if st.differs then dd = dd + 1 end
    end
    table.insert(d.heardLog, { at = GetServerTime(), who = who, v = v, vn = vn, t = t, tn = tn,
        c = size(h.confirmed), d = size(h.deBands), dn = dn, dd = dd })
    while #d.heardLog > 2000 do table.remove(d.heardLog, 1) end
    d.helpers = d.helpers or {}
    if ns.Net.IsMine and ns.Net.IsMine(who) then return vn, tn, dn end -- your own characters
    local e = Dev.Credit(d.helpers, who, { v = v, t = t, new = vn + tn + dn, c = size(h.confirmed),
        d = size(h.deBands) }, GetServerTime(), senderNames[who])
    if relayedBy[who] then e.via = relayedBy[who] end
    return vn, tn, dn
end

-- The heard window: its own scrolling log of notifications (TradebookDevDB.heardMessages, the
-- last MAX_HEARD_LINES lines, kept over /reload), the since-import totals on top, Clear, and
-- "Also in chat". Opens by itself when data arrives (unless turned off: /tbdev heard auto).
local heardWin
local MAX_HEARD_LINES = 300

local function heardLines()
    local d = db()
    d.heardMessages = d.heardMessages or {}
    return d.heardMessages
end

local function updateHeardSummary()
    if heardWin then heardWin.summary:SetText(countText() or "Nothing from other players since the last import.") end
end

local function saveHeardPosition()
    local point, _, rel, x, y = heardWin:GetPoint()
    db().heardWindow = { point = point, rel = rel, x = x, y = y, w = heardWin:GetWidth(), h = heardWin:GetHeight() }
end

local function createHeardWindow()
    local w = CreateFrame("Frame", "TradebookDevHeardFrame", UIParent, "BasicFrameTemplateWithInset")
    heardWin = w
    local pos = db().heardWindow
    w:SetSize(pos and pos.w or 620, pos and pos.h or 300)
    if pos and pos.point then
        w:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x, pos.y)
    else
        w:SetPoint("TOP", 0, -120)
    end
    w:SetFrameStrata("MEDIUM")
    w:SetClampedToScreen(true)
    w:SetMovable(true)
    w:SetResizable(true)
    if w.SetResizeBounds then w:SetResizeBounds(380, 160, 1400, 1000) end
    w:EnableMouse(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", w.StartMoving)
    w:SetScript("OnDragStop", function()
        w:StopMovingOrSizing()
        saveHeardPosition()
    end)
    if w.TitleText then w.TitleText:SetText("Tradebook Dev: heard from other players") end
    local grip = CreateFrame("Button", nil, w)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() w:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        w:StopMovingOrSizing()
        saveHeardPosition()
    end)
    w.summary = w:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    w.summary:SetPoint("TOPLEFT", 12, -30)
    w.summary:SetPoint("RIGHT", -12, 0)
    w.summary:SetJustifyH("LEFT")
    w.summary:SetWordWrap(true)
    local log = CreateFrame("ScrollingMessageFrame", nil, w)
    log:SetPoint("TOPLEFT", w.summary, "BOTTOMLEFT", 0, -6)
    log:SetPoint("BOTTOMRIGHT", -12, 34)
    log:SetFontObject(_G.ChatFontNormal)
    log:SetJustifyH("LEFT")
    log:SetFading(false)
    log:SetMaxLines(MAX_HEARD_LINES + 50)
    log:SetInsertMode(_G.SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM or "BOTTOM")
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    w.log = log
    local clear = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    clear:SetSize(80, 22)
    clear:SetPoint("BOTTOMLEFT", 10, 8)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function()
        db().heardMessages = {}
        log:Clear()
    end)
    local chat = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate")
    chat:SetSize(24, 24)
    chat:SetPoint("LEFT", clear, "RIGHT", 12, 0)
    local chatLabel = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chatLabel:SetPoint("LEFT", chat, "RIGHT", 2, 0)
    chatLabel:SetText("Also in chat")
    chat:SetScript("OnClick", function(self) db().heardChat = self:GetChecked() and true or false end)
    w:SetScript("OnShow", function()
        chat:SetChecked(db().heardChat == true)
        updateHeardSummary()
        log:Clear()
        for _, line in ipairs(heardLines()) do log:AddMessage(line) end
        log:ScrollToBottom()
    end)
    tinsert(UISpecialFrames, "TradebookDevHeardFrame") -- ESC closes it
    w:Hide()
end

-- Open or close the heard window (show: true / false, or nil to switch).
function Dev.ToggleHeard(show)
    if not ns then say("Tradebook isn't loaded.") return end
    if not heardWin then createHeardWindow() end
    if show == nil then show = not heardWin:IsShown() end
    heardWin:SetShown(show)
end

-- Add lines to the heard log (and the window when it's open).
local function addHeard(lines)
    local log = heardLines()
    for _, line in ipairs(lines) do
        log[#log + 1] = line
        if heardWin and heardWin:IsShown() then heardWin.log:AddMessage(line) end
    end
    while #log > MAX_HEARD_LINES do table.remove(log, 1) end
end

-- The heard window (and chat, when chosen), the message in the middle of the screen, a sound,
-- and the since-import totals.
local function showHeard(label, h, ctx, vn, tn, dn, test)
    local lines = Dev.HeardLines(label, h, ctx)
    if not lines then return end
    local stamp = "|cff999999" .. date("%H:%M") .. "|r " .. (test and "|cffff8000TEST|r " or "")
    lines[1] = stamp .. lines[1]
    addHeard(lines)
    if db().heardAuto ~= false then Dev.ToggleHeard(true) end
    updateHeardSummary()
    if db().heardChat == true then
        print("|cff33ff99Tradebook Dev|r heard " .. lines[1])
        for i = 2, #lines do print(lines[i]) end
    end
    local errors = _G.UIErrorsFrame
    if errors and errors.AddMessage then
        errors:AddMessage((test and "TEST " or "") .. "Tradebook: " .. Dev.HeardKinds(h, vn, tn, dn) .. " from another player",
            0.2, 1, 0.6)
    end
    if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.TELL_MESSAGE or SOUNDKIT.IG_PLAYER_INVITE) end
end

-- /tbdev test: a made-up notification from what Tradebook already has (one shipped vendor and a
-- made-up new one, a trainer, a confirmation, two disenchant bands). Not logged or counted.
function Dev.ShowTest()
    local h = { vendors = {}, trainers = {}, confirmed = {}, deBands = {} }
    local npc, e = next(ns.CommunityVendors or {})
    if npc then
        local n = 0
        for _ in pairs(e.items or {}) do n = n + 1 end
        h.vendors[npc] = { name = e.name or "?", items = n, map = e.loc and e.loc.m }
        h.confirmed["vendor:" .. npc] = { kind = "vendor", npc = npc }
    end
    h.vendors[999999] = { name = "Made-up Vendor", items = 3 }
    local tnpc, t = next(ns.CommunityTrainers or {})
    if tnpc then h.trainers[tnpc] = { name = t.name or "?", skill = t.skill, services = #(t.services or {}) } end
    h.deBands[4] = { n = 3, mats = { [10940] = { t = 2, q = 3, lo = 1, hi = 2 }, [10938] = { t = 1, q = 1, lo = 1, hi = 1 } } }
    h.deBands[999] = { n = 1, mats = { [10939] = { t = 1, q = 2, lo = 2, hi = 2 } } }
    showHeard("Another player (#0)", h, context(), 1, 0, 1, true)
end

local function flushHeard(who)
    local h = heardPending[who]
    heardPending[who] = nil
    if not h then return end
    local ctx = context()
    local vn, tn, dn = logHeard(who, h, ctx) -- before the NEW marks: logging doesn't change them
    if db().notify == false then return end
    if not playerNumbers[who] then
        playerCount = playerCount + 1
        playerNumbers[who] = playerCount
    end
    local name = senderNames[who]
    local label = name and ("|cffffffff" .. name .. "|r") or ("Another player (#" .. playerNumbers[who] .. ")")
    if not name and relayedBy[who] then
        label = label .. ", passed along by |cffffffff" .. relayedBy[who] .. "|r"
    end
    showHeard(label, h, ctx, vn, tn, dn)
end

-- Sender names, for the heard notifications only (this addon is never published). Tradebook
-- itself drops the name the game gives each addon message and keeps only Net.Hash of it; this
-- listens to the same messages and remembers, for this session, which name gave which hash.
-- The name map is memory only; the heard window's saved lines (TradebookDevDB.heardMessages,
-- local, never committed) do show the names. heardLog keeps hashes only. Data relayed for another player carries only
-- that player's hash, so it shows a name only if they also sent to you directly this session.
-- PURE. The original player's hash in the first message of a passed-along report, or nil.
function Dev.RelayedFor(msg)
    return tostring(msg):match("^%w+~1~%d+~TBR1~[^%^]*%^R~(%x+)")
end

local function startNameWatcher()
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:SetScript("OnEvent", function(_, _, prefix, text, chatType, sender)
        if not (ns.Net and prefix == ns.Net.PREFIX and chatType == "CHANNEL") then return end
        sender = tostring(sender or "")
        if sender == "" then return end
        local short = (_G.Ambiguate and _G.Ambiguate(sender, "short")) or sender
        local hash = ns.Net.Hash(sender)
        senderNames[hash] = short
        -- Passed along for another player: the first part names them (TBR1 header, then R~hash).
        local original = Dev.RelayedFor(text)
        if original then relayedBy[original] = short end
        local helpers = db().helpers
        if helpers and helpers[hash] then
            helpers[hash].name = short
            -- As the game gave it (may name their server); shown by /tbdev thanks when it differs.
            helpers[hash].full = sender ~= short and sender or nil
        end
    end)
end

local function onHeard(who, info)
    local h = heardPending[who]
    if not h then
        h = { vendors = {}, trainers = {}, confirmed = {}, deBands = {} }
        heardPending[who] = h
    end
    for npc, v in pairs(info.vendors or {}) do h.vendors[npc] = v end
    for npc, t in pairs(info.trainers or {}) do h.trainers[npc] = t end
    for _, c in ipairs(info.confirmed or {}) do h.confirmed[c.kind .. ":" .. c.npc] = c end
    for band, rec in pairs(info.deBands or {}) do h.deBands[band] = rec end
    -- A player's backlog arrives one NPC a second or so: one notification for the lot.
    ns.Throttle("dev:heard:" .. who, 5, function() flushHeard(who) end)
end

function Dev.Attach(tradebookNS)
    ns = tradebookNS
    ns.Listen("NET_HEARD", onHeard)
    -- You collect: other players pass along what they heard until you have received it.
    if ns.Net and ns.Net.SetCollector then ns.Net.SetCollector(true) end
    -- Entries from before the last import are already in the data: drop them.
    local d, cutoff = db(), lastImport()
    if d.heardLog and cutoff > 0 then
        local keep = {}
        for _, e in ipairs(d.heardLog) do if (e.at or 0) > cutoff then keep[#keep + 1] = e end end
        d.heardLog = keep
    end
    startWatcher()
    startNameWatcher()
    -- Your own characters don't belong in the thank-you list (relayed scans of your alts).
    if d.helpers and ns.Net.OwnHashes then
        local own = ns.Net.OwnHashes(ns.db and ns.db.characters)
        for who in pairs(d.helpers) do if own[who] then d.helpers[who] = nil end end
    end
    -- The calendar fills in after a server query; read it when it arrives.
    local cal = CreateFrame("Frame")
    pcall(cal.RegisterEvent, cal, "CALENDAR_UPDATE_EVENT_LIST")
    cal:SetScript("OnEvent", readCalendar)
    if _G.C_Calendar and _G.C_Calendar.OpenCalendar then pcall(_G.C_Calendar.OpenCalendar) end
    C_Timer.After(5, readCalendar)
end

-- /tbdev thanks: the thank-you list in its own window, as text to copy (Ctrl+C).
local thanksWin
function Dev.ShowThanks()
    if not thanksWin then
        local w = CreateFrame("Frame", "TradebookDevThanksFrame", UIParent, "BasicFrameTemplateWithInset")
        w:SetSize(420, 340)
        w:SetPoint("CENTER")
        w:SetFrameStrata("DIALOG")
        w:SetToplevel(true)
        w:SetMovable(true)
        w:EnableMouse(true)
        w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", w.StartMoving)
        w:SetScript("OnDragStop", w.StopMovingOrSizing)
        local title = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
        title:SetText("Tradebook Dev: thank you list")
        local help = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", 14, -32)
        help:SetPoint("RIGHT", -14, 0)
        help:SetJustifyH("LEFT")
        help:SetText("Players who sent you data (vendors, trainers, confirmations, disenchants), most first."
            .. " Click Select all, then Ctrl+C to copy.")
        local scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
        scroll:SetPoint("BOTTOMRIGHT", -32, 40)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetFontObject("ChatFontNormal")
        box:SetWidth(360)
        box:SetAutoFocus(false)
        box:SetScript("OnEscapePressed", function() w:Hide() end)
        -- Read only: typing puts the list back.
        box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(w.text or "") end end)
        scroll:SetScrollChild(box)
        w.box = box
        local select = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
        select:SetSize(120, 22)
        select:SetPoint("BOTTOMLEFT", 12, 10)
        select:SetText("Select all")
        select:SetScript("OnClick", function()
            box:SetFocus()
            box:HighlightText()
        end)
        tinsert(UISpecialFrames, "TradebookDevThanksFrame") -- ESC closes it
        thanksWin = w
    end
    local lines = Dev.ThanksLines(db().helpers)
    thanksWin.text = #lines > 0 and table.concat(lines, "\n") or "No data from other players yet."
    thanksWin.box:SetText(thanksWin.text)
    thanksWin:Show()
end

SLASH_TRADEBOOKDEV1 = "/tbdev"
SlashCmdList.TRADEBOOKDEV = function(msg)
    if (msg or ""):lower():match("^%s*count") then
        print("|cff33ff99Tradebook Dev|r " .. (countText() or "Nothing from other players since the last import."))
        return
    end
    local lower = (msg or ""):lower()
    if lower:match("^%s*thanks") then
        Dev.ShowThanks()
        return
    end
    if lower:match("^%s*heard%s+auto") then
        local d = db()
        d.heardAuto = d.heardAuto == false
        say("the heard window opens by itself when data comes in: " .. (d.heardAuto and "on" or "off"))
        return
    end
    if lower:match("^%s*heard") then
        Dev.ToggleHeard()
        return
    end
    if (msg or ""):lower():match("^%s*test") then
        Dev.ShowTest()
        return
    end
    if (msg or ""):lower():match("^%s*notify") then
        local d = db()
        d.notify = d.notify == false
        print("|cff33ff99Tradebook Dev|r notifications for other players' data: " .. (d.notify and "on" or "off"))
        return
    end
    Dev.Toggle()
end
