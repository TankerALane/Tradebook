# Testing — round 6: leveling plan

Tick `[X]` and add notes in `[brackets]`; paste any Lua error text at the bottom.

**First: fully restart WoW** (new files `Core\Planner.lua` and `UI\Planner.lua`). Have Auctionator prices from a recent scan if you can.

## A. Opening it
- [X] On a profession tab, the **Leveling plan** button sits to the left of the skill bar. Click it: the **Leveling plan** window opens (drag to move, Escape closes). Clicking the button again closes it.
- [X] Clicking the skill bar itself opens only the rank window (where to train, requirements, specializations), with no leveling plan in it.
- [X] At the cap (e.g. 75/75), the planner says "train the next rank first". [No planner is shown at max level since it was removed from the Skill bar]

## B. The plan
- [X] It says "<Name>: <Profession> 131 to 150", then **Steps** with the total cost on the right.
- [X] Each step reads "131-137  craft about 9 x <Recipe>" with the recipe's result icon and its cost. Clicking a step opens that recipe in Tradebook.
- [X] Recipes you'd learn first say "(learn from a trainer)". Untick **Include trainer recipes not learned yet**: only known recipes are used (the plan may stop early: "No recipe gives skill-ups from N").
- [X] Untick **Use materials in my bags and bank first**: the cost goes up (owned materials are no longer free) and the plan may change.
- [X] **Materials**: every material with "need N, have M" and a red "buy X" when short.
- [X] Without Auctionator: a note says recipes are picked by the fewest materials to buy, and no costs are shown. [It should still shown a path for materials I do have if they can make the item.}
- [X] [Does the plan make sense for one of your characters? Which recipes would you have picked instead?]

## C. Shopping list
- [X] **Shopping list** at the bottom opens the shopping list for the whole plan (minus what you have), with its cost and **Send to Auctionator**. [Shopping List in general should be split by things you can buy from Vendors and things you need to buy from the Auction house. It should also show the purchase price from each.]

## Notes / errors

