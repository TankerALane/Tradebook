-- UI/Settings.lua
-- Settings panel in the game's Settings window (Options > AddOns > Tradebook).

local _, ns = ...
local L, W = ns.L, ns.W

local Settings_ = {}
ns.Settings = Settings_

local category

local function slider(parent, label, min, max, step, get, set, fmt)
    local s = CreateFrame("Slider", nil, parent, "MinimalSliderTemplate")
    s:SetSize(220, 18)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s.label = W.Text(parent, "GameFontHighlight")
    s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)
    s.value = W.Text(parent, "GameFontHighlightSmall")
    s.value:SetPoint("LEFT", s, "RIGHT", 10, 0)
    local function update(v)
        s.label:SetText(label)
        s.value:SetText(string.format(fmt or "%s", v))
    end
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        set(v)
        update(v)
    end)
    s.Refresh = function() s:SetValue(get()); update(get()) end
    return s
end

local function build()
    local panel = CreateFrame("Frame")
    panel:Hide()

    local title = W.Text(panel, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.ADDON_TITLE)

    local replace = W.Check(panel, L.OPT_REPLACE, function(v) ns.db.settings.replaceDefault = v end)
    replace:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -4, -16)

    local minimap = W.Check(panel, L.OPT_MINIMAP, function(v) ns.Minimap.SetShown(v) end)
    minimap:SetPoint("TOPLEFT", replace, "BOTTOMLEFT", 0, -6)

    -- Gathering tabs: shown or hidden in the tab layout (the current character's, Core/TabLayout.lua).
    local function gatheringIDs()
        local ids = {}
        for _, p in ipairs(ns.Professions.list) do if p.gathering then ids[#ids + 1] = p.id end end
        return ids
    end
    local function tabLayout() return ns.TabLayout.Get(ns.db.settings, ns.charKey) end
    local gathering = W.Check(panel, L.OPT_GATHERING, function(v)
        for _, id in ipairs(gatheringIDs()) do ns.TabLayout.SetHidden(tabLayout(), id, not v) end
        if ns.UI.LayoutTabs then ns.UI.LayoutTabs() end
    end)
    W.Tooltip(gathering, { L.OPT_GATHERING, L.OPT_TABS_TIP })
    gathering:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -6)

    local crossFaction = W.Check(panel, L.OPT_CROSS_FACTION, function(v)
        ns.db.settings.crossFaction = v
        ns.Recipes.Invalidate()
        if ns.UI.LayoutTabs then ns.UI.LayoutTabs() end
        ns.UI.Refresh()
    end)
    crossFaction:SetPoint("TOPLEFT", gathering, "BOTTOMLEFT", 0, -6)
    W.Tooltip(crossFaction, { L.OPT_CROSS_FACTION, L.OPT_CROSS_FACTION_TIP })

    local netShare = W.Check(panel, L.OPT_NETSHARE, function(v) ns.Net.SetEnabled(v) end)
    netShare:SetPoint("TOPLEFT", crossFaction, "BOTTOMLEFT", 0, -6)
    W.Tooltip(netShare, { L.OPT_NETSHARE, L.OPT_NETSHARE_TIP })

    -- Disenchant information: one switch for all of it, the tooltip options under it.
    local deTooltip, deCompact
    local function deSubOptions()
        local on = ns.db.settings.deShow ~= false
        for _, c in ipairs({ deTooltip, deCompact }) do
            c:SetEnabled(on)
            if c.text then c.text:SetFontObject(on and "GameFontHighlight" or "GameFontDisable") end
        end
    end
    local deShow = W.Check(panel, L.OPT_DE_SHOW, function(v)
        ns.db.settings.deShow = v
        deSubOptions()
        ns.UI.Refresh()
    end)
    deShow:SetPoint("TOPLEFT", netShare, "BOTTOMLEFT", 0, -6)
    W.Tooltip(deShow, { L.OPT_DE_SHOW, L.OPT_DE_SHOW_TIP })
    deTooltip = W.Check(panel, L.OPT_DE_TOOLTIP, function(v) ns.db.settings.deTooltip = v end)
    deTooltip:SetPoint("TOPLEFT", deShow, "BOTTOMLEFT", 20, -6)
    deCompact = W.Check(panel, L.OPT_DE_COMPACT, function(v) ns.db.settings.deCompact = v end)
    deCompact:SetPoint("TOPLEFT", deTooltip, "BOTTOMLEFT", 0, -6)

    local scale = slider(panel, L.OPT_SCALE, 0.6, 1.4, 0.05,
        function() return ns.db.settings.scale or 1 end,
        function(v) ns.db.settings.scale = v; ns.UI.ApplyScale() end, "%.2f")
    scale:SetPoint("TOPLEFT", deCompact, "BOTTOMLEFT", -14, -36)

    local stale = slider(panel, L.OPT_STALE, 7, 180, 1,
        function() return ns.db.settings.staleDays or 30 end,
        function(v) ns.db.settings.staleDays = v end, "%d")
    stale:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", 0, -40)

    local del = W.Button(panel, L.OPT_DELETE, 200, 24)
    del:SetPoint("TOPLEFT", stale, "BOTTOMLEFT", -2, -30)
    del:SetScript("OnClick", function()
        HideUIPanel(SettingsPanel)
        ns.UI.ShowCharacters()
    end)

    local credits = W.Text(panel, "GameFontDisableSmall")
    credits:SetPoint("BOTTOMLEFT", 16, 16)
    credits:SetPoint("RIGHT", -16, 0)
    credits:SetText(L.OPT_CREDITS)

    panel:SetScript("OnShow", function()
        replace:SetChecked(ns.db.settings.replaceDefault)
        minimap:SetChecked(not ns.db.settings.minimap.hide)
        local anyShown = false
        for _, id in ipairs(gatheringIDs()) do
            if not tabLayout().hidden[id] then anyShown = true end
        end
        gathering:SetChecked(anyShown)
        crossFaction:SetChecked(ns.db.settings.crossFaction == true)
        netShare:SetChecked(ns.db.settings.netShare ~= false)
        deShow:SetChecked(ns.db.settings.deShow ~= false)
        deTooltip:SetChecked(ns.db.settings.deTooltip ~= false)
        deCompact:SetChecked(ns.db.settings.deCompact ~= false)
        deSubOptions()
        scale.Refresh()
        stale.Refresh()
    end)
    return panel
end

function Settings_.Start()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = build()
    category = Settings.RegisterCanvasLayoutCategory(panel, L.ADDON_TITLE)
    Settings.RegisterAddOnCategory(category)
end

function Settings_.Open()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    end
end
