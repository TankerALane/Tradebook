-- UI/Shopping.lua
-- Shopping list popup for missing reagents (one recipe, or all pinned recipes combined).

local _, ns = ...
local L, W, Compat = ns.L, ns.W, ns.Compat

local Shopping = {}
ns.Shopping = Shopping

local popup

local function createRow(row)
    row.item = W.ItemButton(row, 18)
    row.item:SetPoint("LEFT", 2, 0)
    row.text = W.Text(row, "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.item, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", -110, 0)
    row.text:SetWordWrap(false)
    row.right = W.Text(row, "GameFontHighlightSmall", "RIGHT")
    row.right:SetPoint("RIGHT", -4, 0)
end

local function initRow(row, data)
    row.item:SetItem(data.itemID)
    row.text:SetText(Compat.ItemInfo(data.itemID) or ("item:" .. data.itemID))
    local right = W.ColorText(W.RED, tostring(data.missing))
    if data.bank + data.account > 0 then
        right = W.ColorText(W.GOLD, "(" .. L.IN_BANK:format(data.bank + data.account) .. ") ") .. right
    end
    row.right:SetText(right)
end

local function ensure()
    if popup then return popup end
    popup = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(340, 360)
    popup:SetPoint("CENTER", 380, 0)
    popup:SetFrameStrata("DIALOG")
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup.title = W.Text(popup, "GameFontHighlight", "CENTER")
    popup.title:SetPoint("TOP", 0, -5)
    popup.list = W.List(popup, 22, createRow, initRow)
    popup.list:SetPoint("TOPLEFT", 12, -32)
    popup.list:SetPoint("BOTTOMRIGHT", -24, 12)
    popup.empty = W.Text(popup, "GameFontDisable", "CENTER")
    popup.empty:SetPoint("CENTER")
    return popup
end

-- entries: { { recipeID, times } }
function Shopping.Show(entries, title)
    local p = ensure()
    p.title:SetText(title or L.SHOPPING_LIST)
    local list = ns.Reagents.ShoppingList(ns.db, ns.char, entries)
    p.list:SetItems(list)
    p.empty:SetText(#list == 0 and L.SHOPPING_EMPTY or "")
    p:Show()
end

function Shopping.ShowPinned()
    local entries = {}
    for recipeID, times in pairs(ns.db.pinned) do
        entries[#entries + 1] = { recipeID = recipeID, times = tonumber(times) or 1 }
    end
    Shopping.Show(entries, L.SHOPPING_PINNED)
end
