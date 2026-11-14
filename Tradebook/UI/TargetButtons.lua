-- UI/TargetButtons.lua
-- Click an NPC line (vendor, trainer, mob) to target it and mark it with a purple diamond
-- when it's nearby, as well as setting the waypoint. Targeting is protected, so this uses secure buttons running "/targetexact
-- Name" (the standard way for addons to offer targeting).
--
-- Secure buttons can't be shown, moved or hidden in combat, and a secure child inside the
-- Tradebook window would also stop the window closing in combat. So they are only attached
-- out of combat and are all detached on PLAYER_REGEN_DISABLED (which fires just before combat
-- lockdown starts). In combat, lines just set the waypoint.

local _, ns = ...
local W = ns.W

local TargetButtons = {}
ns.TargetButtons = TargetButtons

local pool, used = {}, 0
local DIAMOND = 3 -- raid target icon 3 = purple diamond

-- The macro, built just before each click (PreClick runs out of combat only, where
-- attributes can change). Marking is protected, so it's done in the macro with /tm:
--   /cleartarget first, so an out-of-range NPC leaves no target and /tm marks nothing
--     (instead of marking whatever was targeted before);
--   /tm toggles, so it's left out when this NPC is already the target with the diamond.
local function macroFor(name)
    local alreadyMarked = UnitExists("target") and UnitName("target") == name
        and GetRaidTargetIndex("target") == DIAMOND
    if alreadyMarked then return "/targetexact " .. name end
    return "/cleartarget\n/targetexact " .. name .. "\n/tm " .. DIAMOND
end

local function detachAll()
    for _, b in ipairs(pool) do
        b:Hide()
        b:ClearAllPoints()
        b:SetParent(UIParent)
    end
    used = 0
end

local function create()
    local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    -- Rebuilt on both down and up: the macro runs on one of them, depending on the
    -- ActionButtonUseKeyDown setting; nothing has run yet when it's rebuilt.
    b:SetScript("PreClick", function(self)
        if not InCombatLockdown() and self.targetName then
            self:SetAttribute("macrotext", macroFor(self.targetName))
        end
    end)
    -- The secure click targets and marks; this post-hook sets the waypoint (on mouse up).
    b:HookScript("OnClick", function(self, _, down)
        if not down and self.onClick then self.onClick() end
    end)
    W.Tooltip(b, function(self) return self.tooltip end)
    b:Hide()
    return b
end

-- Release every button (call before laying out the lines again). Out of combat only.
function TargetButtons.Release()
    if InCombatLockdown() then return end
    detachAll()
end

-- Cover `line` with a secure button that targets `name` and then calls onClick.
-- Returns false (and does nothing) in combat; the line's own click still works then.
function TargetButtons.Attach(line, name, onClick, tooltip)
    if InCombatLockdown() or not name or name == "" then return false end
    used = used + 1
    local b = pool[used]
    if not b then
        b = create()
        pool[used] = b
    end
    b:SetParent(line)
    b:ClearAllPoints()
    b:SetAllPoints(line)
    b:SetFrameLevel(line:GetFrameLevel() + 5)
    b:SetAttribute("macrotext", macroFor(name))
    b.onClick, b.tooltip, b.targetName = onClick, tooltip, name
    b:Show()
    return true
end

ns.On("PLAYER_REGEN_DISABLED", detachAll)
