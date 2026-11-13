-- UI/LegacyView.lua
-- Read-only Legacy: Professions perks for the logged-in character (C_Traits tree 1187).

local _, ns = ...
local L, W = ns.L, ns.W

local View = {}
ns.UI.RegisterView("legacy", View)

function View:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    self.title = W.Text(f, "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 12, -10)
    self.title:SetText(L.LEGACY_TITLE)
    self.points = W.Text(f, "GameFontHighlight")
    self.points:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -8)
    self.body = W.Text(f, "GameFontHighlight")
    self.body:SetPoint("TOPLEFT", self.points, "BOTTOMLEFT", 0, -14)
    self.body:SetPoint("RIGHT", f, "RIGHT", -30, 0)
    self.body:SetSpacing(5)
end

function View:Show()
    self:Refresh()
end

function View:Refresh()
    local data = ns.Scanner.Legacy()
    if not data then
        self.points:SetText("")
        self.body:SetText(L.LEGACY_UNAVAILABLE)
        return
    end
    self.points:SetText(L.LEGACY_POINTS:format(data.points or 0))
    local lines = {}
    for _, n in ipairs(data.nodes) do
        local color = n.rank > 0 and W.GOLD or W.GREY
        local line = color:WrapTextInColorCode(string.format("%s  %d/%d", n.name, n.rank, n.max))
        if n.description and n.description ~= "" then
            line = line .. "\n   " .. W.ColorText(W.GREY, n.description)
        end
        lines[#lines + 1] = line
    end
    self.body:SetText(table.concat(lines, "\n"))
end
