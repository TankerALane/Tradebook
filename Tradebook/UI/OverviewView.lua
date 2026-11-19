-- UI/OverviewView.lua
-- "My professions": the logged-in character's main profession slots (how many of the two are
-- used) and which secondary professions they have, like the Professions book. The window
-- opens here when no profession window is open (the K key, the minimap button, /tb).
-- Click a profession to open its tab.

local _, ns = ...
local L, W = ns.L, ns.W

local View = {}
ns.UI.RegisterView("overview", View)

local RANK_OF_CAP = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }

function View:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f
    self.title = W.Text(f, "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 12, -10)
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", 12, -40)
    body:SetPoint("BOTTOMRIGHT", -8, 8)
    self.pane = ns.Details.NewLinePane(body)
end

function View:Show()
    self:Refresh()
end

local function nameOf(p)
    local text = L[p.name] or p.name
    return (p.icon and ("|T" .. p.icon .. ":16|t ") or "") .. text
end

-- One learned profession: name, skill and rank; click opens its tab.
local function addLearned(pane, p, prof)
    local rank = RANK_OF_CAP[prof.max]
    local right = L.SKILL_RANK:format(prof.rank or 0, prof.max or 0)
    if rank then right = right .. "  " .. W.ColorText(W.GREY, L.RANK_NAMES[rank]) end
    pane:Add({ indent = 1, text = nameOf(p), right = right,
        onClick = function() ns.UI.SelectTab(p.id) end,
        tooltip = { L[p.name] or p.name, L.OVERVIEW_OPEN_TIP } })
end

function View:Refresh()
    if not self.frame then return end
    local c = ns.char
    local pane = self.pane
    pane:Begin()
    if not c then
        self.title:SetText(L.OVERVIEW_TITLE_NONE)
        pane:Finish()
        return
    end
    self.title:SetText(L.OVERVIEW_TITLE:format(W.ClassName(c)))
    local slots = ns.Characters.ProfessionSlots(ns.Professions.list, c.professions)

    pane:Add({ text = L.OVERVIEW_MAIN:format(#slots.main, ns.Characters.MAIN_SLOTS), font = "GameFontNormal",
        color = W.GOLD })
    for _, s in ipairs(slots.main) do addLearned(pane, s.def, s.prof) end
    if slots.mainFree > 0 then
        for _ = 1, slots.mainFree do
            pane:Add({ indent = 1, text = W.ColorText(W.GREY, L.OVERVIEW_EMPTY_SLOT) })
        end
        pane:Add({ indent = 1, text = L.OVERVIEW_CAN_LEARN:format(slots.mainFree), color = W.GREEN })
    else
        pane:Add({ indent = 1, text = L.OVERVIEW_MAIN_FULL, color = W.GREY })
    end
    pane:Gap(10)

    pane:Add({ text = L.OVERVIEW_SECONDARY:format(slots.secondaryKnown, #slots.secondary), font = "GameFontNormal",
        color = W.GOLD })
    for _, s in ipairs(slots.secondary) do
        if s.prof then
            addLearned(pane, s.def, s.prof)
        else
            pane:Add({ indent = 1, text = W.ColorText(W.GREY, nameOf(s.def)), right = W.ColorText(W.GREY, L.OVERVIEW_NOT_LEARNED),
                onClick = function() ns.UI.SelectTab(s.def.id) end,
                tooltip = { L[s.def.name] or s.def.name, L.OVERVIEW_NOT_LEARNED_TIP } })
        end
    end
    pane:Gap(10)
    pane:Add({ text = L.OVERVIEW_NOTE, color = W.GREY })
    pane:Finish()
end
