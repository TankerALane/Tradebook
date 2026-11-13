# Testing — round 3

What's still open after round 2: the three fixes, plus everything that needs another character or wasn't checked yet. Tick `[X]` and add notes in `[brackets]`. Turn on error display (BugSack, or `/console scriptErrors 1`), `/reload`, and paste any Lua error text at the bottom.

## A. Fixes from round 2 (any character)
- [X] **Open in default window, profession already open**: open Tailoring (or any profession) in Tradebook, pick a recipe, click **Open in default window**. The default window shows with that recipe selected.
- [X] **Open in default window, profession not open**: go to the Camp tab, click a recipe from a profession that isn't open, then **Open in default window**. The default window opens that profession on that recipe.
- [X] **Star on a recipe row**: clicking the small star on a row removes the star (tooltip: "Starred (click to remove the star)"), and the recipe leaves the Starred section.
- [X] **X in combat**: open Tradebook, get into combat (a training dummy or any mob), click the X at the top right. Tradebook closes. After combat, open a profession normally: no stray default window is left open.
- [X] **ESC in combat**: same as above, using ESC instead of the X.

## B. Materials (needs a second character with some materials)
- [X] A material's tooltip shows Bags and Bank, then, after a blank line, other characters who have it (first name: count).

## C. Alt recipes without opening the profession (quick scan)
- [X] Log in on a character whose professions you **haven't opened yet**. Wait a few seconds, then open Tradebook **without opening the profession**. Its tab already lists its learned recipes, with the note "Recipes found in the spellbook...".
- [X] `/tb debug` shows "quick scan added N recipes" (note N here). Turn debug off again with `/tb debug`.
- [X] Opening that profession once replaces the list with the full one (categories and unlearned recipes).

## D. Characters view
- [X] Left column **"Next rank-up"**: one block per profession, stacked, showing who is closest and to what rank (for example "Ana 145/150 (5 to go), then Expert", or "ready to train Expert").

## E. Regression check
- [X] Professions key, micro button and spellbook still open Tradebook. ESC closes it in one press (out of combat).
- [X] Craft qty 1 / qty 3 / Craft All still work.
- [X] `/reload` keeps size, position, scale, stars, pins and characters.

## F. Skill-up and material colours (any character)
- [X] **Gloves of Meditation** (Tailoring 115): the Skill-up section reads **orange until 125 / yellow until 140 / green until 155**, each line in its colour.
- [X] A **yellow** recipe starts at "yellow until …"; a **green** one shows only "green until …"; a **grey** one shows no Skill-up section.
- [X] Recipe colours in Tradebook's list match the default window (compare a few with **Default UI**).
- [X] Material names in a recipe's details are **white** when you have enough in your bags, **red** only when you're short.

## Lua errors
[paste here]

## Anything else
[notes]
