-- UI/TrackingButton.lua
-- A profession's spells as icons on its tab: the profession itself (Tailoring, Smelting for
-- Mining, Fishing...) and the gathering tracking spell (Find Herbs, Find Minerals). Drag one
-- to an action bar, or click it. Forever's spellbook doesn't list these, so this is where
-- players find them.
--
-- Spell IDs from Forever's SkillLineAbility table (build 1.60.1.70938), each rank superseding
-- the one before: Alchemy 2259 3101 3464 11611, Blacksmithing 2018 3100 3538 9785, Enchanting
-- 7411 7412 7413 13920, Engineering 4036 4037 4038 12656, Leatherworking 2108 3104 3811 10662,
-- Tailoring 3908 3909 3910 12180, Cooking 2550 3102 3413 18260, First Aid 3273 3274 7924 10846,
-- Fishing 7620 7731 7732 18248, Mining (186) Smelting 2656. Tracking: Herbalism (182) Find
-- Herbs 2383 (8387 supersedes it), Mining Find Minerals 2580 (8388).
--
-- A profession with a recipe window opens through Tradebook (ns.Crafting.OpenProfession: not
-- protected, and it doesn't close the window when it's already open). Fishing and tracking
-- are cast, which is protected: the click goes through a secure button laid over the icon.
-- Like UI/TargetButtons.lua it is only attached out of combat and is detached when combat
-- starts (a secure child would stop the Tradebook window closing in combat). In combat those
-- icons can still be dragged; clicking them does nothing.

local _, ns = ...
local L, Compat = ns.L, ns.Compat

local TrackingButton = {}
ns.TrackingButton = TrackingButton

-- PURE. Profession -> its tracking spells, newest rank first.
TrackingButton.spells = {
    [182] = { 8387, 2383 }, -- Find Herbs
    [186] = { 8388, 2580 }, -- Find Minerals
}

-- PURE. Profession -> the spell that opens it (or casts it: Fishing), newest rank first.
TrackingButton.professionSpells = {
    [171] = { 11611, 3464, 3101, 2259 }, -- Alchemy
    [164] = { 9785, 3538, 3100, 2018 }, -- Blacksmithing
    [333] = { 13920, 7413, 7412, 7411 }, -- Enchanting
    [202] = { 12656, 4038, 4037, 4036 }, -- Engineering
    [165] = { 10662, 3811, 3104, 2108 }, -- Leatherworking
    [197] = { 12180, 3910, 3909, 3908 }, -- Tailoring
    [185] = { 18260, 3413, 3102, 2550 }, -- Cooking
    [129] = { 10846, 7924, 3274, 3273 }, -- First Aid
    [356] = { 18248, 7732, 7731, 7620 }, -- Fishing (cast, not a window)
    [186] = { 2656 }, -- Smelting
}

local CAST = { [356] = true } -- professions whose spell is cast rather than opening a window

local function isKnown(spellID)
    return Compat.Call("C_SpellBook.IsSpellKnown", spellID) == true
        or Compat.Call("IsPlayerSpell", spellID) == true
end

local function newest(list, known)
    for _, id in ipairs(list or {}) do
        if known(id) then return id end
    end
end

-- PURE (given isKnown). The tracking spell the player knows for a profession, or nil.
function TrackingButton.KnownSpell(skillLineID, known)
    return newest(TrackingButton.spells[skillLineID], known or isKnown)
end

