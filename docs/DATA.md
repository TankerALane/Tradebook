# Bundled data and keeping it current

Tradebook ships generated data files. Never edit them by hand; re-run the scripts.

| File | What | Source | How it's updated |
|---|---|---|---|
| `Tradebook/Data/SkillLevels.lua` | Skill-up thresholds (where each recipe turns yellow, green, grey) | WoW Forever's own `SkillLineAbility` table, via wago.tools | **Automatically checked every week** (GitHub Actions "Game data check"); a pull request opens when a new build changes anything |
| `Tradebook/Data/SourceData.lua` | Where recipes are learned (trainer, vendor, drop, quest, container), NPC names, skill needed to learn | LibProfessionDB (MIT, by Pimptasty) | By hand when LibProfessionDB releases a new version |
| `Tradebook/Data/RecipeVendors.lua` | Recipe vendors checked for WoW Forever (replace the classic vendor lists above) | `docs/research/recipe_vendors.json` (QuestieDB Forever + Forever web sources) | `python -I scripts/build_recipe_vendors.py` after editing the research file |

## Skill-up thresholds (every Forever build)

- Rule (checked in game against every colour the game reported: 166 of 166 matched): yellow from `TrivialSkillLineRankLow`, grey from `TrivialSkillLineRankHigh`, green from `floor((low + high) / 2)`, orange below yellow.
- **Automatic:** `.github/workflows/game-data.yml` runs every Tuesday at 3pm Pacific (23:00 UTC), after weekly maintenance, (and on demand from the Actions tab, optionally for a specific build). It regenerates the file, runs lint and tests, and opens a PR titled "Game data update: Forever <build>" listing added, removed and changed recipes. It also warns if the build suggests a new TOC `## Interface` number.
- **By hand:** `python -I scripts/update_game_data.py [build]`.
- **In the game:** every time a profession is opened, Tradebook compares these numbers with the game's own colours. Any recipe that disagrees is flagged (`TradebookDB.badThresholds`); its "until" lines are hidden and the game's colour is used. `/tb debug` reports how many disagreed. If that number isn't 0 after a patch, run the update.

## Recipe sources (LibProfessionDB releases)

1. Download the new LibProfessionDB zip from CurseForge (project 1558781) into an empty folder and unzip it.
2. `python -I scripts/build_source_data.py "<folder>/ProfessionDB/Data/Forever/_core" "<ProfessionDB version>"`
3. Run the tests, check `git diff`, commit.

LibProfessionDB's Forever sources are borrowed from classic and flagged unconfirmed; Tradebook says so in the recipe details. Its skill-up thresholds are not used (they were wrong for ~400 recipes).

## Recipe vendors (checked 2026-11-13, Forever 1.60.1)

LibProfessionDB lists a vendor for 321 recipes, all copied from classic. Each was checked
against two independent Forever sources:
1. **QuestieDB for Forever** (the installed addon's baked data, decoded by
   `scripts/research/qdb_parse.py`): who sells the recipe item. The recipe spell is linked to
   its item through Forever's own game tables on wago.tools (`ItemEffect` with
   `TriggerType = 6`: its `SpellID` is the taught recipe; `scripts/research/check.py`).
