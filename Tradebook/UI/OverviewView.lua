-- UI/OverviewView.lua
-- Professions: the logged-in character's professions, like the game's Professions book. Two
-- primary boxes (blank while a slot is free) and the secondary professions (greyed out until
-- learned), each with a large icon, rank and skill bar. Click one to open its tab. The window
-- opens here when no profession window is open (the K key, the minimap button, /tb).

local _, ns = ...
local L, W = ns.L, ns.W

local View = {}
ns.UI.RegisterView("overview", View)

local RANK_OF_CAP = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }
local PAD, GAP, HEADER_H = 12, 10, 26
local PRIMARY_H, SECONDARY_H = 70, 58
local PRIMARY_MAX_W, SECONDARY_MAX_W = 300, 230 -- boxes don't stretch across a wide window
local PRIMARY_ICON, SECONDARY_ICON = 52, 40

local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- One profession box: border, big icon, name, rank and a skill bar.
local function newBox(parent, iconSize)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetBackdrop(BACKDROP)
    b:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
    b:SetBackdropBorderColor(0.5, 0.42, 0.3, 1)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:GetHighlightTexture():SetAlpha(0.35)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(iconSize, iconSize)
    b.icon:SetPoint("LEFT", 9, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- Smaller boxes (secondary) get a smaller name, so name, rank and bar fit beside the icon.
    b.name = W.Text(b, iconSize >= 48 and "GameFontNormalLarge" or "GameFontNormal")
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 10, 0)
    b.name:SetPoint("RIGHT", -10, 0)
    b.rank = W.Text(b, "GameFontHighlightSmall")
    b.rank:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
    b.bar = CreateFrame("StatusBar", nil, b)
    b.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    b.bar:SetStatusBarColor(0.0, 0.45, 0.85)
    b.bar:SetHeight(12)
    b.bar:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 10, 0)
    b.bar:SetPoint("RIGHT", -14, 0)
    b.bar.bg = b.bar:CreateTexture(nil, "BACKGROUND")
    b.bar.bg:SetAllPoints()
    b.bar.bg:SetColorTexture(0, 0, 0, 0.6)
    b.bar.text = W.Text(b.bar, "GameFontHighlightSmall", "CENTER")
    b.bar.text:SetPoint("CENTER", 0, 0)
    b:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip[1], 1, 1, 1)
        for i = 2, #self.tip do GameTooltip:AddLine(self.tip[i], nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-- Fill a box: def (Data/Professions.lua entry) and prof ({ rank, max } or nil). With no def
-- the box is blank (a free primary slot); a def without prof is greyed out (not learned).
local function fillBox(b, def, prof)
    local learned = def and prof
    b.icon:SetShown(def ~= nil)
    b.name:SetShown(def ~= nil)
    b.rank:SetShown(def ~= nil)
    b.bar:SetShown(learned and true or false)
    if not def then
        b.tip = { L.OVERVIEW_EMPTY_SLOT, L.OVERVIEW_EMPTY_TIP }
        b:SetScript("OnClick", nil)
        b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        return
    end
    local name = L[def.name] or def.name
    b.icon:SetTexture(def.icon)
    b.icon:SetDesaturated(not learned)
    b.icon:SetAlpha(learned and 1 or 0.45)
    b.name:SetText(name)
    b:SetBackdropBorderColor(learned and 0.5 or 0.3, learned and 0.42 or 0.3, learned and 0.3 or 0.3, 1)
    if learned then
        b.name:SetTextColor(W.GOLD:GetRGB())
        local rank = RANK_OF_CAP[prof.max]
        b.rank:SetText(rank and L.RANK_NAMES[rank] or "")
        b.bar:SetMinMaxValues(0, math.max(1, prof.max or 1))
        b.bar:SetValue(prof.rank or 0)
        b.bar.text:SetText(L.SKILL_RANK:format(prof.rank or 0, prof.max or 0))
        b.tip = { name, L.OVERVIEW_OPEN_TIP }
    else
        b.name:SetTextColor(W.GREY:GetRGB())
        b.rank:SetText(W.ColorText(W.GREY, L.OVERVIEW_NOT_LEARNED))
        b.tip = { name, L.OVERVIEW_NOT_LEARNED_TIP }
    end
    b:SetScript("OnClick", function() ns.UI.SelectTab(def.id) end)
end

local function header(f, text)
    local h = W.Text(f, "GameFontNormalLarge")
    h:SetText(text)
    h.count = W.Text(f, "GameFontDisable")
    h.count:SetPoint("LEFT", h, "RIGHT", 8, 0)
    return h
end

function View:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    self.primaryHeader = header(f, L.OVERVIEW_PRIMARY)
    self.secondaryHeader = header(f, L.OVERVIEW_SECONDARY)
    self.primary, self.secondary = {}, {}
    for i = 1, ns.Characters.MAIN_SLOTS do self.primary[i] = newBox(f, PRIMARY_ICON) end
    self.note = W.Text(f, "GameFontDisableSmall")
    f:SetScript("OnSizeChanged", function() View:Layout() end)
end

-- Boxes in rows of `perRow`, `height` tall, from y down; returns the y below them.
local function placeRow(f, boxes, perRow, height, y, maxWidth)
    local width = math.min(maxWidth, (f:GetWidth() - 2 * PAD - (perRow - 1) * GAP) / perRow)
    for i, b in ipairs(boxes) do
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        b:ClearAllPoints()
        b:SetSize(math.max(60, width), height)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + col * (width + GAP), y - row * (height + GAP))
    end
    local rows = math.ceil(#boxes / perRow)
    return y - rows * height - (rows - 1) * GAP
end

function View:Layout()
    local f = self.frame
    if not f or f:GetWidth() < 1 then return end
    local y = -PAD
    self.primaryHeader:ClearAllPoints()
    self.primaryHeader:SetPoint("TOPLEFT", PAD, y)
    y = placeRow(f, self.primary, #self.primary, PRIMARY_H, y - HEADER_H, PRIMARY_MAX_W) - 2 * GAP
    self.secondaryHeader:ClearAllPoints()
    self.secondaryHeader:SetPoint("TOPLEFT", PAD, y)
    y = placeRow(f, self.secondary, math.max(1, #self.secondary), SECONDARY_H, y - HEADER_H,
        SECONDARY_MAX_W) - 2 * GAP
    self.note:ClearAllPoints()
    self.note:SetPoint("TOPLEFT", PAD, y)
    self.note:SetPoint("RIGHT", -PAD, 0)
end

function View:Show()
    self:Refresh()
end

function View:Refresh()
    if not self.frame then return end
    local c = ns.char
    local slots = ns.Characters.ProfessionSlots(ns.Professions.list, c and c.professions)
    for i, b in ipairs(self.primary) do
        local s = slots.main[i]
        fillBox(b, s and s.def, s and s.prof)
    end
    for i, s in ipairs(slots.secondary) do
        self.secondary[i] = self.secondary[i] or newBox(self.frame, SECONDARY_ICON)
        fillBox(self.secondary[i], s.def, s.prof)
    end
    self.primaryHeader.count:SetText(L.OVERVIEW_COUNT:format(#slots.main, ns.Characters.MAIN_SLOTS))
    self.secondaryHeader.count:SetText(L.OVERVIEW_COUNT:format(slots.secondaryKnown, #slots.secondary))
    self.note:SetText(slots.mainFree > 0 and L.OVERVIEW_CAN_LEARN:format(slots.mainFree) or "")
    self:Layout()
end
