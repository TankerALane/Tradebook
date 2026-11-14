-- Data/RankTrainers.lua
-- PURE. Which trainers teach which profession rank in WoW Forever (1.60.1).
--
-- Only entries that at least two independent Forever sources agree on (researched
-- 2026-11-13; sources and conflicts in docs/DATA.md): Warcraft Tavern's Forever trainer list,
-- wow-professions.com/forever, method.gg/wow-forever, Icy Veins and Wowhead Forever guides.
-- Checked against trainer windows read in game (Lavinia Crowe teaches Journeyman, not Expert).
-- Where sources disagreed between Journeyman and Expert, the trainer is listed as Journeyman
-- only (true either way). Single-source trainers are left out.
--
-- A trainer is listed under the highest rank it teaches. The rank-up window lists the
-- trainers for exactly the rank being trained. NPC titles ("Expert Enchanter") are NOT the
-- rank taught. id = NPC ID where a source gave one (otherwise found by name in QuestieDB).
-- Trainers read in game (Core/Trainers.lua) still win over this list.

local _, ns = ...

local RankTrainers = {}
ns.RankTrainers = RankTrainers

local function T(id, name) return { id = id, name = name } end

RankTrainers.crafting = {
    [333] = { -- Enchanting
        Journeyman = { T(3345, "Godan"), T(3011, "Teg Dawnstrider"), T(4616, "Lavinia Crowe"), T(4213, "Taladan"),
            T(5157, "Gimble Thistlefuzz"), T(1317, "Lucan Cordell"), T(7949, "Xylinnia Starshine"),
            T(251978, "Vanessa Sellers") },
        Expert = { T(11074, "Hgarth"), T(11072, "Kitta Firewind"), T(251978, "Vanessa Sellers") },
        Artisan = { T(11073, "Annora") }, -- Uldaman; the only Artisan Enchanting trainer
    },
    [171] = { -- Alchemy
        Journeyman = { T(3347, "Yelmak"), T(3009, "Bena Winterhoof"), T(4609, "Doctor Marsh"), T(2391, "Serge Hinott"),
            T(2837, "Jaxin Chong"), T(5499, "Lilyssia Nightbreeze"), T(5177, "Tally Berryfizz"), T(3964, "Kylanna"),
            T(4900, "Alchemist Narett"), T(11042, "Sylvanna Forestmoon") },
        Expert = { T(4611, "Doctor Herbert Halsey"), T(4160, "Ainethil"), T(246795, "Linzy Blackbolt") },
        Artisan = { T(1386, "Rogvar"), T(7948, "Kylanna Windwhisper") },
    },
    [164] = { -- Blacksmithing
        Journeyman = { T(1383, "Snarl"), T(2998, "Karn Stonehoof"), T(4596, "James Van Brunt"), T(3478, "Traugh"),
            T(276067, "Angus Hammerhand"), T(252479, "Daeann Steelwind"), T(10276, "Rotgath Stonebeard"),
            T(5511, "Therum Deepforge"), T(3136, "Clarise Gnarltree") },
        Expert = { T(3355, "Saru Steelfury"), T(4258, "Bengus Deepforge"), T(28694, "Alard Schmied") },
        Artisan = { T(2836, "Brikk Keencraft") }, -- Booty Bay, both factions
    },
    [197] = { -- Tailoring
        Journeyman = { T(5567, "Sellandus"), T(5153, "Jormund Stonebrow"), T(4159, "Me'lynn"), T(3363, "Magar"),
            T(11049, "Rhiannon Davis"), T(3004, "Tepa"), T(3704, "Mahani"), T(2627, "Grarnik Goodstitch"),
            T(251991, "Taleen Shimmerthread"), T(252380, "Othesia Evengale") },
        Expert = { T(1346, "Georgio Bolero"), T(251972, "Charles Worth"), T(4576, "Josef Gregorian") },
        Artisan = { T(11052, "Timothy Worthington"), T(2399, "Daryl Stack") },
    },
    [165] = { -- Leatherworking
        Journeyman = { T(5564, "Simon Tanner"), T(5127, "Fimble Finespindle"), T(11081, "Faldron"),
            T(3967, "Aayndia Floralwind"), T(3365, "Karolek"), T(11084, "Tarn"), T(4588, "Arthur Moore"),
            T(1385, "Brawn"), T(3703, "Krulmoo Fullmoon"), T(8153, "Narv Hidecrafter"), T(252376, "Emerii Tallgust") },
        Expert = { T(4212, "Telonis"), T(3007, "Una") },
        Artisan = { T(nil, "Drakk Stonehand"), T(11098, "Hahrana Ironhide") },
    },
    [202] = { -- Engineering
        Journeyman = { T(11029, "Trixie Quikswitch"), T(1676, "Finbus Geargrind"), T(5518, "Lilliam Sparkspindle"),
            T(3412, "Nogg"), T(11031, "Franklin Lloyd") },
        Expert = { T(5174, "Springspindle Fizzlegear"), T(11017, "Roxxik") },
        Artisan = { T(8736, "Buzzek Bracketswing"), T(249235, "Kaylaena Springwhisper") },
    },
}

