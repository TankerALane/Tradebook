-- Core/Takeover.lua
-- Replaces the default Professions window with Tradebook without tainting it.
--
-- Phase 0: every way of opening professions shows ProfessionsFrame, and hiding that
-- frame closes the trade-skill session (its OnHide calls CloseTradeSkill). So while
-- Tradebook is up, the default frame stays OPEN but invisible (alpha 0, tiny scale so it
-- can't catch clicks). Closing Tradebook closes the default frame, which ends the
-- session normally. No Blizzard function is replaced; only EventRegistry callbacks,
-- HookScript and our own button are used.

local _, ns = ...
local L = ns.L

local Takeover = {}
ns.Takeover = Takeover

local HIDDEN_SCALE = 0.001
local owner = {}
local state = {
    hidden = false,      -- default frame currently hidden behind Tradebook
    useDefault = false,  -- user chose the default UI until the default frame closes
    closingFromUs = false,
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

local function hideDefault()
    local f = frame()
    if not f then return end
    f:SetAlpha(0)
    f:SetScale(HIDDEN_SCALE)
    state.hidden = true
end

local function restoreDefault()
    local f = frame()
    if not f then return end
    f:SetAlpha(1)
    f:SetScale(1)
    state.hidden = false
end

local function shouldTakeOver()
    return ns.db and ns.db.settings.replaceDefault and not state.useDefault
end

-- "Tradebook" button on the default frame, to switch back.
local switchButton
local function ensureSwitchButton(f)
    if switchButton or not f then return end
    switchButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    switchButton:SetText(L.OPEN_TRADEBOOK)
    switchButton:SetSize(96, 20)
    local anchor = f.CloseButton or f
    switchButton:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
    switchButton:SetFrameLevel(f:GetFrameLevel() + 20)
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
            if not state.closingFromUs and ns.UI and ns.UI.OnDefaultClosed then ns.UI.OnDefaultClosed() end
        end)
    end
    if shouldTakeOver() then
        hideDefault()
        if ns.UI then ns.UI.Show() end
    end
end

function Takeover.Start()
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ProfessionsFrame.Show", onDefaultShow, owner)
    end
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
end

-- "Tradebook" button on the default frame.
function Takeover.UseTradebook()
    state.useDefault = false
    local f = frame()
    if f and f:IsShown() then hideDefault() end
    if ns.UI then ns.UI.Show() end
end
