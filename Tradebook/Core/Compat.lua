-- Core/Compat.lua
-- Safe wrappers around the WoW API. Nothing here throws into the user's chat:
-- failures return nil and are only printed with /tb debug on.

local _, ns = ...

local Compat = {}
ns.Compat = Compat

local function resolve(path)
    local cur = _G
    for part in path:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[part]
    end
    return cur
end
Compat.Resolve = resolve

function Compat.Has(path)
    return type(resolve(path)) == "function"
end

local function passResults(path, ok, ...)
    if not ok then
        ns.Debug("API error", path, (...))
        return
    end
    return ...
end

-- Call an API by dotted name. Returns its results, or nothing on a missing API or error.
function Compat.Call(path, ...)
    local fn = resolve(path)
    if type(fn) ~= "function" then
        ns.Debug("missing API", path)
        return
    end
    return passResults(path, pcall(fn, ...))
end

function Compat.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Debug printing (only when /tb debug is on). The last DEBUG_KEEP lines are also kept in
-- TradebookDB.debugLog (written on /reload or logout), so bug reports can be read from the
-- SavedVariables instead of copied out of chat.
local DEBUG_KEEP = 300
function ns.Debug(...)
    local db = ns.db
    if not (db and db.settings and db.settings.debug) then return end
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[#parts + 1] = Compat.IsSecret(v) and "<secret>" or tostring(v)
    end
    local line = table.concat(parts, " ")
    print("|cffb07a3aTradebook debug|r: " .. line)
    db.debugLog = db.debugLog or {}
    local log = db.debugLog
    log[#log + 1] = date("%H:%M:%S ") .. line
    while #log > DEBUG_KEEP do table.remove(log, 1) end
end

function ns.Print(msg)
    print("|cffd9a54a" .. ns.L.ADDON_TITLE .. "|r: " .. tostring(msg))
end

-- Item name/icon/quality with a load request when not cached yet.
function Compat.ItemInfo(itemID)
    if not itemID then return end
    local name, link, quality, _, _, _, _, _, _, icon = Compat.Call("C_Item.GetItemInfo", itemID)
    if not name then
        Compat.Call("C_Item.RequestLoadItemDataByID", itemID)
        icon = icon or Compat.Call("C_Item.GetItemIconByID", itemID)
    end
    return name, link, quality, icon
end

function Compat.ClassColor(classFile)
    local color = classFile and C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classFile)
    if color then return color end
    return HIGHLIGHT_FONT_COLOR
end

function Compat.ProfessionTexture(skillLineID)
    local tex = Compat.Call("C_TradeSkillUI.GetTradeSkillTexture", skillLineID)
    if tex and tex ~= 0 then return tex end
    local p = ns.Professions.Get(skillLineID)
    return p and p.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
