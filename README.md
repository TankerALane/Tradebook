# Tradebook

A profession companion for **World of Warcraft: Forever**.

> For WoW Forever 1.60.1. Please report problems on GitHub.

## Features

- A profession window laid out like the modern Professions window (recipe list on the left, details on the right). It replaces the default window, with a one-click switch back to the default UI.
- A bottom tab for every Forever profession, plus a **Camp** tab for campsite recipes.
- Crafting from Tradebook for the character you're logged into: Craft, quantity, Craft All.
- Every character's professions, skill levels and known recipes saved account-wide, with a fast **"Who can craft this?"** search.
- Reagent counts from bags and bank, missing-reagent highlights, an expandable reagent tree with the nearest vendors for each material, and shopping lists split into vendor and auction house.
- A **leveling plan**: the cheapest way to a profession's skill cap, with materials, cost and a shopping list.
- Where to get every recipe in Forever: trainers, vendors (with Merchant's Favor costs and reputation), the mobs that drop it with drop chances, world drops and quests; and the vendor price next to the auction house price.
- A **Vendors** tab: search any item a vendor sells, nearest vendors first, with prices and waypoints. It ships with a community database of vendors and trainers scanned in game, and the vendors and trainers you open are scanned and shared in game with other Tradebook users (NPC data only; can be turned off).
- **Train the next rank**: when a character can train Journeyman, Expert or Artisan, the requirements, cost, and the trainers, books or quests that teach it in Forever. Specializations (Gnomish/Goblin Engineering, Dragonscale/Elemental/Tribal Leatherworking) too.
- **Browse any profession**, even one none of your characters have, and see which of your characters **could learn** a recipe.
- A Camp tab for campsite recipes across all your characters.
- A read-only view of your Legacy profession perks.
- Friends' profession ranks if you use Fellowship Ledger, and where to farm materials if you use Questie.
- A minimap button and a Data Broker launcher.

## Optional addons

Tradebook works on its own; these add more when installed:

- **Questie**: vendors nobody has scanned yet, the mobs and gathering nodes for each material, and the nearest trainers and vendors for unlearned recipes, with waypoints (click an NPC nearby to target and mark it).
- **TomTom**: waypoints use TomTom's arrow (otherwise the game's map pin).
- **Fellowship Ledger**: friends' profession ranks.
- **Auctionator**: auction and vendor prices for materials, the cost to craft, what the result sells for and the profit (at auction or to a vendor), a profit column in the recipe list, and sending a shopping list to Auctionator.

## Help build the vendor database

Tradebook shares the vendors and trainers you open with other Tradebook users in game, on a hidden channel (setting on by default; `/tb net` for status; see [docs/DATA.md](docs/DATA.md), "In-game sharing"). What your copy hears is exported by the maintainer's "import npc data" step. Or type `/tb share` in game, copy the text and paste it into the [Vendor data form](https://github.com/TankerALane/Tradebook/issues/new?template=vendor-data.yml). Shares are merged with `python -I scripts/merge_vendor_shares.py --issues` into `Tradebook/Data/CommunityVendors.lua` for the next release. Only vendor data is shared.

## Install

Install from CurseForge (search "Tradebook"), or download the zip from [GitHub Releases](https://github.com/TankerALane/Tradebook/releases) and extract the `Tradebook` folder into `World of Warcraft\_forever_\Interface\AddOns`.

## Credits

- Developed by **Decoupled Lane Studio**.
- Recipe source data adapted from **LibProfessionDB** by Pmptasty (MIT License).
- Classic disenchanting table from the **Warcraft Wiki** "Disenchanting tables" page (CC BY-SA 4.0), shown as classic until confirmed in WoW Forever.
- Skill-up ranges from WoW Forever's game data (via wago.tools).

## License

MIT. See [LICENSE](LICENSE). Embedded libraries keep their own licenses.
