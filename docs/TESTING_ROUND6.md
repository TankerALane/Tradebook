# Testing — round 6: leveling plan

Tick `[X]` and add notes in `[brackets]`; paste any Lua error text at the bottom.

**First: fully restart WoW** (new files `Core\Planner.lua` and `UI\Planner.lua`). Have Auctionator prices from a recent scan if you can.

## A. Opening it
- [ ] Click the skill bar on a profession that's below its cap: the rank window has a gold **Leveling plan to N** line near the top. Click it: the **Leveling plan** window opens (drag to move, Escape closes). Clicking the line again closes it.
- [ ] At the cap (e.g. 75/75), the line isn't there (the planner window would say "train the next rank first").

## B. The plan
- [ ] It says "<Name>: <Profession> 131 to 150", then **Steps** with the total cost on the right.
- [ ] Each step reads "131-137  craft about 9 x <Recipe>" with the recipe's result icon and its cost. Clicking a step opens that recipe in Tradebook.
- [ ] Recipes you'd learn first say "(learn from a trainer)". Untick **Include trainer recipes not learned yet**: only known recipes are used (the plan may stop early: "No recipe gives skill-ups from N").
- [ ] Untick **Use materials in my bags and bank first**: the cost goes up (owned materials are no longer free) and the plan may change.
- [ ] **Materials**: every material with "need N, have M" and a red "buy X" when short.
- [ ] Without Auctionator: a note says recipes are picked by the fewest materials to buy, and no costs are shown.
- [ ] [Does the plan make sense for one of your characters? Which recipes would you have picked instead?]

## C. Shopping list
- [ ] **Shopping list** at the bottom opens the shopping list for the whole plan (minus what you have), with its cost and **Send to Auctionator**.

## Notes / errors

