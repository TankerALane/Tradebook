-- UI/VendorsView.lua
-- The Vendors tab: search any item and see which vendors sell it (Core/VendorDB.lua), nearest
-- first. Each item expands to its 5 closest vendors (price, zone, distance; click for a
-- waypoint) with "See all" for the rest. Filters: zone, friendly to you, this continent, item
-- type, how it's paid for, and where the data came from. "Share your scans" opens /tb share.

local _, ns = ...
local L, W, Compat = ns.L, ns.W, ns.Compat

local View = {}
ns.UI.RegisterView("vendors", View)

local TOP_N = 5
local ITEM_CLASSES = { 7, 5, 0, 9, 1, 2, 4, 6, 11, 15 } -- trade goods first: the common reason to look
local DEFAULTS = { friendlyOnly = true }

local function filters()
    local s = ns.db.settings
    if not s.vendorFilters then
        s.vendorFilters = {}
        for k, v in pairs(DEFAULTS) do s.vendorFilters[k] = v end
    end
    return s.vendorFilters
end

local function className(id)
    return Compat.Call("C_Item.GetItemClassInfo", id) or Compat.Call("GetItemClassInfo", id) or ("#" .. id)
end

local SOURCE_TEXT = function(source)
    return ({ scanned = L.VENDOR_SRC_SCANNED, community = L.VENDOR_SRC_COMMUNITY, players = L.VENDOR_SRC_PLAYERS,
        questie = L.VENDOR_SRC_QUESTIE })[source] or source
end

---------------------------------------------------------------------------
-- rows: { kind = "item" | "vendor" | "more", ... }
---------------------------------------------------------------------------

local function priceText(row)
    local text = ns.Merchants.PriceText({ price = row.price, cost = row.cost })
    if text == "" then return W.ColorText(W.GREY, L.VENDOR_NO_PRICE) end
    -- Questie rows already say "Questie", which means a base price; the tooltip explains it.
    if row.price and not row.priceSeen and not row.cost and row.source ~= "questie" then
        text = text .. " " .. W.ColorText(W.GREY, L.VENDOR_BASE_PRICE)
    end
    return text
end

