-- UI/CharactersView.lua
-- Every saved character: class, level, play type, last seen, professions; hide/delete;
-- a stale-data warning; and who is closest to each profession's next rank.

local _, ns = ...
local L, W = ns.L, ns.W
local Characters = ns.Characters

local View = {}
ns.UI.RegisterView("characters", View)

local SUMMARY_WIDTH = 280

StaticPopupDialogs["TRADEBOOK_DELETE_CHARACTER"] = {
    text = L.DELETE_CONFIRM,
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, data)
        Characters.Delete(ns.db, data)
        ns.Recipes.Invalidate()
        ns.UI.Refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function createRow(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(32, 32)
    row.icon:SetPoint("TOPLEFT", 6, -6)
    row.name = W.Text(row, "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.info = W.Text(row, "GameFontHighlightSmall")
    row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    -- Professions in three aligned columns: name | rank (right-aligned) | not learned (grey).
    local function column(width, justify)
        local fs = W.Text(row, "GameFontHighlightSmall", justify)
        fs:SetWidth(width)
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(false)
        return fs
    end
    row.profs = column(110)
    row.profs:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 236, 0)
    row.ranks = column(64, "RIGHT")
    row.ranks:SetPoint("TOPLEFT", row.profs, "TOPRIGHT", 0, 0)
    row.missing = column(130)
    row.missing:SetPoint("TOPLEFT", row.ranks, "TOPRIGHT", 14, 0)
    row.warn = W.Text(row, "GameFontRedSmall")
    row.warn:SetPoint("TOPLEFT", row.info, "BOTTOMLEFT", 0, -3)
    row.hide = W.Button(row, L.HIDE, 64, 20)
    row.hide:SetPoint("TOPRIGHT", -76, -8)
    row.hide:SetScript("OnClick", function(self)
        local c = self:GetParent().data
        c.hidden = not c.hidden or nil
        ns.Recipes.Invalidate()
        View:Refresh()
        ns.UI.UpdateTabs()
    end)
    row.delete = W.Button(row, L.DELETE, 64, 20)
    row.delete:SetPoint("TOPRIGHT", -8, -8)
    row.delete:SetScript("OnClick", function(self)
        local c = self:GetParent().data
        StaticPopup_Show("TRADEBOOK_DELETE_CHARACTER", ns.CharName(c.key), nil, c.key)
    end)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
end

local function initRow(row, c)
    row.data = c
    local isMe = c.key == ns.charKey
    local coords = c.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c.class]
    if coords then
        row.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        row.icon:SetTexCoord(unpack(coords))
    else
        row.icon:SetTexture(134400)
        row.icon:SetTexCoord(0, 1, 0, 1)
    end
    row.name:SetText(W.ClassName(c) .. (c.hidden and W.ColorText(W.GREY, "  (" .. L.HIDE .. ")") or ""))
    local playType = L.PLAYTYPE[c.playType or "unknown"] or L.PLAYTYPE.unknown
    local seen = isMe and L.NOW_ONLINE or L.LAST_SEEN:format(W.Ago(c.lastSeen))
    row.info:SetText(string.format("%s %s  -  %s  -  %s", LEVEL or "Level", tostring(c.level or "?"), playType, seen))
    local now = GetServerTime()
    if Characters.IsStale(c, now, ns.db.settings.staleDays, ns.charKey) then
        row.warn:SetText(L.STALE:format(Characters.DaysSince(c, now)))
    else
        row.warn:SetText("")
    end
    local names, ranks, missingLines = {}, {}, {}
    for _, p in ipairs(ns.Professions.list) do
        local prof = c.professions[p.id]
        if prof then
            local missing = ns.Recipes.Missing(ns.db, c, p.id)
            names[#names + 1] = L[p.name] or p.name
            ranks[#ranks + 1] = L.SKILL_RANK:format(prof.rank or 0, prof.max or 0)
            missingLines[#missingLines + 1] = (missing and #missing > 0) and L.MISSING_FOR:format(#missing) or " "
        end
    end
    row.profs:SetText(table.concat(names, "\n"))
    row.ranks:SetText(table.concat(ranks, "\n"))
    row.missing:SetText(table.concat(missingLines, "\n"))
    row.missing:SetTextColor(W.GREY:GetRGB())
    row.hide:SetText(c.hidden and L.UNHIDE or L.HIDE)
    row.hide:SetEnabled(not isMe)
    row.delete:SetEnabled(not isMe)
    row.bg:SetColorTexture(1, 1, 1, isMe and 0.06 or 0.02)
end

function View:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    self.title = W.Text(f, "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 12, -10)
    self.title:SetText(L.CHARACTERS)
    self.showHidden = W.Check(f, L.SHOW_HIDDEN, function(checked)
        ns.db.settings.showHidden = checked
        self:Refresh()
    end)
    self.showHidden:SetPoint("TOPRIGHT", -170, -6)

    -- Left column: one block per profession, stacked, with who is next to rank up.
    self.rankTitle = W.Text(f, "GameFontNormal")
    self.rankTitle:SetPoint("TOPLEFT", 12, -40)
    self.rankTitle:SetText(L.NEXT_RANKUP)
    self.summary = W.Text(f, "GameFontHighlightSmall")
    self.summary:SetPoint("TOPLEFT", self.rankTitle, "BOTTOMLEFT", 0, -8)
    self.summary:SetWidth(SUMMARY_WIDTH - 20)
    self.summary:SetJustifyV("TOP")
    self.summary:SetSpacing(3)

    self.list = W.List(f, 74, createRow, initRow)
    self.list:SetPoint("TOPLEFT", SUMMARY_WIDTH, -40)
    self.list:SetPoint("BOTTOMRIGHT", -22, 8)
end

-- "Ana  145/150  ->  Expert" / "Ana  ready to train Expert" for one profession.
local function rankUpText(skillLineID)
    local c, gap = Characters.ClosestToRankUp(ns.db, skillLineID, ns.charKey)
    if not c then return nil end
    local prof = c.professions[skillLineID]
    local nextRank = Characters.NextRank(prof.max)
    local rankName = nextRank and (L.RANK_NAMES[nextRank] or nextRank) or ""
    local who = ns.Compat.ClassColor(c.class):WrapTextInColorCode(c.name or c.key) -- first name
    if gap == 0 then return L.READY_TO_TRAIN:format(who, prof.rank or 0, prof.max or 0, rankName) end
    return L.CLOSEST_RANKUP:format(who, prof.rank or 0, prof.max or 0, gap, rankName)
end

function View:Show()
    self:Refresh()
end

function View:Refresh()
    self.showHidden:SetChecked(ns.db.settings.showHidden)
    local lines = {}
    for _, p in ipairs(ns.Professions.list) do
        local text = rankUpText(p.id)
        if text then
            lines[#lines + 1] = W.ColorText(W.GOLD, L[p.name] or p.name)
            lines[#lines + 1] = "   " .. text
        end
    end
    self.summary:SetText(#lines > 0 and table.concat(lines, "\n") or W.ColorText(W.GREY, L.MINIMAP_NONE))
    self.list:SetItems(Characters.List(ns.db, ns.charKey, ns.db.settings.showHidden))
end
