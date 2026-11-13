-- Core/Takeover.lua
-- Replaces the default Professions window with Tradebook without tainting it.
--
-- Phase 0: every way of opening professions shows ProfessionsFrame, and hiding that
-- frame closes the trade-skill session (its OnHide calls CloseTradeSkill). So while
-- Tradebook is up, the default frame stays OPEN but invisible: alpha 0 and moved
-- off-screen so it can't catch clicks. Its scale is never touched (the panel manager
-- scales it to fit, and Blizzard sizes some buttons from text width). Closing Tradebook
-- closes the default frame, which ends the session normally. No Blizzard function is
-- replaced; only EventRegistry callbacks, HookScript/hooksecurefunc and our own button.

local _, ns = ...
local L = ns.L

local Takeover = {}
ns.Takeover = Takeover

local owner = {}
local state = {
    hidden = false,      -- default frame currently hidden behind Tradebook
    useDefault = false,  -- user chose the default UI until the default frame closes
    closingFromUs = false,
    points = nil,        -- the panel manager's anchors, restored when shown again
    clamped = nil,
    moving = false,
}

local function frame()
    return _G.ProfessionsFrame
end

function Takeover.IsDefaultShown()
    local f = frame()
    return f ~= nil and f:IsShown()
end

function Takeover.IsHiding()
    return state.hidden
end

local OFFSCREEN_X = -5000

local function capturePoints(f)
    local points = {}
    for i = 1, f:GetNumPoints() do points[i] = { f:GetPoint(i) } end
    -- Ignore our own off-screen anchor (the panel manager may not have moved the frame).
    if #points > 0 and points[1][4] ~= OFFSCREEN_X then state.points = points end
end

local function moveOffscreen(f)
    state.moving = true
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", OFFSCREEN_X, 0)
    state.moving = false
end

local function hideDefault()
    local f = frame()
    if not f then return end
    if not state.hidden then
        capturePoints(f)
        state.clamped = f:IsClampedToScreen()
    end
    f:SetClampedToScreen(false)
    f:SetAlpha(0)
    moveOffscreen(f)
    state.hidden = true
end

local function restoreDefault()
    local f = frame()
    if not f or not state.hidden then return end
    state.hidden = false
    f:SetAlpha(1)
    if state.points then
        f:ClearAllPoints()
        for _, p in ipairs(state.points) do f:SetPoint(unpack(p)) end
    end
    if state.clamped ~= nil then f:SetClampedToScreen(state.clamped) end
    state.points, state.clamped = nil, nil
end

-- The panel manager re-anchors panels when others open or close; keep ours hidden.
local function onPanelsMoved()
    local f = frame()
    if state.hidden and f and f:IsShown() and not state.moving then
        capturePoints(f)
        moveOffscreen(f)
    end
end

local function shouldTakeOver()
    return ns.db and ns.db.settings.replaceDefault and not state.useDefault
end

-- "Tradebook" button on the default frame, to switch back. It is our own top-level
-- button (parented to UIParent, drawn above the default frame's title art) anchored to
-- the frame, shown only while the default frame is visible to the player.
local switchButton

local function updateSwitchButton()
    local f = frame()
    if not switchButton then return end
    switchButton:SetShown(f ~= nil and f:IsShown() and not state.hidden)
end

local function ensureSwitchButton(f)
    if not f or switchButton then return end
    switchButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    switchButton:SetText(L.OPEN_TRADEBOOK)
    switchButton:SetSize(96, 20)
    switchButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -1)
    switchButton:SetFrameStrata("HIGH")
    switchButton:SetToplevel(true)
    switchButton:Hide()
    switchButton:SetScript("OnClick", function() Takeover.UseTradebook() end)
    switchButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.OPEN_TRADEBOOK_TIP)
        GameTooltip:Show()
    end)
    switchButton:SetScript("OnLeave", GameTooltip_Hide)
end

local hookedHide = false
local function onDefaultShow()
    local f = frame()
    if not f then return end
    ensureSwitchButton(f)
    if not hookedHide then
        hookedHide = true
        f:HookScript("OnHide", function()
            restoreDefault()
            state.useDefault = false
            updateSwitchButton()
            if not state.closingFromUs and ns.UI and ns.UI.OnDefaultClosed then ns.UI.OnDefaultClosed() end
        end)
    end
    if shouldTakeOver() then
        hideDefault()
        if ns.UI then ns.UI.Show() end
    end
    updateSwitchButton()
end

function Takeover.Start()
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ProfessionsFrame.Show", onDefaultShow, owner)
    end
    if type(UpdateUIPanelPositions) == "function" then
        hooksecurefunc("UpdateUIPanelPositions", onPanelsMoved)
    end
end

function Takeover.DebugState()
    local f = frame()
    return string.format("defaultShown=%s hidden=%s useDefault=%s switchButton=%s",
        tostring(f and f:IsShown()), tostring(state.hidden), tostring(state.useDefault),
        tostring(switchButton and switchButton:IsVisible()))
end

-- Tradebook is closing: close the hidden default frame too (ends the trade skill properly).
function Takeover.OnTradebookHidden()
    local f = frame()
    if state.hidden and f and f:IsShown() then
        state.closingFromUs = true
        HideUIPanel(f)
        state.closingFromUs = false
    end
    restoreDefault()
end

-- "Default UI" button: show the default window (with the same profession open).
function Takeover.UseDefault()
    state.useDefault = true
    local f = frame()
    if f and f:IsShown() then
        restoreDefault()
    elseif ShowProfessionsFrame then
        ShowProfessionsFrame()
    end
    if ns.UI then ns.UI.Hide(true) end
    updateSwitchButton()
end

-- "Tradebook" button on the default frame.
function Takeover.UseTradebook()
    state.useDefault = false
    local f = frame()
    if f and f:IsShown() then hideDefault() end
    updateSwitchButton()
    if ns.UI then ns.UI.Show() end
end