2. **Forever web sources**: wow-professions.com/forever NPC pages (pages marked "not checked
   in WoW Forever yet" not counted), forever.warcraftdb.com, Wowhead's Forever item pages
   (zones only) and guides, MetaForge's Forever database, method.gg, wow.gg. Two of these
   agreeing counts as "confirmed" on the web side.

Rules (`scripts/research/merge_vendors.py`, then `make_research.py` writes the research file):
- **Confirmed:** QuestieDB and a web source that names the NPC agree, or two web sources agree.
  Wowhead item pages only list zones ("purchasable in Orgrimmar"), so they never count as
  naming a vendor (revised after Kithas turned out not to sell Enchant Chest - Lesser
  Intellect, seen in game 2026-11-13).
- **Unconfirmed** ("Vendor (unconfirmed)" in the addon): one source only.
- **Removed:** only the classic list has it, the NPC isn't in Forever (later-expansion NPCs),
  the vendor's own checked Forever page doesn't list it (and no web source names it), or it
  was seen in game not to sell it (`SEEN_NOT_SOLD` in `make_research.py`).
- Recipes no vendor sells show QuestieDB's drops and quests instead, and "No vendor is known
  to sell this in WoW Forever."

Result: 277 recipes with a vendor (67 vendor entries unconfirmed), 28 with no known vendor in
Forever (drops or quests: Dig Rat Stew, Festival Dress/Suit, the firework launchers, Runic
Plate, the four flasks, several enchants and engineering schematics), 100 classic vendors
removed, 65 Forever vendors added (Nyalah Brightfire, Gritta Chumwater, Nasalanna Windsinger, Stitch Pinwizzle, Kor'gar,
Fizzix Boomshot, Super-Seller 680, Vendor-Tron 1000, Balai Lok'Wein and others).

Judgement calls:
- Aendel Windspear's Cenarion Circle patterns and Vargus's Obsidian / Ironvine plans: QuestieDB
  still lists them, but no recipe item for them exists in Forever's web databases and Vargus's
  checked page sells new Forever plans instead. Shown as "doesn't seem to be in Forever yet".
- Alchemist's Stone: one source says it's bought in Mount Hyjal (vendor unnamed), another that
  it can't be obtained. Shown as "sources disagree".
- Expert Cookbook, "The Bass and You" and "Under Wraps": QuestieDB plus the rank research above.
- Worth checking in game: Lokhtos Darkbargainer's Blackrock Depths patterns and plans
  (QuestieDB only, zone matches on Wowhead) and Gelvas Grimegate for Steam Tonk Controller
  (web only). Andorov's Obsidian plans have only a Wowhead zone listing, so no vendor is shown.

**New Forever vendors (added 2026-11-13, `scripts/research/make_new_research.py`):** QuestieDB
Forever lists 525 recipe items sold by vendors Tradebook had none for. After the web check, 461
were added (456 with a vendor confirmed by QuestieDB plus a Forever web source naming it):
- Merchant's Favor supply camps (Durotar Supply and Logistics, the Barrens / Azeroth Commerce
  Authority, Redridge): Apothecary Durelle / Nina Surefire, Gor'mak / Stondry Darkhammer,
  Aza'bek / Kalsey Sanden, Beneris / Alynsia, Fizzlefuse / Fritz Fizzle, Pawani / Daniel
  Stitchsong, Jim'bek / Mivin Shadowweave. Same lists and prices on both sides. Favor cost and
  standing from wow-professions.com/forever NPC pages, forever.warcraftdb.com and conquestcapped's
  camp guides (they agree). Shown as "Costs N Merchant's Favor" and "Requires <standing> with
  <your faction's camp>". Gnomish Army Knife and Loot-A-Rang are QuestieDB only (unconfirmed).
- Aisarra Nightmeadow (Hyjal, 72 patterns; wow.gg + conquestcapped), the Skyforged / Gustwoven
  quartermasters, Granny Finespindle, Gorhak and Molkar (Molkar is web-only for 11, unconfirmed),
  Pexmit, Vargus and Mishta's new plans, reagent bag patterns at tailoring suppliers.
- Reputation from the game's item data (ItemSparse MinFactionID / MinReputation) where present.
- Left out (63): Season of Discovery recipe items QuestieDB still lists (Wowhead Forever: "not
  available to players"), AQ-era items with no Forever item, and recipes the classic check
  above already decided.
- Not shown yet: costs in other currencies (Malleable Essence of Nature, Carved Centaur Totems)
  and vendor-side reputation gates (Guardians of Hyjal, centaur clans).

**In game (Core/Merchants.lua):** every time a vendor window opens, Tradebook reads which
recipe items it sells (`GetMerchantItemID`, `C_MerchantFrame.GetItemInfo().numAvailable`;
-1 = unlimited, otherwise limited supply) and saves it in `TradebookDB.vendors`. Recipe items
are recognised with `Data/RecipeItems.lua` (generated weekly by `update_game_data.py` from
`ItemEffect` / `ItemXItemEffect` / `SpellEffect`). A vendor seen selling a recipe counts as
confirmed and is added if the data doesn't have it; limited stock is shown as "limited supply".
A sold-out limited recipe may be missing from the window, so a vendor whose window didn't list
it is never removed, only marked "not in stock when you visited". `/tb debug` lists recipes
seen at vendors the data doesn't have; fold those (and `SEEN_NOT_SOLD` cases) back into the
research file from the SavedVariables (`WTF/Account/<account>/SavedVariables/Tradebook.lua`).

To re-check after a patch: run `qdb_parse.py` on the new QuestieDB, `check.py`, redo the web
pass, `merge_vendors.py`, `make_research.py`, then `scripts/build_recipe_vendors.py`.

## Profession trainers (seen in game, Forever 1.60.1, Undercity, 2026-11-13)

Read from the trainer windows by Core/Trainers.lua (all filters on). Costs shown were 10% lower
than base (reputation discount): base prices are Journeyman 5s, Expert 50s, Artisan 5g.

| Trainer | Profession | Ranks taught | Notes |
|---|---|---|---|
| Lavinia Crowe (4616), "Expert Enchanter" | Enchanting | Apprentice, Journeyman (level 10) | No Expert, despite the title; recipes up to 150 |
| Malcomb Wynn (11067) | Enchanting | Apprentice | Recipes up to 70 |
| Eunice Burch (4552) | Cooking | Apprentice, Journeyman | No Expert (book) or Artisan; no level requirement |
| Martha Alliestar (4614) | Herbalism | Apprentice, Journeyman, Expert, Artisan | No level requirement |

Service names are "<Rank> <profession>" ("Journeyman Enchanting", "Journeyman Cook"); the game
flags only Apprentice as a profession service. NPC titles don't say which ranks a trainer teaches.

## Rank trainers, books and quests (researched 2026-11-13)

Data/RankTrainers.lua and Data/RankUps.lua. Rule: an entry goes in only when at least two
independent sources that are clearly about WoW Forever agree. Single-source entries are left
out; Journeyman-vs-Expert conflicts are listed as Journeyman only (true either way).

Sources that cover Forever (Forever-only zones and NPCs, launch-era dates):
- Warcraft Tavern trainer list (NPC IDs, coordinates): https://www.warcrafttavern.com/forever/guides/profession-trainers/
- wow-professions.com/forever (per-profession trainer pages, NPC pages): e.g. https://www.wow-professions.com/forever/enchanting-trainers
- method.gg/wow-forever leveling guides (dated Nov 2026; Artisan untested in beta)
- Icy Veins /wow-forever/*-leveling-guide (Nov 4 2026) and Wowhead /forever/guide/professions/*-overview (patch 1.60.1)
Not used: Gfinity (invented NPCs), boosting/gold blogs, Classic pages. NPC titles are one rank
above what a trainer teaches, so titles are never used.

Confirmed rules:
- Skill 50 / 125 / 200 and level 10 / 20 / 35 for Journeyman / Expert / Artisan (crafting);
  Apprentice and gathering ranks have no level. Base costs 5s / 50s / 5g.
- Crafting: most city trainers stop at Journeyman; Expert from 2-3 trainers per faction; Artisan
  from 1-2 remote trainers (Enchanting: Annora in Uldaman only; Blacksmithing: Brikk Keencraft in
  Booty Bay only).
- Gathering: every trainer outside the starting areas teaches Apprentice to Artisan.
- Cooking: trainers teach Journeyman; Expert = Expert Cookbook (16072) from Shandrina (Ashenvale,
  A) / Wulan (Desolace, H); Artisan = quest Clamlette Surprise (6610) from Dirge Quikcleave.
- Fishing: Journeyman level 10; Expert = "The Bass and You" (16083) from Old Man Heming (Booty
  Bay); Artisan = quest Nat Pagle, Angler Extreme (6607), level 35, Fishing 225.
- First Aid: Expert = "Under Wraps" (16084) from Deneb Walker (Arathi, A) / Balai Lok'Wein
  (Dustwallow, H); Artisan = quest Triage (6624 A / 6622 H), level 35.
- Carrie's Cookbook (239021, Cooking 280) is Season of Discovery data left in the files; no way
  to get it in Forever is known.

Left out (single source or conflict): Melanie Sable (Expert Enchanting), Patricia Egan and
Master Mycologist Shurome (Alchemy), Lawrence Schneider (Tailoring), Edward Egan (Herbalism).
Listed as Journeyman only: Sylvanna Forestmoon (Alchemy), Lilliam Sparkspindle and Franklin
Lloyd (Engineering).

## Specializations (Data/Specializations.lua)

- Engineering: Gnomish (spell 20219) or Goblin (20222), level 30 and Engineering 200 (Wowhead,
  Icy Veins and a third Forever source agree). Quest chain IDs from Wowhead's Forever guide only
  (Gnomish 3640/3641 Alliance, 3642/3643 Horde; Goblin 3638/3639), so the window shows a quest
  only when QuestieDB has it, with QuestieDB's giver, location and requirements.
- Leatherworking: Dragonscale (10656), Elemental (10658), Tribal (10660) exist in Forever
  (Wowhead, wow-professions, Icy Veins, Overgear). Trainers and requirements came from one
  source, so they are read from QuestieDB's quests of the same name instead.
- Blacksmithing (Armorsmith/Weaponsmith spells are in the game data) and Tailoring: no Forever
  source confirms them, so they are not shown.

## Vendor prices (Data/VendorPrices.lua)

Generated by scripts/update_game_data.py from ItemSparse (BuyPrice / VendorStackCount) for
stackable consumables, reagents and trade goods (Item ClassID 0, 5, 7), about 1300 items.
Every item has a buy price in the data, so Tradebook only uses it for items QuestieDB lists a
vendor for. Prices are before reputation discounts. Auctionator's own vendor price (seen at a
merchant) wins when it has one.
