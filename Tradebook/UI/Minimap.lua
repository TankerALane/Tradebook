-- UI/Minimap.lua
-- LibDataBroker launcher + LibDBIcon minimap button.
-- Left-click: open Tradebook. Right-click: settings. Shift-click: Camp tab.

local _, ns = ...
local L = ns.L

local Minimap = {}
ns.Minimap = Minimap

Minimap.ICON = "Interface\\AddOns\\Tradebook\\Media\\icon.png"

local function onClick(_, button)
    if button == "RightButton" then
        ns.Settings.Open()
    elseif IsShiftKeyDown() then
        ns.UI.Show()
        ns.UI.SelectTab("camp")
    else
        ns.UI.Toggle()
    end
end

local function onTooltip(tooltip)
    tooltip:AddLine(L.ADDON_TITLE, 1, 0.82, 0.35)
    local counts = ns.Characters.ProfessionCounts(ns.db, ns.charKey)
    local any = false
    for _, p in ipairs(ns.Professions.list) do
        if counts[p.id] then
            any = true
            local names = {}
            for _, c in ipairs(ns.Characters.WithProfession(ns.db, p.id, ns.charKey)) do
                local prof = c.professions[p.id]
                names[#names + 1] = string.format("%s (%d)", c.name or c.key, prof.rank or 0)
            end
            tooltip:AddDoubleLine(L[p.name] or p.name, table.concat(names, ", "), 1, 1, 1, 0.8, 0.8, 0.8)
        end
    end
    if not any then tooltip:AddLine(L.MINIMAP_NONE, 0.7, 0.7, 0.7) end
    tooltip:AddLine(" ")
    tooltip:AddLine(L.MINIMAP_LEFT, 0.6, 0.8, 1)
    tooltip:AddLine(L.MINIMAP_RIGHT, 0.6, 0.8, 1)
    tooltip:AddLine(L.MINIMAP_SHIFT, 0.6, 0.8, 1)
end

function Minimap.Start()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB then return end
    Minimap.broker = LDB:NewDataObject("Tradebook", {
        type = "launcher",
        label = L.ADDON_TITLE,
        icon = Minimap.ICON,
        OnClick = onClick,
        OnTooltipShow = onTooltip,
    })
    local icon = LibStub("LibDBIcon-1.0", true)
    if icon and Minimap.broker then
        icon:Register("Tradebook", Minimap.broker, ns.db.settings.minimap)
        Minimap.icon = icon
    end
end

function Minimap.SetShown(show)
    ns.db.settings.minimap.hide = not show
    if not Minimap.icon then return end
    if show then Minimap.icon:Show("Tradebook") else Minimap.icon:Hide("Tradebook") end
end