-- PURE (given isKnown). The icons for a profession's tab, in order:
-- { { spellID, cast = true (secure cast) or false (opens the profession), tracking } }.
function TrackingButton.SpellsFor(skillLineID, known)
    known = known or isKnown
    local out = {}
    local prof = newest(TrackingButton.professionSpells[skillLineID], known)
    if prof then out[#out + 1] = { spellID = prof, cast = CAST[skillLineID] == true } end
    local track = newest(TrackingButton.spells[skillLineID], known)
    if track then out[#out + 1] = { spellID = track, cast = true, tracking = true } end
    return out
end

local function pickup(spellID)
    if not spellID then return end
    if Compat.Has("C_Spell.PickupSpell") then
        Compat.Call("C_Spell.PickupSpell", spellID)
    else
        Compat.Call("PickupSpell", spellID)
    end
end

-- Put a spell on the cursor (to drop on an action bar).
TrackingButton.Pickup = pickup

local function showTooltip(owner, icon)
    local spellID = icon.spellID
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if not (spellID and pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)) then
        GameTooltip:SetText(Compat.Call("C_Spell.GetSpellName", spellID) or "?", 1, 1, 1)
    end
    local tip = icon.tracking and L.TRACKING_TIP or (icon.cast and L.SPELL_CAST_TIP or L.SPELL_OPEN_TIP)
    GameTooltip:AddLine(tip, 0.2, 1, 0.2, true)
    if InCombatLockdown() then GameTooltip:AddLine(L.TRACKING_COMBAT, 1, 0.3, 0.3, true) end
    GameTooltip:Show()
end

local icons = {} -- every icon made, for attaching again after combat

local function detach(icon)
    local secure = icon.secure
    if not secure or InCombatLockdown() then return end
    secure:Hide()
    secure:ClearAllPoints()
    secure:SetParent(UIParent)
end

local function attach(icon)
    if InCombatLockdown() then return end
    if not (icon.spellID and icon.cast) then
        detach(icon)
        return
    end
    local secure = icon.secure
    if not secure then
        secure = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        -- Fires on down or up depending on the "cast on key down" setting.
        secure:RegisterForClicks("AnyUp", "AnyDown")
        secure:RegisterForDrag("LeftButton")
        secure:SetAttribute("type", "spell")
        secure:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        secure:SetScript("OnDragStart", function() pickup(icon.spellID) end)
        secure:SetScript("OnEnter", function(self) showTooltip(self, icon) end)
        secure:SetScript("OnLeave", GameTooltip_Hide)
        icon.secure = secure
    end
    secure:SetAttribute("spell", icon.spellID)
    secure:SetParent(icon)
    secure:ClearAllPoints()
    secure:SetAllPoints(icon)
    secure:SetFrameLevel(icon:GetFrameLevel() + 5)
    secure:Show()
end

-- One icon button (not secure) with the spell's name to its right. Position it, then call
-- :SetSpell(entry, skillLineID) on each refresh (entry from SpellsFor; nil hides it).
function TrackingButton.Create(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(32, 32)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("LEFT", b, "RIGHT", 8, 0)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self) pickup(self.spellID) end)
    b:SetScript("OnEnter", function(self) showTooltip(self, self) end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self)
        if self.skill and not self.cast then ns.Crafting.OpenProfession(self.skill) end
    end)
    b:SetScript("OnShow", attach)
    b:SetScript("OnHide", detach)
    b:Hide()
    function b:SetSpell(entry, skillLineID)
        self.spellID = entry and entry.spellID
        self.cast = entry and entry.cast or false
        self.tracking = entry and entry.tracking or false
        self.skill = skillLineID
        if not self.spellID then
            self:Hide()
            return
        end
        self.tex:SetTexture(Compat.Call("C_Spell.GetSpellTexture", self.spellID) or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.label:SetText(Compat.Call("C_Spell.GetSpellName", self.spellID) or "")
        if self:IsShown() then attach(self) else self:Show() end
    end
    -- Width with its label, for placing the next icon.
    function b:FullWidth()
        return 32 + 8 + (self.label:GetStringWidth() or 0)
    end
    icons[#icons + 1] = b
    return b
end

ns.On("PLAYER_REGEN_DISABLED", function()
    for _, icon in ipairs(icons) do detach(icon) end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
    for _, icon in ipairs(icons) do
        if icon:IsVisible() then attach(icon) end
    end
end)
