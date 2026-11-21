# Tradebook — CurseForge description

Keep this up to date as features ship; paste it into the CurseForge project page.
Every optional addon below must also be listed as an optional dependency on CurseForge.

**Summary** (the one line under the project name):

> Professions for WoW Forever: a better Professions window, every character's recipes, where to get every recipe, leveling plans, and a shared vendor database.

---

## Tradebook

The profession companion for **World of Warcraft: Forever**. A better Professions window, all your characters' professions in one place, and **where to get every recipe in Forever**, checked in game.

### Professions tab (press K)
- **Your professions at a glance**, like the game's Professions book: your **two primary profession slots** (an empty box while one is free) and your **secondary professions** (Cooking, First Aid, Fishing; greyed out until learned), each with its rank and skill bar. Click one to open it.
- **Profession spells** (Alchemy, Smelting, Fishing...) and **Find Herbs / Find Minerals**: Forever's spellbook doesn't list them, so drag them from here to your action bars, or click Find Herbs / Find Minerals to start tracking.
- **Unlearn a profession** with the red cross next to its skill bar (primary professions only). The game still asks you to type UNLEARN to confirm.
- Rather have K open the tab you had last? Turn off **K opens on Professions** in the options.
- **Characters**, **Legacy** and **Vendors** sit beside it as icon tabs down the right side of the window.

### Where to get every recipe
- **Every source, checked for Forever**: trainers, vendors, the **mobs that drop it** (with drop chances), world drops and quests. Wrong classic sources are gone, Forever's new vendors are in, and recipes that aren't in Forever say so.
- **Merchant's Favor recipes**: their cost and the supply camp reputation you need.
- **Vendor price vs auction house price**, with the cheaper one marked.
- **Real skill levels and training costs**, read from Forever's own trainers.
- Click any vendor, trainer or mob for a waypoint. If it's nearby, it's also targeted and marked.

### Vendors tab: a community vendor database
- Search **any item** and see the **nearest vendors** that sell it, their price (gold, Merchant's Favor or other currency), zone and distance. Items no vendor sells show their **auction price** (with Auctionator and Questie). Filter like the auction house: **level range**, **rarity**, **usable by this character**, item type, zone and more.
- **Vendor > Auction** (with Auctionator): items listed at the auction house for less than a vendor pays for them, biggest profit first. It checks every item Tradebook and Questie know, not just what vendors sell.
- Ships with **592 vendors and 171 trainers** scanned in game, from Orgrimmar to Teldrassil, and grows with every update.
- **Built by players**: every vendor and trainer you open is scanned and **shared in game** with other Tradebook users while you play. Log in later and the players online **catch you up** on what was shared in the last week. It runs on a hidden channel (nothing in your chat) and pauses in combat and dungeons. Only NPC data is shared, never anything about your characters, and you can turn it off in the settings.

### A better Professions window
- **Replaces the default window** (switch back any time with **Default UI**).
- **A tab for every profession** plus **Camp**, with a skill bar like the default. **Right-click a tab** to move it, hide it or show hidden ones again, hide every profession none of your characters have in one click, or give a character its own tab layout.
- **Recipe list** with search, Starred and Pinned sections, and filters: learned, not learned (learnable now, from a trainer, from a vendor, from a mob, nearest first), have materials (or everything but what a vendor sells), and skill-up colour.
- **Recipe details**: materials with bag and bank counts (and which of your characters have them), the **nearest vendors** that sell each one with their price, a tree of craftable materials, and skill-up ranges ("orange until 125").
- **Craft, quantity and Craft All.**
- **Shift-click into search boxes**: while you're typing in the auction house's (or Auctionator's) search box, shift-clicking an item in Tradebook puts its name there instead of linking it in chat.
- **Disenchanting**: item tooltips show what an item disenchants into, its value and whether to disenchant or sell; enchanting materials show what they're disenchanted from. Results are recorded from real disenchants in Forever and shared between Tradebook users, so the table gets confirmed for Forever. Don't want it? Turn it off in the options.
- **Profession links**: click another player's profession link in chat and their recipes open in Tradebook, with materials, where to buy them and prices. The **link button** next to the skill bar posts your own profession in chat.

### Level up faster
- **Leveling plan**: a sure way to your skill cap (orange recipes, a skill-up every craft, cheapest first), step by step, with the materials you need, what you already have, the cost and a shopping list.
- **Train the next rank**: a button when you can train Journeyman, Expert or Artisan, with the requirements and the nearest trainers, books or quests.
- **Specializations**: Gnomish/Goblin Engineering and Dragonscale/Elemental/Tribal Leatherworking, with their quests.
- **Shopping lists**, split into what to buy from a vendor and what to buy at the auction house.

### All your characters
- Every character's professions, recipes, bags and bank, saved account-wide.
- **"Who can craft…?"** search across all of them, and **Could learn it** for recipes nobody knows yet.
- **Characters view**: who is next to rank up, missing recipes, stale-data warning.
- **Browse any profession**, even one none of your characters have.
- **Camp tab** for campsite recipes, and **Legacy** for your Legacy profession perks.

### Optional addons
Tradebook works on its own. These add more when installed:

| Addon | What it adds |
|---|---|
| **Questie** | Vendors nobody has scanned yet in the Vendors tab, finding items no vendor sells there, and many more items for the Vendor > Auction filter. The nearest trainers and vendors for recipes you haven't learned. For each material: the mobs that drop it and the nodes it's gathered from. |
| **Auctionator** | Material prices, the **cost to craft**, what the result **sells for** and your **profit** selling at auction, to a vendor or by disenchanting it, a **profit column in the recipe list** (vendor, auction house or disenchant), the **disenchant value** in item tooltips, shopping list costs, auction prices for items no vendor sells in the Vendors tab, the **Vendor > Auction** filter, and **Send to Auctionator**. |
| **TomTom** | Waypoints use TomTom's arrow (otherwise the game's map pin). |
| **Fellowship Ledger** | Your **friends' profession ranks** on each profession tab. |

### Notes
- **WoW Forever only.**
- Recipe sources are checked against Forever's own game data, QuestieDB (read while you play, nothing copied) and Forever websites. Anything only one source names is marked "(unconfirmed)".
- Commands: `/tb` opens Tradebook, `/tb help` lists the rest. `/tb share` sends your scans through the [Vendor data form](https://github.com/TankerALane/Tradebook/issues/new?template=vendor-data.yml) if you'd like to help that way too.
- Free and open source (MIT): https://github.com/TankerALane/Tradebook. Bug reports welcome on GitHub.
