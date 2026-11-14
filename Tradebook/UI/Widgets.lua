-- UI/Widgets.lua
-- Small factories over Blizzard templates (all confirmed in the Forever 1.60.1 UI source).

local _, ns = ...
local Compat = ns.Compat

local W = {}
ns.W = W

-- Brand accents: warm gold and brown (Tradebook icon).
W.GOLD = CreateColor(0.85, 0.65, 0.29)
W.BROWN = CreateColor(0.45, 0.30, 0.16)
W.GREY = CreateColor(0.5, 0.5, 0.5)
W.RED = CreateColor(1, 0.3, 0.3)
W.GREEN = CreateColor(0.3, 1, 0.3)

-- Skill-up colors, same as the default window.
W.DIFFICULTY = {
    [0] = CreateColor(1.0, 0.5, 0.25),  -- Optimal (orange)
    [1] = CreateColor(1.0, 1.0, 0.0),   -- Medium (yellow)
    [2] = CreateColor(0.25, 0.75, 0.25),-- Easy (green)
    [3] = CreateColor(0.5, 0.5, 0.5),   -- Trivial (grey)
}

function W.Button(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 100, height or 22)
    b:SetText(text or "")
    return b
end

function W.Text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(true)
    return fs
end

function W.SearchBox(parent, width, onChange)
    local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    box:SetSize(width or 200, 20)
    box:SetAutoFocus(false)
    box:HookScript("OnTextChanged", function(self, userInput)
        if userInput or self:GetText() == "" then onChange(self:GetText()) end
    end)
    return box
end

function W.Check(parent, text, onClick)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c.text = c.text or c.Text
    if c.text then c.text:SetText(text or "") end
    c:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
    return c
end

-- Two-column tooltip lines: every { left, right } line in one tooltip starts its right part
-- at the same x (just past the widest left part), by padding with spaces measured in the
-- tooltip font. (AddDoubleLine would push the right parts to the far edge instead.)
local measure
local function textWidth(text)
    if not measure then
        measure = UIParent:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        measure:Hide()
    end
    measure:SetText(text)
    return measure:GetStringWidth()
end

local COLUMN_GAP = 12
local function columnLines(list)
    local col = 0
    for _, line in ipairs(list) do
        if type(line) == "table" then col = math.max(col, textWidth(line[1])) end
    end
    local space = math.max(1, textWidth("a a") - textWidth("aa"))
    local out = {}
    for i, line in ipairs(list) do
        if type(line) == "table" then
            local pad = math.floor((col + COLUMN_GAP - textWidth(line[1])) / space + 0.5)
            out[i] = line[1] .. string.rep(" ", math.max(1, pad)) .. "|cffffffff" .. line[2] .. "|r"
        else
            out[i] = line
        end
    end
    return out
end

function W.Tooltip(owner, lines, anchor)
    owner:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        local list = type(lines) == "function" and lines(self) or lines
        if type(list) == "string" then list = { list } end
        -- A line is text, or { left, right } for two aligned columns (no wrap).
        local hasColumns = false
        for _, line in ipairs(list or {}) do if type(line) == "table" then hasColumns = true end end
        local aligned = hasColumns and columnLines(list) or nil
        for i, line in ipairs(list or {}) do
            if type(line) == "table" then
                if i == 1 then GameTooltip:SetText(" ") end
                GameTooltip:AddLine(aligned[i], nil, nil, nil, false)
            elseif i == 1 then
                GameTooltip:SetText(line, 1, 1, 1, 1, true)
            else
                GameTooltip:AddLine(line, nil, nil, nil, true)
            end
        end
        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", GameTooltip_Hide)
end

-- Scrolling list using the modern ScrollBox. initializer(frame, data) styles each row;
-- create(frame) builds a row once.
function W.List(parent, rowHeight, create, initializer)
    local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 4, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(rowHeight)
    view:SetElementInitializer("Button", function(frame, data)
        if not frame.built then
            frame.built = true
            create(frame)
        end
        initializer(frame, data)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
    box.bar = bar
    function box:SetItems(items)
        local provider = CreateDataProvider(items)
        self:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
    end
    return box
end

-- An item icon button with the item tooltip (gear stats included by the game tooltip).
function W.ItemButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 32, size or 32)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetAllPoints()
    b.border:SetAtlas("bags-glow-white")
    b.border:Hide()
    -- Optional default-window look: slot background + bronze/gold slot frame
    -- (Professions-Slot-bg / Professions-Slot-Frame, as ProfessionsButtonTemplate uses).
    b.slotBg = b:CreateTexture(nil, "BACKGROUND")
    b.slotBg:SetAtlas("Professions-Slot-bg")
    b.slotBg:SetAllPoints()
    b.slotBg:Hide()
    b.slotFrame = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.slotFrame:SetAtlas("Professions-Slot-Frame")
    b.slotFrame:SetAllPoints()
    b.slotFrame:Hide()
    function b:SetSlotStyle(on)
        self.slotBg:SetShown(on)
        self.slotFrame:SetShown(on)
        self.icon:ClearAllPoints()
        if on then
            local inset = math.max(2, math.floor(self:GetWidth() * 0.07 + 0.5))
            self.icon:SetPoint("TOPLEFT", inset, -inset)
            self.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
        else
            self.icon:SetAllPoints()
        end
    end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnEnter", function(self)
        if not self.itemID and not self.link and not self.spellID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.link then
            GameTooltip:SetHyperlink(self.link)
        elseif self.itemID then
            GameTooltip:SetItemByID(self.itemID)
        else
            -- Recipes without a result item (enchants and the like): the recipe's spell says
            -- what it does.
            GameTooltip:SetSpellByID(self.spellID)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self)
        if self.link and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(self.link) end
    end)
    -- spellID: shown on hover when there's no item (a recipe's spell, for enchants).
    function b:SetItem(itemID, link, icon, spellID)
        self.itemID, self.link, self.spellID = itemID, link, spellID
        local _, itemLink, quality, itemIcon = Compat.ItemInfo(itemID)
        self.link = link or itemLink
        self.icon:SetTexture(icon or itemIcon or 134400)
        if quality and quality > 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
            local c = ITEM_QUALITY_COLORS[quality]
            self.border:SetVertexColor(c.r, c.g, c.b)
            self.border:Show()
        else
            self.border:Hide()
        end
    end
    return b
end

function W.ColorText(color, text)
    return color:WrapTextInColorCode(text)
end

function W.ClassName(c)
    local color = Compat.ClassColor(c and c.class)
    return color:WrapTextInColorCode(ns.CharName(c.key))
end

function W.Ago(t)
    if not t then return "?" end
    local diff = GetServerTime() - t
    local L = ns.L
    if diff < 3600 then return L.AGO_MINUTES:format(math.max(1, math.floor(diff / 60))) end
    if diff < 86400 then return L.AGO_HOURS:format(math.floor(diff / 3600)) end
    return L.AGO_DAYS:format(math.floor(diff / 86400))
end
