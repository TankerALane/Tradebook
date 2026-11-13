# Testing — round 4

Everything changed since round 3. Tick `[X]` and add notes in `[brackets]`; paste any Lua error text at the bottom.

**First: fully restart WoW** (not just `/reload`). The TOC file was renamed (`Tradebook_Camelot.toc`) and new files were added; the game only picks those up on a restart. Turn on error display (BugSack, or `/console scriptErrors 1`).

## A. Still loads after the TOC rename
- [ ] Tradebook appears in the AddOns list (one entry, with its icon) and loads with no errors.
- [ ] Your characters, stars, pins and settings are all still there.

## B. Where to get materials (needs Questie)
- [ ] `/tb debug` shows `questie=true` and a position like `map 1453 continent 0 (...)`. Note what it says here. Turn debug off again.
- [ ] Open a recipe that uses a **vendor** material (thread, vials, flux, salt…). Its row has a **+**. Expand it: **Sold by** lists up to 3 vendors friendly to your faction, nearest first, with zone, coordinates and distance. [Are they really the nearest?]
- [ ] A **dropped** material (cloth, leather…) shows **Dropped by** with mob levels; an ore or herb shows **Gathered from**.
- [ ] For a material that is also **crafted**, the **Made by** lines come first, then Sold by / Dropped by / Gathered from.
- [ ] **Click a vendor line**: a TomTom arrow appears (or the game's map pin), and chat says "Waypoint set: …".
- [ ] Hovering a vendor material's icon/name shows **Sold by** with the nearest vendors in the tooltip.
- [ ] In a dungeon (position unknown), the section says vendors are listed by name instead.

## C. Layout changes (any character)
- [ ] **Skill bar** in the header (between the "Who can craft…?" search and the Legacy button) reads e.g. **Tailoring 115 / 150** with a blue fill; hidden on Camp, Characters, search, Legacy and grey tabs.
- [ ] **Friends (N)** button sits on the same row as the character picker; hovering lists friends in aligned columns (name | rank | ago).
- [ ] On a **grey tab**, friends are listed in aligned columns under the guide text.
- [ ] Section headers show their count next to the name, e.g. **Robes and Vests (65)**.
- [ ] **Material icons** are bigger with the gold slot frame (and the result icon at the top too); icons line up whether or not a row has a **+**.
- [ ] **Filter**: no Season of Discovery option; Orange/Yellow/Green sit indented under "Gives skill-ups"; a **red X** appears on the Filter button when filters are changed, and clicking it resets them.
- [ ] Hovering the **Camp** tab (and short tabs like Mining) highlights normally.

## D. Screenshots
- [ ] `/tb fake`: the window shows four made-up characters (Aldric, Mirelle, Thornick, Sefaria Fernhollow) and "(made-up data)" in the title; Craft is disabled. `/tb fake` again (or `/reload`) brings back your real characters, unchanged.
- [ ] `/tb shots`: takes 8 screenshots (don't move the mouse over the window), then puts your view back. Chat says "Done: 8 screenshots…".
- [ ] `/reload`, then tell me — I'll run the crop script and check the pictures (or run `python -I scripts/crop_shots.py "E:\Blizzard\World of Warcraft\_forever_"` yourself).

## E. Quick regression
- [ ] Professions key, spellbook and minimap still open Tradebook; ESC closes it; Default UI and the Tradebook button work.
- [ ] Craft qty 1 / Craft All still work.

## Lua errors
[paste here]

## Anything else
[notes]
