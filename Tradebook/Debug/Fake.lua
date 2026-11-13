-- Debug/Fake.lua
-- /tb fake: swap the made-up account (Debug/FakeData.lua) in and out. In memory only:
-- TradebookDB on disk is never touched, and the scanners/crafting check ns.fake.

local _, ns = ...
local L = ns.L

local Fake = {}
ns.Fake = Fake

function Fake.IsOn()
    return ns.fake == true
end

function Fake.On()
    if ns.fake then return end
    ns.real = { db = ns.db, char = ns.char, key = ns.charKey }
    local db, key = ns.FakeData.Build(ns.db, GetServerTime(), function(target, id, skillLineID)
        ns.Scanner.CacheRecipeInto(target, id, skillLineID)
    end)
    ns.db, ns.char, ns.charKey, ns.fake = db, db.characters[key], key, true
    ns.Recipes.Invalidate()
    if ns.UI.SetFakeBanner then ns.UI.SetFakeBanner(true) end
    if ns.UI.LayoutTabs then ns.UI.LayoutTabs() end -- settings were swapped (gathering tabs)
    ns.UI.Refresh()
    ns.Print(L.FAKE_ON)
end

function Fake.Off()
    if not ns.fake then return end
    ns.db, ns.char, ns.charKey = ns.real.db, ns.real.char, ns.real.key
    ns.real, ns.fake = nil, nil
    ns.Recipes.Invalidate()
    if ns.UI.SetFakeBanner then ns.UI.SetFakeBanner(false) end
    if ns.UI.LayoutTabs then ns.UI.LayoutTabs() end
    ns.UI.Refresh()
    ns.Print(L.FAKE_OFF)
end

function Fake.Toggle()
    if ns.fake then Fake.Off() else Fake.On() end
end
