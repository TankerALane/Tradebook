-- UI/SearchView.lua
-- "Who can craft this?" results for the global search box: every recipe on the
-- account matching the text, with the characters who know it.

local _, ns = ...
local L, W = ns.L, ns.W

local View = {}
ns.UI.RegisterView("search", View)

local function createRow(row)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 6, 0)
    row.name = W.Text(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(260)
    row.name:SetWordWrap(false)
    row.prof = W.Text(row, "GameFontNormalSmall")
    row.prof:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.prof:SetWidth(110)
    row.who = W.Text(row, "GameFontHighlightSmall")
    row.who:SetPoint("LEFT", row.prof, "RIGHT", 8, 0)
    row.who:SetPoint("RIGHT", -6, 0)
    row.who:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
        ns.UI.OpenRecipe(self.data.id, self.data.crafters[1], true)
    end)
    -- What it makes (item tooltip), or what it does for enchants and the like (spell tooltip).
    row:SetScript("OnEnter", function(self)
        local r = self.data and self.data.recipe
        if not r then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if r.o then GameTooltip:SetItemByID(r.o) else GameTooltip:SetSpellByID(self.data.id) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
end

local function initRow(row, data)
    row.data = data
    row.icon:SetTexture(data.recipe.i or 134400)
    row.name:SetText(data.recipe.n)
    local p = ns.Professions.Get(data.recipe.s)
    row.prof:SetText(p and (L[p.name] or p.name) or "")
    if #data.crafters > 0 then
        local names = {}
        for _, key in ipairs(data.crafters) do
            local c = ns.db.characters[key]
            names[#names + 1] = c and W.ClassName(c) or key
        end
        row.who:SetText(table.concat(names, ", "))
        row.name:SetTextColor(1, 1, 1)
    else
        -- Nobody knows it: the character closest to learning it, if any has the profession.
        local cl = ns.Recipes.CouldLearn(ns.db, data.id)[1]
        local ch = cl and ns.db.characters[cl.key]
        if ch then
            row.who:SetText(L.COULD_LEARN_WHO:format(W.ClassName(ch)) .. "  " .. ns.Details.CouldLearnText(cl))
        else
            row.who:SetText(W.ColorText(W.GREY, L.NOBODY))
        end
        row.name:SetTextColor(0.6, 0.6, 0.6)
    end
end

function View:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    self.title = W.Text(f, "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 12, -10)
    self.onlyKnown = W.Check(f, L.KNOWN_BY, function(checked)
        self.knownOnly = checked
        self:Refresh()
    end)
    self.onlyKnown:SetPoint("TOPRIGHT", -120, -6)
    self.list = W.List(f, 26, createRow, initRow)
    self.list:SetPoint("TOPLEFT", 8, -40)
    self.list:SetPoint("BOTTOMRIGHT", -22, 8)
    self.empty = W.Text(f, "GameFontDisable", "CENTER")
    self.empty:SetPoint("TOP", 0, -80)
end

function View:Show(text)
    self.text = text
    self:Refresh()
end

function View:Refresh()
    local results = ns.Recipes.Search(ns.db, self.text, { limit = 300, onlyKnown = self.knownOnly })
    self.title:SetText(L.SEARCH_ALL .. "  " .. W.ColorText(W.GOLD, self.text or ""))
    self.list:SetItems(results)
    self.empty:SetText(#results == 0 and L.NO_RECIPES or "")
end
