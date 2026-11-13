-- Core/Unsupported.lua
-- Loaded only by the fallback Tradebook.toc (a client that didn't pick Tradebook_Forever.toc).

local _, ns = ...

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    print("|cffd9a54aTradebook|r: " .. ns.L.UNSUPPORTED)
end)
