-- UI/CampView.lua
-- Campsite recipes across all characters: who can make each one, who knows it,
-- materials and whether you have them now. Grid grouped by profession, or a list
-- grouped by character. (Camp-object cooldowns aren't exposed by the API, and what's
-- active at the camp is intentionally not shown.)

local _, ns = ...
local L, W, Compat = ns.L, ns.W, ns.Compat
local Recipes, Reagents = ns.Recipes, ns.Reagents

local View = {}
ns.UI.RegisterView("camp", View)

local function createRow(row)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.item = W.ItemButton(row, 28)
    row.item:SetPoint("TOPLEFT", 8, -4)
    row.name = W.Text(row, "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row.item, "TOPRIGHT", 8, 0)
    row.name:SetWidth(240)
    row.name:SetWordWrap(false)
    row.mats = W.Text(row, "GameFontHighlightSmall")
    row.mats:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.mats:SetPoint("RIGHT", -420, 0)
    row.mats:SetWordWrap(false)
    row.who = W.Text(row, "GameFontHighlightSmall")
    row.who:SetPoint("TOPLEFT", row, "TOPRIGHT", -410, -6)
    row.who:SetPoint("RIGHT", -142, 0)
    row.who:SetJustifyV("TOP")
    row.craft = W.Button(row, L.CRAFT, 80, 22)
    row.craft:SetPoint("RIGHT", -8, 0)
    -- One call per click: opens the profession if that's all that's missing, else crafts.
    row.craft:SetScript("OnClick", function(self)
        ns.Crafting.Click(self:GetParent().data.id, 1)
        C_Timer.After(0.4, function() View:Refresh() end)
    end)
    row.header = W.Text(row, "GameFontNormal")
    row.header:SetPoint("LEFT", 10, 0)
    row:SetScript("OnClick", function(self)
        if self.data.id then ns.UI.OpenRecipe(self.data.id, nil, true) end
    end)
end

local function matsText(recipe)
    local parts = {}
    local list = Reagents.Shortage(ns.db, ns.char, recipe, 1)
    for _, m in ipairs(list) do
        local name = Compat.ItemInfo(m.itemID) or ("item:" .. m.itemID)
        local color = m.missing == 0 and W.GREEN or (m.fetch > 0 and W.GOLD or W.RED)
        parts[#parts + 1] = color:WrapTextInColorCode(string.format("%s %d/%d", name, m.bags, m.need))
    end
    return table.concat(parts, ", ")
end

local function initRow(row, data)
    row.data = data
    local isHeader = data.header ~= nil
    row.header:SetShown(isHeader)
    row.item:SetShown(not isHeader)
    row.name:SetShown(not isHeader)
    row.mats:SetShown(not isHeader)
    row.who:SetShown(not isHeader)
    row.craft:SetShown(not isHeader)
    if isHeader then
        row.header:SetText(data.header)
        row:GetHighlightTexture():SetAlpha(0)
        return
    end
    row:GetHighlightTexture():SetAlpha(1)
    local r = ns.db.recipes[data.id]
    row.item:SetItem(r.o, nil, r.i)
    row.name:SetText(r.n)
    row.mats:SetText(matsText(r))
    local known = Recipes.KnownBy(ns.db, data.id)
    local can, knows = {}, {}
    for _, key in ipairs(known) do
        local c = ns.db.characters[key]
        if c then
            knows[#knows + 1] = W.ClassName(c)
            local _, possible = Reagents.Shortage(ns.db, c, r, 1)
            if possible > 0 then can[#can + 1] = W.ClassName(c) end
        end
    end
    local lines = {}
    lines[#lines + 1] = L.CAMP_KNOWS:format(#knows > 0 and table.concat(knows, ", ") or W.ColorText(W.GREY, L.NOBODY))
    if #can > 0 then lines[#lines + 1] = L.CAMP_CAN_MAKE:format(table.concat(can, ", ")) end
    row.who:SetText(table.concat(lines, "\n"))
    local state = ns.Crafting.State(data.id)
    local mine = ns.char and ns.char.professions[r.s] and ns.char.professions[r.s].recipes[data.id]
    local _, possible = Reagents.Shortage(ns.db, ns.char, r, 1)
    local closed = state == "closed"
    local p = ns.Professions.Get(r.s)
    row.craft:SetShown(mine ~= nil)
    row.craft:SetText(closed and p and L.OPEN_PROFESSION:format(L[p.name] or p.name) or L.CRAFT)
    row.craft:SetWidth(closed and 130 or 80)
    -- Enabled when craftable now, or when only the profession needs opening and you have the materials.
    row.craft:SetEnabled(state == "ok" or (closed and possible > 0 and not InCombatLockdown()))
end

function View:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    self.title = W.Text(f, "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 12, -10)
    self.title:SetText(L.CAMP_TITLE)
    self.toggle = W.Button(f, "", 140, 22)
    self.toggle:SetPoint("TOPRIGHT", -12, -8)
    self.toggle:SetScript("OnClick", function()
        local s = ns.db.settings
        s.campView = s.campView == "character" and "profession" or "character"
        self:Refresh()
    end)
    self.list = W.List(f, 44, createRow, initRow)
    self.list:SetPoint("TOPLEFT", 8, -40)
    self.list:SetPoint("BOTTOMRIGHT", -22, 8)
    self.empty = W.Text(f, "GameFontDisable", "CENTER")
    self.empty:SetPoint("TOP", 0, -80)
    self.empty:SetWidth(500)
end

function View:Show()
    self:Refresh()
end

function View:Refresh()
    local byCharacter = ns.db.settings.campView == "character"
    self.toggle:SetText(byCharacter and L.CAMP_BY_PROFESSION or L.CAMP_BY_CHARACTER)
    local camp = Recipes.Camp(ns.db)
    local items = {}
    if byCharacter then
        for _, c in ipairs(ns.Characters.List(ns.db, ns.charKey, false)) do
            local mine = {}
            for _, p in ipairs(ns.Professions.list) do
                for _, id in ipairs(camp[p.id] or {}) do
                    local prof = c.professions[p.id]
                    if prof and prof.recipes[id] then mine[#mine + 1] = id end
                end
            end
            if #mine > 0 then
                items[#items + 1] = { header = W.ClassName(c) }
                for _, id in ipairs(mine) do items[#items + 1] = { id = id } end
            end
        end
    else
        for _, p in ipairs(ns.Professions.list) do
            local ids = camp[p.id]
            if ids and #ids > 0 then
                items[#items + 1] = { header = L[p.name] or p.name }
                for _, id in ipairs(ids) do items[#items + 1] = { id = id } end
            end
        end
    end
    self.list:SetItems(items)
    self.empty:SetText(#items == 0 and L.CAMP_NONE or "")
end
