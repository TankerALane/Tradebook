# Tradebook — CurseForge description (draft)

Keep this up to date as features ship; paste it into the CurseForge project description when ready.
Every optional addon below must also be listed as an optional dependency on CurseForge.

---

## Tradebook

A profession companion for **World of Warcraft: Forever**: a better Professions window, every character's professions and recipes in one place, and a fast "Who can craft this?" search.

### Features
- **Replaces the default Professions window** (one click to switch back with **Default UI**, and a **Tradebook** button on the default window to come back).
- **A tab for every profession** plus a **Camp** tab, with a skill bar like the default window.
- **Recipe list** with search, filters (learned; not learned — learnable now, from a trainer, from a recipe, nearest first; have materials; gives skill-ups by colour), and **Starred** and **Pinned** sections.
- **Recipe details**: result tooltip, materials with bag and bank counts (and which of your other characters have them), a tree of materials you can craft, skill-up ranges ("orange until 125"), and where to learn recipes you don't know yet.
- **Craft, quantity and Craft All** for the character you're on.
- **All your characters**: professions, ranks, known recipes, bags and bank, saved account-wide. **"Who can craft…?"** searches them all.
- **Characters view**: who is next to rank up in each profession, missing recipes, hide or delete characters, stale-data warning.
- **Camp tab**: every campsite recipe across your characters, who knows it and who can make it now.
- **Legacy**: your Legacy profession perks and unspent points.
- **Shopping lists** for a recipe or all pinned recipes.
- Minimap button and Data Broker launcher.

### Optional addons
Tradebook works on its own. These addons add extra information when they are installed:

| Addon | What it adds to Tradebook |
|---|---|
| **Questie** | Where to learn unlearned recipes, nearest first (trainers and vendors, with distance and waypoints). Where to get each material: the nearest **vendors** that sell it (your faction, with zone, coordinates and distance), the **mobs** that drop it, and the **nodes** it's gathered from. Click one to set a waypoint. |
| **TomTom** | Waypoints from Tradebook use TomTom's arrow. Without TomTom, Tradebook uses the game's own map pin instead. |
| **Fellowship Ledger** | Your **friends' profession ranks** on each profession tab (Friends button) and on professions none of your characters have. |
| **Auctionator** | *(coming soon)* Auction and vendor prices for materials, the cost to craft a recipe, and sending your shopping list to Auctionator. |

### Notes
- WoW Forever only. Data such as recipe sources comes from LibProfessionDB (MIT) and is marked unconfirmed where it was borrowed from classic; skill-up ranges come from Forever's own game data.
- Free and open source (MIT): https://github.com/TankerALane/Tradebook
