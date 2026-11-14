-- UI/RankUp.lua
-- "Train <rank>" pop-up, opened from the button in the skill bar once a character can train
-- the next rank (Data/RankUps.lua). It shows the requirements (skill, level) and the ways to
-- train: the nearest trainers, a book (auction/vendor price and where it's sold), or a quest
-- (giver, requirements such as level and reputation, prerequisite quests).
-- Locations come from Questie and prices from Auctionator when they are installed.

local _, ns = ...
local L, W, Compat = ns.L, ns.W, ns.Compat

local RankUp = {}
ns.RankUp = RankUp

local popup

local function ensure()
    if popup then return popup end
    popup = CreateFrame("Frame", "TradebookRankUpFrame", UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(440, 420)
    popup:SetPoint("CENTER", 0, 40)
    popup:SetFrameStrata("DIALOG")
    popup:SetToplevel(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:SetClampedToScreen(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup.title = W.Text(popup, "GameFontHighlight", "CENTER")
    popup.title:SetPoint("TOP", 0, -5)
    local body = CreateFrame("Frame", nil, popup)
    body:SetPoint("TOPLEFT", 14, -32)
    body:SetPoint("BOTTOMRIGHT", -10, 12)
    popup.pane = ns.Details.NewLinePane(body)
    tinsert(UISpecialFrames, "TradebookRankUpFrame") -- Escape closes it
    popup:Hide()
    return popup
end

local function check(ok)
    return ok and W.GREEN or W.RED
end

-- One NPC line: name (title) on the left, place and distance on the right; click for a
-- waypoint, and (nearby, out of combat) target and mark it.
local function npcLine(pane, e, indent, note)
    local text = e.name .. (e.sub and ("  " .. W.ColorText(W.GREY, "<" .. e.sub .. ">")) or "")
    if note then text = text .. "  " .. note end
    pane:Add({ indent = indent, text = text, right = ns.Details.PlaceText(e),
        onClick = function() ns.Waypoints.Set(e.areaID, e.x, e.y, e.name) end,
        target = e.name,
        tooltip = e.sub and { e.name, e.sub, L.WAYPOINT_TARGET_CLICK } or { e.name, L.WAYPOINT_TARGET_CLICK } })
end

local STANDINGS = { { 42000, 8 }, { 21000, 7 }, { 9000, 6 }, { 3000, 5 }, { 0, 4 } }
local function standingName(value)
    for _, s in ipairs(STANDINGS) do
        if value >= s[1] then return _G["FACTION_STANDING_LABEL" .. s[2]] or tostring(value) end
    end
    return tostring(value)
end

local function addTrainers(pane, skill, nextRank, faction, profName)
    pane:Add({ text = L.RANKUP_BY_TRAINER, font = "GameFontNormal", color = W.GOLD })
    local list = ns.Questie.RankTrainers(skill, nextRank.rank, faction)
    if #list == 0 then
        pane:Add({ indent = 1, text = L.RANKUP_ANY_TRAINER:format(profName, L.RANK_NAMES[nextRank.rank]),
            color = W.GREY })
        if not ns.Questie.Available() then pane:Add({ indent = 1, text = L.RANKUP_NEED_QUESTIE, color = W.GREY }) end
    else
        local unsure = false
        for _, e in ipairs(list) do
            npcLine(pane, e, 1, e.confirmed and W.ColorText(W.GREEN, L.RANKUP_CONFIRMED) or nil)
            if not e.confirmed then unsure = true end
        end
        if unsure then pane:Add({ indent = 1, text = L.RANKUP_UNCONFIRMED, color = W.GREY }) end
    end
    pane:Gap()
end

local function addBook(pane, nextRank, c, profName)
    local book = nextRank.book
    local name = Compat.ItemInfo(book) or ("item:" .. book)
    pane:Add({ text = L.RANKUP_BY_BOOK, font = "GameFontNormal", color = W.GOLD })
    -- The book itself, with how many of your characters already have one.
    local have = ns.Reagents.Have(ns.db, c, book)
    local others = ns.Reagents.OnOtherCharacters(ns.db, book, c and c.key)
    local right = (have.total > 0) and W.ColorText(W.GREEN, L.RANKUP_YOU_HAVE) or ""
    pane:Add({ indent = 1, itemID = book, text = name, right = right, large = true, font = "GameFontHighlight" })
    local reqs = {}
    if nextRank.bookSkill then reqs[#reqs + 1] = L.REQUIRES_SKILL:format(profName, nextRank.bookSkill) end
    if nextRank.bookLevel then reqs[#reqs + 1] = L.RANKUP_LEVEL:format(nextRank.bookLevel) end
    if #reqs > 0 then pane:Add({ indent = 2, text = table.concat(reqs, ", "), color = W.GREY }) end
    for _, o in ipairs(others) do
        local who = Compat.ClassColor(o.class):WrapTextInColorCode(o.name)
        pane:Add({ indent = 2, text = L.CHAR_HAS:format(who, o.total) })
    end
    -- Prices (Auctionator).
    if ns.Prices.Available() then
        local p = ns.Prices.Get(book)
        pane:Add({ indent = 2, text = L.PRICE_PURCHASE_FROM, color = W.GOLD })
        if p.auction then
            local age = p.age and p.age > 0 and ("  " .. W.ColorText(W.GREY, L.PRICE_AGE:format(p.age))) or ""
            pane:Add({ indent = 3, text = L.PRICE_AUCTION, right = ns.Prices.Money(p.auction) .. age })
        end
        local vendor = p.vendor or nextRank.bookPrice
        if vendor then pane:Add({ indent = 3, text = L.PRICE_VENDOR, right = ns.Prices.Money(vendor) }) end
        if not p.auction and not vendor then pane:Add({ indent = 3, text = L.PRICE_NONE, color = W.GREY }) end
    elseif nextRank.bookPrice then
        pane:Add({ indent = 2, text = L.PRICE_PURCHASE_FROM, color = W.GOLD })
        pane:Add({ indent = 3, text = L.PRICE_VENDOR, right = ns.Prices.Money(nextRank.bookPrice) })
    end
    -- Where it's sold (Questie).
    local where = ns.Questie.HasSources(book) and ns.Questie.WhereToGet(book)
    if where and #where.vendors > 0 then
        pane:Add({ indent = 2, text = L.SOLD_BY .. ":", color = W.GOLD })
        for _, e in ipairs(where.vendors) do npcLine(pane, e, 3) end
    elseif not ns.Questie.Available() then
        pane:Add({ indent = 2, text = L.RANKUP_NEED_QUESTIE, color = W.GREY })
    end
    pane:Gap()
end

local function addQuest(pane, nextRank, faction, c, isMe, profName)
    pane:Add({ text = L.RANKUP_BY_QUEST, font = "GameFontNormal", color = W.GOLD })
    local q = ns.Questie.RankQuest(nextRank.quest, faction)
    if not q then
        pane:Add({ indent = 1, text = L.RANKUP_QUEST_NAME:format(nextRank.quest) })
        if not ns.Questie.Available() then pane:Add({ indent = 1, text = L.RANKUP_NEED_QUESTIE, color = W.GREY }) end
        pane:Gap()
        return
    end
    local done = isMe and Compat.Call("C_QuestLog.IsQuestFlaggedCompleted", q.id)
    pane:Add({ indent = 1, text = L.RANKUP_QUEST_NAME:format(q.name),
        right = done and W.ColorText(W.GREEN, L.RANKUP_QUEST_DONE) or nil })
    -- Its requirements, checked against the character where possible.
    if q.level and q.level > 1 then
        local ok = c and c.level and c.level >= q.level
        pane:Add({ indent = 2, text = L.RANKUP_LEVEL:format(q.level),
            right = c and c.level and check(ok):WrapTextInColorCode(L.RANKUP_YOU:format(c.level)) or nil })
    end
    if q.skill and q.skill[2] then
        local prof = c and c.professions[nextRank.skillLine or 0]
        local rank = prof and prof.rank
        pane:Add({ indent = 2, text = L.REQUIRES_SKILL:format(profName, q.skill[2]),
            right = rank and check(rank >= q.skill[2]):WrapTextInColorCode(L.RANKUP_YOU:format(rank)) or nil })
    end
    if q.rep then
        local factionName, _, _, _, _, barValue = Compat.Call("GetFactionInfoByID", q.rep[1])
        local text = L.RANKUP_REP:format(standingName(q.rep[2]), factionName or ("#" .. q.rep[1]))
        local right
        if isMe and barValue then
            right = check(barValue >= q.rep[2]):WrapTextInColorCode(L.RANKUP_YOU:format(standingName(barValue)))
        end
        pane:Add({ indent = 2, text = text, right = right })
    end
    for _, pre in ipairs(q.prereqs) do
        local preDone = isMe and Compat.Call("C_QuestLog.IsQuestFlaggedCompleted", pre.id)
        pane:Add({ indent = 2, text = L.RANKUP_PREREQ:format(pre.name),
            right = isMe and check(preDone):WrapTextInColorCode(preDone and L.RANKUP_QUEST_DONE or L.RANKUP_QUEST_NOT_DONE) or nil })
    end
    if #q.givers > 0 then
        pane:Add({ indent = 2, text = L.RANKUP_GIVER, color = W.GOLD })
        for _, e in ipairs(q.givers) do npcLine(pane, e, 3) end
    end
    pane:Gap()
end

function RankUp.Refresh()
    if not (popup and popup:IsShown() and popup.charKey) then return end
    local c = ns.db.characters[popup.charKey]
    local skill = popup.skill
    local prof = c and c.professions[skill]
    local ready, nextRank = ns.RankUps.Ready(skill, prof)
    local def = ns.Professions.Get(skill)
    local profName = def and (L[def.name] or def.name) or ""
    local pane = popup.pane
    pane:Begin()
    if not nextRank then
        popup.title:SetText(profName)
        pane:Add({ text = L.RANKUP_NOTHING, color = W.GREY })
        pane:Finish()
        return
    end
    nextRank.skillLine = skill
    local rankName = L.RANK_NAMES[nextRank.rank]
    popup.title:SetText(L.RANKUP_TITLE:format(rankName, profName))
    local isMe = popup.charKey == ns.charKey
    local who = W.ClassName(c)
    pane:Add({ text = L.RANKUP_RAISES:format(who, profName, nextRank.cap) })
    pane:Gap()

    -- Requirements.
    pane:Add({ text = L.RANKUP_REQUIREMENTS, font = "GameFontNormal", color = W.GOLD })
    for _, r in ipairs(ns.RankUps.Requirements(nextRank, prof, c.level)) do
        local text = r.key == "skill" and L.REQUIRES_SKILL:format(profName, r.need) or L.RANKUP_LEVEL:format(r.need)
        local right = r.have and check(r.ok):WrapTextInColorCode(L.RANKUP_YOU:format(r.have)) or nil
        pane:Add({ indent = 1, text = text, right = right })
    end
    -- Cost: the trainer's fee, or the book's price. Gold is checked for the character you're on.
    local cost, costNote = nextRank.cost, L.RANKUP_COST_BASE
    -- A trainer's window was read for this rank: its real cost.
    local seen = not nextRank.book and not nextRank.quest and ns.Trainers.RankInfo(skill, nextRank.rank)
    if seen and seen.cost then cost, costNote = seen.cost, nil end
    if nextRank.book then
        local p = ns.Prices.Available() and ns.Prices.Get(nextRank.book) or {}
        cost, costNote = ns.Prices.Cheapest(p) or nextRank.bookPrice, nil
    end
    if cost then
        local money = isMe and Compat.Call("GetMoney")
        local text = nextRank.book and L.RANKUP_COST_BOOK or L.RANKUP_COST
        if costNote then text = text .. "  " .. W.ColorText(W.GREY, costNote) end
        local right = ns.Prices.Money(cost)
        if money then right = right .. "  " .. check(money >= cost):WrapTextInColorCode(L.RANKUP_YOU:format(ns.Prices.Money(money))) end
        pane:Add({ indent = 1, text = text, right = right })
    end
    if not ready then pane:Add({ indent = 1, text = L.RANKUP_NOT_YET, color = W.GREY }) end
    pane:Gap()

    -- Ways to train it.
    local faction = c.faction
    if nextRank.book then addBook(pane, nextRank, c, profName) end
    if nextRank.quest then addQuest(pane, nextRank, faction, c, isMe, profName) end
    if not nextRank.book and not nextRank.quest then addTrainers(pane, skill, nextRank, faction, profName) end
    pane:Finish()
end

-- Open for a character's profession (toggles when it's already showing that one).
function RankUp.Show(charKey, skill)
    local p = ensure()
    if p:IsShown() and p.charKey == charKey and p.skill == skill then
        p:Hide()
        return
    end
    p.charKey, p.skill = charKey, skill
    p:Show()
    RankUp.Refresh()
end

function RankUp.Hide()
    if popup then popup:Hide() end
end

-- The skill-bar button: { text, onClick } when the viewed character can train the next rank.
function RankUp.ButtonFor(charKey, skill)
    local c = ns.db.characters[charKey]
    local prof = c and c.professions[skill]
    local ready, nextRank = ns.RankUps.Ready(skill, prof)
    if not ready then return nil end
    return {
        text = L.RANKUP_BUTTON:format(L.RANK_NAMES[nextRank.rank]),
        onClick = function() RankUp.Show(charKey, skill) end,
    }
end
