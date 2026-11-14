# Changelog

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
