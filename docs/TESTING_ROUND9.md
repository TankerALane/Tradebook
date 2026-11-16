# Testing — round 9: before v1.0.0

Fully restart WoW first. Tick `[X]` what works and write anything odd under the item or in
**Notes / errors** at the bottom. Notes in brackets are things I can't see in the data.

## A. Profit section in recipe details (needs Auctionator)
- [ ] A recipe with auction prices for all its materials: under **Cost** (Cost to craft, Sells at auction), a **Profit** header with **Auction** and **Vendor**, green when positive, red when negative.
- [ ] Forceful Medium Armor Kit (or any item vendors won't buy): **Vendor** says "won't sell" in grey.
- [ ] An enchant (makes no item): no Profit section.
- [ ] A recipe with a material that has no price: Cost shows "N materials without a price" and there is no Profit section.
- [ ] Changing the quantity next to Craft: the Profit numbers change with it. [Did they?]

## B. Clean install
Exit WoW, rename `WTF\Account\<account>\SavedVariables\Tradebook.lua` to `Tradebook.lua.bak`, log in. Afterwards put it back (delete the new one first) to keep your data.
- [ ] No Lua errors at login. The minimap button is there.
- [ ] `/tb` opens the window. Your professions' tabs are gold and show recipes without opening the profession first.
- [ ] Opening a profession: Tradebook replaces the default window; **Default UI** switches back; **Tradebook** on the default window switches again.
- [ ] Settings (`/tb options`) show the defaults: sharing ticked, profit Off in the recipe list's Filter menu.
- [ ] Log a second character: both show in the Characters tab.

## C. Without Auctionator and Questie
Turn both off at the character select screen (AddOns button), log in.
- [ ] No Lua errors when opening every tab and a few recipes.
- [ ] Recipe details: no Cost or Profit section. The recipe list's Filter menu offers profit Off and Selling to a vendor only.
- [ ] Selling to a vendor still shows profits where every material has a known vendor price (thread, vials...). [Which recipes showed one?]
- [ ] Vendors tab works with the community data only (no "Questie" vendors).
- [ ] Turn them back on afterwards.

## D. Upgrading from an old version
Only if you still have an old SavedVariables file (from 0.1–0.3), e.g. a backup. Skip otherwise.
- [ ] Copy it in place of `Tradebook.lua` (keep your current one as a backup), log in: no errors, characters, scale, pinned and starred recipes are kept.
- [ ] Put your current file back.

## E. Alliance character
- [ ] A supply camp recipe (Azeroth Commerce Authority, Redridge): its Merchant's Favor cost and the reputation needed show, for the Alliance camp.
- [ ] **No Merchant's Favor** hides those recipes on the Alliance character too.
- [ ] Vendors tab with **Only friendly vendors**: no Horde vendors.
- [ ] Train the next rank: the nearest trainers are Alliance ones.

## F. High skill (225–300)
Only if a character is that high.
- [ ] Train Artisan button and window at 200+ skill: requirements, cost and trainers look right.
- [ ] Leveling plan near the cap: steps, materials and cost look sensible.
- [ ] Skill-up colours at the top match the default window (orange / yellow / green / grey).

## G. Window size and scale
- [ ] Settings scale at the smallest: window narrow and wide, every tab, nothing overlaps.
- [ ] Scale at the largest: same.
- [ ] Put the scale back.

## H. Combat
- [ ] Open Tradebook, enter combat: no "blocked action" or taint errors. After combat, Craft and Find Herbs/Minerals work.
- [ ] Craft All, then get pulled into combat: crafting stops cleanly, no errors.

## I. Sharing with another player (when you can)
- [ ] A friend with Tradebook (0.4.0 or newer): after you open a vendor, their `/tb net` shows "NPC reports heard from 1 players", and your vendor shows in their Vendors tab as "(unconfirmed)".
- [ ] They open one: you hear theirs the same way.

## J. Page and listing
- [ ] `/tb shots` again for pictures 11–13 (profit column, narrow window, Profit section). [Tell me when they're taken.]
- [ ] CurseForge description pasted from `docs/CURSEFORGE_DESCRIPTION.md`.

## K. Your call
- [ ] Skill bar end gap: leave it / try again. [Which?]
- [ ] Anything else that must be in 1.0? [List here]

## For me (no testing needed)
- v1.0.0 CHANGELOG entry with a short summary of what Tradebook does.
- `.toc`, README and CurseForge description: no leftover "beta" wording, right game version.
- Check that a tag without `-beta` goes to CurseForge as a Release.
- A last "import npc data" before tagging.

## Notes / errors
