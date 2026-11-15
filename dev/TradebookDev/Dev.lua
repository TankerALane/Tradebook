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
    d.checked = d.checked or {} -- [npcID] = { name, at, how = "auto" | "manual" }: no vendor window
    if not d.factions then d.factions = Dev.DefaultFactions(UnitFactionGroup("player")) end
    return d
end

-- PURE. Factions shown by default: yours, Both and unknown.
function Dev.DefaultFactions(mine)
    return { Horde = mine ~= "Alliance", Alliance = mine == "Alliance", Both = true, Neither = false, Unknown = true }
end

-- PURE. Does row r pass filter settings f? (factions: [faction or "Unknown"] = shown;
-- within: yards or nil; recipeOnly; showChecked: also NPCs checked to have no vendor window.)
function Dev.Passes(r, f)
    if f.factions and f.factions[r.faction or "Unknown"] == false then return false end
    if f.recipeOnly and not r.recipe then return false end
    if f.within and not (r.distance and r.distance <= f.within) then return false end
    if r.checked and not f.showChecked then return false end
    return true
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

-- The unscanned vendor set (Questie's vendor lists load in batches), then done(set).
local lastSet
local function candidates(done)
    ns.Questie.VendorItems(function(index)
        local d = db()
        local scanned = { ns.db.vendors, ns.CommunityVendors }
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
                    faction = ns.Questie.NpcFaction and ns.Questie.NpcFaction(npc), checked = checked[npc] ~= nil }
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
    if r.friendly == false then lines[#lines + 1] = W.ColorText(W.RED, "Not friendly to you") end
    local c = r.checked and db().checked[r.npcID]
    if c then
        local how = c.how == "auto" and "you talked to it and no window opened" or "marked by you"
        lines[#lines + 1] = W.ColorText(W.GREY, ("Marked: %s (%s)"):format(MARK_TEXT[c.reason or "novendor"], how))
    end
    if r.place then lines[#lines + 1] = L.WAYPOINT_TARGET_CLICK end
    lines[#lines + 1] = "Box or right-click: mark as not a vendor / not there"
    return lines
end

---------------------------------------------------------------------------
-- Marked NPCs (TradebookDevDB.checked[npcID] = { name, at, how, reason }): ones Questie
-- calls vendors that you checked in game.
--   reason "novendor": talking to it opens no vendor or trainer window (marked automatically
--     when you talk to one and nothing opens, or by hand);
--   reason "missing": not there: you couldn't find it at its marked location (by hand).
-- Mark with the box at the left of a row or a right-click. Marked NPCs are hidden unless
-- "Show marked NPCs" is ticked.
---------------------------------------------------------------------------

function Dev.SetChecked(npc, name, on, how, reason)
    local list = db().checked
    if on then
        list[npc] = { name = name, at = time(), how = how, reason = reason or "novendor" }
    else
        list[npc] = nil
    end
    for _, r in ipairs(View.rows or {}) do
        if r.npcID == npc then r.checked = on or nil end
    end
    View:RefreshList()
end

-- The mark menu for row r (from its box or a right-click).
local function markMenu(owner, r)
    local name = r.name or ("NPC " .. r.npcID)
    local function set(reason)
        Dev.SetChecked(r.npcID, r.name, reason ~= nil, "manual", reason)
        say(reason and ("%s marked: %s."):format(name, MARK_TEXT[reason]) or ("%s unmarked."):format(name))
    end
    local current = r.checked and (db().checked[r.npcID] or {}).reason or nil
    if r.checked and not current then current = "novendor" end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(name)
        root:CreateRadio("Not a vendor (no vendor window)", function() return current == "novendor" end,
            function() set("novendor") end)
        root:CreateRadio("Not there (couldn't find it here)", function() return current == "missing" end,
            function() set("missing") end)
        root:CreateRadio("Not marked", function() return current == nil end, function() set(nil) end)
    end)
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
        -- It does have a window after all: forget an automatic check.
        local c = id and db().checked[id]
        if c and c.how == "auto" then Dev.SetChecked(id, c.name, false) end
    elseif event == "GOSSIP_CLOSED" then
        local t = talk
        C_Timer.After(1.5, function()
            if talk ~= t then return end
            talk = nil
            if not t or t.opened or db().checked[t.npc] then return end
            candidates(function(set)
                if not set[t.npc] then return end -- not an unscanned vendor
                Dev.SetChecked(t.npc, t.name, true, "auto")
                say(("%s has no vendor window: marked as not a vendor. Use its box in /tbdev to change it."):format(
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
    row.box:SetScript("OnClick", function(self) markMenu(self, self:GetParent().data) end)
    row.box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Mark this NPC", 1, 1, 1)
        GameTooltip:AddLine("Not a vendor (no vendor window), or not there (couldn't find it at its marked location).",
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    row.box:SetScript("OnLeave", GameTooltip_Hide)
    row.name = W.Text(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", row.box, "RIGHT", 4, 0)
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
        if mouse == "RightButton" then markMenu(self, self.data) else waypoint(self.data) end
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
            function() markMenu(row, r) end)
    end
    row.box:SetFrameLevel(row:GetFrameLevel() + 10)
    local reason = r.checked and ((db().checked[r.npcID] or {}).reason or "novendor") or nil
    row.box.mark:SetTexture(reason and MARK_ICON[reason] or nil)
    row.box.mark:SetShown(reason ~= nil)
    local name = r.name or ("NPC " .. r.npcID)
    row.name:SetText(r.checked and W.ColorText(W.GREY, name) or (r.recipe and W.ColorText(W.GOLD, name) or name))
    local parts = {}
    if reason then parts[#parts + 1] = W.ColorText(W.GREY, MARK_TEXT[reason]) end
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
        if d.within then return false end
        local def = Dev.DefaultFactions(UnitFactionGroup("player"))
        for k, v in pairs(def) do if (d.factions[k] ~= false) ~= v then return false end end
        return true
    end)
    filter:SetDefaultCallback(function()
        local d = db()
        for k, v in pairs(DEFAULTS) do d[k] = v end
        d.within = nil
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
        if Dev.Passes(r, d) then shown[#shown + 1] = r end
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

function Dev.Attach(tradebookNS)
    ns = tradebookNS
    startWatcher()
end

SLASH_TRADEBOOKDEV1 = "/tbdev"
SlashCmdList.TRADEBOOKDEV = function() Dev.Toggle() end
