-- Core/TabLayout.lua
-- PURE. The order of the bottom tabs (professions and Camp) and which are hidden, set from a
-- tab's right-click menu (UI/MainFrame.lua). One layout for every character, or a character's
-- own when it has one:
--
--   settings.tabLayout = {
--     shared = { order = { key, ... }, hidden = { [key] = true } },
--     chars  = { [charKey] = { order, hidden } },  -- characters with their own layout
--   }
--
-- Keys are profession skill line IDs and "camp". `order` lists the tabs moved by hand; tabs
-- it doesn't list keep their usual place after them (so new tabs still show up).

local _, ns = ...

local TabLayout = {}
ns.TabLayout = TabLayout

local function newLayout()
    return { order = {}, hidden = {} }
end

local function root(settings)
    settings.tabLayout = settings.tabLayout or {}
    local t = settings.tabLayout
    t.shared = t.shared or newLayout()
    t.chars = t.chars or {}
    return t
end

-- The layout `charKey` uses: its own, else the shared one.
function TabLayout.Get(settings, charKey)
    local t = root(settings)
    local own = charKey and t.chars[charKey]
    local layout = own or t.shared
    layout.order, layout.hidden = layout.order or {}, layout.hidden or {}
    return layout
end

function TabLayout.HasOwn(settings, charKey)
    return charKey ~= nil and root(settings).chars[charKey] ~= nil
end

-- Give a character its own layout (a copy of the shared one), or drop it (back to shared).
function TabLayout.SetOwn(settings, charKey, on)
    local t = root(settings)
    if not charKey then return end
    if on and not t.chars[charKey] then
        local copy = newLayout()
        for i, k in ipairs(t.shared.order or {}) do copy.order[i] = k end
        for k, v in pairs(t.shared.hidden or {}) do copy.hidden[k] = v end
        t.chars[charKey] = copy
    elseif not on then
        t.chars[charKey] = nil
    end
end

-- Forget a deleted character's layout.
function TabLayout.Forget(settings, charKey)
    if settings.tabLayout and settings.tabLayout.chars then settings.tabLayout.chars[charKey] = nil end
end

-- `keys` (the usual order) in the layout's order: moved tabs first, in their order, then the
-- rest as usual. Hidden ones are included (callers skip them).
function TabLayout.Order(layout, keys)
    local known, out, used = {}, {}, {}
    for _, k in ipairs(keys) do known[k] = true end
    for _, k in ipairs(layout.order or {}) do
        if known[k] and not used[k] then
            out[#out + 1], used[k] = k, true
        end
    end
    for _, k in ipairs(keys) do
        if not used[k] then out[#out + 1] = k end
    end
    return out
end

-- The visible tabs, in order. `keep`: a tab shown even when hidden (the one open now).
function TabLayout.Visible(layout, keys, keep)
    local out = {}
    for _, k in ipairs(TabLayout.Order(layout, keys)) do
        if not layout.hidden[k] or k == keep then out[#out + 1] = k end
    end
    return out
end

-- Move tab `key` among the visible tabs: delta -1 / +1 (left / right), "first" or "last".
-- Hidden tabs keep their place in the full order.
function TabLayout.Move(layout, keys, key, delta)
    local order = TabLayout.Order(layout, keys)
    local from
    for i, k in ipairs(order) do if k == key then from = i end end
    if not from then return false end
    local to
    if delta == "first" then
        to = 1
    elseif delta == "last" then
        to = #order
    else
        -- The next visible tab in that direction: swap places with it.
        local i = from + delta
        while order[i] ~= nil and layout.hidden[order[i]] do i = i + delta end
        if order[i] == nil then return false end
        to = i
    end
    if to == from then return false end
    table.remove(order, from)
    table.insert(order, to, key)
    layout.order = order
    return true
end

function TabLayout.SetHidden(layout, key, hidden)
    layout.hidden[key] = hidden and true or nil
end

-- Hide every tab in `keys` for which used(key) is false (professions none of your characters
-- have); returns how many were hidden.
function TabLayout.HideUnused(layout, keys, used)
    local n = 0
    for _, k in ipairs(keys) do
        if not used(k) and not layout.hidden[k] then
            layout.hidden[k] = true
            n = n + 1
        end
    end
    return n
end

-- The hidden tabs, in order.
function TabLayout.Hidden(layout, keys)
    local out = {}
    for _, k in ipairs(TabLayout.Order(layout, keys)) do
        if layout.hidden[k] then out[#out + 1] = k end
    end
    return out
end

function TabLayout.ShowAll(layout)
    layout.hidden = {}
end

function TabLayout.Reset(layout)
    layout.order, layout.hidden = {}, {}
end
