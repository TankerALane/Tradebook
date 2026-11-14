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
## C. Drops, world drops, auction house (after `/reload`)
- [ ] Plans: Shining Mithril Helm (Blacksmithing): **Dropped by** Naga Explorer with zone and level; clicking sets a waypoint. No "Unknown source" under it.
- [ ] Pattern: White Leather Jerkin (Leatherworking): droppers show a chance with the sample, e.g. "11% (1 of 9)", and "(unconfirmed)" where only one source names the mob.
- [ ] A world-drop recipe (e.g. Pattern: Wicked Leather Gauntlets) says "World drop: mobs level X-Y".
- [ ] A Season of Discovery leftover (e.g. Schematic: Soul Vessel) says "Not available in WoW Forever."
- [ ] A recipe item that isn't soulbound shows **Auction house** with the recipe's icon and Auctionator's price (or "no recent price"); a soulbound one (e.g. a Merchant's Favor formula) doesn't.
- [ ] Recipes you already know also show their Source section.
- [ ] A recipe a vendor sells for gold (e.g. Recipe: Smoked Sagefish) shows **Vendor** with a price ("(before reputation discounts)" until you've opened that vendor, then "(seen at a vendor)") next to **Auction house**, and "cheaper" on the lower one. Merchant's Favor recipes show no gold vendor price.
- [ ] Kithas: open his window and check for Enchant Chest - **Lesser Mana** / Lesser Intellect (Tradebook records it either way).

## D. Filters
- [ ] Filter menu: **From a vendor** and **From a mob** sit indented under **From a recipe**. Ticking one also ticks From a recipe and Not learned; unticking From a recipe clears both.
- [ ] From a vendor shows only recipes sold by a vendor; From a mob only dropped ones; both ticked shows either (a recipe sold and dropped appears once).

## E. Vendor database
- [ ] Open a few vendors (any kind: food, reagents, the supply camp). Then type an item they sell in the search box (e.g. "thread", "water"): **Sold by vendors you've visited** lists it with the nearest vendor, price (or Merchant's Favor cost) and distance.
- [ ] Hovering the row shows the item tooltip and the vendor; clicking sets a waypoint to the vendor.

## F. Vendors tab and sharing (fully restart WoW: new files)
- [ ] A **Vendors** tab sits left of Legacy and Characters, with a 10px gap from the profession tabs.
- [ ] Type "thread": items list with the nearest vendor, price and distance; click one to expand the 5 nearest vendors; **See all** shows the rest; clicking a vendor sets a waypoint.
- [ ] The status line says how many vendors you've scanned, the community count, and Questie's item count (after a moment while it loads).
- [ ] Filter: **Zone** lists zones from the results; choosing one with an empty search lists everything sold there. **Paid with: Tokens** shows the supply camp recipes with their Merchant's Favor cost. **Data from** narrows to your scans / community / Questie.
- [ ] Questie vendors show "(base)" prices; vendors you've opened show real prices.
- [ ] **Share your scans** (or /tb share): a window with the share text selected and the GitHub form address. [Optional: paste it into the form to try it.]

## Notes / errors

