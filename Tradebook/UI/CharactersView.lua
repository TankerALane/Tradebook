-- UI/CharactersView.lua
-- Every saved character: class, level, play type, last seen, professions; hide/delete;
-- a stale-data warning; and who is closest to each profession's next rank.

local _, ns = ...
local L, W = ns.L, ns.W
local Characters = ns.Characters

local View = {}
ns.UI.RegisterView("characters", View)

local SUMMARY_WIDTH = 280
local ROW_MIN = 74 -- icon, name, two info lines and the buttons (narrow layout)
local PROF_LINE = 16 -- one profession line (font + spacing), rounded up

-- A character's row: tall enough for every profession line (two primary and three secondary
-- need more than the minimum; a fixed height let them run into the next row).
local function rowHeight(c)
    local n = 0
    for _, p in ipairs(ns.Professions.list) do
        if c.professions and c.professions[p.id] then n = n + 1 end
    end
    return math.max(ROW_MIN, 6 + n * PROF_LINE + 8)
end

-- Row layout. Wide: name and info on one line each, professions 236 past the icon, then
-- the "not learned" column and Hide/Delete at the right. Narrow (the row can't hold all
-- that): info on two lines, professions closer, Hide/Delete under the info, and the
-- "not learned" column only when it still fits (otherwise it is in the row's tooltip).
local ICON_RIGHT = 46 -- 6 + 32 icon + 8
local PROFS_WIDE, PROFS_NARROW = 236, 170
local COLS = 110 + 64 -- profession name + rank
local MISSING = 14 + 130
local BUTTONS = 8 + 64 + 12 + 64 + 8
local WIDE_NEED = ICON_RIGHT + PROFS_WIDE + COLS + MISSING + BUTTONS

local LAYOUT_WIDE = { wide = true, missing = true }
local LAYOUT_NARROW = { wide = false, missing = true }
local LAYOUT_NARROWEST = { wide = false, missing = false }

local function layoutFor(width)
    if width >= WIDE_NEED then return LAYOUT_WIDE end
    if width >= ICON_RIGHT + PROFS_NARROW + COLS + MISSING + 8 then return LAYOUT_NARROW end
    return LAYOUT_NARROWEST
end

StaticPopupDialogs["TRADEBOOK_DELETE_CHARACTER"] = {
    text = L.DELETE_CONFIRM,
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, data)
        Characters.Delete(ns.db, data)
        ns.TabLayout.Forget(ns.db.settings, data)
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
    row.warn:SetWidth(220) -- wraps before the profession column (which starts 228 in)
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
    row:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for i, line in ipairs(self.tip) do
            if i == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, nil, nil, nil, true) end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
end

local function applyLayout(row, layout)
    if row.layout == layout then return end
    row.layout = layout
    row.profs:ClearAllPoints()
    row.profs:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", layout.wide and PROFS_WIDE or PROFS_NARROW, 0)
    row.name:SetWidth(layout.wide and 0 or PROFS_NARROW - 6)
    row.name:SetWordWrap(false)
    row.hide:ClearAllPoints()
    row.delete:ClearAllPoints()
    if layout.wide then
        row.hide:SetPoint("TOPRIGHT", -76, -8)
        row.delete:SetPoint("TOPRIGHT", -8, -8)
    else
        row.hide:SetPoint("BOTTOMLEFT", ICON_RIGHT, 6)
        row.delete:SetPoint("LEFT", row.hide, "RIGHT", 6, 0)
    end
    row.missing:SetShown(layout.missing)
    row.warn:SetShown(layout.wide)
end

local function initRow(row, c)
    row.data = c
    -- Width not known yet: the narrowest layout (never overlaps), not the wide one.
    local layout = View.layout or LAYOUT_NARROWEST
    applyLayout(row, layout)
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
    local now = GetServerTime()
    local stale = Characters.IsStale(c, now, ns.db.settings.staleDays, ns.charKey)
        and L.STALE:format(Characters.DaysSince(c, now)) or nil
    local levelText = string.format("%s %s  -  %s", LEVEL or "Level", tostring(c.level or "?"), playType)
    if layout.wide then
        row.info:SetText(levelText .. "  -  " .. seen)
    else
        -- Narrow: last seen on its own line, red when the data is stale (the warning is in the tooltip).
        row.info:SetText(levelText .. "\n" .. (stale and W.ColorText(W.RED, seen) or seen))
    end
    row.info:SetSpacing(3)
    row.warn:SetText(stale or "")
    local names, ranks, missingLines = {}, {}, {}
    local tip = { W.ClassName(c) }
    if stale then tip[#tip + 1] = W.ColorText(W.RED, stale) end
    for _, p in ipairs(ns.Professions.list) do
        local prof = c.professions[p.id]
        if prof then
            local missing = ns.Recipes.Missing(ns.db, c, p.id)
            local profName = L[p.name] or p.name
            names[#names + 1] = profName
            ranks[#ranks + 1] = L.SKILL_RANK:format(prof.rank or 0, prof.max or 0)
            missingLines[#missingLines + 1] = (missing and #missing > 0) and L.MISSING_FOR:format(#missing) or " "
            if not layout.missing and missing and #missing > 0 then
                tip[#tip + 1] = profName .. ": " .. W.ColorText(W.GREY, L.MISSING_FOR:format(#missing))
            end
        end
    end
    row.tip = (not layout.wide and #tip > 1) and tip or nil
    -- Explicit height: without it the client keeps these at one line and cuts the rest ("...").
    local _, size = row.profs:GetFont()
    local height = math.max(1, #names) * ((size or 12) + 3)
    for _, col in ipairs({ { row.profs, names }, { row.ranks, ranks }, { row.missing, missingLines } }) do
        col[1]:SetSpacing(3)
        col[1]:SetHeight(height)
        col[1]:SetText(table.concat(col[2], "\n"))
    end
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

    self.list = W.List(f, rowHeight, createRow, initRow)
    self.list:SetPoint("TOPLEFT", SUMMARY_WIDTH, -40)
    self.list:SetPoint("BOTTOMRIGHT", -22, 8)
    self.list:HookScript("OnSizeChanged", function(_, width)
        local layout = layoutFor(width)
        if layout == self.layout then return end
        self.layout = layout
        if f:IsVisible() then self:Refresh() end
    end)
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
    -- The row layout from the list's width now (its size-change hook alone missed some
    -- changes, leaving the wide layout on a narrow window: Hide/Delete over the professions).
    local width = self.list:GetWidth()
    if width and width > 0 then self.layout = layoutFor(width) end
    self.list:SetItems(Characters.List(ns.db, ns.charKey, ns.db.settings.showHidden))
end
