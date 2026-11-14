# Testing — round 7: recipe vendors

Tick `[X]` and add notes in `[brackets]`; paste any Lua error text at the bottom.

**First: fully restart WoW** (new files `Data\RecipeVendors.lua`, `Data\RecipeItems.lua`, `Core\Merchants.lua`).

## A. Checked vendor data
Pick recipes you haven't learned and look at **Source** in the details pane.
- [X] Enchant Chest - Lesser Intellect: no Kithas; "No vendor is known to sell this in WoW Forever."
- [X] Dig Rat Stew (Cooking): "Quest: Dig Rat Stew", no vendor. [It shows Quest: #862]
- [ ] Pattern: Spitfire Bracers or Plans: Ironvine Belt: "The recipe doesn't seem to be in WoW Forever yet."
- [ ] Brilliant Smallfish (Cooking): Nyalah Brightfire is listed; clicking her sets a waypoint. [How do I see vendor location on recipes I already know.]
- [ ] A Lokhtos Darkbargainer pattern shows "Vendor (unconfirmed)" and "(Vendor, unconfirmed)" in Learn from.

## B. Vendor windows
- [X] Open a recipe vendor (e.g. Kithas in Orgrimmar, or any cooking/tailoring supplier). Close it. A recipe it sells now lists that vendor as a normal (confirmed) vendor.
- [ ] A recipe that vendor sells with limited stock (a number on the icon) shows "(limited supply)" / "(Vendor, limited supply)". [didnt run into one]
- [ ] A vendor the data lists for a recipe, but whose window didn't have it, shows "(not in stock when you visited)".
- [X] `/tb debug` (twice, to turn it off again) prints "Vendors read: N" and any recipe a vendor sold that the data didn't list.
- [X] [Any vendor that sells a recipe Tradebook didn't know about? Name and recipe:] [Not sure]
## Notes / errors

