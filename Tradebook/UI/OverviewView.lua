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
-- The bronze slot frame of the default Professions window's slots (Professions-Slot-Frame)
-- around an icon, so it reads as a button you can drag to an action bar.
local function slotFrame(owner, icon, outset)
    local t = owner:CreateTexture(nil, "OVERLAY")
    t:SetAtlas("Professions-Slot-Frame")
    t:SetPoint("TOPLEFT", icon, "TOPLEFT", -outset, outset)
    t:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outset, -outset)
    return t
end

local function newBox(parent, iconSize)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetBackdrop(BACKDROP)
    b:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
    b:SetBackdropBorderColor(0.5, 0.42, 0.3, 1)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:GetHighlightTexture():SetAlpha(0.35)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(iconSize, iconSize)
    b.icon:SetPoint("LEFT", 11, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.iconFrame = slotFrame(b, b.icon, math.floor(iconSize * 0.08 + 0.5))
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
    -- Under the rank line (not at the icon's bottom: on the smaller secondary boxes that put
    -- the bar over the rank).
    b.bar:SetPoint("TOPLEFT", b.rank, "BOTTOMLEFT", 0, -4)
    -- Primary boxes leave room right of the bar for the Unlearn cross.
    b.bar:SetPoint("RIGHT", iconSize >= 48 and -28 or -14, 0)
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
    -- Drag the box to an action bar: the profession's spell (Alchemy, Smelting for Mining,
    -- Find Herbs for Herbalism...), when this character knows one.
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        if self.spellID then ns.TrackingButton.Pickup(self.spellID) end
    end)
    -- The tracking spell (Find Herbs, Find Minerals): a smaller icon at the right, just above
    -- the skill bar. Click to cast it (through a secure button laid over it out of combat,
    -- UI/TrackingButton.lua), or drag it to an action bar.
    local extra = ns.TrackingButton.Create(b)
    extra:SetSize(26, 26)
    -- Placed from the box itself, not the bar: the secure button laid over it can't be anchored
    -- (even indirectly) to a font string, and the bar hangs under the rank text. This puts it
    -- above the bar's right end in the primary boxes (Herbalism and Mining are primary).
    extra:SetPoint("TOPRIGHT", b, "TOPRIGHT", -14, -10)
    extra.label:Hide()
    extra.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    slotFrame(extra, extra.tex, 2)
    b.extra = extra
    -- Primary boxes: the game's red Unlearn cross right of the skill bar, like the default
    -- window (it opens the game's own pop-up, where you type UNLEARN to confirm).
    if iconSize >= 48 then
        b.unlearn = ns.UI.CreateUnlearnButton(b)
        b.unlearn:SetPoint("LEFT", b.bar, "RIGHT", 6, 0)
        b.unlearn:Hide()
    end
    return b
end

-- Fill a box: def (Data/Professions.lua entry) and prof ({ rank, max } or nil). With no def
-- the box is blank (a free primary slot); a def without prof is greyed out (not learned).
local function fillBox(b, def, prof)
    local learned = def and prof
    b.icon:SetShown(def ~= nil)
    b.iconFrame:SetShown(def ~= nil)
    b.iconFrame:SetDesaturated(not learned)
    b.name:SetShown(def ~= nil)
    b.rank:SetShown(def ~= nil)
    b.bar:SetShown(learned and true or false)
    if b.unlearn then
        local shots = ns.Screenshots and ns.Screenshots.trackingShot -- /tb shots: show it in the picture
        b.unlearn:SetShown(learned and def.primary and ns.UI.CanUnlearn() and (shots or not ns.fake) and true or false)
        b.unlearn.name, b.unlearn.skillLine = def and (L[def.name] or def.name), def and def.id
    end
    -- The profession's own spell (Alchemy, Smelting for Mining) drags from the box; a tracking
    -- spell (Find Herbs, Find Minerals) is a different thing: its own small icon.
    local main, second
    -- (/tb shots: every spell counts as known, so the made-up characters' boxes show them.)
    local known = ns.Screenshots and ns.Screenshots.trackingShot and function() return true end or nil
    for _, s in ipairs(learned and ns.TrackingButton.SpellsFor(def.id, known) or {}) do
        if s.tracking then second = second or s.spellID else main = main or s.spellID end
    end
    b.spellID = main
    b.extra:SetSpell(second and { spellID = second, cast = true, tracking = true } or nil, def and def.id)
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
        if b.spellID then b.tip[#b.tip + 1] = W.ColorText(W.GREEN, L.OVERVIEW_DRAG_TIP) end
    else
        b.name:SetTextColor(W.GREY:GetRGB())
        b.rank:SetText(W.ColorText(W.GREY, L.OVERVIEW_NOT_LEARNED))
        b.tip = { name, L.OVERVIEW_NOT_LEARNED_TIP }
    end
    b:SetScript("OnClick", function() ns.UI.SelectTab(def.id, true) end)
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
    -- (/tb shots can show another character: View.showKey.)
    local c = (View.showKey and ns.db.characters[View.showKey]) or ns.char
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
