# Testing — round 9: before v1.0.0

Fully restart WoW first. Tick `[X]` what works and write anything odd under the item or in
**Notes / errors** at the bottom. Notes in brackets are things I can't see in the data.

## A. Profit section in recipe details (needs Auctionator)
- [X] A recipe with auction prices for all its materials: under **Cost** (Cost to craft, Sells at auction), a **Profit** header with **Auction** and **Vendor**, green when positive, red when negative.
- [X] Forceful Medium Armor Kit (or any item vendors won't buy): **Vendor** says "won't sell" in grey.
- [X] An enchant (makes no item): no Profit section.
- [X] A recipe with a material that has no price: Cost shows "N materials without a price" and there is no Profit section.
- [X] Changing the quantity next to Craft: the Profit numbers change with it. [Did they?]

## B. Clean install
Exit WoW, rename `WTF\Account\<account>\SavedVariables\Tradebook.lua` to `Tradebook.lua.bak`, log in. Afterwards put it back (delete the new one first) to keep your data.
- [X] No Lua errors at login. The minimap button is there.
- [X] `/tb` opens the window. Your professions' tabs are gold and show recipes without opening the profession first.
- [X] Opening a profession: Tradebook replaces the default window; **Default UI** switches back; **Tradebook** on the default window switches again.
- [X] Settings (`/tb options`) show the defaults: sharing ticked, profit Off in the recipe list's Filter menu.
- [X] Log a second character: both show in the Characters tab.

## C. Without Auctionator and Questie
Turn both off at the character select screen (AddOns button), log in.
- [X] No Lua errors when opening every tab and a few recipes.
- [X] Recipe details: no Cost or Profit section. The recipe list's Filter menu offers profit Off and Selling to a vendor only.
- [X] Selling to a vendor still shows profits where every material has a known vendor price (thread, vials...). [Which recipes showed one?]
- [X] Vendors tab works with the community data only (no "Questie" vendors).
- [X] Turn them back on afterwards.

## D. Upgrading from an old version
Only if you still have an old SavedVariables file (from 0.1–0.3), e.g. a backup. Skip otherwise.
- [X] Copy it in place of `Tradebook.lua` (keep your current one as a backup), log in: no errors, characters, scale, pinned and starred recipes are kept.
- [X] Put your current file back.

## E. Alliance character
- [X] A supply camp recipe (Azeroth Commerce Authority, Redridge): its Merchant's Favor cost and the reputation needed show, for the Alliance camp.
- [X] **No Merchant's Favor** hides those recipes on the Alliance character too.
- [X] Vendors tab with **Only friendly vendors**: no Horde vendors.
- [X] Train the next rank: the nearest trainers are Alliance ones.

## F. High skill (225–300) [These are not test as I do not have access  to this with me or my friends characters. We will leave as good for now and will be okay for v1.0.0]
Only if a character is that high.
- [ ] Train Artisan button and window at 200+ skill: requirements, cost and trainers look right.
- [ ] Leveling plan near the cap: steps, materials and cost look sensible.
- [ ] Skill-up colours at the top match the default window (orange / yellow / green / grey).

## G. Window size and scale
- [X] Settings scale at the smallest: window narrow and wide, every tab, nothing overlaps.
- [X] Scale at the largest: same.
- [X] Put the scale back.

## H. Combat
- [X] Open Tradebook, enter combat: no "blocked action" or taint errors. After combat, Craft and Find Herbs/Minerals work.
- [X] Craft All, then get pulled into combat: crafting stops cleanly, no errors.[Crafting kept going with no errors until I stopped it to attack]

## I. Sharing with another player (when you can) [Theirs came to me I am going to assume it goes both ways since we are using the same addon]
- [ ] A friend with Tradebook (0.4.0 or newer): after you open a vendor, their `/tb net` shows "NPC reports heard from 1 players", and your vendor shows in their Vendors tab as "(unconfirmed)".
- [ ] They open one: you hear theirs the same way.

## J. Page and listing
- [X] `/tb shots` again for pictures 11–13 (profit column, narrow window, Profit section). [Tell me when they're taken.] [These have been take]
- [X] CurseForge description pasted from `docs/CURSEFORGE_DESCRIPTION.md`. [This has been updated.]

## K. Your call
- [X] Skill bar end gap: leave it / try again. [Which?] The small gap is fine
- [X] Anything else that must be in 1.0? [List here]

## For me (no testing needed)
- v1.0.0 CHANGELOG entry with a short summary of what Tradebook does.
- `.toc`, README and CurseForge description: no leftover "beta" wording, right game version.
- Check that a tag without `-beta` goes to CurseForge as a Release.
- A last "import npc data" before tagging.

## Notes / errors
