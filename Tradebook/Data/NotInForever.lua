-- Data/NotInForever.lua
-- PURE. NPCs Questie's Forever data has that aren't in WoW Forever: never offered as a vendor,
-- trainer or mob location (Core/Questie.lua skips them). Each one is backed by two sources;
-- the evidence is in docs/research/npc_checks.json.

local _, ns = ...

ns.NotInForever = {
    [214096] = true, -- Dokimi, Supply Officer: not there in game; no Forever database page
    [214098] = true, -- Gishah, Supply Officer: not there in game; no Forever database page
    [233428] = true, -- Rune Broker: not there in game; no Forever database page
}
