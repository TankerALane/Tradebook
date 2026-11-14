-- UI/Details.lua
-- Right-hand recipe details: result item, who knows it, reagents (with an expandable
-- tree of reagents made by other recipes), sources, and the craft controls.

local _, ns = ...
local L, W, Compat = ns.L, ns.W, ns.Compat
local Recipes, Reagents = ns.Recipes, ns.Reagents

local Details = {}
ns.Details = Details

-- Window width outside the details pane: insets plus the recipe list column (ProfessionView).
local DETAILS_MARGIN = 6 + 8 + 330 + 22 + 8 + 6
local LINE_H = 22
local LARGE_LINE_H = 42 -- reagent rows
local LARGE_ICON = 36   -- about the size of the default window's reagent slots
local Pane = {}
Pane.__index = Pane

---------------------------------------------------------------------------
-- a simple vertical line layout inside a scroll frame
---------------------------------------------------------------------------

function Pane:Line()
    self.used = self.used + 1
    local line = self.lines[self.used]
    if not line then
        line = CreateFrame("Button", nil, self.content)
        line:SetHeight(LINE_H)
        line.item = W.ItemButton(line, 18)
        line.toggle = CreateFrame("Button", nil, line)
        line.toggle:SetSize(14, 14)
        line.toggle:SetNormalAtlas("Professions-Slot-Plus")
        line.text = W.Text(line, "GameFontHighlightSmall")
        line.text:SetWordWrap(false)
        line.right = W.Text(line, "GameFontHighlightSmall", "RIGHT")
        line.right:SetPoint("RIGHT", -4, 0)
        line.right:SetWordWrap(false)
        line:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        self.lines[self.used] = line
    end
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -self.y)
    line:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
    line.item:Hide()
    line.toggle:Hide()
    line.text:SetFontObject("GameFontHighlightSmall")
    line.text:SetTextColor(1, 1, 1)
    line.right:SetText("")
    line.right:SetFontObject("GameFontHighlightSmall")
    line.right:ClearAllPoints()
    line.right:SetPoint("RIGHT", -4, 0)
    line.right:SetJustifyH("RIGHT")
    line:SetScript("OnClick", nil)
    line:SetScript("OnEnter", nil)
    line:SetScript("OnLeave", nil)
    line:GetHighlightTexture():SetAlpha(0)
    line:Show()
    return line
end

