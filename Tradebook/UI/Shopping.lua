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
    row.text:SetWordWrap(false)
    row.right = W.Text(row, "GameFontHighlightSmall", "RIGHT")
    row.right:SetPoint("RIGHT", -4, 0)
    row.right:SetWordWrap(false)
end

-- Rows: a section header { header, right } or an item { itemID, missing, bank, account, unit, cost }.
local function initRow(row, data)
    row.text:ClearAllPoints()
    if data.header then
        row.item:Hide()
        row.text:SetPoint("LEFT", 2, 0)
        row.text:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
        row.text:SetText(W.ColorText(W.GOLD, data.header))
        row.right:SetText(data.right or "")
        return
    end
    row.item:Show()
    row.item:SetItem(data.itemID)
    row.text:SetPoint("LEFT", row.item, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
    row.text:SetText(Compat.ItemInfo(data.itemID) or ("item:" .. data.itemID))
    -- "(Bank: 5)  3 x 10c = 30c": how many to buy and what it costs.
    local right = W.ColorText(W.RED, tostring(data.missing))
    if data.unit then
        right = right .. " x " .. ns.Prices.Money(data.unit) .. "  " .. ns.Prices.Money(data.cost)
    elseif data.priced ~= false then
        right = right .. "  " .. W.ColorText(W.GREY, L.PLAN_PRICE_UNKNOWN)
    end
    if data.bank + data.account > 0 then
        right = W.ColorText(W.GOLD, "(" .. L.IN_BANK:format(data.bank + data.account) .. ") ") .. right
    end
    row.right:SetText(right)
end

local function ensure()
    if popup then return popup end
    popup = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(420, 380)
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
    popup.list:SetPoint("BOTTOMRIGHT", -24, 42)
    -- Footer: total cost and "Send to Auctionator" (the auction house items; needs Auctionator).
    popup.cost = W.Text(popup, "GameFontHighlightSmall")
    popup.cost:SetPoint("BOTTOMLEFT", 14, 16)
    popup.export = W.Button(popup, L.SHOPPING_EXPORT, 150, 22)
    popup.export:SetPoint("BOTTOMRIGHT", -10, 10)
    popup.export:SetScript("OnClick", function()
        local name = L.SHOPPING_LIST_NAME
        local sent = ns.Prices.ExportShoppingList(popup.auctionItems or {}, name)
        if sent then ns.Print(L.SHOPPING_EXPORTED:format(sent, name)) else ns.Print(L.SHOPPING_EXPORT_FAILED) end
    end)
    W.Tooltip(popup.export, { L.SHOPPING_EXPORT, L.SHOPPING_EXPORT_TIP:format(L.SHOPPING_LIST_NAME) })
    popup.empty = W.Text(popup, "GameFontDisable", "CENTER")
    popup.empty:SetPoint("CENTER")
    return popup
end

-- entries: { { recipeID, times } }
function Shopping.Show(entries, title)
    local p = ensure()
    p.title:SetText(title or L.SHOPPING_LIST)
    local list = ns.Reagents.ShoppingList(ns.db, ns.char, entries)
    -- Split by where to buy: vendor (game or Auctionator vendor price) or auction house.
    local split = ns.Prices.SplitShopping(list, ns.Prices.Get)
    local rows = {}
    local function section(header, group)
        if #group.items == 0 then return end
        rows[#rows + 1] = { header = header, right = group.total > 0 and ns.Prices.Money(group.total) or nil }
        for _, item in ipairs(group.items) do rows[#rows + 1] = item end
    end
    section(L.SHOPPING_VENDOR, split.vendor)
    section(L.SHOPPING_AUCTION, split.auction)
    p.list:SetItems(rows)
    p.auctionItems = split.auction.items
    p.empty:SetText(#list == 0 and L.SHOPPING_EMPTY or "")
    p.export:SetShown(ns.Prices.Available())
    p.export:SetEnabled(#split.auction.items > 0)
    if #list > 0 then
        local text = L.SHOPPING_COST:format(ns.Prices.Money(split.vendor.total + split.auction.total))
        if split.auction.unpriced > 0 then
            text = text .. "  " .. W.ColorText(W.GREY, L.COST_UNPRICED:format(split.auction.unpriced))
        end
        p.cost:SetText(text)
    else
        p.cost:SetText("")
    end
    p:Show()
end

function Shopping.ShowPinned()
    local entries = {}
    for recipeID, times in pairs(ns.db.pinned) do
        entries[#entries + 1] = { recipeID = recipeID, times = tonumber(times) or 1 }
    end
    Shopping.Show(entries, L.SHOPPING_PINNED)
end

function Shopping.Hide()
    if popup then popup:Hide() end
end
