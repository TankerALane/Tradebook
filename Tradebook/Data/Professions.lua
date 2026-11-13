-- Data/Professions.lua
-- PURE. The 12 Forever professions in tab order: primary, then secondary.
-- IDs are classic skill lines (confirmed in game for 129, 165, 185, 197, 333, 356, 393).

local _, ns = ...

local Professions = {}
ns.Professions = Professions

Professions.list = {
    { id = 171, name = "Alchemy",        primary = true,  icon = "Interface\\Icons\\Trade_Alchemy" },
    { id = 164, name = "Blacksmithing",  primary = true,  icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { id = 333, name = "Enchanting",     primary = true,  icon = "Interface\\Icons\\Trade_Engraving" },
    { id = 202, name = "Engineering",    primary = true,  icon = "Interface\\Icons\\Trade_Engineering" },
    { id = 182, name = "Herbalism",      primary = true,  icon = "Interface\\Icons\\Trade_Herbalism", gathering = true },
    { id = 165, name = "Leatherworking", primary = true,  icon = "Interface\\Icons\\Trade_LeatherWorking" },
    { id = 186, name = "Mining",         primary = true,  icon = "Interface\\Icons\\Trade_Mining" },
    { id = 393, name = "Skinning",       primary = true,  icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", gathering = true },
    { id = 197, name = "Tailoring",      primary = true,  icon = "Interface\\Icons\\Trade_Tailoring" },
    { id = 185, name = "Cooking",        primary = false, icon = "Interface\\Icons\\INV_Misc_Food_15" },
    { id = 129, name = "First Aid",      primary = false, icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    { id = 356, name = "Fishing",        primary = false, icon = "Interface\\Icons\\Trade_Fishing" },
}

Professions.byID = {}
for index, p in ipairs(Professions.list) do
    p.order = index
    Professions.byID[p.id] = p
end

function Professions.Get(id)
    return Professions.byID[tonumber(id)]
end

function Professions.IsKnown(id)
    return Professions.byID[tonumber(id)] ~= nil
end
