# Testing — round 2

Covers everything changed since round 1. Tick `[X]` and add notes in `[brackets]` after any item, like last time.
Turn on error display first (BugSack, or `/console scriptErrors 1`), `/reload`, and paste any Lua error text at the bottom.

## 1. Window and tabs
- [X] At the default size, all tabs fit inside the window with a small gap and no overlap. Long names may end in "...", and hovering a tab shows its full name.
- [X] Tab order: Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking, First Aid, Fishing, Herbalism, Mining, Skinning, Camp.
- [X] At scale 1.0 the window looks the same size as your old 1.25. The Settings slider goes from 0.6 to 1.4.
- [X] Settings → untick "Show gathering profession tabs": Herbalism, Mining and Skinning tabs disappear. Their characters still show in Characters and in search. Tick it again: the tabs come back on the right.

## 2. Default window
- [X] **Default UI**: the normal Professions window looks right. Create, Create All and the quantity box sit inside their boxes.
- [Xs] The **Tradebook** button is visible on the default window and switches back to Tradebook.
- [ ] **Open in default window** opens the default window on that recipe every time, including for a profession that wasn't open. [No it does not]
- [X] **Open in default window** is greyed out for recipes from a profession this character doesn't have.

## 3. Recipe list: Starred and Pinned
- [X] Starred recipes appear in a **Starred** section at the very top, and still in their own category.
- [X] Pinned recipes appear in a **Pinned** section under Starred, with a gold pin icon on the row.
- [X] Clicking a row's pin icon unpins it. The Pin/Unpin button in the details moves the recipe in or out of Pinned straight away. [Can we make the star do the same thing if you click the star unstar it]
- [X] In the details, the star is on the far right with Pin to its left. They don't overlap.

## 4. Open → Craft
- [X] Go to the Camp tab first, then click a recipe from a profession that isn't open. The details button reads **"Open <profession>"**. One click opens it, and the button then reads **Craft** and crafts.
- [X] On the Camp tab, a recipe you know reads **"Open <profession>"** when that profession isn't open and you have the materials. Clicking it opens the profession, then it reads **Craft** and crafts.

## 5. Materials
- [ ] A material's tooltip shows Bags and Bank, then other characters who have it (first name: count).
- [X] No "account bank" text anywhere.

## 6. Alt recipes without opening the profession (quick scan)
- [ ] Log in on a character whose professions you **haven't opened yet**. Wait a few seconds, then open Tradebook **without opening the profession**. Its tab already lists its learned recipes, with the note "Recipes found in the spellbook...".
- [ ] `/tb debug` shows "quick scan added N recipes" (note N here). Turn debug off again.
- [ ] Opening that profession once replaces the list with the full one (categories and unlearned recipes).

## 7. Characters view
- [ ] Left column **"Next rank-up"**: one block per profession, stacked, showing who is closest and to what rank (for example "Ana 145/150 (5 to go), then Expert", or "ready to train Expert").

## 8. Quick regression check
- [ ] Professions key, micro button and spellbook still open Tradebook. ESC closes it in one press.
- [ ] Craft qty 1 / qty 3 / Craft All still work.
- [ ] `/reload` keeps size, position, scale, stars, pins and characters.

## Lua errors
[paste here]

## Anything else
[notes]

[When in combat the X in the top right does not close Tradebook]