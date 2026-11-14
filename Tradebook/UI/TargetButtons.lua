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
local NL = string.char(10)

-- The NPC Tradebook last marked. The game hides raid marker values from addons ("secret"
-- values that can't be compared), so we remember what we marked instead of reading it.
local lastMarked

-- The target's name, or nil when there's no target or the game hides it.
local function targetName()
    if not UnitExists("target") then return nil end
    local n = UnitName("target")
    if issecretvalue and issecretvalue(n) then return nil end
    return n
end

-- The macro, built just before each click (PreClick runs out of combat only, where
-- attributes can change). Marking is protected, so it's done in the macro with /tm:
--   /cleartarget first, so an out-of-range NPC leaves no target and /tm marks nothing
--     (instead of marking whatever was targeted before);
--   /tm toggles, so it's left out when this NPC is already the target and we marked it.
local function macroFor(name)
    if lastMarked == name and targetName() == name then return "/targetexact " .. name end
    return "/cleartarget" .. NL .. "/targetexact " .. name .. NL .. "/tm " .. DIAMOND
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
    -- The macro runs on mouse down or up depending on the "cast on key down" setting, so
    -- listen for both.
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    -- Build the macro once per press (on down, before anything has run) and keep it for the
    -- up, so whichever of the two runs it gets the same macro.
    b:SetScript("PreClick", function(self, _, down)
        if InCombatLockdown() or not self.targetName then return end
        if down or not self.pressMacro then self.pressMacro = macroFor(self.targetName) end
        self:SetAttribute("macrotext", self.pressMacro)
    end)
    -- On up (the macro has run by then): set the waypoint, and remember the mark if the
    -- macro reached the NPC.
    b:HookScript("OnClick", function(self, _, down)
        if down then return end
        self.pressMacro = nil
        if self.onClick then self.onClick() end
        if self.targetName and targetName() == self.targetName then lastMarked = self.targetName end
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
