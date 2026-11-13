# Tradebook spike — in-game checklist (about 15 minutes)

The spike addon "Tradebook Spike" is already linked into your AddOns folder. It saves everything to its SavedVariables, so you only need to do the steps and then **log out or `/reload`**. You don't need to copy anything. Notes in brackets are things I can't see in the data, so tell me what you saw.

Use a character with at least one crafting profession, near its materials. A second character with a different profession helps.

## A. Basics (any character)
1. Enable **Tradebook Spike** in the AddOns list. [Does its icon show in the AddOns list?][Yes]
2. Log in. After about 3 seconds chat says "probes saved".
3. `/tbs panel`. [The icon test row shows 3 squares: PNG(.png), PNG(no ext), TGA. Which show the icon, and which show magenta?][I only saw 2 icons and not highlighting]

## B. Recipes and unlearned recipes
4. Open a crafting profession the normal way (spellbook or Professions window). Chat says "scanned ...".
5. `/tbs unlearned` (turns on "show unlearned" in the default filter). Wait for the second "scanned" line.
6. Open a second profession if you have one.

## C. Crafting
7. `/tbs panel`. The recipe box is pre-filled with something you can make (or type a recipe ID).
8. Click **Craft (click)** with qty 1. [Did it craft?][No]
9. Set qty to 3 and click **Craft (click)**. [Did it craft 3 in a row?][No it did not make any]
10. Click **Craft (timer)**. This crafts 1 second after the click, with no key press. [Did it craft, or did you get an error or "blocked" popup?][It didnt craft but an error didn't show either]

## D. Replacing the default window
11. `/tbs mode alpha`. Open your profession with **each** of these, closing the spike panel between tries:
    - the Professions **key** (and the **micro-menu button**)
    - clicking the profession in the Professions window / spellbook
    - a **crafting station** (an anvil or forge for Blacksmithing, a cooking fire for Cooking)

    Each time: [Did the default window disappear and the spike panel appear? Could you click "through" the invisible window: hovering over where it was, do tooltips or highlights appear? Does ESC close things cleanly?][Spike panel appeared but I am not sure what you mean by click "through"]
12. With the spike panel up, click **Default UI**. [Did the normal window come back and work? Craft one item with the normal Create button.] Then **Back to spike**. [It did open the Default UI but the Default UI did not have a Back to spike button]
13. Close the spike panel with its X. [Did the hidden default window close too? Does the Professions key still open the normal window if you `/tbs mode off`?][not sure]
14. `/tbs mode scale`, open the profession once, and note the same things as step 11.
15. `/tbs mode hide`, open the profession once. (This one is expected to fail. It shows the trade skill closing.)
16. `/tbs mode off`. Press the Professions key (book page, no profession open), then `/tbs panel` → **OpenTradeSkill (click)**, then **OpenTradeSkill (timer)**, then **Cast profession (secure)**. [Which of the three opened your first profession?][click worked then secure. timer did not work.]
17. In the panel, type a recipe ID and click **Open in default**. [Did the default window open on that recipe?][yes]

## E. Bank
18. Visit a banker and open the bank. If the account bank tab is available, click it. Close the bank.

## F. Legacy and identity
19. If you've bought any Legacy profession perks, open the Legacy window (its key binding) once.
20. Tell me the **play type** of each character you tested (Normal / PvP / RP / RP-PvP).

## G. Second character
21. Log out to the character screen, log into another character, and repeat A-2, B-4 and E-18 if you can.

## Finish
22. **Log out (or `/reload`)** so the data is written. Then tell me you're done, with your notes in [brackets]. I'll read `TradebookSpikeDB.lua` and finish `docs/FEASIBILITY.md`.

Afterwards you can disable or delete the spike (`AddOns\TradebookSpike` is only a link; deleting it doesn't touch the project).
