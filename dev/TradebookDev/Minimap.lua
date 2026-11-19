-- dev/TradebookDev/Minimap.lua
-- A minimap button for the maintainer tools (LibDataBroker + LibDBIcon, which Tradebook
-- ships; this addon depends on Tradebook so they're loaded first).
--   Left-click: open or close the heard window (/tbdev notify stays as it is).
--   Right-click: a menu: switch the options, open the windows, and run the tests.
-- Position and shown/hidden in TradebookDevDB.minimap. /tbdev minimap shows it again.
--
-- Tests: anything in Dev.TESTS is in the menu's Tests section. A new test adds itself with
-- Dev.AddTest(text, tooltip, run) from its own file (loaded before this one in the TOC) or
-- here; `run` is called on click. Use a submenu table instead of `run` for several variants:
-- Dev.AddTest(text, tooltip, { { text, tooltip, run }, ... }).

local Dev = TradebookDev
local NAME = "TradebookDev"
local ICON = "Interface\\Icons\\INV_Misc_Gear_01"

local function say(msg) print("|cffd9a54aTradebook Dev|r: " .. msg) end

Dev.TESTS = Dev.TESTS or {}

function Dev.AddTest(text, tooltip, run)
    Dev.TESTS[#Dev.TESTS + 1] = { text = text, tooltip = tooltip, run = run }
end

-- The tests there are now (the same as their /tbdev and /tb commands).
Dev.AddTest("Test notification", "A made-up heard notification (/tbdev test). Not logged or counted.",
    function() Dev.ShowTest() end)
Dev.AddTest("Net test: 20 messages", "Queue 20 test share messages (/tb net test); other players' Tradebook "
    .. "ignores them. Zone into a dungeon to watch sending pause.", function()
    local ns = Dev.NS()
    if not (ns and ns.Net and ns.Net.Test) then return say("Tradebook's sharing isn't loaded.") end
    if ns.Net.Test(20) then
        say("20 test messages queued. Zone into a dungeon now; /tb net shows them waiting.")
    else
        say("sharing is off (Tradebook settings).")
    end
end)
Dev.AddTest("Rate tests", "How fast addon messages can go out (/tbdev ratetest). These run for minutes "
    .. "and hold Tradebook's own sharing meanwhile.", {
    { "Rates (about 11 minutes)", "/tbdev ratetest", function() Dev.RateTest("") end },
    { "Long (30 minutes)", "/tbdev ratetest long: the setup Tradebook would use",
        function() Dev.RateTest("long") end },
    { "Channels", "/tbdev ratetest channels: 1 a second on several channels at once",
        function() Dev.RateTest("channels") end },
    { "Max channels", "/tbdev ratetest maxchannels: how many chat channels a character can be in",
        function() Dev.RateTest("maxchannels") end },
    { "Stop", "/tbdev ratetest stop: stop early, results so far", function() Dev.RateTest("stop") end },
})

local function withTip(desc, tip)
    if tip and desc.SetTooltip then
        desc:SetTooltip(function(tooltip) tooltip:AddLine(tip, 1, 1, 1, true) end)
    end
    return desc
end

local function menu(owner)
    local util = _G.MenuUtil
    if not (util and util.CreateContextMenu) then return say("menus aren't available here; use /tbdev.") end
    util.CreateContextMenu(owner, function(_, root)
        local d = Dev.DB()
        root:CreateTitle("Tradebook Dev")
        root:CreateTitle("Other players' data")
        withTip(root:CreateCheckbox("Alerts", function() return d.notify ~= false end, function()
            d.notify = d.notify == false
        end), "The window opening, the message on screen and the sound when data comes in (/tbdev notify). "
            .. "Off, it's still written to the heard window.")
        withTip(root:CreateCheckbox("Heard window opens by itself", function() return d.heardAuto ~= false end,
            function() d.heardAuto = d.heardAuto == false end), "/tbdev heard auto")
        withTip(root:CreateCheckbox("Also in chat", function() return d.heardChat == true end,
            Dev.ToggleHeardChat), "A copy of each notification in chat.")
        withTip(root:CreateCheckbox("Players' shares count as scanned", function() return d.countHeard == true end,
            Dev.ToggleCountHeard), "Vendors other players shared drop off the Unscanned list.")
        root:CreateDivider()
        root:CreateTitle("Windows")
        root:CreateButton("Heard from other players", function() Dev.ToggleHeard(true) end)
        root:CreateButton("Unscanned vendors", function() Dev.Toggle(true) end)
        root:CreateButton("Thank-you list", Dev.ShowThanks)
        withTip(root:CreateButton("Since the last import (chat)", function() SlashCmdList.TRADEBOOKDEV("count") end),
            "/tbdev count")
        root:CreateDivider()
        root:CreateTitle("Tests")
        for _, t in ipairs(Dev.TESTS) do
            if type(t.run) == "table" then
                local sub = withTip(root:CreateButton(t.text), t.tooltip)
                for _, v in ipairs(t.run) do
                    withTip(sub:CreateButton(v[1], v[3]), v[2])
                end
            else
                withTip(root:CreateButton(t.text, t.run), t.tooltip)
            end
        end
        root:CreateDivider()
        withTip(root:CreateButton("Hide this button", function() Dev.SetMinimapShown(false) end),
            "/tbdev minimap shows it again.")
    end)
end

local icon
function Dev.SetMinimapShown(show)
    local d = Dev.DB()
    d.minimap = d.minimap or {}
    d.minimap.hide = not show
    if icon then
        if show then icon:Show(NAME) else icon:Hide(NAME) end
    end
    if not show then say("minimap button hidden; /tbdev minimap shows it again.") end
end

local function start()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (LDB and DBI) then return end
    local d = Dev.DB()
    d.minimap = d.minimap or {}
    local broker = LDB:NewDataObject(NAME, {
        type = "launcher",
        label = "Tradebook Dev",
        icon = ICON,
        OnClick = function(owner, button)
            if button == "RightButton" then menu(owner) else Dev.ToggleHeard() end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Tradebook Dev", 0.85, 0.65, 0.29)
            tooltip:AddLine("Left-click: open or close heard from other players", 0.6, 0.8, 1)
            tooltip:AddLine("Right-click: options and tests", 0.6, 0.8, 1)
        end,
    })
    DBI:Register(NAME, broker, d.minimap)
    icon = DBI
end

-- The saved table is ready once this addon has loaded.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", start)
