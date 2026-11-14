-- UI/TrackingButton.lua
-- The gathering tracking spell (Find Herbs, Find Minerals) as an icon on its profession's
-- tab: drag it to an action bar, or click it to start tracking.
--
-- Spell IDs from Forever's SkillLineAbility table (build 1.60.1.70938): Herbalism (182)
-- teaches Find Herbs 2383 (8387 supersedes it), Mining (186) Find Minerals 2580 (8388).
--
-- Casting is protected, so the click goes through a secure button laid over the icon. Like
-- UI/TargetButtons.lua it is only attached out of combat and is detached when combat starts
-- (a secure child would stop the Tradebook window closing in combat). In combat the icon
-- can still be dragged; clicking it does nothing.

local _, ns = ...
local L, Compat = ns.L, ns.Compat

local TrackingButton = {}
ns.TrackingButton = TrackingButton

-- PURE. Profession -> its tracking spells, newest rank first.
TrackingButton.spells = {
    [182] = { 8387, 2383 }, -- Find Herbs
    [186] = { 8388, 2580 }, -- Find Minerals
}

local function isKnown(spellID)
    return Compat.Call("C_SpellBook.IsSpellKnown", spellID) == true
        or Compat.Call("IsPlayerSpell", spellID) == true
end

-- PURE (given isKnown). The tracking spell the player knows for a profession, or nil.
function TrackingButton.KnownSpell(skillLineID, known)
    known = known or isKnown
    for _, id in ipairs(TrackingButton.spells[skillLineID] or {}) do
        if known(id) then return id end
    end
end

local secure -- the one secure click button, laid over the icon out of combat

local function pickup(spellID)
    if not spellID then return end
    if Compat.Has("C_Spell.PickupSpell") then
        Compat.Call("C_Spell.PickupSpell", spellID)
    else
        Compat.Call("PickupSpell", spellID)
    end
end

local function showTooltip(owner, spellID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if not (spellID and pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)) then
        GameTooltip:SetText(Compat.Call("C_Spell.GetSpellName", spellID) or "?", 1, 1, 1)
    end
    GameTooltip:AddLine(L.TRACKING_TIP, 0.2, 1, 0.2, true)
    if InCombatLockdown() then GameTooltip:AddLine(L.TRACKING_COMBAT, 1, 0.3, 0.3, true) end
    GameTooltip:Show()
end

local function detach()
    if not secure or InCombatLockdown() then return end
    secure:Hide()
    secure:ClearAllPoints()
    secure:SetParent(UIParent)
end

local function attach(icon)
    if InCombatLockdown() or not icon.spellID then return end
    if not secure then
        secure = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        -- Fires on down or up depending on the "cast on key down" setting.
        secure:RegisterForClicks("AnyUp", "AnyDown")
        secure:RegisterForDrag("LeftButton")
        secure:SetAttribute("type", "spell")
        secure:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        secure:SetScript("OnDragStart", function(self) pickup(self.spellID) end)
        secure:SetScript("OnEnter", function(self) showTooltip(self, self.spellID) end)
        secure:SetScript("OnLeave", GameTooltip_Hide)
    end
    secure.spellID = icon.spellID
    secure:SetAttribute("spell", icon.spellID)
    secure:SetParent(icon)
    secure:ClearAllPoints()
    secure:SetAllPoints(icon)
    secure:SetFrameLevel(icon:GetFrameLevel() + 5)
    secure:Show()
end

-- The icon button (not secure). Position it, then call :SetSkill(skillLineID) on each refresh.
function TrackingButton.Create(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(32, 32)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    -- The spell's name to the right of the icon.
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("LEFT", b, "RIGHT", 8, 0)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self) pickup(self.spellID) end)
    b:SetScript("OnEnter", function(self) showTooltip(self, self.spellID) end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnShow", attach)
    b:SetScript("OnHide", detach)
    b:Hide()
    -- Show it for the logged-in character's tracking spell (spellID nil hides it).
    function b:SetSpell(spellID)
        self.spellID = spellID
        if not spellID then
            self:Hide()
            return
        end
        self.tex:SetTexture(Compat.Call("C_Spell.GetSpellTexture", spellID) or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.label:SetText(Compat.Call("C_Spell.GetSpellName", spellID) or "")
        if self:IsShown() then attach(self) else self:Show() end
    end
    TrackingButton.icon = b
    return b
end

ns.On("PLAYER_REGEN_DISABLED", detach)
ns.On("PLAYER_REGEN_ENABLED", function()
    local icon = TrackingButton.icon
    if icon and icon:IsVisible() then attach(icon) end
end)
