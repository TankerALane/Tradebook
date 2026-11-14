# Testing — round 5

Auctionator prices, plus the features added since round 4. Tick `[X]` and add notes in `[brackets]`; paste any Lua error text at the bottom.

**First: fully restart WoW** (not just `/reload`): a new file was added (`Core\Prices.lua`). Keep error display on (BugSack, or `/console scriptErrors 1`).

## A. Auctionator prices
Before you start, scan the auction house once with Auctionator (Auctionator's "Full Scan", or search for a few materials), and open a vendor that sells thread or vials so Auctionator records its prices.

- [ ] `/tb debug` shows `Auctionator API v1 found`. Turn debug off again.
- [ ] Hover a **material's name** in recipe details: the tooltip has a gold **Purchase from:** line with **Auction: …** (with "(N days old)" when the price is old) and/or **Vendor: …** indented under it. A material with no price says "No price yet…". Hovering the **icon** still shows the item's own tooltip (its sell price).
- [ ] Recipe details have a **Cost** section under Materials: **Cost to craft** (the materials at their cheapest price, vendor or auction).
- [ ] Changing the **quantity** next to Craft changes the cost.
- [ ] If the result has an auction price: **Sells for (after the auction house cut)** and **Profit** (green, or red for a loss). [Do the numbers look right?]
- [ ] A recipe where some materials have no price shows "N materials without a price" and no Profit line.
- [ ] **Shopping list** (one recipe, and pinned): the bottom shows **Cost: …** for the missing items and a **Send to Auctionator** button.
- [ ] Click **Send to Auctionator**: chat says "Sent N items to the Auctionator shopping list "Tradebook"". At the auction house, Auctionator's Shopping tab has a **Tradebook** list with those items and amounts, and searching it works.
- [ ] Sending again replaces the list (no duplicates).
- [ ] With Auctionator **disabled** (AddOns list, then restart): no Cost section, no price lines, no Send button, no errors.

## B. Not learned filters (from round 4 additions)
- [ ] Filter, **Not learned**: the sub-options **Learnable now**, **From a trainer**, **From a recipe** and **Nearest first** (with Questie) are indented under it.
- [ ] **Learnable now** keeps only unlearned recipes your rank is high enough for.
- [ ] **From a trainer** / **From a recipe** keep only those kinds (ticking both shows both).
- [ ] **Nearest first** adds a section at the top with unlearned recipes sorted by distance to their nearest trainer or vendor, distance shown on the right.

## C. Target and mark (needs Questie)
- [ ] Click a nearby vendor or trainer line: it's targeted, marked with a **purple diamond**, and the waypoint is set.
- [ ] Click it again: the diamond stays.
- [ ] Click a far-away one: waypoint only, nothing marked.
- [ ] In combat: clicking sets the waypoint only, and the X still closes the window.

## Notes / errors

