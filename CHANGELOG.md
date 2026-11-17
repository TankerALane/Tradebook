# Changelog

## Unreleased

## v1.4.0

### Recipe list
- The recipe list is now in the **same order as the default window**, so switching over feels familiar: categories in the game's order, and in each category the recipes you know first, then by colour (orange, yellow, green, grey), then the higher-level recipe first. Prefer alphabetical? **Filter → List order → A to Z**.
- The game's category order is read when you open a profession; until you've opened it once with this version, its categories stay A to Z.

### Crafting
- **Craft All fills in the quantity**, and the quantity **counts down** as each craft finishes, with Craft All or with Craft and a number (like a leveling plan step's). When the batch is done it goes back to 1; if it stops early (you moved, got attacked), it shows how many are left, so Craft carries on from there.
- Changing the number by hand during a batch stops the count-down (the game keeps crafting the batch it was given).

### Data
- New vendors: Kaja (Orgrimmar) and Innkeeper Gryshka (Orgrimmar); Jim'bek now has a location. 483 vendors, 6,363 items.
- New trainer: Victor Ward (Tailoring, Undercity), confirmed by two players. 136 trainers.

## v1.3.0

### Tabs
- **Right-click a profession tab** (or Camp) to arrange the tabs: move it left or right, to the front or the end, or hide it. Hidden tabs come back from the same menu ("Show a hidden tab"), or all at once.
- **Hide professions none of my characters have**, in one click from that menu.
- **Per character**: tick "Own tab layout for <character>" in the menu to give that character its own order and hidden tabs; untick it to go back to the layout the others share.
- A hidden profession you open from the game still shows its tab while it's open. Vendors, Legacy and Characters stay at the right.
- The "Show gathering profession tabs" setting now hides or shows those three tabs in this layout (if you had turned it off, they start hidden).

### Professions
- **Unlearn** a main profession from Tradebook: a red cross next to the skill bar (like the one in the default window's profession book), so you don't have to switch back to the default window. It opens the game's own confirmation, where you type UNLEARN. Not shown for Cooking, First Aid and Fishing (the game has no unlearn for them there either), or for other characters and linked professions.

## v1.2.2

### Leveling plan
- Fixed: a step's tooltip could say to buy 1 or 2 of a material you already have enough of (for example "need 16, have 15, buy 1" with 20 Empty Vials in your bags). It now counts whole items, in step order, matching the totals below.
- "Have" now shows everything you have (bags and bank), in the totals and in a step's tooltip, not just as many as are needed. "Buy" is what's missing; for a step, after the earlier steps have used what you have.

### Data
- New trainer: Rhiannon Davis (Tailoring, Undercity). Trainer data now covers 135 trainers.
- The disenchant database now has 30 disenchants in 9 bands. New: blue armor of item level 26-30 (Large Glimmering Shard, which matches the classic table).

## v1.2.1

### Sharing in game
- What you hear from other players is now **passed along to the community database** too: when the Tradebook maintainer comes online, Tradebook sends what it heard from other players (vendors, trainers, disenchant results) that hasn't reached the database yet, a little at a time, and stops once it has arrived. So scans from players who are never online at the same time as the maintainer still make it into the next update. It also re-sends your own recent scans then.
- Only NPC and disenchant data is passed along, as before; players are told apart only by a short code, never by name. Regular copies of Tradebook don't take in passed-along data, so it never counts twice.

### Leveling plan
- Hover a step to see the materials for just that step: need, have and buy, like the totals below. What you have is used by the earlier steps first.
- Clicking a step opens the recipe with the **quantity set** to that step's number of crafts.

## v1.2.0

### Disenchanting
- **Item tooltips** say what a green, blue or purple weapon or armor disenchants into. By default it's one line (materials and value); **hold Shift** for the details: each material with its icon, count, chance and auction price, the total **value at auction**, and where the numbers come from. Turn it off, or always show the details, in the settings.
- **Disenchant or sell?** With Auctionator, the tooltip says what pays most: disenchanting, selling to a vendor or selling at auction ("Roughly equal" when they're close).
- **"Disenchanted from"** on enchanting materials' tooltips (Strange Dust, essences, shards): which items give it, by quality and item level.
- **"Can't be disenchanted"** on weapons and armor that WoW Forever won't let you disenchant.
- **Disenchant profit**: "Disenchanting it" in the recipe list's profit menu, and a **Disenchant** line in a recipe's Profit section: craft it, disenchant it, sell the materials at auction.
- **Shared in game**: your disenchants are recorded (`/tb de` lists them) and shared in the background with other Tradebook users, like vendors and trainers. Only the results per item level band are shared, nothing about your characters. Another player's results count once two players have reported that band.
- **Disenchant database**: Tradebook now ships the disenchant results recorded so far (21 disenchants in 8 bands), so everyone starts with them. First finding: in WoW Forever, green weapons of item level 21-30 have given Greater Magic Essence every time (3 of 3), where the classic table says Astral Essence; their tooltips say so.
- **Where the numbers come from**: which items disenchant comes from WoW Forever's own game data. What they give isn't in the game data, so the classic table is shown (from the Warcraft Wiki, checked against the classic server databases), marked "not yet confirmed in WoW Forever". Green armor of item level 5-15, 16-20 and 26-30 matches Wowhead's WoW Forever data. After 10 disenchants of a band: "Confirmed in WoW Forever" if they fit the classic table, otherwise what Forever actually gave is shown. Blue items of item level 56+ say the sources disagree on the Nexus Crystal chance.

### Data
- The community database now has **481 vendors (6,341 items)** and **134 trainers (1,763 services)** scanned in game, up from 471 and 132.

## v1.1.0

### Profession links
- **Other players' profession links open in Tradebook**: click a [Tailoring] link in chat and Tradebook shows that player's recipes on the Tailoring tab, with everything Tradebook adds: materials with your bag counts, where to buy them, prices, cost and profit. Their name shows "(linked)" and stays in the character menu of that tab until you log out. Nothing about them is saved.
- **Link button**, a small chat icon right of the skill bar (like the default window): click to put your profession's link in the chat you were typing in (your last channel, not Say), right-click to post it in Guild, Party, Raid or a channel. It works while that profession is open (the Open button at the bottom).

### Fixes
- Skill-ups for a recipe you can't learn yet start at the skill it needs: Enchant Bracer - Superior Stamina shows orange 300 - 320, not from your current skill.

## v1.0.2

### Fixes
- Opening Tradebook with the Character window (or another side window) open no longer pushes that window to the middle of the screen behind Tradebook: it stays on the left.

## v1.0.1

### Leveling plan
- **Orange from what you have first**: when you have the materials for an orange recipe (a sure skill-up), the plan uses it before anything else, so you level as far as your bags and bank take you without buying.
- After that, the cheapest gold per skill point. Materials you have count for a little (a yellow recipe you have materials for no longer beats a cheaper orange one), and an orange recipe is chosen unless a yellow or green one is clearly cheaper (under 3/4 of its cost per point).

## v1.0.0

**Tradebook 1.0**, the first full release for WoW Forever, after nine betas. Thanks to everyone who tested and shared vendor data.

What Tradebook does:
- **A better Professions window** with a tab for every profession and Camp, search, filters, Starred and Pinned recipes, crafting, and a **profit column** (vendor or auction).
- **Where to get every recipe in Forever**, checked against Forever's own data: trainers, vendors (with Merchant's Favor costs), mobs with drop chances, world drops and quests.
- **A community vendor database** (471 vendors, 132 trainers scanned in game) in the **Vendors** tab, which grows as players share what they open in game.
- **Level up faster**: the leveling plan, train the next rank, specializations and shopping lists.
- **All your characters** in one place: "Who can craft...?", Could learn it, the Characters view, and browsing any profession.

Optional: Questie, Auctionator, TomTom and Fellowship Ledger add more when installed.

### Where to buy materials, without Questie
- A recipe's materials expand (green plus) to their **nearest vendors** from the vendor database (your scans, the community data, other players and Questie), with the **price**, zone and distance. Click one for a waypoint. Before, this needed Questie.
- Vendor goods like thread and vials have a vendor price without Questie too, so their recipes' cost and profit show.

### Fixes
- The **Default UI** button at the top right, next to the close button, shows again (it was hidden behind the window's title art).

## v0.5.2-beta

### Profit in recipe details
- A new **Profit** section under Cost shows the profit of both ways to sell: **Auction** (after the cut) and **Vendor** ("won't sell" for items vendors won't buy).

### Fixes
- Characters tab in a narrow window: the Hide and Delete buttons no longer cover the professions. When the window is narrow they move under the character's level, "Last seen" gets its own line (red when the data is old), and if there's still no room, the "not learned" counts move to the row's tooltip.

## v0.5.1-beta

### Filters
- **No Merchant's Favor** under From a recipe: hides recipes you can only buy with Merchant's Favor (supply camps). Recipes a trainer teaches or a mob drops stay.

## v0.5.0-beta

### Profit in the recipe list
- **Show profit** (in the recipe list's Filter menu): each recipe shows what one craft earns after buying all its materials, between its name and the count. Choose **Selling to a vendor** or **Selling at the auction house** (needs Auctionator), or **Off**. Hover a recipe for the cost, the sale and the profit. Recipes with a material or sale price that isn't known yet show nothing.
- Items vendors won't buy say "won't sell" under Selling to a vendor.

### Smaller window
- The window can be made narrower (760 instead of about 990). When the tabs don't fit, they first switch to short names (Alch, Smithing, Leather...) and then wrap onto a second row; the Open in default window and Shopping list buttons move up a line.

### Fixes
- The blue skill bar no longer sticks out past its frame on the left and right.

### Data
- One more vendor item (Martine Tramblay sells Aquadynamic Fish Attractor), and the first NPC confirmation shared in game by another player.

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
