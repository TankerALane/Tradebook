# Testing

## Automated (run locally or in CI)

- `luajit tests/run.lua` (or `lua5.1`): data-logic tests. Covers saving and merging characters, play type, stale detection, hide/delete, "who can craft this" search, missing recipes, camp grouping, reagent shortage math (bags only, bank as fetch-first), shopping list totals, reagent tree (cycles, depth), DB migration, and the bundled source data.
- `bash scripts/lint.sh`: luacheck over the addon and tests (CI runs the same check on every push and pull request).

## In game

Turn on Lua error display first: install BugSack/BugGrabber, or `/console scriptErrors 1`. Report any error text.

### 1. First login with empty data
- [ ] Log in. No errors. The minimap button (Tradebook icon) shows, and its tooltip lists your professions.
- [ ] `/tb` opens the window: a portrait frame with 13 bottom tabs (9 primary, 3 secondary, Camp).
- [ ] Tabs: professions you have are gold, ones only an alt has are white, ones nobody has are grey. A small number shows how many characters have each one.

### 2. Opening Tradebook
- [ ] **Professions key**: Tradebook opens; the default window does not appear.
- [ ] **Micro-menu Professions button**: same.
- [ ] **Clicking a profession in the default Professions window / spellbook**: Tradebook opens on that profession.
- [ ] **A crafting station** (forge or anvil, cooking fire): Tradebook opens on that profession.
- [ ] **Minimap button**: left-click toggles Tradebook, right-click opens settings, shift-click opens the Camp tab. You can drag it around the minimap.
- [ ] Click where the default window would be while Tradebook is up: nothing invisible should react (no tooltips, no clicks).
- [ ] ESC closes Tradebook (and the profession) in one press.

### 3. Default UI and back
- [ ] **Default UI** (top right): Tradebook closes and the normal Professions window shows, with the same profession open.
- [ ] On the default window, the **Tradebook** button (next to its close button) switches back.
- [ ] Settings → untick "Use Tradebook instead of the default Professions window". The key and stations now open the default window normally, and `/tb` still opens Tradebook.

### 4. Recipes and crafting (logged-in character)
- [ ] Each profession tab opens that profession (the default window stays hidden) and lists its recipes by category, with skill-up colours and the `+N` side indicator.
- [ ] Search box, Filter menu (learned / not learned / have materials / gives skill-ups / Season of Discovery), and favourites (star) all work.
- [ ] Details: hovering the result item shows its tooltip with stats. Reagents show have/need in green or red; bank items show "(Bank: n)".
- [ ] A reagent made by another recipe has a **+** that expands the tree ("Made by ...", who knows it).
- [ ] **Craft** with qty 1 crafts one. Qty 3 crafts three. **Craft All** crafts the maximum.
- [ ] With the profession not open (for example on the Camp tab first), Craft is greyed out and says "Open X to craft".
- [ ] **Open in default window** opens the default window on that recipe.
- [ ] **Shopping list** (this recipe ×qty) and **Pin** + **Shopping list (pinned)** list the missing reagents.

### 5. Bank
- [ ] Open the bank, then close it. Reagent counts in Tradebook now include bank items as "(Bank: n)".

### 6. Second character
- [ ] Log in on a second character and open one of their professions once.
- [ ] Tabs and badges now count both characters. On a tab only the first character has, the recipes show read-only with "Viewing X's saved recipes".
- [ ] The character picker (top left of the list) switches between characters who have that profession.
- [ ] The global search ("Who can craft...?") finds a recipe the first character knows and lists them. Clicking a result opens it.

### 7. Characters view
- [ ] **Characters** button: every character with class icon and colour, level, play type, last seen, professions with ranks, and missing-recipe counts. The summary line shows who is closest to the next rank in each profession.
- [ ] **Hide** a character: they disappear from tabs and search. Tick "Show hidden characters" to see them again, then **Show** them.
- [ ] **Delete** a character (confirm): their data is gone.
- [ ] A character not seen for 30+ days shows the stale warning (adjust the threshold in settings to test, e.g. 7 days).

### 8. Camp tab
- [ ] Lists each profession's Camping recipes (after the profession has been opened once), with materials coloured by whether you have them, who knows each recipe, and who can make it now.
- [ ] "By character" toggle switches to a list grouped by character.
- [ ] **Craft** on a camp recipe your character knows crafts it (with that profession open).

### 9. Greyed-out profession and Legacy
- [ ] Click a grey tab: a short guide (what it does, where to learn it, ranks).
- [ ] **Legacy** button: Professions perks with ranks and unspent points.

### 10. Persistence and settings
- [ ] `/reload`: window size, position, scale, favourites, pins and characters are kept.
- [ ] Settings: scale slider resizes the window; minimap toggle hides and shows the button.
- [ ] `/tb debug` prints diagnostics; turn it off again with `/tb debug`.
