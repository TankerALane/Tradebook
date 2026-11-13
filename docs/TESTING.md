# Testing

## Automated (run locally or in CI)

- `luajit tests/run.lua` (or `lua5.1`): data-logic tests. Covers saving and merging characters, play type, stale detection, hide/delete, "who can craft this" search, missing recipes, camp grouping, reagent shortage math (bags only, bank as fetch-first), shopping list totals, reagent tree (cycles, depth), DB migrations, tab order, rank names, and the bundled source data.
- `bash scripts/lint.sh`: luacheck over the addon and tests (CI runs the same check on every push and pull request).

## In game

Turn on Lua error display first: install BugSack/BugGrabber, or `/console scriptErrors 1`. Report any error text.

### 1. First login with empty data
- [ ] Log in. No errors. The minimap button shows, and its tooltip lists your professions.
- [ ] `/tb` opens the window. Tabs, left to right: Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking, First Aid, Fishing, Herbalism, Mining, Skinning, Camp. **All tabs fit inside the window at the default size** (they shrink if needed).
- [ ] Tab colours: yours are gold, alt-only white, nobody grey. A number shows how many characters have each.

### 2. Opening Tradebook
- [ ] **Professions key** and the **micro-menu Professions button** open Tradebook; the default window does not appear.
- [ ] **Clicking a profession** in the default window's book page or the spellbook opens Tradebook on it.
- [ ] **Minimap button**: left-click toggles, right-click opens settings, shift-click opens Camp, drag works.
- [ ] Nothing invisible reacts where the default window would be.
- [ ] ESC closes Tradebook (and the profession) in one press.

### 3. Default UI and back
- [ ] **Default UI** (top right): Tradebook closes and the normal window shows with the same profession open. **Its layout looks normal** (Create / Create All and the quantity box sit inside their boxes).
- [ ] The normal window has a **Tradebook** button at its top right (left of the close X) that switches back.
- [ ] Settings → untick "Use Tradebook instead of the default Professions window": the key and spellbook open the default window normally; `/tb` still opens Tradebook.

### 4. Recipes and crafting (logged-in character)
- [ ] Each profession tab opens that profession (the default window stays hidden) and lists recipes by category with skill-up colours and the `+N` side indicator.
- [ ] Search, Filter menu and favourites (star) work. The star is at the far right, with **Pin** to its left (no overlap).
- [ ] Details: item tooltip with stats; reagents have/need in green/red; bank items show "(Bank: n)". No "account bank" text anywhere.
- [ ] A reagent made by another recipe has a **+** that expands "Made by ..." with who knows it; clicking that line opens the recipe.
- [ ] **Craft** qty 1 and qty 3, and **Craft All**, craft the right amounts.
- [ ] Go to the Camp tab, then click a recipe of a profession that isn't open: the details button reads **"Open <profession>"**. One click opens it, then the button becomes **Craft**.
- [ ] **Open in default window** opens the default window on that recipe, **including for a profession that wasn't open**. It is greyed out for recipes from professions this character doesn't have.
- [ ] **Shopping list** (this recipe ×qty) and **Pin** + **Shopping list (pinned)** list the missing reagents.

### 5. Bank
- [ ] Open the bank, then close it. Reagent counts now include bank items as "(Bank: n)".

### 6. Second character and quick scan
- [ ] Log in on a character whose professions **you haven't opened yet**, wait a few seconds, and open Tradebook **without opening the profession**. Its tab should already list its learned recipes, with the note "Recipes found in the spellbook..." (`/tb debug` shows "quick scan added N recipes").
- [ ] Opening the profession once replaces that with the full list (categories, unlearned recipes).
- [ ] Tabs and badges count both characters; an alt's profession shows read-only with "Viewing X's saved recipes", and the character picker switches between characters.
- [ ] The global search ("Who can craft...?") finds a recipe the other character knows; clicking a result opens it.

### 7. Characters view
- [ ] Left column **"Next rank-up"**: one block per profession, stacked, showing who is closest and to what rank (e.g. "Ana  145/150 (5 to go), then Expert", or "ready to train Expert").
- [ ] Right: every character with class icon and colour, level, play type, last seen, professions with ranks and missing-recipe counts.
- [ ] Hide / show hidden / Show again; Delete (with confirm).
- [ ] (Later) a character not seen for 30+ days shows the stale warning.

### 8. Camp tab
- [ ] Lists each profession's Camping recipes with materials coloured (green have, gold in bank, red missing), who knows each, and who can make it now.
- [ ] "By character" switches to a list grouped by character.
- [ ] The button on a recipe you know reads **"Open <profession>"** when that profession isn't open and you have the materials (enabled); after opening, it reads **Craft** and crafts.

### 9. Greyed-out profession and Legacy
- [ ] A grey tab shows the guide; **Legacy** shows perks, ranks and unspent points.

### 10. Persistence and settings
- [ ] Window **scale 1.0 is now as big as the old 1.25**; your saved scale was converted, so it should look the same as before. The slider goes 0.6-1.4.
- [ ] **Show gathering profession tabs** off: Herbalism, Mining and Skinning tabs disappear (their characters are still in Characters and search); on: they come back at the right.
- [ ] `/reload` keeps size, position, scale, favourites, pins and characters.
- [ ] Minimap toggle works; `/tb debug` prints diagnostics (including the default-window state).
