# Changelog

## Unreleased

- **Auctionator prices** (optional): auction and vendor prices in material tooltips, a Cost section in recipe details (cost to craft, sells for, profit), the cost of a shopping list, and **Send to Auctionator** to create an Auctionator shopping list.
- **Questie** (optional): where to get each material (nearest vendors, mobs and nodes) and the nearest trainers and vendors for unlearned recipes, with distance and waypoints. Clicking an NPC that's nearby also targets it and marks it with a purple diamond.
- **Not learned** filter options: Learnable now, From a trainer, From a recipe, and Nearest first.
- "Made by" is listed first under a material.
- Camp shows recipes that exist once per faction (Faction Banner) only once.
- Characters: every profession is shown (no more cut-off columns).
- `/tb shots` takes screenshots with fake data for the addon page.

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
