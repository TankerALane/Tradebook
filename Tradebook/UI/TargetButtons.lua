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

-- After the secure macro ran: if it really targeted this NPC (it was in range), put a
-- purple diamond on it. SetRaidTarget sets (never toggles), so repeat clicks keep it.
-- In a group this needs lead/assist; otherwise the game just ignores it.
local function mark(name)
    if UnitExists("target") and UnitName("target") == name
        and GetRaidTargetIndex("target") ~= DIAMOND then
        SetRaidTarget("target", DIAMOND)
    end
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
    -- The secure click targets; this post-hook marks it and sets the waypoint (on mouse up).
    b:HookScript("OnClick", function(self, _, down)
        if down then return end
        if self.targetName then mark(self.targetName) end
        if self.onClick then self.onClick() end
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
    b:SetAttribute("macrotext", "/targetexact " .. name)
    b.onClick, b.tooltip, b.targetName = onClick, tooltip, name
    b:Show()
    return true
end

ns.On("PLAYER_REGEN_DISABLED", detachAll)
