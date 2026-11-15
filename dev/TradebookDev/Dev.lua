-- dev/TradebookDev/Dev.lua
-- Maintainer-only tools for Tradebook. Never packaged (.pkgmeta ignores dev/); linked into the
-- maintainer's AddOns folder only. Tradebook hands over its namespace at login
-- (Core/Init.lua: TradebookDev.Attach(ns)); without this addon nothing of it exists.
--
-- Unscanned tab: every vendor Questie knows, plus the bundled recipe vendors
-- (Data/RecipeVendors.lua), that nobody has scanned yet (not in your scans, the community
-- data, or what other players shared in game), nearest first. Click a row for a waypoint, and
-- to target and mark the vendor when it's nearby. /tbdev shows or hides the tab.

TradebookDev = {}
local Dev = TradebookDev

local ns -- Tradebook's namespace, from Attach
local View = {}
local BATCH = 60 -- vendors located per frame

local function db()
    TradebookDevDB = TradebookDevDB or {}
    local d = TradebookDevDB
    if d.showTab == nil then d.showTab = true end
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
                    friendly = place and place.friendly, place = place }
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
    if r.friendly == false then parts[#parts + 1] = W.ColorText(W.RED, "hostile") end
    row.mid:SetText(table.concat(parts, "  "))
    row.right:SetText(ns.Locations.DistanceText(r.distance) or W.ColorText(W.GREY, "far"))
end

function View:Build(parent)
    local W = ns.W
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    self.status = W.Text(f, "GameFontNormal")
    self.status:SetPoint("TOPLEFT", 14, -12)
    local refresh = W.Button(f, "Refresh", 90, 22)
    refresh:SetPoint("TOPRIGHT", -14, -8)
    refresh:SetScript("OnClick", function() View:Load() end)
    local d = db()
    local function check(label, key, anchor)
        local c = W.Check(f, label, function(v)
            db()[key] = v and true or false
            if key == "countHeard" then View:Load() else View:RefreshList() end
        end)
        c:SetPoint("RIGHT", anchor, "LEFT", -(c.text and c.text:GetStringWidth() or 100) - 16, 0)
        c:SetChecked(d[key])
        return c
    end
    local heard = check("Count players' shares as scanned", "countHeard", refresh)
    local recipe = check("Recipe vendors only", "recipeOnly", heard)
    check("Friendly only", "friendlyOnly", recipe)
    self.list = W.List(f, 20, createRow, initRow)
    self.list:SetPoint("TOPLEFT", 8, -40)
    self.list:SetPoint("BOTTOMRIGHT", -26, 8)
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

function View:Show()
    -- Positions depend on where you stand: rebuild on each visit.
    self:Load()
end

function View:Refresh() end

---------------------------------------------------------------------------
-- attach and toggle
---------------------------------------------------------------------------

function Dev.Attach(tradebookNS)
    ns = tradebookNS
    ns.UI.RegisterView("devUnscanned", View)
    ns.UI.AddTab("devUnscanned", "Unscanned", "devUnscanned", function() return db().showTab end,
        "Dev: vendors nobody has scanned yet, nearest first. /tbdev hides this tab.")
end

SLASH_TRADEBOOKDEV1 = "/tbdev"
SlashCmdList.TRADEBOOKDEV = function()
    if not ns then say("Tradebook isn't loaded.") return end
    local d = db()
    d.showTab = not d.showTab
    ns.UI.LayoutTabs()
    if not d.showTab and ns.UI.CurrentView() == View then ns.UI.SelectTab(ns.Professions.list[1].id) end
    say(d.showTab and "Unscanned tab shown." or "Unscanned tab hidden.")
end