-- Add a line: { indent, itemID, text, right, color, font, onClick, toggle = bool|nil, expanded, onToggle,
-- tooltip, large = true for a big icon row (reagents, like the default window's slots),
-- target = NPC name: clicking also targets it when nearby (secure button, out of combat),
-- rightAt = x: put the right value left-aligned at x instead of at the right edge }
function Pane:Add(o)
    local line = self:Line()
    local height = o.large and LARGE_LINE_H or LINE_H
    line:SetHeight(height)
    self.y = self.y + height
    local x = (o.indent or 0) * 16
    if o.toggle ~= nil then
        line.toggle:Show()
        line.toggle:ClearAllPoints()
        line.toggle:SetPoint("LEFT", x, 0)
        line.toggle:SetNormalAtlas(o.expanded and "Campaign_HeaderIcon_Open" or "Professions-Slot-Plus")
        line.toggle:SetScript("OnClick", o.onToggle)
    end
    -- Large rows always keep the "+" column so their icons line up with or without it.
    if o.toggle ~= nil or o.large then x = x + 16 end
    if o.itemID then
        local size = o.large and LARGE_ICON or 18
        line.item:SetSize(size, size)
        line.item:SetSlotStyle(o.large == true)
        line.item:Show()
        line.item:ClearAllPoints()
        line.item:SetPoint("LEFT", x, 0)
        line.item:SetItem(o.itemID)
        x = x + size + 6
    end
    line.text:ClearAllPoints()
    line.text:SetPoint("LEFT", x, 0)
    line.text:SetPoint("RIGHT", line.right, "LEFT", -6, 0)
    if o.font then line.text:SetFontObject(o.font) end
    if o.large then line.right:SetFontObject("GameFontHighlight") end
    line.text:SetText(o.text or "")
    if o.color then line.text:SetTextColor(o.color:GetRGB()) end
    line.right:SetText(o.right or "")
    -- The right column (place and distance) always fits on one line; the name gets "..."
    -- instead when space runs out.
    local fs = line.right
    local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
    fs:SetWidth(math.ceil(w) + 2)
    if o.rightAt then
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", o.rightAt, 0)
        fs:SetJustifyH("LEFT")
    end
    if o.onClick then
        line:GetHighlightTexture():SetAlpha(1)
        line:SetScript("OnClick", o.onClick)
    end
    if o.tooltip then W.Tooltip(line, o.tooltip) end
    if o.target and o.onClick then
        ns.TargetButtons.Attach(self, line, o.target, o.onClick,
            o.targetTooltip or o.tooltip)
    end
    return line
end

function Pane:Gap(h)
    self.y = self.y + (h or 6)
end

function Pane:Begin()
    self.used, self.y = 0, 0
    ns.TargetButtons.Release(self)
end

function Pane:Finish()
    for i = self.used + 1, #self.lines do self.lines[i]:Hide() end
    self.content:SetHeight(math.max(1, self.y))
end

-- A scrolling line pane (Add/Gap/Begin/Finish) inside `parent`, for other windows.
-- Fills `parent` (leave room for a scroll bar on the right).
function Details.NewLinePane(parent)
    local self = setmetatable({ lines = {}, used = 0, y = 0, expanded = {} }, Pane)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -14, 0)
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    self.content = CreateFrame("Frame", nil, scroll)
    self.content:SetSize(1, 1)
    scroll:SetScrollChild(self.content)
    scroll:SetScript("OnSizeChanged", function(_, w) self.content:SetWidth(w) end)
    ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
    self.scroll = scroll
    return self
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function Details.Create(parent)
    local self = setmetatable({ lines = {}, used = 0, y = 0, expanded = {} }, Pane)
    local f = CreateFrame("Frame", nil, parent)
    self.frame = f

    -- Header: result item, name, makes N, favorite/pin.
    self.output = W.ItemButton(f, 42)
    self.output:SetPoint("TOPLEFT", 2, -2)
    self.output:SetSlotStyle(true)
    self.title = W.Text(f, "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", self.output, "TOPRIGHT", 10, -2)
    self.title:SetPoint("RIGHT", f, "RIGHT", -96, 0)
    self.title:SetWordWrap(false)
    self.sub = W.Text(f, "GameFontHighlightSmall")
    self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
    self.sub:SetPoint("RIGHT", f, "RIGHT", -96, 0)

    self.favBtn = CreateFrame("Button", nil, f)
    self.favBtn:SetSize(22, 22)
    self.favBtn:SetPoint("TOPRIGHT", -2, -2)
    self.favBtn.tex = self.favBtn:CreateTexture(nil, "ARTWORK")
    self.favBtn.tex:SetAllPoints()
    self.favBtn.tex:SetAtlas("auctionhouse-icon-favorite")
    self.favBtn:SetScript("OnClick", function()
        local id = self.recipeID
        if not id then return end
        ns.db.favorites[id] = not ns.db.favorites[id] or nil
        ns.UI.Refresh()
    end)
    W.Tooltip(self.favBtn, function() return ns.db.favorites[self.recipeID] and L.UNFAVORITE or L.FAVORITE end)

    self.pinBtn = W.Button(f, L.PIN, 56, 20)
    self.pinBtn:SetPoint("RIGHT", self.favBtn, "LEFT", -6, 0)
    self.pinBtn:SetScript("OnClick", function()
        local id = self.recipeID
        if not id then return end
        if ns.db.pinned[id] then ns.db.pinned[id] = nil else ns.db.pinned[id] = self:Quantity() end
        ns.UI.Refresh() -- moves it into/out of the Pinned group in the list
    end)

    -- Scrolling body.
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", self.output, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 64)
    local bar = CreateFrame("EventFrame", nil, f, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    self.content = CreateFrame("Frame", nil, scroll)
    self.content:SetSize(1, 1)
    scroll:SetScrollChild(self.content)
    scroll:SetScript("OnSizeChanged", function(_, w) self.content:SetWidth(w) end)
    ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
    self.scroll = scroll

    -- Craft bar.
    self.status = W.Text(f, "GameFontNormalSmall")
    self.status:SetPoint("BOTTOMLEFT", 2, 36)
    self.status:SetPoint("RIGHT", f, "RIGHT", -2, 0)

    self.craftAll = W.Button(f, L.CRAFT_ALL, 90, 22)
    self.craftAll:SetPoint("BOTTOMRIGHT", -2, 4)
    self.qty = CreateFrame("EditBox", nil, f, "NumericInputSpinnerTemplate")
    self.qty:SetPoint("RIGHT", self.craftAll, "LEFT", -34, 0)
    self.qty:SetMinMaxValues(1, 999)
    self.qty:SetValue(1)
    self.qty:SetOnValueChangedCallback(function() self:RefreshReagents() end)
    self.craft = W.Button(f, L.CRAFT, 80, 22)
    self.craft:SetPoint("RIGHT", self.qty, "LEFT", -30, 0)
    -- Each click makes exactly one call (Phase 0: crafting and opening need a hardware event).
    -- If only the profession is closed, the button reads "Open <profession>" and opens it.
    self.craft:SetScript("OnClick", function()
        ns.Crafting.Click(self.recipeID, self:Quantity())
        C_Timer.After(0.3, function() self:Refresh() end)
    end)
    self.craftAll:SetScript("OnClick", function()
        local _, max = ns.Crafting.State(self.recipeID)
        if max and max > 0 then ns.Crafting.Craft(self.recipeID, max) end
        C_Timer.After(0.2, function() self:Refresh() end)
    end)

    self.defaultBtn = W.Button(f, L.OPEN_IN_DEFAULT, 180, 22)
    self.defaultBtn:SetPoint("BOTTOMLEFT", 2, 4)
    self.defaultBtn:SetScript("OnClick", function()
        if self.recipeID then ns.Crafting.OpenInDefault(self.recipeID) end
    end)
    self.shopBtn = W.Button(f, L.SHOPPING_LIST, 120, 22)
    self.shopBtn:SetPoint("LEFT", self.defaultBtn, "RIGHT", 4, 0)
    self.shopBtn:SetScript("OnClick", function(btn)
        MenuUtil.CreateContextMenu(btn, function(_, root)
            root:CreateButton(L.SHOPPING_LIST, function()
                ns.Shopping.Show({ { recipeID = self.recipeID, times = self:Quantity() } })
            end)
            root:CreateButton(L.SHOPPING_PINNED, function() ns.Shopping.ShowPinned() end)
        end)
    end)
    return self
end

function Pane:Quantity()
    return math.max(1, tonumber(self.qty:GetValue()) or 1)
end

---------------------------------------------------------------------------
-- content
---------------------------------------------------------------------------

function Pane:SetRecipe(recipeID, charKey)
    if self.recipeID ~= recipeID then
        self.expanded = {}
        if self.qty then self.qty:SetValue(1) end
    end
    self.recipeID, self.charKey = recipeID, charKey
    self:Refresh()
end

local function knownByText(keys)
    local names = {}
    for i, key in ipairs(keys) do
        if i > 6 then
            names[#names + 1] = "+" .. (#keys - 6)
            break
        end
        local c = ns.db.characters[key]
        names[#names + 1] = c and W.ClassName(c) or key
    end
    return table.concat(names, ", ")
end

-- "Made by <recipe> (<profession>)" line for a reagent maker, with who knows it,
-- followed by that maker's own reagent sub-tree.
function Pane:AddMaker(maker, indent, path)
    local r = ns.db.recipes[maker.recipeID]
    local prof = ns.Professions.Get(maker.skillLineID)
    local profName = prof and (L[prof.name] or prof.name) or "?"
    local who = Recipes.KnownBy(ns.db, maker.recipeID)
    self:Add({ indent = indent, text = L.MADE_BY:format((r and r.n or "?") .. " (" .. profName .. ")"),
        right = #who > 0 and knownByText(who) or W.ColorText(W.GREY, L.NOBODY),
        onClick = function() ns.UI.OpenRecipe(maker.recipeID, nil, true) end })
    self:AddTree(maker.children, indent + 1, path .. "." .. maker.recipeID)
end

function Pane:AddTree(nodes, indent, path)
    for i, node in ipairs(nodes) do
        local key = path .. "." .. i
        local name = Compat.ItemInfo(node.itemID) or ("item:" .. node.itemID)
        if #node.makers > 0 then
            self:Add({ indent = indent, itemID = node.itemID, text = name, right = "x" .. node.count,
                toggle = true, expanded = self.expanded[key],
                onToggle = function() self.expanded[key] = not self.expanded[key]; self:Refresh() end })
            if self.expanded[key] then
                for _, maker in ipairs(node.makers) do self:AddMaker(maker, indent + 1, key) end
            end
        end
    end
end

-- Reagent tooltip: this character's bags/bank, then (no header) every other character who has
-- some (first name, class colour, bags + bank from their last login / bank visit).
-- "Name  (lvl 12-14)" for mobs.
local function levelText(e)
    if not e.minLevel then return "" end
    if e.maxLevel and e.maxLevel ~= e.minLevel then return "  " .. L.LEVEL_RANGE:format(e.minLevel, e.maxLevel) end
    return "  " .. L.LEVEL_ONE:format(e.minLevel)
end

-- "Stormwind City (52, 47)  ·  120 yd"
local function placeText(e)
    local text = L.PLACE:format(ns.Questie.ZoneName(e.areaID), e.x, e.y)
    local d = ns.Locations.DistanceText(e.distance)
    if d then text = text .. "  " .. W.ColorText(W.GREY, d) end
    return text
end
Details.PlaceText = placeText

-- "Learnable now" / "15 more skill (190)" / "Train Artisan first (190)" for Recipes.CouldLearn.
function Details.CouldLearnText(cl)
    if cl.status == "now" then return W.ColorText(W.GREEN, L.COULD_NOW) end
    if cl.status == "skill" then return W.ColorText(W.GOLD, L.COULD_MORE:format(cl.required - cl.rank, cl.required)) end
    if cl.status == "rank" then
        local step = ns.RankUps.byCap[cl.max]
        local rank = step and L.RANK_NAMES[step.rank]
        return W.ColorText(W.RED, rank and L.COULD_TRAIN:format(rank, cl.required) or L.COULD_NEEDS:format(cl.required))
    end
    return W.ColorText(W.GREY, L.COULD_UNKNOWN)
end


-- Where to get a material (QuestieDB): nearest vendors, mobs and gathering nodes; click a
-- line to set a waypoint.
function Pane:AddWhereToGet(itemID, indent)
    local data = ns.Questie.WhereToGet(itemID)
    if not data then return end
    local function section(title, list, nameOf, isNpc)
        if #list == 0 then return end
        self:Add({ indent = indent, text = title, color = W.GOLD })
        for _, e in ipairs(list) do
            local hint = isNpc and L.WAYPOINT_TARGET_CLICK or L.WAYPOINT_CLICK
            self:Add({ indent = indent + 1, text = nameOf(e), right = placeText(e),
                onClick = function() ns.Waypoints.Set(e.areaID, e.x, e.y, e.name) end,
                target = isNpc and e.name or nil,
                tooltip = e.sub and { e.name, e.sub, hint } or { e.name, hint } })
        end
    end
    section(L.SOLD_BY, data.vendors, function(e) return e.name end, true)
    section(L.DROPPED_BY, data.drops, function(e) return e.name .. levelText(e) end, true)
    section(L.GATHERED_FROM, data.objects, function(e) return e.name end, false)
    if not data.located then self:Add({ indent = indent, text = L.WHERE_NO_POSITION, color = W.GREY }) end
end

local INDENT = "    "
local SKILLUP_VALUE_X = 184 -- fallback: the Shopping list button's left edge (2 + 180 + 4 - 2)
function Pane:ReagentTooltip(c, name, item)
    local lines = { name, L.IN_BAGS:format(item.bags), L.IN_BANK:format(item.bank) }
    if item.fetch > 0 then lines[#lines + 1] = L.BANK_FETCH end
    local where = ns.Questie.HasSources(item.itemID) and ns.Questie.WhereToGet(item.itemID)
    if where and #where.vendors > 0 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = W.ColorText(W.GOLD, L.SOLD_BY .. ":")
        for _, e in ipairs(where.vendors) do lines[#lines + 1] = { INDENT .. e.name, placeText(e) } end
    end
    if ns.Prices.Available() then
        lines[#lines + 1] = " "
        for _, p in ipairs(ns.Prices.TooltipLines(item.itemID)) do lines[#lines + 1] = p end
    end
    local others = Reagents.OnOtherCharacters(ns.db, item.itemID, c and c.key)
    if #others > 0 then
        lines[#lines + 1] = " "
        for _, o in ipairs(others) do
            local who = Compat.ClassColor(o.class):WrapTextInColorCode(o.name)
            lines[#lines + 1] = L.CHAR_HAS:format(who, o.total)
        end
    end
    return lines
end

-- Cost section (Auctionator): materials at their cheapest known price, what the result sells
-- for at auction, and the profit. Hidden without Auctionator.
function Pane:AddCost(r, list, times)
    local Prices = ns.Prices
    if not Prices.Available() or #list == 0 then return end
    self:Add({ text = L.COST, font = "GameFontNormal", color = W.GOLD, tooltip = { L.COST, L.COST_TIP } })
    local cost, unpriced = Prices.CraftCost(list, Prices.Get)
    if unpriced == #list then
        self:Add({ indent = 1, text = L.COST_NO_DATA, color = W.GREY })
        self:Gap()
        return
    end
    self:Add({ indent = 1, text = L.COST_TO_CRAFT, right = Prices.Money(cost) })
    if unpriced > 0 then
        self:Add({ indent = 1, text = L.COST_UNPRICED:format(unpriced), color = W.GREY })
    end
    local made = ((r.q1 or 1) + (r.q2 or r.q1 or 1)) / 2 * times
    local sale = r.o and Prices.Get(r.o).auction
    local value, profit = Prices.Profit(cost, sale, made)
    if value then
        self:Add({ indent = 1, text = L.COST_SELLS_FOR, right = Prices.Money(value) })
        if unpriced == 0 then
            self:Add({ indent = 1, text = L.COST_PROFIT, right = (profit >= 0 and W.GREEN or W.RED)
                :WrapTextInColorCode(Prices.Money(profit)) })
        end
    end
    self:Gap()
end

function Pane:RefreshReagents()
    self:Refresh()
end

function Pane:Refresh()
    local id = self.recipeID
    local r = id and ns.db.recipes[id]
    self:Begin()
    if not r then
        self.output:Hide()
        self.title:SetText("")
        self.sub:SetText("")
        self.favBtn:Hide()
        self.pinBtn:Hide()
        self:Finish()
        self:RefreshCraft()
        return
    end
    self.output:Show()
    self.output:SetItem(r.o, nil, r.i)
    local _, _, quality = Compat.ItemInfo(r.o)
    self.title:SetText(r.n)
    local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if qc then self.title:SetTextColor(qc.r, qc.g, qc.b) else self.title:SetTextColor(W.GOLD:GetRGB()) end
    local prof = ns.Professions.Get(r.s)
    local makes = (r.q1 and r.q2 and r.q2 > r.q1) and L.MAKES_RANGE:format(r.q1, r.q2) or L.MAKES:format(r.q1 or 1)
    self.sub:SetText((prof and (L[prof.name] or prof.name) or "") .. "  -  " .. makes)
    self.favBtn:Show()
    self.favBtn.tex:SetDesaturated(not ns.db.favorites[id])
    self.pinBtn:Show()
    self.pinBtn:SetText(ns.db.pinned[id] and L.UNPIN or L.PIN)

    -- Who can craft this.
    local who = Recipes.KnownBy(ns.db, id)
    self:Add({ text = L.WHO_CAN_CRAFT, font = "GameFontNormal", color = W.GOLD })
    self:Add({ indent = 1, text = #who > 0 and knownByText(who) or L.NOBODY, color = (#who == 0) and W.GREY or nil })
    -- Nobody knows it: which of your characters with this profession could learn it.
    if #who == 0 then
        local could = Recipes.CouldLearn(ns.db, id)
        if #could > 0 then
            self:Add({ indent = 1, text = L.COULD_LEARN, color = W.GOLD })
            for i, cl in ipairs(could) do
                if i > 4 then break end
                local ch = ns.db.characters[cl.key]
                self:Add({ indent = 2, text = (ch and W.ClassName(ch) or cl.key) .. "  "
                    .. W.ColorText(W.GREY, L.SKILL_RANK:format(cl.rank, cl.max)), right = Details.CouldLearnText(cl) })
            end
        end
    end
    self:Gap()

    -- Reagents for the viewed character (bags usable; bank shown as fetch-first).
    local c = ns.db.characters[self.charKey] or ns.char
    local times = self:Quantity()
    local list = Reagents.Shortage(ns.db, c, r, times)
    self:Add({ text = L.REAGENTS, font = "GameFontNormal", color = W.GOLD })
    local tree = Reagents.Tree(ns.db, id, 3)
    for i, item in ipairs(list) do
        local name = Compat.ItemInfo(item.itemID) or ("item:" .. item.itemID)
        local enough = item.missing == 0
        local right = L.HAVE_NEED:format(item.bags, item.need)
        right = (enough and W.GREEN or W.RED):WrapTextInColorCode(right)
        if item.fetch > 0 then
            right = W.ColorText(W.GOLD, "(" .. L.IN_BANK:format(item.bank) .. ") ") .. right
        end
        local node = tree[i]
        local key = "r." .. i
        local hasMakers = node and #node.makers > 0
        local hasSources = ns.Questie.HasSources(item.itemID)
        self:Add({ indent = 0, itemID = item.itemID, text = name, right = right, large = true,
            font = "GameFontHighlight", color = (not enough) and W.RED or nil,
            toggle = (hasMakers or hasSources) and true or nil, expanded = self.expanded[key],
            onToggle = function() self.expanded[key] = not self.expanded[key]; self:Refresh() end,
            tooltip = self:ReagentTooltip(c, name, item) })
        if self.expanded[key] then
            -- Made by (crafted) first, then where to get it (vendors, drops, nodes).
            if hasMakers then
                for _, maker in ipairs(node.makers) do self:AddMaker(maker, 1, key) end
            end
            if hasSources then self:AddWhereToGet(item.itemID, 1) end
        end
    end
    self:Gap()
    self:AddCost(r, list, times)

    -- Skill-up section. The current colour comes from the game (live when the profession
    -- is open, else the last scan or trusted thresholds). "until N" lines come from the
    -- bundled thresholds and are only added when they're trustworthy for this recipe.
    -- Stacked from the current colour onward; grey is the default after green and isn't
    -- listed (no section once the recipe is grey).
    local current = ns.Scanner.Difficulty(c, r.s, id)
    local viewed = c and c.professions[r.s]
    local lines = ns.Sources.SkillUpLines(id, viewed and viewed.rank, current, ns.db.badThresholds[id])
    if #lines > 0 then
        -- Laid out like the other sections: colour (and what it means) on the left, the skill
        -- range on the right, starting from the character's rank; then where grey starts.
        local rank = viewed and viewed.rank
        -- Values line up with the left edge of the Shopping list button below.
        local col = SKILLUP_VALUE_X
        if self.shopBtn:GetLeft() and self.content:GetLeft() then
            col = math.floor(self.shopBtn:GetLeft() - self.content:GetLeft() + 0.5)
        end
        -- Every range's "-" sits at one x (dashX), and the rank in the header is centred over it.
        local function width(text)
            self.measure = self.measure or self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            self.measure:Hide()
            self.measure:SetText(text)
            return self.measure:GetStringWidth()
        end
        local dashX, prev = col, rank
        for _, line in ipairs(lines) do
            if prev and line.untilSkill then dashX = math.max(dashX, col + width(prev .. " ")) end
            prev = line.untilSkill
        end
        local headerAt = col
        if rank then
            local label = L.SKILLUP_YOUR_RANK:format(rank)
            local number = tostring(rank)
            headerAt = dashX + width("-") / 2 - (width(label) - width(number) / 2)
        end
        self:Add({ text = L.SKILLUP_LABEL, font = "GameFontNormal", color = W.GOLD, rightAt = math.floor(headerAt + 0.5),
            right = rank and W.ColorText(W.GREY, L.SKILLUP_YOUR_RANK:format(rank)) or nil })
        local from = rank
        for _, line in ipairs(lines) do
            local name = W.DIFFICULTY[line.colour]:WrapTextInColorCode(L.SKILLUP_COLORS[line.colour + 1])
            local text = name .. "  " .. W.ColorText(W.GREY, L.SKILLUP_CHANCE[line.colour + 1])
            local right
            local at = col
            if line.untilSkill and from then
                right = L.SKILLUP_RANGE:format(from, line.untilSkill)
                at = math.floor(dashX - width(from .. " ") + 0.5)
            elseif line.untilSkill then
                right = L.SKILLUP_UNTIL:format(line.untilSkill)
            else
                right = L.SKILLUP_NOW
            end
            self:Add({ indent = 1, text = text, right = right, rightAt = at })
            from = line.untilSkill
        end
        if from then
            self:Add({ indent = 1, text = W.DIFFICULTY[3]:WrapTextInColorCode(L.SKILLUP_COLORS[4]) .. "  "
                .. W.ColorText(W.GREY, L.SKILLUP_CHANCE[4]), right = L.SKILLUP_FROM:format(from), rightAt = col })
        end
        self:Gap()
    end

    -- Sources (bundled data), shown when the viewed character hasn't learned it.
    local mine = c and c.professions[r.s] and c.professions[r.s].recipes[id]
    if not mine then
        self:Add({ text = L.SOURCE, font = "GameFontNormal", color = W.GOLD })
        local required = ns.Sources.Required(id)
        if required then
            self:Add({ indent = 1, text = L.REQUIRES_SKILL:format(prof and (L[prof.name] or prof.name) or "", required) })
        end
        -- Nearest trainers/vendors that teach it (Questie locations); click for a waypoint.
        local near = ns.Questie.RecipeSources(id)
        if near then
            self:Add({ indent = 1, text = L.LEARN_FROM, color = W.GOLD })
            for _, e in ipairs(near.list) do
                local kind = e.kind == "trainer" and L.KIND_TRAINER or L.KIND_VENDOR
                self:Add({ indent = 2, text = e.name .. "  " .. W.ColorText(W.GREY, "(" .. kind .. ")"),
                    right = placeText(e),
                    onClick = function() ns.Waypoints.Set(e.areaID, e.x, e.y, e.name) end,
                    target = e.name,
                    tooltip = e.sub and { e.name, e.sub, L.WAYPOINT_TARGET_CLICK }
                        or { e.name, L.WAYPOINT_TARGET_CLICK } })
            end
        end
        local sources, borrowed = ns.Sources.Get(id, {
            quest = function(q) return Compat.Call("C_QuestLog.GetTitleForQuestID", q) end,
            item = function(i) return (Compat.ItemInfo(i)) end,
        })
        if sources then
            for _, s in ipairs(sources) do self:Add({ indent = 1, text = s.text, right = s.right }) end
            if borrowed then self:Add({ indent = 1, text = L.SOURCE_UNCONFIRMED, color = W.GREY }) end
        else
            self:Add({ indent = 1, text = L.SOURCE_UNKNOWN, color = W.GREY })
        end
    end
    self:Finish()
    self:RefreshCraft()
end

function Pane:RefreshCraft()
    local id = self.recipeID
    if not id then
        self.craft:Disable()
        self.craftAll:Disable()
        self.status:SetText("")
        return
    end
    local state, max, reason = ns.Crafting.State(id)
    local ok = state == "ok"
    local closed = state == "closed"
    local r = ns.db.recipes[id]
    local prof = r and ns.Professions.Get(r.s)
    self.craft:SetText(closed and prof and L.OPEN_PROFESSION:format(L[prof.name] or prof.name) or L.CRAFT)
    self.craft:SetWidth(math.max(80, self.craft:GetFontString():GetStringWidth() + 26))
    -- The button row (Open in default window, Shopping list | Craft, quantity, Craft All) must
    -- fit side by side: tell the window how wide it has to stay.
    local row = self.defaultBtn:GetWidth() + self.shopBtn:GetWidth() + self.craft:GetWidth()
        + self.qty:GetWidth() + self.craftAll:GetWidth() + 2 + 4 + 16 + 30 + 34 + 2
    ns.UI.SetMinWidth("craftRow", row + DETAILS_MARGIN)
    self.craft:SetEnabled(ok or (closed and not InCombatLockdown()))
    self.craftAll:SetEnabled(ok and max > 0)
    self.defaultBtn:SetEnabled(ns.Crafting.CanOpenInDefault(id))
    self.qty:SetEnabled(state ~= "notlearned" and state ~= "other")
    if ok then
        self.status:SetText(W.ColorText(W.GREEN, L.CRAFT_ALL .. ": " .. max))
    else
        self.status:SetText(reason or "")
        self.status:SetTextColor(1, 0.82, 0)
    end
end
