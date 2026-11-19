-- UI/MainFrame.lua
-- The Tradebook window: native portrait frame, header (global search, Default UI), a content
-- inset that hosts one view at a time, bottom tabs for every profession plus Camp, and icon
-- tabs down the right side (Professions, Characters, Legacy, Vendors; name on hover).

local _, ns = ...
local L, W = ns.L, ns.W

local UI = {}
ns.UI = UI

UI.views = {}
local frame, inset
local tabs = {}
local current = { tab = nil, view = nil }
local hideKeepsDefault = false

local CAMP = "camp"
local OVERVIEW, VENDORS, LEGACY, CHARACTERS = "overview", "vendors", "legacy", "characters" -- tabs at the far right
local RIGHT_TABS = { [OVERVIEW] = true, [VENDORS] = true, [LEGACY] = true, [CHARACTERS] = true }
-- The side tabs, top to bottom, and their icons (Forever's own side-tab art).
local SIDE_ORDER = { OVERVIEW, CHARACTERS, LEGACY, VENDORS }
local SIDE_ICONS = {
    [OVERVIEW] = "Interface\\Icons\\INV_SideTab_Professions_c60",
    [CHARACTERS] = "Interface\\Icons\\INV_SideTab_Stats_c60",
    [LEGACY] = "Interface\\Icons\\INV_SideTab_Reputation2_c60",
    [VENDORS] = "Interface\\Icons\\INV_SideTab_Currency_c60",
}
local EXTRA_ICON = "Interface\\Icons\\INV_SideTab_Bank_c60"
local sideTabs = {}
local MIN_W, MIN_H = 760, 500

-- Extra tabs at the far right, added before the window is built (UI.AddTab). Tradebook itself
-- adds none; the maintainer's dev addon (dev/TradebookDev, never packaged) adds one.
local extraTabs, extraOrder = {}, {}

-- Add a right-hand tab showing view `view` (registered with UI.RegisterView). shown() decides
-- whether it's visible (checked whenever the tabs are laid out). Call before the window opens.
function UI.AddTab(key, label, view, shown, tooltip)
    if extraTabs[key] then return end
    extraTabs[key] = { label = label, view = view, shown = shown, tooltip = tooltip }
    extraOrder[#extraOrder + 1] = key
    RIGHT_TABS[key] = true
end

---------------------------------------------------------------------------
-- views
---------------------------------------------------------------------------

-- A view is { frame = <Frame>, Show = function(self, arg) end, Refresh = function(self) end }.
function UI.RegisterView(name, view)
    UI.views[name] = view
end

local function showView(name, arg)
    for key, view in pairs(UI.views) do
        if key ~= name and view.frame then view.frame:Hide() end
    end
    local view = UI.views[name]
    if not view then return end
    if not view.frame then view:Build(inset) end
    -- The skill bar belongs to the profession view; it sets it again when it refreshes.
    if name ~= "profession" then UI.SetRankBar(nil) end
    current.view = name
    view.frame:Show()
    view:Show(arg)
end

function UI.CurrentView()
    return current.view and UI.views[current.view]
end

function UI.Refresh()
    if not (frame and frame:IsShown()) then return end
    UI.UpdateTabs()
    local view = UI.CurrentView()
    if view and view.Refresh then view:Refresh() end
    ns.RankUp.Refresh()
    ns.PlannerUI.Refresh()
end

---------------------------------------------------------------------------
-- tabs
---------------------------------------------------------------------------

local function tabIDs()
    local ids = {}
    for _, p in ipairs(ns.Professions.list) do ids[#ids + 1] = p.id end
    ids[#ids + 1] = CAMP
    return ids
end

local function tabTooltip(tab)
    GameTooltip:SetOwner(tab, RIGHT_TABS[tab.key] and "ANCHOR_RIGHT" or "ANCHOR_TOP")
    if extraTabs[tab.key] then
        GameTooltip:SetText(extraTabs[tab.key].label, 1, 1, 1)
        if extraTabs[tab.key].tooltip then GameTooltip:AddLine(extraTabs[tab.key].tooltip, 0.8, 0.8, 0.8, true) end
    elseif tab.key == CAMP then
        GameTooltip:SetText(L.CAMP_TITLE, 1, 1, 1)
    elseif tab.key == OVERVIEW then
        GameTooltip:SetText(L.TAB_OVERVIEW, 1, 1, 1)
        GameTooltip:AddLine(L.TAB_OVERVIEW_TIP, 0.8, 0.8, 0.8, true)
    elseif tab.key == VENDORS then
        GameTooltip:SetText(L.TAB_VENDORS, 1, 1, 1)
        GameTooltip:AddLine(L.TAB_VENDORS_TIP, 0.8, 0.8, 0.8, true)
    elseif tab.key == LEGACY then
        GameTooltip:SetText(L.TAB_LEGACY, 1, 1, 1)
        GameTooltip:AddLine(L.TAB_LEGACY_TIP, 0.8, 0.8, 0.8, true)
    elseif tab.key == CHARACTERS then
        GameTooltip:SetText(L.TAB_CHARACTERS, 1, 1, 1)
        GameTooltip:AddLine(L.TAB_CHARACTERS_TIP, 0.8, 0.8, 0.8, true)
    else
        local p = ns.Professions.Get(tab.key)
        GameTooltip:SetText(L[p.name] or p.name, 1, 1, 1)
        local with = ns.Characters.WithProfession(ns.db, tab.key, ns.charKey)
        if #with == 0 then
            GameTooltip:AddLine(L.TAB_NOBODY:format(L[p.name] or p.name), 0.7, 0.7, 0.7, true)
        else
            if ns.char and ns.char.professions[tab.key] then GameTooltip:AddLine(L.TAB_YOU, 0.3, 1, 0.3) end
            for _, c in ipairs(with) do
                local prof = c.professions[tab.key]
                GameTooltip:AddDoubleLine(W.ClassName(c), L.SKILL_RANK:format(prof.rank or 0, prof.max or 0))
            end
        end
        -- Friends (Fellowship Ledger, if installed); top few only.
        local friends = ns.Friends.For(tab.key)
        if #friends > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.FRIENDS_HEADER, W.GOLD:GetRGB())
            UI.views.guide.AddFriendsToTooltip(GameTooltip, friends, 5)
        end
    end
    if not RIGHT_TABS[tab.key] then
        GameTooltip:AddLine(L.TAB_RIGHT_CLICK, 0.5, 0.8, 1, true)
    end
    GameTooltip:Show()
end

-- A tab's name; short: the shorter name used when the full names don't fit in one row.
local function tabLabel(key, short)
    if extraTabs[key] then return extraTabs[key].label end
    if key == CAMP then return L.TAB_CAMP end
    if key == OVERVIEW then return L.TAB_OVERVIEW end
    if key == VENDORS then return L.TAB_VENDORS end
    if key == LEGACY then return L.TAB_LEGACY end
    if key == CHARACTERS then return short and L.TAB_CHARACTERS_SHORT or L.TAB_CHARACTERS end
    local p = ns.Professions.Get(key)
    return short and L.TAB_SHORT[p.name] or L[p.name] or p.name
end

---------------------------------------------------------------------------
-- Tab layout: order and hidden tabs (Core/TabLayout.lua), from a tab's right-click menu.
-- Only the profession tabs and Camp; Vendors, Legacy and Characters stay at the right.
---------------------------------------------------------------------------

-- The left-hand tab keys in their usual order.
local function leftKeys()
    local keys = {}
    for _, key in ipairs(tabIDs()) do
        if not RIGHT_TABS[key] then keys[#keys + 1] = key end
    end
    return keys
end

local function layout()
    return ns.TabLayout.Get(ns.db.settings, ns.charKey)
end
UI.TabLayout = layout

-- A tab is in use when one of your characters has that profession (Camp always is).
local function tabUsed(key)
    if key == CAMP then return true end
    return #ns.Characters.WithProfession(ns.db, key, ns.charKey) > 0
end

local function layoutChanged()
    UI.LayoutTabs()
    UI.UpdateTabs()
end

-- Hide a tab; if it's the one open, switch to the first one still shown.
local function hideTab(key)
    ns.TabLayout.SetHidden(layout(), key, true)
    if current.tab == key then
        local first = ns.TabLayout.Visible(layout(), leftKeys())[1]
        UI.SelectTab(first or CHARACTERS)
    end
    layoutChanged()
end

local function tabMenu(owner)
    local menu = _G.MenuUtil
    if not (menu and menu.CreateContextMenu) then return end
    local key, keys, TL = owner.key, leftKeys(), ns.TabLayout
    menu.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(tabLabel(key))
        local function move(text, delta)
            root:CreateButton(text, function()
                if TL.Move(layout(), keys, key, delta) then layoutChanged() end
            end)
        end
        move(L.TABS_MOVE_LEFT, -1)
        move(L.TABS_MOVE_RIGHT, 1)
        move(L.TABS_MOVE_FIRST, "first")
        move(L.TABS_MOVE_LAST, "last")
        root:CreateButton(L.TABS_HIDE, function() hideTab(key) end)
        root:CreateDivider()
        local hidden = TL.Hidden(layout(), keys)
        local show = root:CreateButton(L.TABS_SHOW_HIDDEN:format(#hidden))
        show:SetEnabled(#hidden > 0)
        for _, k in ipairs(hidden) do
            show:CreateButton(tabLabel(k), function()
                TL.SetHidden(layout(), k, false)
                layoutChanged()
            end)
        end
        if #hidden > 1 then
            show:CreateDivider()
            show:CreateButton(L.TABS_SHOW_ALL, function()
                TL.ShowAll(layout())
                layoutChanged()
            end)
        end
        root:CreateButton(L.TABS_HIDE_UNUSED, function()
            local n = TL.HideUnused(layout(), keys, tabUsed)
            if current.tab and layout().hidden[current.tab] then
                local first = TL.Visible(layout(), keys)[1]
                UI.SelectTab(first or CHARACTERS)
            end
            layoutChanged()
            ns.Print(L.TABS_HID_UNUSED:format(n))
        end)
        root:CreateDivider()
        local name = ns.charKey and ns.CharName(ns.charKey) or "?"
        root:CreateCheckbox(L.TABS_OWN:format(name),
            function() return TL.HasOwn(ns.db.settings, ns.charKey) end,
            function()
                TL.SetOwn(ns.db.settings, ns.charKey, not TL.HasOwn(ns.db.settings, ns.charKey))
                layoutChanged()
            end)
        root:CreateButton(L.TABS_RESET, function()
            TL.Reset(layout())
            layoutChanged()
        end)
    end)
end

local function buildTabs()
    for i, key in ipairs(tabIDs()) do
        local tab = CreateFrame("Button", nil, frame, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab.key = key
        tab:SetText(tabLabel(key))
        tab.badge = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        tab.badge:SetPoint("TOPRIGHT", -6, -4)
        tab:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            UI.SelectTab(self.key, true)
        end)
        -- Right-click menu on mouse-up: the selected tab is disabled by the tab template, and a
        -- disabled button gets no clicks, but still gets mouse up/down.
        tab:HookScript("OnMouseUp", function(self, button)
            if button == "RightButton" and not RIGHT_TABS[self.key] and self:IsMouseOver() then
                tabMenu(self)
            end
        end)
        -- The tooltip (with the right-click hint) on the selected tab too.
        tab:SetMotionScriptsWhileDisabled(true)
        tab:SetScript("OnEnter", tabTooltip)
        tab:SetScript("OnLeave", GameTooltip_Hide)
        tabs[i] = tab
    end
    frame.Tabs = tabs
    PanelTemplates_SetNumTabs(frame, #tabs)

    -- Side tabs: an icon each, the name on hover.
    local sideKeys = {}
    for _, key in ipairs(SIDE_ORDER) do sideKeys[#sideKeys + 1] = key end
    for _, key in ipairs(extraOrder) do sideKeys[#sideKeys + 1] = key end
    for i, key in ipairs(sideKeys) do
        local tab = CreateFrame("Frame", nil, frame, "LargeSideTabButtonTemplate")
        tab.key = key
        tab.Icon:SetTexture(SIDE_ICONS[key] or EXTRA_ICON)
        tab.Icon:SetSize(30, 30)
        tab.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
        tab:SetCustomOnMouseUpHandler(function(self, button, upInside)
            if button == "LeftButton" and upInside then UI.SelectTab(self.key, true) end
        end)
        tab:SetScript("OnEnter", tabTooltip)
        tab:SetScript("OnLeave", GameTooltip_Hide)
        sideTabs[i] = tab
    end
end

-- Lay the visible tabs out along the bottom, shrinking them to fit the window width.
-- Tabs can be hidden and moved (Core/TabLayout.lua; their data is still saved).
-- The window's minimum width: the largest of MIN_W and what parts of it need to fit without
-- overlapping (the tab row, the details' button row). The resize grip enforces it.
local minWidths = {}
function UI.SetMinWidth(key, width)
    minWidths[key] = width and math.ceil(width) or nil
    if not frame then return end
    local need = MIN_W
    for _, w in pairs(minWidths) do need = math.max(need, w) end
    if frame.resizeButton then frame.resizeButton.minWidth = need end
    if frame:GetWidth() < need - 0.5 then frame:SetWidth(need) end
end

local TAB_GAP = 3 -- space between tabs (no overlap)
local GROUP_GAP = 10 -- at least this much between the profession tabs and Legacy/Characters
local MAX_TAB_WIDTH = 110
function UI.LayoutTabs()
    if not frame then return end
    local visible, right, byKey = {}, {}, {}
    for _, tab in ipairs(tabs) do
        byKey[tab.key] = tab
        tab:Hide()
    end
    -- Side tabs down the right edge, top to bottom (an extra tab only while it applies).
    local prevSide
    for _, tab in ipairs(sideTabs) do
        local extra = extraTabs[tab.key]
        local show = not (extra and extra.shown and not extra.shown())
        tab:SetShown(show)
        if show then
            tab:ClearAllPoints()
            if prevSide then
                tab:SetPoint("TOPLEFT", prevSide, "BOTTOMLEFT", 0, -2)
            else
                tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60)
            end
            prevSide = tab
        end
    end
    -- Profession tabs and Camp in the layout's order, without hidden ones (the open tab
    -- shows even when hidden, e.g. a hidden profession opened from the game).
    for _, key in ipairs(ns.TabLayout.Visible(layout(), leftKeys(), current.tab)) do
        local tab = byKey[key]
        if tab then
            tab:Show()
            visible[#visible + 1] = tab
        end
    end
    -- PanelTabButtonTemplate re-sizes itself on show from the parent's tabPadding /
    -- minTabWidth / maxTabWidth, so the limits live on the frame, not just in this call.
    -- A tab must never be narrower than its fixed-size left + right cap art, or the
    -- stretchy middle (and its hover highlight) gets a negative width and draws wrongly.
    local first = visible[1]
    local caps = first and first.Left and first.Right and (first.Left:GetWidth() + first.Right:GetWidth()) or 40
    local minWidth = math.ceil(caps) + 6
    frame.tabPadding, frame.minTabWidth, frame.maxTabWidth = 0, minWidth, MAX_TAB_WIDTH
    -- Names and natural widths: full names when they fit in one row, else the short names,
    -- and if even those don't fit, the profession tabs wrap onto more rows below.
    local rightWidth, widths, natural
    local function measure(short)
        rightWidth, widths, natural = 0, {}, 0
        for i, tab in ipairs(right) do
            tab:SetText(tabLabel(tab.key, short))
            PanelTemplates_TabResize(tab, 0, nil, minWidth, MAX_TAB_WIDTH)
            rightWidth = rightWidth + tab:GetWidth() + (i > 1 and TAB_GAP or 0)
        end
        for i, tab in ipairs(visible) do
            tab:SetText(tabLabel(tab.key, short))
            PanelTemplates_TabResize(tab, 0, nil, minWidth, MAX_TAB_WIDTH)
            widths[i] = tab:GetWidth()
            natural = natural + widths[i] + (i > 1 and TAB_GAP or 0)
        end
    end
    local full = frame:GetWidth() - 16
    measure(false)
    if natural > full - rightWidth - GROUP_GAP then measure(true) end
    -- Rows of profession tabs (a narrow window wraps onto more rows).
    local avail = full - rightWidth - GROUP_GAP
    local rows = ns.util.WrapRows(widths, avail, avail, TAB_GAP)
    -- Narrowest the window can be: the right group plus two tabs in the first row.
    UI.SetMinWidth("tabs", 16 + rightWidth + GROUP_GAP + 2 * minWidth + TAB_GAP)
    local rowHeight = (first and first:GetHeight() or 32) - 4
    for r, row in ipairs(rows) do
        local prev
        for _, i in ipairs(row) do
            local tab = visible[i]
            tab:ClearAllPoints()
            if prev then
                tab:SetPoint("LEFT", prev, "RIGHT", TAB_GAP, 0)
            else
                tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 8, 2 - (r - 1) * rowHeight)
            end
            prev = tab
        end
        -- A single tab wider than its row (very narrow window): shrink it to fit.
        if #row == 1 and widths[row[1]] > avail then
            PanelTemplates_TabResize(visible[row[1]], 0, nil, minWidth, math.max(minWidth, avail))
        end
    end
    UI.tabRows = #rows
end

function UI.UpdateTabs()
    if not frame then return end
    -- Select first: PanelTemplates restyles every tab, then we color them. A side tab open:
    -- no bottom tab is selected.
    local selected = 0
    for i, tab in ipairs(tabs) do
        if tab.key == current.tab then selected = i end
    end
    PanelTemplates_SetTab(frame, selected)
    for _, tab in ipairs(sideTabs) do tab:SetChecked(tab.key == current.tab) end
    local counts = ns.Characters.ProfessionCounts(ns.db, ns.charKey)
    for _, tab in ipairs(tabs) do
        local text = tab.Text or tab:GetFontString()
        if RIGHT_TABS[tab.key] then
            tab.badge:SetText("")
            if text then text:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB()) end
        elseif tab.key == CAMP then
            tab.badge:SetText("")
            if text then text:SetTextColor(W.GOLD:GetRGB()) end
        else
            local n = counts[tab.key] or 0
            tab.badge:SetText(n > 0 and tostring(n) or "")
            local mine = ns.char and ns.char.professions[tab.key]
            if text then
                if n == 0 then
                    text:SetTextColor(W.GREY:GetRGB())
                elseif mine then
                    text:SetTextColor(W.GOLD:GetRGB())
                else
                    text:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
                end
            end
        end
    end
end

-- Select a tab (a profession you have also opens in the game). fromClick: a real click.
-- Browse every recipe of a profession none of your characters have (or go back to its
-- guide page). Remembered per profession.
function UI.SetBrowse(skillLineID, on)
    ns.db.settings.browse = ns.db.settings.browse or {}
    ns.db.settings.browse[skillLineID] = on or nil
    if on then ns.Scanner.CacheProfession(ns.db, skillLineID) end
    UI.SelectTab(skillLineID)
end

function UI.SelectTab(key, fromClick)
    if not frame then UI.Create() end
    local old = current.tab
    current.tab = key
    -- A hidden tab shows while it's open: lay the tabs out again when one opens or closes.
    local hidden = layout().hidden
    if (old ~= nil and hidden[old]) or hidden[key] then UI.LayoutTabs() end
    ns.db.settings.lastTab = key
    if extraTabs[key] then
        showView(extraTabs[key].view)
    elseif key == CAMP then
        showView("camp")
    elseif key == OVERVIEW then
        showView("overview")
    elseif key == VENDORS then
        showView("vendors")
    elseif key == LEGACY then
        showView("legacy")
    elseif key == CHARACTERS then
        showView("characters")
    else
        local mine = ns.char and ns.char.professions[key]
        local browse = ns.db.settings.browse and ns.db.settings.browse[key]
        local linked = UI.pendingLinked and UI.pendingLinked.skill == key
        -- Switching to a profession you have opens it in the game too (so Craft works), from
        -- any switch, not only a tab click; but not over another player's linked profession
        -- being shown (unless you clicked the tab).
        if mine and not linked and (fromClick or not ns.Takeover.IsForeignView()) then
            ns.Crafting.OpenProfession(key)
        end
        if #ns.Characters.WithProfession(ns.db, key, ns.charKey) == 0 and not browse and not linked then
            showView("guide", key)
        else
            showView("profession", key)
        end
    end
    UI.UpdateTabs()
end

-- Which tab to show when the window opens: the profession whose window is open, else My
-- professions (the K key, like the Professions book), unless that's turned off in the options
-- (then the tab you had open last).
local function defaultTab()
    if UI.pendingLinked then return UI.pendingLinked.skill end
    local open = ns.Scanner.OpenProfession()
    if open then return open.professionID end
    if ns.db.settings.openOverview ~= false then return OVERVIEW end
    local last = ns.db.settings.lastTab
    -- (A tab that no longer exists, e.g. a dev tab without its addon, is skipped.)
    local known = last and (ns.Professions.Get(last) or last == CAMP or RIGHT_TABS[last])
    local extra = known and extraTabs[last]
    local hidden = layout().hidden
    if known and not hidden[last] and not (extra and extra.shown and not extra.shown()) then return last end
    local visible = ns.TabLayout.Visible(layout(), leftKeys())
    for _, key in ipairs(visible) do
        if ns.char and ns.char.professions[key] then return key end
    end
    if visible[1] then return visible[1] end
    return ns.Professions.list[1].id
end

---------------------------------------------------------------------------
-- window
---------------------------------------------------------------------------

local function savePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    local w = ns.db.settings.window
    w.point, w.relPoint, w.x, w.y = point, relPoint, x, y
    w.width, w.height = frame:GetSize()
end

local function restorePosition()
    local w = ns.db.settings.window
    frame:SetSize(math.max(MIN_W, w.width or MIN_W), math.max(MIN_H, w.height or MIN_H))
    frame:ClearAllPoints()
    if w.point then
        frame:SetPoint(w.point, UIParent, w.relPoint or w.point, w.x or 0, w.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

-- Scale 1.0 in settings is drawn at DB.BASE_SCALE.
function UI.ApplyScale()
    if frame then frame:SetScale((ns.db.settings.scale or 1) * ns.DB.BASE_SCALE) end
end

local function buildHeader()
    frame:SetPortraitToAsset(ns.Minimap.ICON)
    if frame.SetTitle then frame:SetTitle(L.ADDON_TITLE) end

    local defaultBtn = W.Button(frame, L.DEFAULT_UI, 96, 20)
    defaultBtn:SetPoint("TOPRIGHT", -28, -1)
    -- Draw it above the window's border and title art (NineSlice, TitleContainer, close
    -- button), whose frame levels the template sets well above the window's own.
    local function raise()
        local level = frame:GetFrameLevel()
        for _, part in ipairs({ frame.NineSlice, frame.TitleContainer, frame.CloseButton }) do
            if part and part.GetFrameLevel then level = math.max(level, part:GetFrameLevel()) end
        end
        defaultBtn:SetFrameLevel(level + 2)
    end
    raise()
    frame:HookScript("OnShow", raise)
    defaultBtn:SetScript("OnClick", function() ns.Takeover.UseDefault() end)
    W.Tooltip(defaultBtn, L.DEFAULT_UI_TIP, "ANCHOR_BOTTOM")

    -- Right end of the header row (Legacy and Characters are bottom tabs now).
    local headerRight = CreateFrame("Frame", nil, frame)
    headerRight:SetSize(1, 22)
    headerRight:SetPoint("TOPRIGHT", -10, -30)

    local search = W.SearchBox(frame, 260, function(text)
        if ns.util.Query(text) then showView("search", text) elseif current.view == "search" then
            UI.SelectTab(current.tab or defaultTab())
        end
    end)
    search:SetPoint("TOPLEFT", 66, -32)
    if search.Instructions then search.Instructions:SetText(L.SEARCH_ALL) end
    frame.globalSearch = search

    -- Between the search box and the Legacy button:
    --   [Leveling plan]  [====== skill bar ======]  [Train <rank>]
    -- styled like the default Professions window (its frame and background art, blue fill).
    -- The buttons show when they apply; the bar takes the space that's left (UI.SetRankBar).
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetHeight(29)
    bar.leftEdge, bar.rightEdge = search, headerRight
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAtlas("Professions-skillbar-bg", true)
    bar.bg:SetPoint("TOPLEFT")
    bar.fill = CreateFrame("StatusBar", nil, bar)
    bar.fill:SetPoint("TOPLEFT", 5, -3) -- moved in by OnSizeChanged
    bar.fill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar.fill:SetStatusBarColor(0.22, 0.52, 1.0)
    -- Border art and number sit on a frame above the fill (a child frame draws over its
    -- parent's textures, so the border can't live on `bar` itself).
    bar.fill:SetFrameLevel(bar:GetFrameLevel() + 1)
    local overlay = CreateFrame("Frame", nil, bar)
    overlay:SetAllPoints(bar)
    overlay:SetFrameLevel(bar.fill:GetFrameLevel() + 2)
    bar.border = overlay:CreateTexture(nil, "ARTWORK")
    bar.border:SetAtlas("Professions-skillbar-frame", true)
    bar.border:SetPoint("TOPLEFT")
    bar.text = overlay:CreateFontString(nil, "OVERLAY", "Number12FontOutline")
    bar.text:SetPoint("CENTER", bar.fill, "CENTER", 0, 0)
    bar:SetScript("OnSizeChanged", function(self, w)
        self.bg:SetWidth(w)
        self.border:SetWidth(w - 2)
        -- The frame art (451 wide at its own size) stretches sideways with the bar, and so
        -- do its bevelled ends. The square blue fill starts and stops just inside the ends'
        -- upright lines (8 art pixels in), or its corners stick out past the frame.
        local edge = 8 * (w - 2) / 451
        self.fill:ClearAllPoints()
        self.fill:SetPoint("TOPLEFT", edge, -3)
        self.fill:SetSize(math.max(1, w - 2 - 2 * edge), 18)
    end)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self.tip, 1, 1, 1)
        if self.open then GameTooltip:AddLine(L.RANKBAR_CLICK, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    -- Click the bar: ranks, how to train the next one, specializations (UI/RankUp.lua).
    bar:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.open then self.open() end
    end)
    bar:SetScript("OnLeave", GameTooltip_Hide)
    -- "Train <rank>" to the right of the bar (UI/RankUp.lua), when the viewed character can
    -- train the next rank; "Leveling plan" to its left (UI/Planner.lua), below the cap.
    bar.rankUp = W.Button(frame, "", 110, 22)
    bar.rankUp:SetPoint("RIGHT", headerRight, "LEFT", 0, 0)
    bar.rankUp:SetScript("OnClick", function(self) if self.action then self.action() end end)
    bar.rankUp:Hide()
    bar.plan = W.Button(frame, L.PLAN_BUTTON, 110, 22)
    bar.plan:SetPoint("LEFT", search, "RIGHT", 14, 0)
    bar.plan:SetScript("OnClick", function(self) if self.action then self.action() end end)
    W.Tooltip(bar.plan, { L.PLAN_BUTTON, L.PLAN_OPEN_TIP }, "ANCHOR_BOTTOM")
    bar.plan:Hide()
    bar.link = UI.CreateLinkButton(frame)
    bar.link:Hide()
    bar.unlearn = UI.CreateUnlearnButton(frame)
    bar.unlearn:Hide()
    bar:Hide()
    frame.rankBar = bar
end

---------------------------------------------------------------------------
-- Link button: post the open profession's recipe list in chat, like the default window's
-- (C_TradeSkillUI.GetTradeSkillListLink; only while that profession is open).
---------------------------------------------------------------------------

local function professionLink()
    return ns.Compat.Call("C_TradeSkillUI.GetTradeSkillListLink")
end

-- Open the chat box with `text`. No chat frame is passed, so the game picks the box you
-- used last, still on its channel (Guild, Party, a whisper...), not the first tab's Say.
local function openChatWith(text)
    local util = _G.ChatFrameUtil
    if util and util.OpenChat then util.OpenChat(text)
    elseif _G.ChatFrame_OpenChat then _G.ChatFrame_OpenChat(text) end
end

-- Put a link in the chat box: into the one being typed in, else open the last one with it.
local function insertInChat(link)
    local util = _G.ChatFrameUtil
    if util and util.GetActiveWindow and util.GetActiveWindow() and util.InsertLink then
        util.InsertLink(link)
    elseif _G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow() and _G.ChatEdit_InsertLink then
        _G.ChatEdit_InsertLink(link)
    else
        openChatWith(link)
    end
end
UI.InsertInChat = insertInChat

-- PURE. Is an edit box (its name, whether it belongs to a chat frame) a chat box?
function UI.IsChatBox(name, chatFrame)
    return chatFrame ~= nil or (name or ""):match("^ChatFrame%d+EditBox$") ~= nil
end

-- The box being typed in when it isn't a chat box (the auction house's or Auctionator's search
-- box, or any other), else nil.
local function searchBox()
    local focus = _G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus()
    if not (focus and focus.GetObjectType and focus:GetObjectType() == "EditBox") then return nil end
    if UI.IsChatBox(focus.GetName and focus:GetName(), focus.chatFrame) then return nil end
    return focus
end

-- Shift-click an item link: while typing in a search box (the auction house's, Auctionator's...)
-- the item's name goes there, as the game's own bags do; else the link goes in the chat box.
function UI.InsertItemLink(link)
    local box = searchBox()
    local name = box and link and link:match("|h%[(.-)%]|h")
    if name then
        if box.IsMultiLine and box:IsMultiLine() then box:Insert(name) else box:SetText(name) end
        return
    end
    insertInChat(link)
end

-- Shift-click an item (by ID): UI.InsertItemLink (waits for the item's data when it isn't
-- loaded yet).
function UI.LinkItem(itemID)
    local _, link = ns.Compat.ItemInfo(itemID)
    if link then
        UI.InsertItemLink(link)
    elseif _G.Item and _G.Item.CreateFromItemID then
        local item = _G.Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            local l = item:GetItemLink()
            if l then UI.InsertItemLink(l) end
        end)
    end
end

-- Right-click: Guild, Party, Raid and your chat channels (as the default window offers).
local function linkMenu(owner)
    local menu = _G.MenuUtil
    if not (menu and menu.CreateContextMenu) then return end
    menu.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(_G.TRADESKILL_POST or L.LINK_POST)
        local channels = {
            { _G.SLASH_GUILD1 or "/g", _G.GUILD or "Guild", IsInGuild() },
            { _G.SLASH_PARTY1 or "/p", _G.PARTY or "Party", (GetNumSubgroupMembers() or 0) > 0 },
            { _G.SLASH_RAID1 or "/raid", _G.RAID or "Raid", IsInRaid() },
        }
        local list = { GetChannelList() }
        for i = 1, #list, 3 do
            local util = _G.ChatFrameUtil
            local name = util and util.ResolveChannelName and util.ResolveChannelName(list[i + 1]) or list[i + 1]
            -- Tradebook's own hidden sharing channels are no place for links.
            if not (ns.Net and ns.Net.LaneOfChannel and ns.Net.LaneOfChannel(tostring(list[i + 1]))) then
                channels[#channels + 1] = { "/" .. list[i], name, not list[i + 2] }
            end
        end
        for _, ch in ipairs(channels) do
            local button = root:CreateButton(ch[2], function()
                local link = professionLink()
                if link then openChatWith(ch[1] .. " " .. link) end
            end)
            button:SetEnabled(ch[3] and true or false)
        end
    end)
end

function UI.CreateLinkButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(22, 22)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER")
    b.icon:SetSize(15, 15)
    local function art()
        local enabled, over = b:IsEnabled(), b:IsMouseOver()
        b.icon:SetAtlas(enabled and "common-icon-chatlink" or "common-icon-chatlink-disable")
        b.bg:SetAtlas(not enabled and "common-button-tertiary-square-disabled"
            or (b.down and over and "common-button-tertiary-square-pressed")
            or (over and "common-button-tertiary-square-hover") or "common-button-tertiary-square-normal")
    end
    b.UpdateArt = art
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnMouseDown", function() b.down = true; art() end)
    b:SetScript("OnMouseUp", function() b.down = false; art() end)
    b:SetScript("OnEnable", art)
    b:SetScript("OnDisable", art)
    b:SetScript("OnShow", art)
    b:SetScript("OnEnter", function(self)
        art()
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(_G.LINK_TRADESKILL_TOOLTIP or L.LINK_TIP, nil, nil, nil, nil, true)
        if not self:IsEnabled() and self.disabledTip then
            GameTooltip:AddLine(self.disabledTip, 1, 0.3, 0.3, true)
        else
            GameTooltip:AddLine(L.LINK_RIGHT_CLICK, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() art(); GameTooltip_Hide() end)
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", function(self, button)
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        if button == "RightButton" then
            linkMenu(self)
            return
        end
        local link = professionLink()
        if link then insertInChat(link) end
    end)
    return b
end

---------------------------------------------------------------------------
-- Unlearn button: the red cross the default window has next to a main profession's skill bar
-- (its profession book page). It opens the game's own "Unlearn" pop-up, where you type UNLEARN
-- to confirm, so nothing is unlearned by a stray click.
---------------------------------------------------------------------------

-- Whether the game's unlearn pop-up is there to use.
function UI.CanUnlearn()
    return _G.StaticPopupDialogs ~= nil and _G.StaticPopupDialogs.UNLEARN_SKILL ~= nil
        and _G.StaticPopup_Show ~= nil
end

function UI.CreateUnlearnButton(parent)
    local b = CreateFrame("Button", nil, parent)
    -- Smaller than the Link button: it's rarely used and shouldn't draw the eye.
    b:SetSize(14, 14)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetAtlas("Profession-button-red-crossmark")
    b.pressed = b:CreateTexture(nil, "OVERLAY")
    b.pressed:SetAllPoints()
    b.pressed:SetAtlas("Profession-button-red-crossmark-pressed")
    b.pressed:Hide()
    b:SetScript("OnMouseDown", function() b.pressed:Show() end)
    b:SetScript("OnMouseUp", function() b.pressed:Hide() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.UNLEARN_TITLE:format(self.name or "?"), 1, 0.3, 0.3)
        GameTooltip:AddLine(_G.UNLEARN_SKILL_TOOLTIP or L.UNLEARN_TIP, nil, nil, nil, true)
        GameTooltip:AddLine(L.UNLEARN_CONFIRM, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() b.pressed:Hide(); GameTooltip_Hide() end)
    b:SetScript("OnClick", function(self)
        if not (self.skillLine and UI.CanUnlearn()) then return end
        local popup = _G.InputUtil and _G.InputUtil.IsGamepadUIEnabled and _G.InputUtil.IsGamepadUIEnabled()
            and _G.StaticPopupDialogs.UNLEARN_SKILL_GAMEPAD and "UNLEARN_SKILL_GAMEPAD" or "UNLEARN_SKILL"
        _G.StaticPopup_Show(popup, self.name, nil, self.skillLine)
    end)
    return b
end

-- Show the skill bar for a character's profession, or hide it (rank == nil).
-- label: shown in front of the numbers (the profession name).
-- rankUp: { text, onClick, plan } : text shows the "Train <rank>" button, plan the
-- "Leveling plan" button, onClick opens the rank window from a click on the bar.
-- link: { live = bool, disabledTip } shows the Link button (your own profession), enabled
-- while that profession is open.
-- unlearn: { name, skillLine } shows the Unlearn button (your own main professions).
function UI.SetRankBar(rank, max, tip, label, rankUp, link, unlearn)
    local bar = frame and frame.rankBar
    if not bar then return end
    local shown = rank and max and max > 0
    local showTrain = shown and rankUp ~= nil and rankUp.text ~= nil
    local showPlan = shown and rankUp ~= nil and rankUp.plan ~= nil
    local showLink = shown and link ~= nil
    local showUnlearn = shown and unlearn ~= nil and UI.CanUnlearn()
    bar.rankUp:SetShown(showTrain)
    bar.link:SetShown(showLink)
    bar.unlearn:SetShown(showUnlearn)
    -- Right of the bar: [Unlearn] [Link] [Train <rank>], each when it applies.
    local right, gap = bar.rightEdge, -14
    if showTrain then right, gap = bar.rankUp, -6 end
    if showLink then
        bar.link:SetEnabled(link.live and true or false)
        bar.link.disabledTip = link.disabledTip
        bar.link:UpdateArt()
        bar.link:ClearAllPoints()
        bar.link:SetPoint("RIGHT", right, "LEFT", gap, -3)
        right, gap = bar.link, -2
    end
    if showUnlearn then
        bar.unlearn.name, bar.unlearn.skillLine = unlearn.name, unlearn.skillLine
        bar.unlearn:ClearAllPoints()
        bar.unlearn:SetPoint("RIGHT", right, "LEFT", gap, right == bar.link and 0 or -3)
        right = bar.unlearn
    end
    bar.plan:SetShown(showPlan)
    bar.open = rankUp and rankUp.onClick
    if showTrain then
        bar.rankUp:SetText(rankUp.text)
        bar.rankUp:SetWidth(math.max(90, bar.rankUp:GetFontString():GetStringWidth() + 24))
        bar.rankUp.action = rankUp.onClick
    end
    if showPlan then
        bar.plan:SetWidth(math.max(90, bar.plan:GetFontString():GetStringWidth() + 24))
        bar.plan.action = rankUp.plan
    end
    -- The bar fills the space between whichever buttons show.
    bar:ClearAllPoints()
    bar:SetPoint("LEFT", showPlan and bar.plan or bar.leftEdge, "RIGHT", showPlan and 10 or 18, -3)
    if showUnlearn or showLink then
        bar:SetPoint("RIGHT", right, "LEFT", -2, 0)
    else
        bar:SetPoint("RIGHT", showTrain and bar.rankUp or bar.rightEdge, "LEFT", showTrain and -10 or -18, -3)
    end
    if not shown then
        bar:Hide()
        return
    end
    bar.fill:SetMinMaxValues(0, max)
    bar.fill:SetValue(math.min(rank, max))
    local numbers = L.SKILL_RANK:format(rank, max)
    bar.text:SetText(label and (label .. "  " .. numbers) or numbers)
    bar.tip = tip
    bar:Show()
end

function UI.Create()
    if frame then return frame end
    -- One named frame so ESC closes it (UISpecialFrames needs a global name).
    frame = CreateFrame("Frame", "TradebookFrame", UIParent, "PortraitFrameTemplate")
    frame:SetToplevel(true)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition()
    end)
    frame:Hide()
    tinsert(UISpecialFrames, "TradebookFrame")
    -- The template's X calls HideUIPanel, which does nothing in combat. Tradebook isn't
    -- a protected frame, so hide it directly (return false = skip HideUIPanel).
    frame.onCloseCallback = function()
        UI.Hide()
        return false
    end

    inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 6, -60)
    inset:SetPoint("BOTTOMRIGHT", -6, 6)
    frame.inset = inset

    local resize = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
    resize:SetPoint("BOTTOMRIGHT", -2, 2)
    resize:SetFrameLevel(frame:GetFrameLevel() + 20)
    resize:Init(frame, MIN_W, MIN_H, 1800, 1200)
    frame.resizeButton = resize
    resize:SetOnResizeStoppedCallback(savePosition)

    buildHeader()
    buildTabs()
    restorePosition()
    UI.ApplyScale()
    UI.LayoutTabs()
    frame:HookScript("OnSizeChanged", function() UI.LayoutTabs() end)

    frame:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        UI.SelectTab(defaultTab())
        -- Tabs resize themselves in their own OnShow; lay out again once that's done.
        C_Timer.After(0, UI.LayoutTabs)
    end)
    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        if not hideKeepsDefault then ns.Takeover.OnTradebookHidden() end
        hideKeepsDefault = false
    end)

    -- Refresh on data changes, only while shown.
    local function refreshSoon() if frame:IsShown() then ns.Throttle("ui", 0.2, UI.Refresh) end end
    ns.Listen("RECIPES_UPDATED", function(skillLineID)
        if frame:IsShown() and current.tab == skillLineID and current.view == "guide" then
            UI.SelectTab(skillLineID)
        end
        refreshSoon()
    end)
    ns.Listen("PROFESSIONS_UPDATED", refreshSoon)
    ns.Listen("ITEMS_UPDATED", refreshSoon)
    ns.On("TRADE_SKILL_SHOW", function()
        if not frame:IsShown() then return end
        local open = ns.Scanner.OpenProfession()
        local onProfession = current.view == "profession" or current.view == "guide"
        if open and open.professionID ~= current.tab and onProfession then
            UI.SelectTab(open.professionID)
        elseif open and current.view == "profession" then
            -- Your own profession opened while a linked one of the same kind was shown.
            local view = UI.views.profession
            if view and ns.Linked.IsKey(view.charKey) then
                view.charKey = ns.charKey
                view:Refresh()
            end
        end
    end)
    ns.On("TRADE_SKILL_CLOSE", refreshSoon)
    -- Item names/icons not cached yet show as "item:123" until the game loads them.
    ns.On("GET_ITEM_INFO_RECEIVED", refreshSoon)
    ns.On("ITEM_DATA_LOAD_RESULT", refreshSoon)
    ns.On("PLAYER_REGEN_ENABLED", refreshSoon)
    ns.On("PLAYER_REGEN_DISABLED", refreshSoon)
    return frame
end

-- Title shows a banner while the made-up account (/tb fake) is on.
function UI.SetFakeBanner(on)
    if not (frame and frame.SetTitle) then return end
    frame:SetTitle(on and (L.ADDON_TITLE .. "  " .. W.ColorText(W.RED, L.FAKE_BANNER)) or L.ADDON_TITLE)
end

function UI.Show()
    UI.Create()
    if not frame:IsShown() then frame:Show() end
end

-- keepDefault: hide Tradebook but leave the default window open (Default UI button).
function UI.Hide(keepDefault)
    if not (frame and frame:IsShown()) then return end
    hideKeepsDefault = keepDefault and true or false
    frame:Hide()
end

function UI.Toggle()
    if frame and frame:IsShown() then UI.Hide() else UI.Show() end
end

function UI.IsShown()
    return frame ~= nil and frame:IsShown()
end

-- The default window closed by itself (ESC, walking away): close Tradebook too.
function UI.OnDefaultClosed()
    if frame and frame:IsShown() then
        hideKeepsDefault = true
        frame:Hide()
    end
end

-- Show another player's linked profession (Core/Linked.lua) on its tab.
function UI.ShowLinked(c, skill)
    UI.Create()
    UI.pendingLinked = { key = c.key, skill = skill }
    if frame:IsShown() then UI.SelectTab(skill) else frame:Show() end
    UI.pendingLinked = nil
end

-- For the profession view: the linked character to show on this tab, once.
function UI.TakeLinked(skill)
    local p = UI.pendingLinked
    if p and p.skill == skill then
        UI.pendingLinked = nil
        return p.key
    end
    return nil
end

function UI.ShowCharacters()
    UI.Create()
    if not frame:IsShown() then frame:Show() end
    UI.SelectTab(CHARACTERS)
end

function UI.GlobalSearch(text)
    UI.Create()
    if not frame:IsShown() then frame:Show() end
    frame.globalSearch:SetText(text or "")
    if ns.util.Query(text) then showView("search", text) end
end

-- Jump to a recipe (from search, characters, camp). fromClick: also open the profession.
-- quantity: also fill the quantity box (a leveling plan step's crafts).
function UI.OpenRecipe(recipeID, charKey, fromClick, quantity)
    local r = ns.db.recipes[recipeID]
    if not r then return end
    UI.SelectTab(r.s, fromClick)
    local view = UI.views.profession
    if current.view == "profession" and view.SelectRecipe then
        view:SelectRecipe(recipeID, charKey)
        if quantity and view.details then view.details:SetQuantity(quantity) end
    end
end

function UI.ShowView(name, arg)
    showView(name, arg)
end
