-- UI/GuideView.lua
-- Shown for a profession no saved character has: what it does, where to learn it, ranks,
-- and friends who have it (Fellowship Ledger), in aligned columns.

local _, ns = ...
local L, W = ns.L, ns.W

local View = {}
ns.UI.RegisterView("guide", View)

local NAME_W, RANK_W = 200, 70

-- The parts of a friend line: class-coloured name, "132/225", "2 days ago" (or nil).
function View.FriendParts(f)
    local who = ns.Compat.ClassColor(f.class):WrapTextInColorCode(f.name)
    return who, L.SKILL_RANK:format(f.rank, f.max), f.at and W.Ago(f.at) or nil
end

-- Add friends to a tooltip as aligned two-column lines (name | rank  ago).
function View.AddFriendsToTooltip(tooltip, friends, limit)
    for i, f in ipairs(friends) do
        if limit and i > limit then
            tooltip:AddLine(L.SOURCE_MORE:format(#friends - limit), 0.6, 0.6, 0.6)
            break
        end
        local who, rank, ago = View.FriendParts(f)
        tooltip:AddDoubleLine(who, rank .. (ago and ("  " .. W.ColorText(W.GREY, ago)) or ""), 1, 1, 1, 1, 1, 1)
    end
end

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

    self.friendsHeader = W.Text(f, "GameFontNormal")
    self.friendsHeader:SetPoint("TOPLEFT", self.body, "BOTTOMLEFT", 0, -18)
    self.friendsHeader:SetText(L.FRIENDS_HEADER)
    self.friendsNote = W.Text(f, "GameFontDisableSmall")
    self.friendsNote:SetWidth(NAME_W + RANK_W + 160)
    self.rows = {}
end

-- One aligned row: name | rank (right-aligned) | ago.
function View:Row(i)
    local row = self.rows[i]
    if not row then
        row = {}
        row.name = W.Text(self.frame, "GameFontHighlight")
        row.name:SetWidth(NAME_W)
        row.name:SetWordWrap(false)
        row.rank = W.Text(self.frame, "GameFontHighlight", "RIGHT")
        row.rank:SetWidth(RANK_W)
        row.ago = W.Text(self.frame, "GameFontDisableSmall")
        row.rank:SetPoint("LEFT", row.name, "RIGHT", 0, 0)
        row.ago:SetPoint("LEFT", row.rank, "RIGHT", 14, 0)
        self.rows[i] = row
    end
    return row
end

function View:Show(skillLineID)
    local p = ns.Professions.Get(skillLineID)
    local name = L[p.name] or p.name
    self.icon:SetTexture(ns.Compat.ProfessionTexture(skillLineID))
    self.title:SetText(L.GUIDE_TITLE:format(name))
    self.body:SetText(table.concat({
        L.TAB_NOBODY:format(name),
        "",
        L.PROF_DESC[skillLineID] or "",
        "",
        L.GUIDE_LEARN:format(name),
        p.primary and L.GUIDE_PRIMARY or L.GUIDE_SECONDARY,
        L.GUIDE_RANKS,
    }, "\n"))

    -- Friends who have it (Fellowship Ledger, if installed).
    local friends = ns.Friends.For(skillLineID)
    self.friendsHeader:SetShown(#friends > 0)
    self.friendsNote:SetShown(#friends > 0)
    local anchor = self.friendsHeader
    for i, f in ipairs(friends) do
        local row = self:Row(i)
        local who, rank, ago = View.FriendParts(f)
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -8 or -4)
        row.name:SetText(who)
        row.rank:SetText(rank)
        row.ago:SetText(ago or "")
        for _, fs in pairs(row) do fs:Show() end
        anchor = row.name
    end
    for i = #friends + 1, #self.rows do
        for _, fs in pairs(self.rows[i]) do fs:Hide() end
    end
    self.friendsNote:ClearAllPoints()
    self.friendsNote:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    self.friendsNote:SetText(L.FRIENDS_NOTE)
end

function View:Refresh() end
