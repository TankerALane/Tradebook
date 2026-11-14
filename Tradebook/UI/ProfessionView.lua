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
local NEAREST_KEY = "\002nearest" -- not learned, nearest place to learn first
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
        if data.header then return end
        local r = ns.db.recipes[data.id]
        -- Recipes without a result item (enchants and the like): what the spell does.
        local desc = r and not r.o and ns.Compat.Call("C_Spell.GetSpellDescription", data.id)
        if desc == "" then desc = nil end
        if not data.diff and not desc then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(data.name, 1, 1, 1)
        if desc then GameTooltip:AddLine(desc, nil, nil, nil, true) end
        local key = data.diff and ({ [0] = "DIFF_OPTIMAL", [1] = "DIFF_MEDIUM", [2] = "DIFF_EASY", [3] = "DIFF_TRIVIAL" })[data.diff]
        if key then GameTooltip:AddLine(L[key], W.DIFFICULTY[data.diff]:GetRGB()) end
        if data.skillUps and data.skillUps > 1 then GameTooltip:AddLine(L.SKILLUP_TIP:format(data.skillUps)) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
end

-- Rank groups for browsing (by the skill a recipe needs).
local BROWSE_GROUPS = {
    { rank = "Apprentice", from = 1, upTo = 75 },
    { rank = "Journeyman", from = 75, upTo = 150 },
    { rank = "Expert", from = 150, upTo = 225 },
    { rank = "Artisan", from = 225, upTo = 301 },
}

