# Tradebook — CurseForge description (draft)

Keep this up to date as features ship; paste it into the CurseForge project description when ready.
Every optional addon below must also be listed as an optional dependency on CurseForge.

---

## Tradebook

A profession companion for **World of Warcraft: Forever**: a better Professions window, every character's professions and recipes in one place, and a fast "Who can craft this?" search.

### Features
- **Replaces the default Professions window** (one click to switch back with **Default UI**, and a **Tradebook** button on the default window to come back).
- **A tab for every profession** plus a **Camp** tab, with a skill bar like the default window.
- **Recipe list** with search, filters (learned; not learned — learnable now, from a trainer, from a recipe (from a vendor, from a mob), nearest first; have materials; gives skill-ups by colour, with a coloured dot on recipes you haven't learned yet), and **Starred** and **Pinned** sections.
- **Recipe details**: result tooltip (enchants say what they do), materials with bag and bank counts (and which of your other characters have them), a tree of materials you can craft, skill-up ranges ("orange until 125"), and **where to get every recipe in WoW Forever**: trainers, vendors (with **Merchant's Favor** costs and the supply camp reputation needed), the **mobs that drop it** with drop chances, world drops, quests, and recipes that aren't in Forever. Checked against Forever's own data and websites.
- **Purchase price**: the vendor price next to the auction house price for a recipe, with the cheaper one marked.
- **Specializations**: Gnomish/Goblin Engineering and Dragonscale/Elemental/Tribal Leatherworking, with their quests and requirements.
- **Leveling plan**: the cheapest way to reach your skill cap, step by step, with the materials, the cost (Auctionator) and a shopping list.
- **Train the next rank**: a button in the skill bar when you can train Journeyman, Expert or Artisan, with the requirements and where to train it (trainers, books or quests).
- **Browse any profession**, even one none of your characters have: every recipe, its materials and their cost.
- **Could learn it**: for recipes none of your characters know, which of them could learn it and how far they are.
- **Craft, quantity and Craft All** for the character you're on.
- **All your characters**: professions, ranks, known recipes, bags and bank, saved account-wide. **"Who can craft…?"** searches them all.
- **Characters view**: who is next to rank up in each profession, missing recipes, hide or delete characters, stale-data warning.
- **Camp tab**: every campsite recipe across your characters, who knows it and who can make it now.
- **Legacy**: your Legacy profession perks and unspent points.
- **Shopping lists** for a recipe or all pinned recipes, split into what to buy from a vendor and what to buy at the auction house.
- **Vendors tab**: search any item a vendor sells and see the nearest vendors, their prices (gold, Merchant's Favor and other currencies), zone and distance, with a waypoint. Filters for zone, faction, continent, item type and currency.
- **Vendor windows are scanned automatically**, so prices and stock stay real.
- Minimap button and Data Broker launcher.

### Optional addons
Tradebook works on its own. These addons add extra information when they are installed:

| Addon | What it adds to Tradebook |
|---|---|
| **Questie** | Vendors nobody has scanned yet in the **Vendors tab** (QuestieDB's vendor lists, with the game's base prices). Where to train your next rank (nearest trainers, rank-up books and quests). Where to learn unlearned recipes, nearest first (trainers and vendors, with distance and waypoints). Where to get each material: the nearest **vendors** that sell it (your faction, with zone, coordinates and distance), the **mobs** that drop it, and the **nodes** it's gathered from. Click one to set a waypoint; if the NPC is nearby, it's also targeted and marked with a purple diamond. |
| **TomTom** | Waypoints from Tradebook use TomTom's arrow. Without TomTom, Tradebook uses the game's own map pin instead. |
| **Fellowship Ledger** | Your **friends' profession ranks** on each profession tab (Friends button) and on professions none of your characters have. |
| **Auctionator** | Auction and vendor prices for each material (in its tooltip), the **cost to craft** a recipe, what the result **sells for** and your **profit**, the price of rank-up books, the cost of a shopping list, and **Send to Auctionator** to turn a shopping list into an Auctionator shopping list. |

### Help build the vendor database
Every vendor you open is scanned automatically. Type **/tb share**, copy the text, and paste it into the [Vendor data form](https://github.com/TankerALane/Tradebook/issues/new?template=vendor-data.yml) on GitHub: your scans are merged into the next update so everyone gets them. Only vendor data is shared (vendor names, places, items and prices), nothing about your characters.

### Notes
- WoW Forever only. Recipe sources were checked against Forever's own game data, QuestieDB (read at runtime, nothing copied) and Forever websites; anything only one source names is marked "(unconfirmed)". Skill-up ranges and base prices come from Forever's own game data.
- Free and open source (MIT): https://github.com/TankerALane/Tradebook
