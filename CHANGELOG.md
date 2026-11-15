# Changelog

## Unreleased

### Fixes
- The blue skill bar no longer sticks out past its frame on the left and right.

## v0.4.1-beta

### More vendor and trainer data
- The community database now has **471 vendors (6,239 items)** and **132 trainers (1,703 services)** scanned in game, up from 185 and 65. It now covers the Alliance cities (Stormwind, Ironforge, Darnassus) and the Alliance starting zones, including Teldrassil.
- Six Season of Discovery NPCs that Questie lists but that aren't in WoW Forever (Gishah, Dokimi, Marcy Baker, two Rune Brokers and an Ironforge Guard) are no longer offered anywhere.

### Sharing in game
- Tested in dungeons: sharing pauses inside and catches up when you leave. `/tb net` now says when it's paused (in combat or in a dungeon).
- `/tb net test` queues 20 test messages, to check for yourself that sending pauses in a dungeon. Other players' Tradebook ignores them.

### Fixes
- Right-clicking a vendor or mob line no longer targets it; left-click does.

## v0.4.0-beta

### Sharing in game
- **Tradebook now shares the vendors and trainers you open with other Tradebook users while you play.** What they find shows up in your **Vendors tab** as "other players". A vendor only one player has shared is marked "(unconfirmed)" until a second player agrees.
- It runs quietly in the background on a hidden channel: nothing shows in your chat, and it pauses in combat and in dungeons. Only NPC data is shared (vendor and trainer names, places, items, training and prices), never anything about your characters.
- Turn it off in the settings if you like. `/tb net` shows what was sent and heard. `/tb share` and the GitHub form still work as before.
- This is the first version with sharing, so it gets better as more players update.

### More vendor and trainer data
- The community database now has **185 vendors (2,694 items)** and **65 trainers (952 services)** scanned in game.

### Gathering
- **Find Herbs and Find Minerals** on the Herbalism and Mining tabs, on their own row above the search box. Drag the icon to your action bars, or click it to start tracking.

### Fixes
- Clicking an NPC replaces Tradebook's previous waypoint (TomTom arrow) and moves the purple diamond to the new NPC. Clicking an NPC again, after a try from too far away or when it's already marked, keeps the diamond on instead of taking it off.
- Vendors only Questie lists no longer show "(base)" next to their price; they already say "Questie".

## v0.3.0-beta

### Where to get every recipe in WoW Forever
- **Recipe sources checked for Forever.** Every recipe was checked against Forever's own game data, Questie's Forever data and Forever websites. Wrong classic vendors are gone (100), Forever vendors added (65), and **461 recipes from Forever's new vendors** now show where to buy them: the Merchant's Favor supply camps (Durotar Supply and Logistics in the Barrens, Azeroth Commerce Authority in Redridge), Aisarra Nightmeadow, the Skyforged and Gustwoven quartermasters, the centaur quartermasters and more. Supply camp recipes show their **Merchant's Favor cost** and the **reputation** needed with your faction's camp.
- **Who drops it**: the top 5 mobs with zone, level and drop chance from recorded loots (e.g. "11% (1 of 9)"), **world drops** with the mob level range, trainer and quest recipes, and **"Not available in WoW Forever"** for Season of Discovery leftovers. 302 recipes that said "Unknown source" now have one.
- **Trainers seen in game**: trainers that teach a recipe, the real **skill needed** (the old classic values were often wrong: Linen Bag needs 5, not 45) and the **training cost**.
- **Purchase price**: the vendor price next to the auction house price for a recipe, with the cheaper one marked.
- Recipe sources (and vendor locations) show for recipes you already know too, and quests show their name before the game has loaded it.
- Only information that isn't confirmed is labelled: "(unconfirmed)" when only one weaker source names it, "Questie" for vendors only Questie lists.

