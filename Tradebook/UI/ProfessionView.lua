-- UI/ProfessionView.lua
-- Recipe list (left) + details (right) for one profession, for the logged-in
-- character or (read only) any saved alt.

local _, ns = ...
local L, W, Compat = ns.L, ns.W, ns.Compat
local Recipes, Reagents, Characters = ns.Recipes, ns.Reagents, ns.Characters

local View = {}
ns.UI.RegisterView("profession", View)

local LEFT_WIDTH = 330
-- Section keys (also used to remember collapsed state); Starred first, then Pinned,
-- then the categories A-Z.
local STARRED_KEY = "\000starred"
local PINNED_KEY = "\001pinned"
local PIN_ATLAS = "Waypoint-MapPin-Tracked"

---------------------------------------------------------------------------
-- rows
---------------------------------------------------------------------------

local function createRow(row)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 4, 0)
    row.toggle = row:CreateTexture(nil, "ARTWORK")
    row.toggle:SetSize(14, 14)
    row.toggle:SetPoint("LEFT", 2, 0)
    row.name = W.Text(row, "GameFontHighlightSmall")
    row.name:SetWordWrap(false)
    row.right = W.Text(row, "GameFontHighlightSmall", "RIGHT")
    row.right:SetPoint("RIGHT", -4, 0)
    -- Star marker; clicking it removes the star.
    row.fav = CreateFrame("Button", nil, row)
    row.fav:SetSize(13, 13)
    row.fav:SetPoint("RIGHT", row.right, "LEFT", -2, 0)
    row.fav:SetNormalAtlas("auctionhouse-icon-favorite")
    row.fav:SetHighlightAtlas("auctionhouse-icon-favorite", "ADD")
    row.fav:SetScript("OnClick", function(self)
        local data = self:GetParent().data
        if data and data.id then
            ns.db.favorites[data.id] = nil
            ns.UI.Refresh()
        end
    end)
    W.Tooltip(row.fav, ns.L.UNSTAR_TIP)
    -- Pin marker; clicking it unpins.
    row.pin = CreateFrame("Button", nil, row)
    row.pin:SetSize(14, 14)
    row.pin:SetPoint("RIGHT", row.fav, "LEFT", -2, 0)
    row.pin:SetNormalAtlas(PIN_ATLAS)
    row.pin:SetHighlightAtlas(PIN_ATLAS, "ADD")
    row.pin:SetScript("OnClick", function(self)
        local data = self:GetParent().data
        if data and data.id then
            ns.db.pinned[data.id] = nil
            ns.UI.Refresh()
        end
    end)
    W.Tooltip(row.pin, ns.L.UNPIN_TIP)
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(W.GOLD.r, W.GOLD.g, W.GOLD.b, 0.18)
    row:SetScript("OnClick", function(self)
        local data = self.data
        if data.header then
            local collapsed = ns.db.settings.collapsed
            collapsed[data.key] = not collapsed[data.key] or nil
            View:RefreshList()
        else
            View:SelectRecipe(data.id)
        end
    end)
    row:SetScript("OnEnter", function(self)
        local data = self.data
        if data.header or not data.diff then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(data.name, 1, 1, 1)
        local key = ({ [0] = "DIFF_OPTIMAL", [1] = "DIFF_MEDIUM", [2] = "DIFF_EASY", [3] = "DIFF_TRIVIAL" })[data.diff]
        if key then GameTooltip:AddLine(L[key], W.DIFFICULTY[data.diff]:GetRGB()) end
        if data.skillUps and data.skillUps > 1 then GameTooltip:AddLine(L.SKILLUP_TIP:format(data.skillUps)) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
end

local function initRow(row, data)
    row.data = data
    row.selected:SetShown(not data.header and data.id == View.selected)
    if data.header then
        row.icon:Hide()
        row.fav:Hide()
        row.pin:Hide()
        row.toggle:Show()
        row.toggle:SetAtlas(ns.db.settings.collapsed[data.key] and "Campaign_HeaderIcon_Closed" or "Campaign_HeaderIcon_Open")
        row.name:SetPoint("LEFT", 20, 0)
        row.name:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
        row.name:SetFontObject("GameFontNormalSmall")
        row.name:SetText(data.name)
        row.name:SetTextColor(W.GOLD:GetRGB())
        row.right:SetText(data.count and ("(" .. data.count .. ")") or "")
        row.right:SetTextColor(0.6, 0.6, 0.6)
        return
    end
    row.toggle:Hide()
    row.icon:Show()
    row.icon:SetTexture(data.icon or 134400)
    row.icon:SetDesaturated(not data.learned)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", row.pin, "LEFT", -2, 0)
    row.name:SetFontObject("GameFontHighlightSmall")
    row.name:SetText(data.name)
    if data.learned and data.diff and W.DIFFICULTY[data.diff] then
        row.name:SetTextColor(W.DIFFICULTY[data.diff]:GetRGB())
    elseif data.learned then
        row.name:SetTextColor(1, 1, 1)
    else
        row.name:SetTextColor(0.55, 0.55, 0.55)
    end
    row.fav:SetShown(ns.db.favorites[data.id] == true)
    row.pin:SetShown(data.pinned == true)
    -- Side display like the default window: craftable count, then skill-ups in the difficulty color.
    local parts = {}
    if data.possible and data.possible > 0 then parts[#parts + 1] = "[" .. data.possible .. "]" end
    if data.learned and data.diff and data.diff < 3 then
        local color = W.DIFFICULTY[data.diff]
        parts[#parts + 1] = color:WrapTextInColorCode("+" .. (data.skillUps or 1))
    end
    row.right:SetText(table.concat(parts, " "))
    row.right:SetTextColor(0.8, 0.8, 0.8)
end

---------------------------------------------------------------------------
-- data
---------------------------------------------------------------------------

function View:IsLive()
    local open = ns.Scanner.OpenProfession()
    return self.charKey == ns.charKey and open ~= nil and open.professionID == self.skill
end

function View:BuildItems()
    local db = ns.db
    local c = db.characters[self.charKey]
    local p = c and c.professions[self.skill]
    local learnedMap = p and p.recipes or {}
    local isMe = self.charKey == ns.charKey
    local live = self:IsLive()
    local f = db.settings.filters
    local groups, order = {}, {}

    local starred, pinnedList = {}, {}

    local function add(key, item)
        if not groups[key] then
            groups[key] = {}
            order[#order + 1] = key
        end
        table.insert(groups[key], item)
    end

    for _, id in ipairs(Recipes.ForProfession(db, self.skill, db.settings.showSoD)) do
        local r = db.recipes[id]
        if not self.query or ns.util.Matches(r.n, self.query) then
            local learned = learnedMap[id] ~= nil
            local item = { id = id, name = r.n, icon = r.i, learned = learned, pinned = db.pinned[id] ~= nil }
            local diff = learnedMap[id]
            item.diff = type(diff) == "number" and diff or nil
            -- Recompute from the character's current rank where thresholds are known.
            if learned and p and p.rank then item.diff = ns.Sources.Difficulty(id, p.rank) or item.diff end
            if live and learned then
                local info = Compat.Call("C_TradeSkillUI.GetRecipeInfo", id)
                if info then item.diff, item.skillUps = info.relativeDifficulty, info.numSkillUps end
            end
            if isMe and learned then
                local _, possible = Reagents.Shortage(db, c, r, 1)
                item.possible = possible
            end
            -- Starred and Pinned sections are shortcuts: they ignore the filters (search still
            -- applies), and the recipes also stay in their own category below.
            if db.favorites[id] then starred[#starred + 1] = item end
            if item.pinned then pinnedList[#pinnedList + 1] = item end
            local keep = (learned and f.learned) or (not learned and f.unlearned)
            if f.skillup and not (learned and item.diff and item.diff < 3) then keep = false end
            if f.haveMats and not (item.possible and item.possible > 0) then keep = false end
            if keep then
                local cat = db.categories[r.c]
                add(cat and cat.n or OTHER or "Other", item)
            end
        end
    end
    table.sort(order)

    local items = {}
    local function section(key, name, list)
        if #list == 0 then return end
        items[#items + 1] = { header = true, key = key, name = name, count = #list }
        if not db.settings.collapsed[key] then
            for _, item in ipairs(list) do items[#items + 1] = item end
        end
    end
    section(STARRED_KEY, L.STARRED, starred)
    section(PINNED_KEY, L.PINNED, pinnedList)
    for _, key in ipairs(order) do section(key, key, groups[key]) end
    return items
end

---------------------------------------------------------------------------
-- build
---------------------------------------------------------------------------

local function filterMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        local f = ns.db.settings.filters
        local function add(text, key)
            root:CreateCheckbox(text, function() return f[key] end, function()
                f[key] = not f[key]
                View:RefreshList()
            end)
        end
        add(L.FILTER_LEARNED, "learned")
        add(L.FILTER_UNLEARNED, "unlearned")
        add(L.FILTER_CRAFTABLE, "haveMats")
        add(L.FILTER_SKILLUP, "skillup")
        root:CreateDivider()
        root:CreateCheckbox(L.FILTER_SOD, function() return ns.db.settings.showSoD end, function()
            ns.db.settings.showSoD = not ns.db.settings.showSoD
            View:RefreshList()
        end)
    end)
end

local function charMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, c in ipairs(Characters.WithProfession(ns.db, View.skill, ns.charKey)) do
            local prof = c.professions[View.skill]
            local text = W.ClassName(c) .. "  " .. L.SKILL_RANK:format(prof.rank or 0, prof.max or 0)
            root:CreateRadio(text, function() return View.charKey == c.key end, function()
                View.charKey = c.key
                View:Refresh()
            end)
        end
    end)
end

function View:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f

    local left = CreateFrame("Frame", nil, f)
    left:SetPoint("TOPLEFT", 8, -8)
    left:SetPoint("BOTTOMLEFT", 8, 8)
    left:SetWidth(LEFT_WIDTH)

    self.charBtn = W.Button(left, "", 190, 22)
    self.charBtn:SetPoint("TOPLEFT", 0, 0)
    self.charBtn:SetScript("OnClick", charMenu)

    self.rank = W.Text(left, "GameFontNormalSmall", "RIGHT")
    self.rank:SetPoint("LEFT", self.charBtn, "RIGHT", 6, 0)
    self.rank:SetPoint("RIGHT", left, "RIGHT", -18, 0)

    self.notice = W.Text(left, "GameFontDisableSmall")
    self.notice:SetPoint("TOPLEFT", self.charBtn, "BOTTOMLEFT", 2, -6)
    self.notice:SetWidth(LEFT_WIDTH - 20)

    self.openBtn = W.Button(left, "", 170, 22)
    self.openBtn:SetPoint("TOPLEFT", self.notice, "BOTTOMLEFT", -2, -4)
    self.openBtn:SetScript("OnClick", function()
        ns.Crafting.OpenProfession(View.skill)
    end)

    self.search = W.SearchBox(left, LEFT_WIDTH - 104, function(text)
        View.query = ns.util.Query(text)
        View:RefreshList()
    end)
    if self.search.Instructions then self.search.Instructions:SetText(L.SEARCH_RECIPES) end

    self.filterBtn = W.Button(left, L.FILTER, 80, 22)
    self.filterBtn:SetScript("OnClick", filterMenu)

    self.list = W.List(left, 18, createRow, initRow)
    self.list:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -14, 0)

    self.empty = W.Text(left, "GameFontDisable", "CENTER")
    self.empty:SetPoint("TOP", self.list, "TOP", 0, -30)
    self.empty:SetWidth(LEFT_WIDTH - 40)

    self.details = ns.Details.Create(f)
    self.details.frame:SetPoint("TOPLEFT", left, "TOPRIGHT", 22, 0)
    self.details.frame:SetPoint("BOTTOMRIGHT", -8, 8)
end

-- Place search/list below the notice area (which changes height).
function View:Layout(showOpen)
    local anchor = showOpen and self.openBtn or self.notice
    self.search:ClearAllPoints()
    self.search:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 6, -8)
    self.filterBtn:ClearAllPoints()
    self.filterBtn:SetPoint("LEFT", self.search, "RIGHT", 6, 0)
    self.list:ClearAllPoints()
    self.list:SetPoint("TOPLEFT", self.search, "BOTTOMLEFT", -6, -6)
    self.list:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMLEFT", LEFT_WIDTH - 6, 8)
end

---------------------------------------------------------------------------
-- show / refresh
---------------------------------------------------------------------------

function View:Show(skillLineID)
    if self.skill ~= skillLineID then
        self.skill = skillLineID
        self.selected = nil
        self.charKey = nil
        self.search:SetText("")
        self.query = nil
    end
    self:Refresh()
end

function View:PickCharacter()
    local c = ns.db.characters[self.charKey]
    if c and c.professions[self.skill] then return end
    if ns.char and ns.char.professions[self.skill] then
        self.charKey = ns.charKey
        return
    end
    local with = Characters.WithProfession(ns.db, self.skill, ns.charKey)
    self.charKey = with[1] and with[1].key or ns.charKey
end

function View:Refresh()
    if not self.frame or not self.skill then return end
    self:PickCharacter()
    local c = ns.db.characters[self.charKey]
    local prof = c and c.professions[self.skill]
    local pInfo = ns.Professions.Get(self.skill)
    local profName = L[pInfo.name] or pInfo.name
    local isMe = self.charKey == ns.charKey

    self.charBtn:SetText(c and W.ClassName(c) or "?")
    self.rank:SetText(prof and (profName .. "  " .. L.SKILL_RANK:format(prof.rank or 0, prof.max or 0)) or profName)

    local notices, showOpen = {}, false
    if not isMe then notices[#notices + 1] = L.VIEWING_ALT:format(c and ns.CharName(c.key) or "?") end
    if prof and not prof.scannedAt and not pInfo.noRecipes then
        notices[#notices + 1] = (prof.quickAt and L.QUICK_SCANNED or L.NOT_SCANNED):format(profName)
    end
    if isMe and prof and not self:IsLive() and not pInfo.noRecipes then
        showOpen = true
        self.openBtn:SetText(L.OPEN_PROFESSION:format(profName))
        self.openBtn:SetEnabled(not InCombatLockdown())
    end
    if prof and prof.scannedAt and not isMe then
        notices[#notices + 1] = L.LAST_SCANNED:format(W.Ago(prof.scannedAt))
    end
    self.notice:SetText(table.concat(notices, "\n"))
    self.openBtn:SetShown(showOpen)
    self:Layout(showOpen)
    self:RefreshList()
end

function View:RefreshList()
    local items = self:BuildItems()
    self.list:SetItems(items)
    self.empty:SetText(#items == 0 and L.NO_RECIPES or "")
    if not self.selected then
        for _, item in ipairs(items) do
            if not item.header then
                self.selected = item.id
                break
            end
        end
    end
    self.details:SetRecipe(self.selected, self.charKey)
end

function View:SelectRecipe(recipeID, charKey)
    if charKey and ns.db.characters[charKey] then self.charKey = charKey end
    self.selected = recipeID
    local r = ns.db.recipes[recipeID]
    if r then
        local cat = ns.db.categories[r.c]
        if cat then ns.db.settings.collapsed[cat.n] = nil end
    end
    self.list:ForEachFrame(function(row) initRow(row, row.data) end)
    self.details:SetRecipe(recipeID, self.charKey)
    if charKey then self:Refresh() end
end
