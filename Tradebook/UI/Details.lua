-- UI/Details.lua
-- Right-hand recipe details: result item, who knows it, reagents (with an expandable
-- tree of reagents made by other recipes), sources, and the craft controls.

local _, ns = ...
local L, W, Compat = ns.L, ns.W, ns.Compat
local Recipes, Reagents = ns.Recipes, ns.Reagents

local Details = {}
ns.Details = Details

local LINE_H = 22
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
    line:SetScript("OnClick", nil)
    line:SetScript("OnEnter", nil)
    line:SetScript("OnLeave", nil)
    line:GetHighlightTexture():SetAlpha(0)
    line:Show()
    self.y = self.y + LINE_H
    return line
end

-- Add a line: { indent, itemID, text, right, color, font, onClick, toggle = bool|nil, expanded, onToggle, tooltip }
function Pane:Add(o)
    local line = self:Line()
    local x = (o.indent or 0) * 16
    if o.toggle ~= nil then
        line.toggle:Show()
        line.toggle:SetPoint("LEFT", x, 0)
        line.toggle:SetNormalAtlas(o.expanded and "Campaign_HeaderIcon_Open" or "Professions-Slot-Plus")
        line.toggle:SetScript("OnClick", o.onToggle)
        x = x + 16
    end
    if o.itemID then
        line.item:Show()
        line.item:SetPoint("LEFT", x, 0)
        line.item:SetItem(o.itemID)
        x = x + 22
    end
    line.text:ClearAllPoints()
    line.text:SetPoint("LEFT", x, 0)
    line.text:SetPoint("RIGHT", line.right, "LEFT", -6, 0)
    if o.font then line.text:SetFontObject(o.font) end
    line.text:SetText(o.text or "")
    if o.color then line.text:SetTextColor(o.color:GetRGB()) end
    line.right:SetText(o.right or "")
    if o.onClick then
        line:GetHighlightTexture():SetAlpha(1)
        line:SetScript("OnClick", o.onClick)
    end
    if o.tooltip then W.Tooltip(line, o.tooltip) end
    return line
end

function Pane:Gap(h)
    self.y = self.y + (h or 6)
end

function Pane:Begin()
    self.used, self.y = 0, 0
end

function Pane:Finish()
    for i = self.used + 1, #self.lines do self.lines[i]:Hide() end
    self.content:SetHeight(math.max(1, self.y))
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function Details.Create(parent)
    local self = setmetatable({ lines = {}, used = 0, y = 0, expanded = {} }, Pane)
    local f = CreateFrame("Frame", nil, parent)
    self.frame = f

    -- Header: result item, name, makes N, favorite/pin.
    self.output = W.ItemButton(f, 40)
    self.output:SetPoint("TOPLEFT", 2, -2)
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
function Pane:ReagentTooltip(c, name, item)
    local lines = { name, L.IN_BAGS:format(item.bags), L.IN_BANK:format(item.bank) }
    if item.fetch > 0 then lines[#lines + 1] = L.BANK_FETCH end
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
        self:Add({ indent = 0, itemID = item.itemID, text = name, right = right,
            color = (not enough) and W.RED or nil,
            toggle = hasMakers and true or nil, expanded = self.expanded[key],
            onToggle = function() self.expanded[key] = not self.expanded[key]; self:Refresh() end,
            tooltip = self:ReagentTooltip(c, name, item) })
        if hasMakers and self.expanded[key] then
            for _, maker in ipairs(node.makers) do self:AddMaker(maker, 1, key) end
        end
    end
    self:Gap()

    -- Skill-up thresholds and required skill (bundled data).
    local thresholds = ns.Sources.Thresholds(id)
    if thresholds then
        -- thresholds = level where orange, yellow, green and grey START. Stack where each
        -- colour ends ("orange until 23"), starting at the colour the viewed character is
        -- in now, so only what's still ahead shows. Grey is the default after green and is
        -- left out (no section at all once the recipe is grey); empty ranges are skipped.
        local viewed = c and c.professions[r.s]
        local current = viewed and viewed.rank and ns.Sources.Difficulty(id, viewed.rank) or 0
        local lines = {}
        for i = current + 1, 3 do
            if thresholds[i + 1] > thresholds[i] then
                lines[#lines + 1] = { i - 1, L.SKILLUP_UNTIL:format(L.SKILLUP_COLORS[i], thresholds[i + 1]) }
            end
        end
        if #lines > 0 then
            self:Add({ text = L.SKILLUP_LABEL, font = "GameFontNormal", color = W.GOLD })
            for _, line in ipairs(lines) do
                self:Add({ indent = 1, text = line[2], color = W.DIFFICULTY[line[1]] })
            end
            self:Gap()
        end
    end

    -- Sources (bundled data), shown when the viewed character hasn't learned it.
    local mine = c and c.professions[r.s] and c.professions[r.s].recipes[id]
    if not mine then
        self:Add({ text = L.SOURCE, font = "GameFontNormal", color = W.GOLD })
        local required = ns.Sources.Required(id)
        if required then
            self:Add({ indent = 1, text = L.REQUIRES_SKILL:format(prof and (L[prof.name] or prof.name) or "", required) })
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
    self.craft:SetWidth(closed and 130 or 80)
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