### Vendors tab and the community database
- **Vendors tab** (next to Legacy and Characters): search any item a vendor sells. Each item expands to its 5 nearest vendors (price in gold, Merchant's Favor or other currency, zone, distance) with **See all**. Filters: zone, only friendly vendors, only this continent, item type, paid with, and data source.
- **Vendor and trainer windows are scanned automatically**: everything a vendor sells, prices, stock and where it stands; every trainer's list. Limited-supply recipes are marked, and a vendor whose window didn't have a recipe says "(not in stock when you visited)".
- **Community database**: 127 vendors (1,834 items) and 53 trainers already scanned in game ship with this version.
- **/tb share**: send your scans through the [Vendor data form](https://github.com/TankerALane/Tradebook/issues/new?template=vendor-data.yml) on GitHub so everyone gets them in the next update. NPCs that still match are sent as a short "confirmed" line, and only scans since your last share are included. Only NPC data is shared, nothing about your characters.
- Clicking a vendor or a mob also **targets it and marks it with a purple diamond** when it's nearby.

### Recipes and crafting
- **Leveling plan**: the cheapest way to raise a profession to its cap (button left of the skill bar): steps, materials (need / have / buy), cost and a shopping list. Uses your bags and bank first, works without Auctionator.
- **Shopping lists** are split into **Buy from a vendor** and **Buy at the auction house**, with prices and subtotals.
- **Vendor prices from the game** for thread, dyes, vials and other vendor goods.
- New filters: **From a vendor** / **From a mob** under From a recipe. With **Not learned** and **Gives skill-ups** ticked, unlearned recipes that would give skill-ups show with a dot in their skill-up colour.
- **Enchants** say what they do on hover.
- Legacy and Characters moved to tabs at the far right; the window keeps its parts from overlapping when made narrow.

## v0.2.1-beta

- **Browse professions you don't have**: recipes are grouped by the rank they need (Apprentice 1-74, Journeyman 75-149, Expert 150-224, Artisan 225-300) instead of one "Other" list (the game gives no category names for a profession that isn't open).
- Recipes the game returns without a name are no longer listed.
- `/tb shots`: the rank window no longer shows your real gold.

## v0.2.0-beta

Second beta for WoW Forever (1.60.1). Please report problems on GitHub.

**Train the next rank**
- A **Train Journeyman / Expert / Artisan** button appears in the skill bar once a character can train the next rank (skill 50, 125, 200). Clicking the skill bar opens the same window at any time.
- The window shows the requirements (skill, and level 10 / 20 / 35 for crafting professions), the cost (5s / 50s / 5g, or what the trainer actually charged you) and how to get it:
  - the nearest **trainers that teach that rank** in Forever, from a list cross-checked across several Forever guides and trainer windows in game (NPC titles like "Expert Enchanter" don't say what a trainer teaches);
  - the **Expert Cooking, Fishing and First Aid books**, with their auction price and where they're sold;
  - the **Artisan Cooking, Fishing and First Aid quests** (Clamlette Surprise, Nat Pagle, Triage) with the quest giver and requirements.
- **Specializations**: Gnomish/Goblin Engineering and Dragonscale/Elemental/Tribal Leatherworking, with their quests and requirements, or the one a character already has.
- Opening a profession trainer's window teaches Tradebook which ranks that trainer offers and what it costs.

**Recipes**
- **Browse professions you don't have**: a grey tab's guide page has **Show all recipes**, listing every recipe of that profession with materials, costs and where to learn it.
- **Could learn it**: for recipes none of your characters know, which of them could learn it: now, with N more skill, or after training the next rank (also in the Who can craft search).
- **Not learned** filter options: Learnable now, From a trainer, From a recipe, and Nearest first.
- The recipe list shows the craftable count at the far right; the skill-up colour is the name's colour.
- The skill-up section in recipe details lines up your skill with the ranges ("115 - 125").

**Auctionator** (optional)
- Auction and vendor prices in material tooltips ("Purchase from:").
- A **Cost** section in recipe details: cost to craft, what the result sells for after the auction house cut, and the profit.
- Shopping lists show their cost and can be sent to Auctionator (**Send to Auctionator**).

**Questie** (optional)
- Where to get each material: the nearest vendors (your faction), mobs and gathering nodes, with distance and waypoints.
- The nearest trainers and vendors for recipes you haven't learned.
- Clicking a nearby NPC line also targets it and marks it with a purple diamond.

**Other**
- "Made by" is listed first under a material.
- Camp shows recipes that exist once per faction (Faction Banner) only once.
- Characters view: every profession is shown (no more cut-off columns).
- `/tb shots` takes screenshots with made-up characters for the addon page.

## v0.1.0-beta

First beta for WoW Forever (1.60.1). Please report problems on GitHub.

- **Profession window** that replaces the default one, with a "Default UI" button to switch, and a "Tradebook" button on the default window to switch back. Setting to turn the replacement off.
- **Bottom tabs** for all 12 professions plus Camp. Tabs are gold for your professions, white for alt-only, grey for none, with a count of characters. Gathering professions can be hidden.
- **Recipe list** with search, filters (learned, not learned, have materials, gives skill-ups), Starred and Pinned sections, and skill-up colours that match the game.
- **Recipe details**: result item tooltip, who can craft it, reagents with bag and bank counts (and which other characters hold them), an expandable reagent tree, skill-up ranges ("orange until 125" and so on, from Forever's own data), and where to learn recipes you don't know yet.
- **Crafting** for the logged-in character: Craft, quantity, Craft All, and "Open <profession>" when the profession isn't open yet.
- **Account-wide data**: every character's professions, recipes, bags and bank. Recipes are found from the spellbook at login, without opening the profession first.
- **"Who can craft…?"** search across all characters.
- **Characters view**: class, level, play type, last seen, professions and missing recipes; who is next to rank up in each profession; hide or delete characters; stale-data warning.
- **Camp tab**: campsite recipes across all characters, who knows them, who can make them now, and the materials.
- **Legacy**: your Legacy profession perks and unspent points.
- **Shopping lists** for one recipe or all pinned recipes.
- **Minimap button** and Data Broker launcher; settings panel (scale, minimap, gathering tabs, stale-data threshold).

Credits: recipe source data adapted from LibProfessionDB by Pimptasty (MIT). Skill-up ranges from WoW Forever's game data.
