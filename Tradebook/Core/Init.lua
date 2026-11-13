-- Core/Init.lua
-- Load order: last. Sets up the saved variables and starts everything at login.

local addonName, ns = ...

-- Display name for a saved character key ("Name Secondname").
function ns.CharName(key)
    local c = ns.db and ns.db.characters[key]
    if not c then return key end
    if c.second and c.second ~= "" then return c.name .. " " .. c.second end
    return c.name or key
end

local function onLogin()
    TradebookDB = ns.DB.Migrate(TradebookDB)
    ns.db = TradebookDB

    local key, info = ns.Scanner.Identity()
    if key then
        ns.charKey = key
        ns.char = ns.Characters.Ensure(ns.db, key)
        ns.Characters.UpdateIdentity(ns.char, info, GetServerTime())
        ns.char.hidden = nil -- logging in on a hidden character shows it again
    end

    ns.Scanner.Start()
    ns.Takeover.Start()
    if ns.Minimap then ns.Minimap.Start() end
    if ns.Settings then ns.Settings.Start() end
    if ns.Questie then ns.Questie.Start() end
    ns.Debug("ready as", tostring(key))
end

ns.On("PLAYER_LOGIN", function()
    local ok, err = pcall(onLogin)
    if not ok then
        print("|cffd9a54aTradebook|r: could not start (" .. tostring(err) .. "). Please report this.")
    end
end)

-- Silence "unused" for the varargs name in linters while documenting it.
ns.addonName = addonName
