-- Core/Namespace.lua
-- PURE: no WoW API calls at load time. Shared namespace, locale table and small helpers.

local addonName, ns = ...

ns.name = addonName or "Tradebook"
ns.L = setmetatable({}, { __index = function(_, key) return key end })

local util = {}
ns.util = util

-- Copy missing keys from defaults into t (recursively for tables). Existing values win.
function util.Fill(t, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then t[k] = {} end
            util.Fill(t[k], v)
        elseif t[k] == nil then
            t[k] = v
        end
    end
    return t
end

function util.Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function util.Keys(t, sorter)
    local out = {}
    for k in pairs(t or {}) do out[#out + 1] = k end
    table.sort(out, sorter)
    return out
end

-- Lower-case and trim a search string; nil/empty becomes nil.
function util.Query(s)
    if type(s) ~= "string" then return nil end
    s = s:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    return s
end

-- Plain (non-pattern) substring match on lower-cased text.
function util.Matches(text, query)
    if not query then return true end
    if type(text) ~= "string" then return false end
    return text:lower():find(query, 1, true) ~= nil
end