local function placeText(row)
    local parts = {}
    if row.zone then parts[#parts + 1] = row.zone end
    if row.waypoint and row.waypoint.x then parts[#parts + 1] = ("(%.0f, %.0f)"):format(row.waypoint.x, row.waypoint.y) end
    local d = ns.Locations.DistanceText(row.distance)
    if d then parts[#parts + 1] = W.ColorText(W.GREY, d) end
    if row.friendly == false then parts[#parts + 1] = W.ColorText(W.RED, L.VENDOR_HOSTILE) end
    return table.concat(parts, "  ")
end

local function setWaypoint(row)
    local w = row.waypoint
    if not w then return end
    if w.map then ns.Waypoints.SetOnMap(w.map, w.x, w.y, row.name) else ns.Waypoints.Set(w.areaID, w.x, w.y, row.name) end
end

-- Tooltip lines for a vendor row (also used by its target button, which covers the row).
local function vendorTooltip(r)
    local lines = { r.name or ("NPC " .. r.npcID), SOURCE_TEXT(r.source) }
    if r.source == "players" then
        lines[#lines + 1] = (r.agree or 1) >= 2 and L.VENDOR_PLAYERS_AGREE:format(r.agree) or L.VENDOR_PLAYERS_ONE
    end
    if r.seenAt then lines[#lines + 1] = L.VENDOR_SEEN_AGO:format(W.Ago(r.seenAt)) end
    if r.stock and r.stock >= 0 then lines[#lines + 1] = L.VENDOR_LIMITED_TIP:format(r.stock) end
    if r.price and not r.priceSeen then lines[#lines + 1] = L.VENDOR_BASE_PRICE_TIP end
    if r.waypoint then lines[#lines + 1] = L.WAYPOINT_TARGET_CLICK end
    return lines
end

local function createRow(row)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.toggle = row:CreateTexture(nil, "ARTWORK")
    row.toggle:SetSize(14, 14)
    row.toggle:SetPoint("LEFT", 4, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.name = W.Text(row, "GameFontHighlight")
    row.name:SetWordWrap(false)
    row.mid = W.Text(row, "GameFontHighlightSmall")
    row.mid:SetWordWrap(false)
    row.right = W.Text(row, "GameFontHighlightSmall", "RIGHT")
    row.right:SetPoint("RIGHT", -6, 0)
    row.right:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
        local d = self.data
        if d.kind == "item" then
            View.expanded[d.itemID] = not View.expanded[d.itemID] or nil
            View:RefreshList()
        elseif d.kind == "more" then
            View.showAll[d.itemID] = true
            View:RefreshList()
        elseif d.kind == "vendor" then
            setWaypoint(d.row)
        end
    end)
    row:SetScript("OnEnter", function(self)
        local d = self.data
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if d.kind == "item" then
            GameTooltip:SetItemByID(d.itemID)
        elseif d.kind == "vendor" then
            for i, line in ipairs(vendorTooltip(d.row)) do
                if i == 1 then GameTooltip:SetText(line, 1, 1, 1) else GameTooltip:AddLine(line, 0.7, 0.7, 0.7, true) end
            end
        else
            GameTooltip:SetText(L.VENDOR_SEE_ALL_TIP, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
end

local function initRow(row, data)
    row.data = data
    -- Rows are reused while scrolling: drop this row's old target button first.
    ns.TargetButtons.Release(row)
    row.name:ClearAllPoints()
    row.mid:ClearAllPoints()
    if data.kind == "item" then
        row.toggle:Show()
        row.toggle:SetAtlas(View.expanded[data.itemID] and "Campaign_HeaderIcon_Open" or "Campaign_HeaderIcon_Closed")
        row.icon:Show()
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", 22, 0)
        row.icon:SetTexture(Compat.Call("C_Item.GetItemIconByID", data.itemID) or 134400)
        row.name:SetFontObject("GameFontHighlight")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetWidth(240)
        local _, _, quality = Compat.ItemInfo(data.itemID)
        local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        row.name:SetText(data.name)
        if qc then row.name:SetTextColor(qc.r, qc.g, qc.b) else row.name:SetTextColor(1, 1, 1) end
        local best = data.best
        row.mid:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
        row.mid:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
        row.mid:SetText((best.name or "?") .. "  " .. W.ColorText(W.GREY, placeText(best)))
        row.right:SetText(priceText(best) .. "  " .. W.ColorText(W.GREY, L.VENDOR_COUNT:format(#data.vendors)))
        return
    end
    row.toggle:Hide()
    row.icon:Hide()
    row.name:SetFontObject("GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 52, 0)
    row.name:SetWidth(220)
    if data.kind == "more" then
        row.name:SetText(W.ColorText(W.GOLD, L.VENDOR_SEE_ALL:format(data.rest)))
        row.mid:SetText("")
        row.right:SetText("")
        return
    end
    local r = data.row
    -- Click: waypoint, and target + purple diamond when the vendor is nearby (out of combat).
    if r.name and r.waypoint then
        ns.TargetButtons.Attach(row, row, r.name, function() setWaypoint(r) end, vendorTooltip(r))
    end
    row.name:SetText(r.name or ("NPC " .. r.npcID))
    row.name:SetTextColor(1, 1, 1)
    row.mid:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.mid:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
    row.mid:SetText(placeText(r))
    -- Scanned vendors (yours or the community's) carry no tag; vendors only QuestieDB lists
    -- (a good source, but nobody has scanned them yet) say "Questie"; vendors only one other
    -- player shared say "(unconfirmed)" until a second player agrees.
    local tag = r.source == "questie" and L.VENDOR_SRC_QUESTIE
        or (r.source == "players" and (r.agree or 1) < 2 and L.DROP_UNCONFIRMED) or nil
    row.right:SetText(priceText(r) .. (tag and ("  " .. W.ColorText(W.GREY, tag)) or ""))
end

---------------------------------------------------------------------------
-- filters
---------------------------------------------------------------------------

local function filtersAreDefault()
    local f = filters()
    for k, v in pairs(f) do
        if v ~= (DEFAULTS[k] or nil) and v ~= false then return false end
    end
    for k, v in pairs(DEFAULTS) do if f[k] ~= v then return false end end
    return true
end

local function resetFilters()
    ns.db.settings.vendorFilters = nil
    View:RefreshList()
end

local function buildFilterMenu(_, root)
    local f = filters()
    local function check(text, key)
        root:CreateCheckbox(text, function() return f[key] end, function()
            f[key] = not f[key] or nil
            View:RefreshList()
        end)
    end
    local function radios(parent, list, key)
        for _, opt in ipairs(list) do
            parent:CreateRadio(opt.text, function() return f[key] == opt.value end, function()
                f[key] = opt.value
                View:RefreshList()
            end)
        end
    end
    check(L.VENDOR_FILTER_FRIENDLY, "friendlyOnly")
    check(L.VENDOR_FILTER_CONTINENT, "thisContinent")
    -- Zone: the zones the current results are in.
    local zone = root:CreateButton(L.VENDOR_FILTER_ZONE)
    local zones = { { text = L.VENDOR_ANY, value = nil } }
    for _, z in ipairs(View.zones or {}) do zones[#zones + 1] = { text = z, value = z } end
    local listed = false
    for _, z in ipairs(View.zones or {}) do if z == f.zone then listed = true end end
    if f.zone and not listed then zones[#zones + 1] = { text = f.zone, value = f.zone } end
    radios(zone, zones, "zone")
    local class = root:CreateButton(L.VENDOR_FILTER_TYPE)
    local classes = { { text = L.VENDOR_ANY, value = nil } }
    for _, id in ipairs(ITEM_CLASSES) do classes[#classes + 1] = { text = className(id), value = id } end
    radios(class, classes, "class")
    local pay = root:CreateButton(L.VENDOR_FILTER_PAYMENT)
    radios(pay, { { text = L.VENDOR_ANY, value = nil }, { text = L.VENDOR_PAY_GOLD, value = "gold" },
        { text = L.VENDOR_PAY_TOKENS, value = "tokens" } }, "payment")
    local src = root:CreateButton(L.VENDOR_FILTER_SOURCE)
    radios(src, { { text = L.VENDOR_ANY, value = nil }, { text = L.VENDOR_SRC_SCANNED, value = "scanned" },
        { text = L.VENDOR_SRC_COMMUNITY, value = "community" }, { text = L.VENDOR_SRC_PLAYERS, value = "players" },
        { text = L.VENDOR_SRC_QUESTIE, value = "questie" } }, "source")
end

---------------------------------------------------------------------------
-- view
---------------------------------------------------------------------------

function View:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    self.expanded, self.showAll = {}, {}
    self.title = W.Text(f, "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 12, -10)
    self.title:SetText(L.VENDORS_TITLE)
    self.search = W.SearchBox(f, 240, function(text)
        View.text = text
        View:RefreshList()
    end)
    self.search:SetPoint("LEFT", self.title, "RIGHT", 18, 0)
    if self.search.Instructions then self.search.Instructions:SetText(L.VENDOR_SEARCH) end
    self.filterBtn = CreateFrame("DropdownButton", nil, f, "WowStyle1FilterDropdownTemplate")
    self.filterBtn:SetWidth(90)
    self.filterBtn:SetPoint("LEFT", self.search, "RIGHT", 10, 0)
    self.filterBtn:SetDefaultCallback(resetFilters)
    self.filterBtn:SetIsDefaultCallback(filtersAreDefault)
    self.filterBtn:SetupMenu(buildFilterMenu)
    self.share = W.Button(f, L.SHARE_BUTTON, 140, 22)
    self.share:SetPoint("TOPRIGHT", -12, -8)
    self.share:SetScript("OnClick", function() ns.Share.Show() end)
    W.Tooltip(self.share, { L.SHARE_BUTTON, L.SHARE_TIP })
    self.status = W.Text(f, "GameFontDisableSmall")
    self.status:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -8)
    self.status:SetPoint("RIGHT", -12, 0)
    self.list = W.List(f, 22, createRow, initRow)
    self.list:SetPoint("TOPLEFT", 8, -56)
    self.list:SetPoint("BOTTOMRIGHT", -22, 8)
    self.empty = W.Text(f, "GameFontDisable", "CENTER")
    self.empty:SetPoint("TOP", 0, -110)
    self.empty:SetWidth(520)
end

function View:Show()
    -- QuestieDB's vendor lists load a batch per frame the first time.
    ns.VendorDB.Load(function() if View.frame and View.frame:IsShown() then View:RefreshList() end end)
    self:Refresh()
end

function View:Refresh()
    self:RefreshList()
end

function View:RefreshList()
    if not self.frame then return end
    local f = filters()
    local opts = { text = self.text, zone = f.zone, friendlyOnly = f.friendlyOnly, thisContinent = f.thisContinent,
        payment = f.payment, source = f.source, class = f.class, limit = 300 }
    local results, zones = ns.VendorDB.Search(opts)
    self.zones = zones
    local rows = {}
    for _, item in ipairs(results) do
        rows[#rows + 1] = { kind = "item", itemID = item.itemID, name = item.name, vendors = item.vendors, best = item.best }
        if self.expanded[item.itemID] then
            local n = self.showAll[item.itemID] and #item.vendors or math.min(TOP_N, #item.vendors)
            for i = 1, n do rows[#rows + 1] = { kind = "vendor", row = item.vendors[i], itemID = item.itemID } end
            if n < #item.vendors then
                rows[#rows + 1] = { kind = "more", itemID = item.itemID, rest = #item.vendors - n }
            end
        end
    end
    self.list:SetItems(rows)
    local scanned, community, questie, players = ns.VendorDB.Stats()
    local questieText = questie and L.VENDOR_STATUS_QUESTIE:format(questie)
        or (ns.Questie.Available() and L.VENDOR_STATUS_QUESTIE_LOADING or L.VENDOR_STATUS_NO_QUESTIE)
    local playersText = (players or 0) > 0 and ("  " .. L.VENDOR_STATUS_PLAYERS:format(players)) or ""
    self.status:SetText(L.VENDOR_STATUS:format(scanned, community) .. playersText .. "  " .. questieText)
    if #rows > 0 then
        self.empty:SetText("")
    elseif (self.text or "") == "" and not f.zone then
        self.empty:SetText(L.VENDOR_EMPTY_PROMPT)
    else
        self.empty:SetText(L.VENDOR_NONE)
    end
end