local RECIPE_INDENT = 20 -- where a section header's name starts

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
        row.name:SetText(data.name .. (data.count and ("  " .. W.ColorText(W.GREY, "(" .. data.count .. ")")) or ""))
        row.name:SetTextColor(W.GOLD:GetRGB())
        row.right:SetText("") -- the count sits next to the name
        return
    end
    row.toggle:Hide()
    -- Recipes sit indented under their section header (icon lined up with the header name).
    row.icon:SetPoint("LEFT", RECIPE_INDENT, 0)
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
    -- Right side: distance (Nearest first), then how many you can craft at the far right. The
    -- skill-up colour is the name's colour (and skill-ups above 1 are in the tooltip).
    local parts = {}
    if data.distanceText then parts[#parts + 1] = W.ColorText(W.GREY, data.distanceText) end
    if data.possible and data.possible > 0 then parts[#parts + 1] = "[" .. data.possible .. "]" end
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

    local starred, pinnedList, nearestList = {}, {}, {}
    -- "Nearest first": unlearned recipes with a known trainer/vendor go into their own
    -- section, sorted by distance (needs Questie for NPC locations).
    local byDistance = f.unlearned and f.unlearnedNearest and ns.Questie.Available()

    local function add(key, item)
        if not groups[key] then
            groups[key] = {}
            order[#order + 1] = key
        end
        table.insert(groups[key], item)
    end

    -- Browsing a profession nobody has: the game gives no category names while it's closed,
    -- so recipes are grouped by the rank they need instead (in rank order).
    local rankOrder = {}
    local function rankGroup(id)
        local need = ns.Sources.Required(id)
        if not need then
            local lv = ns.RecipeLevels and ns.RecipeLevels[id]
            need = lv and lv[2] and math.max(1, lv[2] - 10) -- learned a little below yellow
        end
        if not need then return nil end
        for i, g in ipairs(BROWSE_GROUPS) do
            if need < g.upTo then
                local name = L.BROWSE_GROUP:format(L.RANK_NAMES[g.rank] or g.rank, g.from, g.upTo - 1)
                rankOrder[name] = i
                return name
            end
        end
        return nil
    end

    for _, id in ipairs(Recipes.ForProfession(db, self.skill)) do
        local r = db.recipes[id]
        if r.n and r.n ~= "" and (not self.query or ns.util.Matches(r.n, self.query)) then
            local learned = learnedMap[id] ~= nil
            local item = { id = id, name = r.n, icon = r.i, learned = learned, pinned = db.pinned[id] ~= nil }
            if live and learned then
                -- Profession open: the game's own colour and skill-up count.
                local info = Compat.Call("C_TradeSkillUI.GetRecipeInfo", id)
                if info then item.diff, item.skillUps = info.relativeDifficulty, info.numSkillUps end
            end
            if learned and item.diff == nil then
                item.diff = ns.Scanner.Difficulty(c, self.skill, id, true)
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
            if self.browsing then keep = true end -- nobody has it: every recipe, search only
            if not self.browsing and f.skillup
                and not (learned and item.diff and item.diff < 3 and f.skillupColors[item.diff + 1]) then
                keep = false
            end
            if not self.browsing and f.haveMats and not (item.possible and item.possible > 0) then keep = false end
            if keep and not learned and not self.browsing then
                -- Under "Not learned": learnable now, and how it's learned (trainer / recipe item).
                if f.unlearnedLearnable and not ns.Sources.Learnable(id, p and p.rank) then keep = false end
                if f.unlearnedTrainer or f.unlearnedRecipe then
                    local kinds = ns.Sources.Kinds(id)
                    if not (kinds and ((f.unlearnedTrainer and kinds.trainer) or (f.unlearnedRecipe and kinds.recipe))) then
                        keep = false
                    end
                end
            end
            local near = keep and byDistance and not learned and ns.Questie.RecipeSources(id)
            if near and near.best then
                item.distance = near.best.distance
                item.distanceText = ns.Locations.DistanceText(near.best.distance)
                nearestList[#nearestList + 1] = item
            elseif keep then
                local cat = db.categories[r.c]
                local group = cat and cat.n or (self.browsing and rankGroup(id)) or OTHER or "Other"
                add(group, item)
            end
        end
    end
    table.sort(order, function(a, b)
        local ra, rb = rankOrder[a], rankOrder[b]
        if ra and rb then return ra < rb end
        if (ra ~= nil) ~= (rb ~= nil) then return ra ~= nil end
        return a < b
    end)
    table.sort(nearestList, function(a, b)
        if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
        if a.distance and b.distance and a.distance ~= b.distance then return a.distance < b.distance end
        return a.name < b.name
    end)

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
    section(NEAREST_KEY, L.NEAREST_TO_LEARN, nearestList)
    for _, key in ipairs(order) do section(key, key, groups[key]) end
    return items
end

---------------------------------------------------------------------------
-- build
---------------------------------------------------------------------------

-- Filters, with the defaults the red X on the Filter button restores.
local DEFAULT_FILTERS = { learned = true, unlearned = false, unlearnedNearest = false, unlearnedLearnable = false,
    unlearnedTrainer = false, unlearnedRecipe = false, haveMats = false, skillup = false }
local SUB_INDENT = 18 -- the colour checkboxes sit one checkbox to the right, under "Gives skill-ups"

local function filtersAreDefault()
    local f = ns.db.settings.filters
    for key, value in pairs(DEFAULT_FILTERS) do
        if (f[key] or false) ~= value then return false end
    end
    for i = 1, 3 do
        if not f.skillupColors[i] then return false end
    end
    return true
end

local function resetFilters()
    local f = ns.db.settings.filters
    for key, value in pairs(DEFAULT_FILTERS) do f[key] = value end
    f.skillupColors = { true, true, true }
    View:RefreshList()
end

-- Shift a menu checkbox (box and label) one checkbox to the right, under its parent option.
local function indent(item)
    item:AddInitializer(function(button)
        if button.leftTexture1 then
            button.leftTexture1:ClearAllPoints()
            button.leftTexture1:SetPoint("LEFT", SUB_INDENT, 0)
        end
    end)
end

local function buildFilterMenu(_, root)
    local f = ns.db.settings.filters
    local function add(text, key)
        root:CreateCheckbox(text, function() return f[key] end, function()
            f[key] = not f[key]
            View:RefreshList()
        end)
    end
    add(L.FILTER_LEARNED, "learned")
    add(L.FILTER_UNLEARNED, "unlearned")
    -- Options under "Not learned" (indented); ticking one turns "Not learned" on.
    local function sub(text, key)
        local item = root:CreateCheckbox(text, function() return f[key] end, function()
            f[key] = not f[key]
            if f[key] then f.unlearned = true end
            View:RefreshList()
        end)
        indent(item)
    end
    sub(L.FILTER_LEARNABLE, "unlearnedLearnable")
    sub(L.FILTER_FROM_TRAINER, "unlearnedTrainer")
    sub(L.FILTER_FROM_RECIPE, "unlearnedRecipe")
    if ns.Questie.Available() then sub(L.FILTER_NEAREST, "unlearnedNearest") end -- needs NPC locations
    add(L.FILTER_CRAFTABLE, "haveMats")
    add(L.FILTER_SKILLUP, "skillup")
    -- Skill-up colours (1 orange, 2 yellow, 3 green); ticking one turns "Gives skill-ups" on.
    for i = 1, 3 do
        local colour = W.DIFFICULTY[i - 1]
        local text = colour:WrapTextInColorCode((L.SKILLUP_COLORS[i]:gsub("^%l", string.upper)))
        local item = root:CreateCheckbox(text, function() return f.skillupColors[i] end, function()
            f.skillupColors[i] = not f.skillupColors[i]
            if f.skillupColors[i] then f.skillup = true end
            View:RefreshList()
        end)
        indent(item) -- under "Gives skill-ups"
    end
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

    -- (The rank is shown as a skill bar in the window header: ns.UI.SetRankBar.)

    -- Friends with this profession (Fellowship Ledger); hover to list them.
    self.friendsBtn = W.Button(left, "", 96, 20)
    -- positioned in View:Layout (row 1, right of the character picker)
    self.friendsBtn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.FRIENDS_HEADER, W.GOLD:GetRGB())
        ns.UI.views.guide.AddFriendsToTooltip(GameTooltip, View.friends or {})
        GameTooltip:AddLine(L.FRIENDS_NOTE, 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    self.friendsBtn:SetScript("OnLeave", GameTooltip_Hide)
    self.friendsBtn:SetScript("OnClick", function(btn) btn:GetScript("OnEnter")(btn) end)

    self.notice = W.Text(left, "GameFontDisableSmall")
    self.notice:SetPoint("TOPLEFT", self.charBtn, "BOTTOMLEFT", 2, -6)
    -- width set in Layout (narrower when the Friends button shows)

    self.openBtn = W.Button(left, "", 170, 22)
    self.openBtn:SetPoint("TOPLEFT", self.notice, "BOTTOMLEFT", -2, -4)
    self.openBtn:SetScript("OnClick", function()
        if View.browsing then ns.UI.SetBrowse(View.skill, false) return end
        ns.Crafting.OpenProfession(View.skill)
    end)

    self.search = W.SearchBox(left, LEFT_WIDTH - 120, function(text)
        View.query = ns.util.Query(text)
        View:RefreshList()
    end)
    if self.search.Instructions then self.search.Instructions:SetText(L.SEARCH_RECIPES) end

    -- Blizzard's filter dropdown: shows a red X to reset when any filter is changed.
    self.filterBtn = CreateFrame("DropdownButton", nil, left, "WowStyle1FilterDropdownTemplate")
    self.filterBtn:SetWidth(90)
    self.filterBtn:SetDefaultCallback(resetFilters)
    self.filterBtn:SetIsDefaultCallback(filtersAreDefault)
    self.filterBtn:SetupMenu(buildFilterMenu)

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
-- Left column, top to bottom with explicit offsets so nothing overlaps:
--   row 1 (y 0):  character picker | Friends button (right, when shown)
--   row 2:        note text (full width)
--   row 3:        "Open <profession>" button (when shown)
--   then the search + Filter row and the list.
function View:Layout(showOpen)
    self.friendsBtn:ClearAllPoints()
    self.friendsBtn:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", LEFT_WIDTH - 6, -9)
    local y = 28 -- below row 1
    self.notice:SetWidth(LEFT_WIDTH - 20)
    local noteH = (self.notice:GetText() or "") ~= "" and self.notice:GetStringHeight() or 0
    self.notice:ClearAllPoints()
    self.notice:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -(8 + y))
    if noteH > 0 then y = y + noteH + 6 end
    self.openBtn:ClearAllPoints()
    self.openBtn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 8, -(8 + y))
    if showOpen then y = y + 26 end
    self.search:ClearAllPoints()
    self.search:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 14, -(8 + y + 4))
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
    -- Skill bar in the header: the viewed character's rank in this profession.
    ns.UI.SetRankBar(prof and prof.rank, prof and prof.max,
        prof and (profName .. " - " .. (c and ns.CharName(c.key) or "")), profName,
        c and ns.RankUp.ButtonFor(c.key, self.skill))
    View.friends = ns.Friends.For(self.skill)
    self.friendsBtn:SetShown(#View.friends > 0)
    self.friendsBtn:SetText(L.FRIENDS_BUTTON:format(#View.friends))

    local notices, showOpen = {}, false
    -- Browsing a profession none of your characters have (from its guide page).
    self.browsing = #Characters.WithProfession(ns.db, self.skill, ns.charKey) == 0
    if self.browsing then
        notices[#notices + 1] = L.BROWSE_NOTE:format(profName)
        showOpen = true
        self.openBtn:SetText(L.BROWSE_BACK)
        self.openBtn:SetEnabled(true)
        isMe = true -- the logged-in character's bags count for the materials
    end
    if not isMe then notices[#notices + 1] = L.VIEWING_ALT:format(c and ns.CharName(c.key) or "?") end
    if prof and not prof.scannedAt and not pInfo.noRecipes then
        notices[#notices + 1] = (prof.quickAt and L.QUICK_SCANNED or L.NOT_SCANNED):format(profName)
    end
    if not self.browsing and isMe and prof and not self:IsLive() and not pInfo.noRecipes and not ns.fake then
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
    if self.filterBtn and self.filterBtn.ValidateResetState then self.filterBtn:ValidateResetState() end
    local items = self:BuildItems()
    self.list:SetItems(items)
    self.empty:SetText(#items == 0 and (self.browsing and L.BROWSE_NONE or L.NO_RECIPES) or "")
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
