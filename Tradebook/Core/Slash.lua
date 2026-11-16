-- Core/Slash.lua
-- /tradebook and /tb

local _, ns = ...
local L = ns.L

SLASH_TRADEBOOK1 = "/tradebook"
SLASH_TRADEBOOK2 = "/tb"

SlashCmdList.TRADEBOOK = function(msg)
    if not ns.db then return end
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        ns.UI.Toggle()
    elseif cmd == "camp" then
        ns.UI.Show()
        ns.UI.SelectTab("camp")
    elseif cmd == "chars" or cmd == "characters" then
        ns.UI.Show()
        ns.UI.ShowCharacters()
    elseif cmd == "search" or cmd == "who" then
        ns.UI.Show()
        ns.UI.GlobalSearch(rest)
    elseif cmd == "default" then
        ns.Takeover.UseDefault()
    elseif cmd == "options" or cmd == "settings" or cmd == "config" then
        ns.Settings.Open()
    elseif cmd == "share" then
        ns.Share.Show()
    elseif cmd == "net" then
        if rest:lower() == "test" then
            if ns.Net.Test(20) then
                ns.Print("20 test messages queued (other players' Tradebook ignores them). "
                    .. "Zone into a dungeon now; /tb net shows them waiting.")
            else
                ns.Print("Sharing is off (settings).")
            end
        end
        for _, line in ipairs(ns.Net.Status()) do ns.Print(line) end
    elseif cmd == "de" or cmd == "disenchant" then
        ns.Disenchant.PrintSummary()
    elseif cmd == "vendors" then
        ns.UI.Show()
        ns.UI.SelectTab("vendors")
    elseif cmd == "fake" then
        ns.Fake.Toggle()
    elseif cmd == "shots" then
        ns.Screenshots.Run()
    elseif cmd == "debug" then
        ns.db.settings.debug = not ns.db.settings.debug
        ns.Print(ns.db.settings.debug and L.DEBUG_ON or L.DEBUG_OFF)
        if ns.db.settings.debug then
            ns.Debug("character", tostring(ns.charKey), "playType", ns.char and ns.char.playType,
                "characters", ns.util.Count(ns.db.characters), "recipes", ns.util.Count(ns.db.recipes),
                "open", ns.Scanner.OpenProfession() and ns.Scanner.OpenProfession().professionName or "none",
                ns.Takeover.DebugState(), ns.Questie.DebugState(), ns.Prices.DebugState())
            -- Vendor windows read, and recipes seen sold by a vendor the data doesn't list.
            for _, line in ipairs(ns.Merchants.DebugLines()) do ns.Debug(line) end
        end
    else
        ns.Print(L.HELP_HEADER)
        for _, line in ipairs(L.HELP_LINES) do print("  " .. line) end
    end
end