-- Gathering: every trainer outside the starting areas teaches Apprentice through Artisan
-- (no level requirement). Names from Warcraft Tavern and wow-professions (both agree).
RankTrainers.allRanks = {
    [182] = { -- Herbalism
        T(4614, "Martha Alliestar"), T(nil, "Jandi"), T(nil, "Komin Winterhoof"), T(nil, "Faruza"), T(nil, "Mishiki"),
        T(nil, "Aranae Venomblood"), T(nil, "Angrun"), T(nil, "Ruw"), T(nil, "Shylamiir"), T(nil, "Tannysa"),
        T(nil, "Reyna Stonebranch"), T(nil, "Firodren Mooncaller"), T(nil, "Herbalist Pomeroy"), T(nil, "Kali Healtouch"),
        T(nil, "Alma Jainrose"), T(nil, "Malorne Bladeleaf"), T(nil, "Cylania Rootstalker"), T(nil, "Brant Jasperbloom"),
        T(nil, "Telurinon Moonshadow"), T(nil, "Flora Silverwind"), T(nil, "Malvor"), T(nil, "Halassa Fernbreeze"),
        T(nil, "Syriel Nightrain"),
    },
    [186] = { -- Mining
        T(nil, "Makaru"), T(nil, "Brek Stonehoof"), T(nil, "Brom Killian"), T(nil, "Krunn"), T(nil, "Johan Focht"),
        T(nil, "Gelman Stonehand"), T(nil, "Geofram Bouldertoe"), T(nil, "Kurdram Stonehammer"), T(nil, "Dank Drizzlecut"),
        T(nil, "Yarr Hammerstone"), T(nil, "Matt Johnson"), T(nil, "Brock Stoneseeker"), T(nil, "Grungle"),
        T(nil, "Pikkle"), T(nil, "Halavuul Cragwind"), T(nil, "Messana Crestwind"),
    },
    [393] = { -- Skinning
        T(nil, "Thuwd"), T(nil, "Mooranta"), T(nil, "Killian Hagey"), T(nil, "Malux"), T(nil, "Kulleg Stonehorn"),
        T(nil, "Yonn Deepcut"), T(nil, "Dranh"), T(nil, "Rand Rhobart"), T(nil, "Maris Granger"),
        T(nil, "Balthus Stoneflayer"), T(nil, "Eladriel"), T(nil, "Helene Peltskinner"), T(nil, "Jayla"),
        T(nil, "Wilma Ranthal"), T(nil, "Radnaal Maneweaver"), T(nil, "Ishlee Breezewhisper"),
        T(nil, "Mendalass Tattermend"),
    },
}

-- Cooking, Fishing and First Aid: every trainer of the profession teaches Apprentice and
-- Journeyman (Expert is a book, Artisan a quest: Data/RankUps.lua).
RankTrainers.journeymanFromAny = { [185] = true, [356] = true, [129] = true }

-- Trainers for `rank` of a profession: list of { id?, name }, and whether they are known
-- for certain (false: no list, the caller falls back to a search).
function RankTrainers.For(skillLine, rank)
    local c = RankTrainers.crafting[skillLine]
    if c then return c[rank] or {}, c[rank] ~= nil end
    local all = RankTrainers.allRanks[skillLine]
    if all and rank ~= "Apprentice" then return all, true end
    return {}, false
end
