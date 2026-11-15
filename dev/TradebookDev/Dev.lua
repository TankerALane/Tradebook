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
    if d.friendlyOnly == nil then d.friendlyOnly = true end
    if d.countHeard == nil then d.countHeard = true end
    return d
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

-- Locate every candidate (a batch per frame), then call done(rows) sorted nearest first.
local building
local function build(done)
    if building then return end
    building = true
    ns.Questie.VendorItems(function(index)
        local d = db()
        local scanned = { ns.db.vendors, ns.CommunityVendors }
        if d.countHeard and ns.Net then scanned[#scanned + 1] = ns.Net.HeardVendors() end
        local set = Dev.Unscanned(index, ns.RecipeVendors, scanned)
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
                    faction = ns.Questie.NpcFaction and ns.Questie.NpcFaction(npc) }
            end
            i = i + BATCH
            if i <= #ids then
                C_Timer.After(0, step)
                return
            end
            table.sort(rows, function(a, b)
                if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
                if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
                return a.npcID < b.npcID
            end)
            building = false
            done(rows)
        end
        step()
    end)
end

---------------------------------------------------------------------------
-- view
---------------------------------------------------------------------------

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
    if r.place then lines[#lines + 1] = L.WAYPOINT_TARGET_CLICK end
    return lines
end

local function createRow(row)
    local W = ns.W
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.name = W.Text(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", 6, 0)
    row.name:SetWidth(240)
    row.name:SetWordWrap(false)
    row.mid = W.Text(row, "GameFontHighlightSmall")
    row.mid:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.mid:SetWordWrap(false)
    row.right = W.Text(row, "GameFontHighlightSmall", "RIGHT")
    row.right:SetPoint("RIGHT", -6, 0)
    row.right:SetWordWrap(false)
    row.mid:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
    row:SetScript("OnClick", function(self) waypoint(self.data) end)
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
        ns.TargetButtons.Attach(row, row, r.name, function() waypoint(r) end, tooltipFor(r))
    end
    local name = r.name or ("NPC " .. r.npcID)
    row.name:SetText(r.recipe and W.ColorText(W.GOLD, name) or name)
    local parts = {}
    if r.sub then parts[#parts + 1] = W.ColorText(W.GREY, "<" .. r.sub .. ">") end
    if r.zone then parts[#parts + 1] = r.zone end
    if r.place and r.place.x then parts[#parts + 1] = ("(%.0f, %.0f)"):format(r.place.x, r.place.y) end
    row.mid:SetText(table.concat(parts, "  "))
    row.right:SetText(factionText(r.faction) .. "   " .. (ns.Locations.DistanceText(r.distance) or W.ColorText(W.GREY, "far")))
end

function View:Build(parent)
    local W = ns.W
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    -- Row 1: status | Refresh.  Row 2: the filter checkboxes, left to right.
    local refresh = W.Button(f, "Refresh", 80, 22)
    refresh:SetPoint("TOPRIGHT", -8, -4)
    refresh:SetScript("OnClick", function() View:Load() end)
    self.status = W.Text(f, "GameFontNormal")
    self.status:SetPoint("TOPLEFT", 10, -9)
    self.status:SetPoint("RIGHT", refresh, "LEFT", -8, 0)
    self.status:SetWordWrap(false)
    local d = db()
    local prev
    local function check(label, key)
        local c = W.Check(f, label, function(v)
            db()[key] = v and true or false
            if key == "countHeard" then View:Load() else View:RefreshList() end
        end)
        if prev then
            c:SetPoint("LEFT", prev, "RIGHT", (prev.text and prev.text:GetStringWidth() or 100) + 14, 0)
        else
            c:SetPoint("TOPLEFT", 6, -30)
        end
        c:SetChecked(d[key])
        prev = c
        return c
    end
    check("Friendly only", "friendlyOnly")
    check("Recipe vendors only", "recipeOnly")
    check("Players' shares count as scanned", "countHeard")
    self.list = W.List(f, 20, createRow, initRow)
    self.list:SetPoint("TOPLEFT", 4, -58)
    self.list:SetPoint("BOTTOMRIGHT", -22, 4)
end

function View:RefreshList()
    if not self.frame then return end
    local d = db()
    local shown = {}
    for _, r in ipairs(self.rows or {}) do
        if not (d.friendlyOnly and r.friendly == false) and not (d.recipeOnly and not r.recipe) then
            shown[#shown + 1] = r
        end
    end
    self.list:SetItems(shown)
    if not ns.Questie.Available() then
        self.status:SetText("Needs Questie for vendor positions. Recipe vendors without Questie: no distance.")
    else
        self.status:SetText(("Unscanned vendors: %d shown of %d (nearest first)"):format(#shown, #(self.rows or {})))
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
    if win.SetResizeBounds then win:SetResizeBounds(420, 220, 1200, 900) end
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
end

SLASH_TRADEBOOKDEV1 = "/tbdev"
SlashCmdList.TRADEBOOKDEV = function() Dev.Toggle() end
