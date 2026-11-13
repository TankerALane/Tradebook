-- UI/GuideView.lua
-- Shown for a profession no saved character has: what it does, where to learn it, ranks.

local _, ns = ...
local L, W = ns.L, ns.W

local View = {}
ns.UI.RegisterView("guide", View)

function View:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    self.icon = f:CreateTexture(nil, "ARTWORK")
    self.icon:SetSize(56, 56)
    self.icon:SetPoint("TOPLEFT", 30, -30)
    self.icon:SetDesaturated(true)
    self.title = W.Text(f, "GameFontNormalHuge")
    self.title:SetPoint("LEFT", self.icon, "RIGHT", 14, 0)
    self.body = W.Text(f, "GameFontHighlight")
    self.body:SetPoint("TOPLEFT", self.icon, "BOTTOMLEFT", 0, -20)
    self.body:SetPoint("RIGHT", f, "RIGHT", -40, 0)
    self.body:SetSpacing(4)
end

function View:Show(skillLineID)
    local p = ns.Professions.Get(skillLineID)
    local name = L[p.name] or p.name
    self.icon:SetTexture(ns.Compat.ProfessionTexture(skillLineID))
    self.title:SetText(L.GUIDE_TITLE:format(name))
    local lines = {
        L.TAB_NOBODY:format(name),
        "",
        L.PROF_DESC[skillLineID] or "",
        "",
        L.GUIDE_LEARN:format(name),
        p.primary and L.GUIDE_PRIMARY or L.GUIDE_SECONDARY,
        L.GUIDE_RANKS,
    }
    -- Friends who have it (Fellowship Ledger, if installed).
    local friends = ns.Friends.For(skillLineID)
    if #friends > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = W.ColorText(W.GOLD, L.FRIENDS_HEADER)
        for _, f in ipairs(friends) do
            lines[#lines + 1] = View.FriendLine(f, name)
        end
        lines[#lines + 1] = W.ColorText(W.GREY, L.FRIENDS_NOTE)
    end
    self.body:SetText(table.concat(lines, "\n"))
end

-- "Cain Ratt: Has Blacksmithing 132/225  (2 days ago)", name in class colour.
function View.FriendLine(f, professionName)
    local who = ns.Compat.ClassColor(f.class):WrapTextInColorCode(f.name)
    local text = L.FRIEND_HAS:format(who, professionName, f.rank, f.max)
    if f.at then text = text .. "  " .. W.ColorText(W.GREY, "(" .. W.Ago(f.at) .. ")") end
    return text
end

function View:Refresh() end
