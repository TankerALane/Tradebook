# Testing — round 5

Auctionator prices, plus the features added since round 4. Tick `[X]` and add notes in `[brackets]`; paste any Lua error text at the bottom.

**First: fully restart WoW** (not just `/reload`): a new file was added (`Core\Prices.lua`). Keep error display on (BugSack, or `/console scriptErrors 1`).

## A. Auctionator prices
Before you start, scan the auction house once with Auctionator (Auctionator's "Full Scan", or search for a few materials), and open a vendor that sells thread or vials so Auctionator records its prices.

- [X] `/tb debug` shows `Auctionator API v1 found`. Turn debug off again.
- [X] Hover a **material's name** in recipe details: the tooltip has a gold **Purchase from:** line with **Auction: …** (with "(N days old)" when the price is old) and/or **Vendor: …** indented under it. A material with no price says "No price yet…". Hovering the **icon** still shows the item's own tooltip (its sell price).
- [X] Recipe details have a **Cost** section under Materials: **Cost to craft** (the materials at their cheapest price, vendor or auction).
- [X] Changing the **quantity** next to Craft changes the cost.
- [X] If the result has an auction price: **Sells for (after the auction house cut)** and **Profit** (green, or red for a loss). [Do the numbers look right?]
- [X] A recipe where some materials have no price shows "N materials without a price" and no Profit line.
- [X] **Shopping list** (one recipe, and pinned): the bottom shows **Cost: …** for the missing items and a **Send to Auctionator** button.
- [X] Click **Send to Auctionator**: chat says "Sent N items to the Auctionator shopping list "Tradebook"". At the auction house, Auctionator's Shopping tab has a **Tradebook** list with those items and amounts, and searching it works.
- [X] Sending again replaces the list (no duplicates).
- [X] With Auctionator **disabled** (AddOns list, then restart): no Cost section, no price lines, no Send button, no errors.

## B. Not learned filters (from round 4 additions)
- [X] Filter, **Not learned**: the sub-options **Learnable now**, **From a trainer**, **From a recipe** and **Nearest first** (with Questie) are indented under it.
- [X] **Learnable now** keeps only unlearned recipes your rank is high enough for.
- [X] **From a trainer** / **From a recipe** keep only those kinds (ticking both shows both).
- [X] **Nearest first** adds a section at the top with unlearned recipes sorted by distance to their nearest trainer or vendor, distance shown on the right.

## C. Target and mark (needs Questie)
- [X] Click a nearby vendor or trainer line: it's targeted, marked with a **purple diamond**, and the waypoint is set.
- [X] Click it again: the diamond stays.
- [X] Click a far-away one: waypoint only, nothing marked.
- [X] In combat: clicking sets the waypoint only, and the X still closes the window.

## D. Train the next rank
Find a character whose skill is at 50+ with a cap of 75, 125+ with 150, or 200+ with 225 (`/tb fake` has Mirelle at Cooking 75/75).

- [X] The profession's skill bar shows a **Train Journeyman / Expert / Artisan** button at its right end. It's not there below the threshold, or after training (cap went up).
- [X] Click it: a **Train <rank> <profession>** window opens (drag to move, Escape closes). It says what it raises the cap to.
- [X] **Requirements**: skill and level, with "You: N" in green or red.
- [X] **Training cost** (trainer ranks: 5s / 1g / 5g, marked "classic price, unconfirmed") or **Book cost** (Expert Cooking/Fishing/First Aid), with your gold in green or red on the character you're on. [What did the trainer actually charge?]
- [X] A crafting profession (e.g. Tailoring) lists the **nearest trainers** for that rank with distance; clicking one sets a waypoint (and targets and marks it nearby). [Are they really trainers who teach that rank?]
- [X] **Expert Cooking / Fishing / First Aid**: shows the **book** (icon, requirements, which characters have one), its auction/vendor price, and the nearest vendors that sell it.
- [X] **Artisan Fishing / First Aid**: shows the **quest** (name, level, reputation if any, prerequisite quests with Done/Not done) and the quest giver's location.
- [X] Viewing an **alt's** profession shows the button for that alt (their level and skill in the checks).
- [X] Herbalism / Skinning / Mining show trainers too. [Any missing?]

## E. Could learn it
- [X] Open a recipe none of your characters know but one has the profession: under **Who can craft this** there's **Could learn it:** with the character, their skill, and "Learnable now" (green), "N more skill (X)" (gold) or "Train <rank> first (X)" (red).
- [X] **Who can craft…?** search: such recipes say "<Name> could learn it: …" instead of "No saved character knows this."

## F. Browse a profession nobody has
- [X] On a **grey tab** (e.g. Engineering), the guide page has a **Show all recipes** button at the top right (not on Herbalism or Skinning).
- [X] Click it: the tab shows the recipe list, with the note "None of your characters have Engineering. Showing all its recipes." and a **Back to the guide** button. [How long did it take the first time?]
- [X] Recipes are grouped into their categories, with names and icons (some may show item:123 for a moment, then fill in).
- [X] **Search** works. Selecting a recipe shows its materials (with your bag counts), the Cost section (Auctionator), Sold by / where to get each material, and where to learn the recipe.
- [X] Craft buttons are disabled; filters don't hide anything here.
- [X] Switch tabs and come back: still showing the list. **Back to the guide** returns to the guide page.

## G. Trainers remember what they teach
Needs a **full WoW restart** (new file `Core\Trainers.lua`).

- [X] Talk to a profession trainer (e.g. Eunice Burch) and open the training window. Nothing looks different, and your trainer filters (Available / Unavailable / Used) are the same as before. With `/tb debug` on, chat prints `trainer <id> <name> skill <id> ranks ...`. [Paste that line here.][Tradebook debug: trainer 4552 Eunuce Burch skill 185 ranks Journeyman,Apprentice]
- [X] Close it, `/reload`, and tell me: I'll read what was saved (every service the trainer lists, with level, skill and cost).
- [X] Open the rank-up window for that profession: trainers whose window you opened say **(teaches it)**, and ones that don't teach the rank are gone. The training cost is the real one (no "classic price").[I think this is gone because of the deep internet search you did]

## H. Specializations and the clickable skill bar
The **skill bar** is the blue progress bar at the top of the window on a profession tab (between the "Who can craft…?" search and the Legacy button), e.g. **Tailoring 131 / 150**.

- [ ] Click anywhere on that blue bar (not just the Train button): the rank window opens even when no rank is ready (it says "has trained every rank" at 300). Hover the bar: the tooltip ends with "Click for how to train the next rank and specializations."
- [ ] **Leatherworking** (`/tb fake`, pick Thornick on the Leatherworking tab, click his bar): a **Specialization** section with Dragonscale, Elemental and Tribal, each with its quest (name, requirements, "Then: next quest", quest giver with waypoint), or "Its quest isn't in Questie's database." [Do the quests and givers look right?]
- [ ] **Engineering** (only if one of your characters has it): level 30 / Engineering 200 checks, then Gnomish and Goblin Engineering with their quests. Skip if none of your characters has Engineering.
- [ ] A character who already has a specialization shows "<Name> is a Goblin Engineer..." instead. [Log in on one if you have one.]
- [ ] Blacksmithing and Tailoring show no Specialization section.

## Notes / errors

