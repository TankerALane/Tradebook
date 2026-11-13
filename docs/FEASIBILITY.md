# Tradebook — Phase 0 feasibility

Status: **Phase 0 complete (2026-11-13).** Source review plus two in-game spike runs on two Normal play-type characters.

Labels: **Source** = Blizzard UI code for this exact build. **In game** = the Tradebook spike (`TradebookSpikeDB`) or your Fellowship Ledger `/fl verify` report. **Pending** = still to test.

## Evidence used

| Source | What it is |
|---|---|
| Installed client | WoW Forever install, product `wowf`, build **1.60.1.70938** |
| Blizzard UI source | `Gethe/wow-ui-source`, branch `forever`, `1.60.1 (70938)`. Read only, nothing copied. |
| Tradebook spike | `spikes/TradebookSpike`, results in `WTF/.../SavedVariables/TradebookSpike.lua` |
| Fellowship Ledger verify | Your addon's `/fl verify` report, build 70938 |

## Client facts

- **Interface `16001`**, game type `camelot`, `WOW_PROJECT_ID = 18`. TOC pattern `Tradebook_Forever.toc` plus a fallback `Tradebook.toc`.
- Modern UI with Forever overrides. Classic globals (`GetItemInfo`, `GetItemCount`, `GetSpellInfo`, `GetSkillLineInfo`) are nil; use `C_Item`, `C_Spell`, `C_TradeSkillUI`.
- Active game rules include **`CraftFromBankRestricted`**: reagents in the bank can't be used to craft. Tradebook should show bank reagents as "in bank: fetch first", not as available.

## 1. Replacing the default Professions frame — **works** (approach: keep it open, invisible)

- Every open path (key, micro button, spellbook, crafting station) shows `ProfessionsFrame` and fires `EventRegistry "ProfessionsFrame.Show"`. **In game:** confirmed for all paths. The key/micro button opens the *book page* with no profession open.
- **In game:** hiding the default frame (`mode hide`) immediately closes the trade skill (`TRADE_SKILL_CLOSE`, `ready=false`). As predicted from source, Tradebook must not hide it.
- **In game:** `mode alpha` (default frame set to alpha 0 and left open) kept the trade skill open; the spike panel appeared every time; closing the panel closed the hidden frame and the trade skill cleanly. "Default UI" restored the normal window with the profession still open. No `ADDON_ACTION_BLOCKED` from any of this.
- **Decision:** Tradebook uses the alpha approach. The default frame stays open at alpha 0 behind Tradebook. Tradebook also stops it taking mouse input (see the open point below). "Default UI" restores alpha; the "Tradebook" button on the default frame (Phase 1 feature, not in the spike) switches back.
- **Open point:** a frame at alpha 0 can still catch mouse clicks and tooltips. Tradebook will sit on top of it at a higher frame strata, and I'll check this in the Phase 1 test pass.

## 2. Crafting — **works from a click**

- **Source:** `C_TradeSkillUI.CraftRecipe` has no restriction flag, and Blizzard's Create button calls it from plain Lua.
- **In game (retest):** with Enchanting open behind the spike panel, `CraftRecipe(id, 1)` and `CraftRecipe(id, 2)` from a button click crafted 1 and 2 Enchanted Lutes (`TRADE_SKILL_CRAFT_BEGIN` → `TRADE_SKILL_ITEM_CRAFTED_RESULT` per item → `UPDATE_TRADESKILL_CAST_STOPPED`). No taint.
- **In game:** the same call from a timer (no hardware event) is **blocked** (`ADDON_ACTION_BLOCKED`).
- **In game:** with **no profession open**, `CraftRecipe` does nothing and gives no error. Tradebook must check `IsTradeSkillReady()` and that the right profession is open, and grey out Craft otherwise.
- **Design rules:** Craft, Craft All and the quantity box each make exactly one `CraftRecipe(id, n)` call inside the click handler. No queues or delayed crafts. Craft All = `GetCraftableCount`.
- Fallback (not needed): "Open in default window" via `C_TradeSkillUI.OpenRecipe(recipeID)`, verified working.

## 3. Current character's professions and recipes — **works**

- **In game:** `GetProfessions` / `GetProfessionInfo` give name, rank, max and skill line for primary and secondary professions (for example Leatherworking 79/150, Skinning 86/150, First Aid 73/75, Fishing 3/75, Cooking 43/...).
- **In game:** **`C_TradeSkillUI.GetAllRecipeIDs()` exists** (it's undocumented) and returns every recipe of the open profession, learned and unlearned (Tailoring 471, Leatherworking 592, Enchanting 262, Cooking 132, First Aid 32, Fishing 3).
- **In game:** with **no profession open**, `GetRecipeInfo(id)` and `GetRecipeSchematic(id)` still return name, reagents and output **for any recipe ID**, but `learned` is only correct for the open profession. So:
  - known-recipe lists need each profession to be opened once per character (then they're saved);
  - reagents and outputs can be read at any time by recipe ID (useful for alts' saved recipes and the Camp tab).
- Recipe info fields: `relativeDifficulty`, `numSkillUps`, `maxTrivialLevel`, `learned`, `craftable`, `categoryID`, `hyperlink`, `icon`.
- **Skill-up colours:** `relativeDifficulty` (orange/yellow/green/grey) plus the coloured side number, exactly as the default window shows them. The exact skill levels where the colour changes aren't exposed; LibProfessionDB has them (its `GetDifficulty`).
- **Category tree:** `GetCategoryInfo` gives `Profession > Subcategory` (for example "Tailoring > Robes and Vests"). There is also a top-level **"SEASON OF DISCOVERY"** category per profession (Tailoring 54, Enchanting 37, Cooking 7 recipes). These look unobtainable in Forever. Tradebook hides recipes that aren't under the profession's own root category, with a setting to show them.
- Events seen in order: `TRADE_SKILL_SHOW` → `TRADE_SKILL_DATA_SOURCE_CHANGING/CHANGED` → `TRADE_SKILL_LIST_UPDATE` (repeats; throttle it) → `TRADE_SKILL_CLOSE`.

## 4. Unlearned recipes — **works (list only, no sources)**

- **In game:** `GetAllRecipeIDs` includes unlearned recipes (for example 406 of 471 Tailoring recipes).
- **In game:** `GetRecipeSourceText` returned an **empty string for all 65 recipes sampled**, and `sourceType` is nil. **The client gives no recipe sources.** Sources come from the bundled LibProfessionDB data (decision 2026-11-13).

## 5. Campsite recipes — **works, cleanly**

- **In game:** every profession has a **"Camping" subcategory** under its root (Tailoring #2591, Cooking #2714, Enchanting #2514, Fishing #2715, ...). Examples: Spinning Wheel, Loom, Faction Banner (Tailoring); Basic/Expert Campfire Kit, Cookie's Feast, Iron Oven (Cooking); Enchanted Lute (Enchanting); Fishing Rack (Fishing). Counts differ (Cooking 5, Tailoring 4, others 3).
- Detection: a recipe is a camp recipe if its category or parent is a "Camping" category. Category IDs are recorded in `Data/Camp.lua` so the check doesn't depend on the English name.
- Cooldowns: `GetRecipeCooldown` returned no cooldown for these recipes (`nil, false, 0, 0`). "Repair All" and similar camp-object cooldowns are effects of the placed object, not recipe cooldowns, so they aren't readable. The Camp tab will leave cooldowns out unless they turn up later.
- The `DisableCampsites` game rule is the character-select "camps" screen, not this feature.

## 6. Legacy system — **works (read-only)**

- **In game:** `C_Traits.GetConfigIDByTreeID(1187)` returned a config. The Professions tree has 9 nodes with names and ranks (Dedicated Study 0/1, Bartering 0/2, Master Chef 0/5, Working Overtime 0/5, Bountiful Harvest 0/5, Performance Bonus 0/3, Luremaster 0/2, plus 2 unnamed). Points: trait currency 4225; renown 1 on faction 2802.
- Tradebook can show a read-only Legacy Professions panel: perks, ranks, unspent points.

## 7. Character identity and play type — **solved**

- **In game:** `UnitFullName("player")` → `"Firstname", "Secondname"`. The second value is the character's **second name**. `GetRealmName()` → **`"CAMWOW US1 Realm 3 PvE"`**, `GetRealmID()` → 6921, GUID `Player-6921-...`. (The Fellowship Ledger "realm" values were second names from `UnitFullName`.)
- **Play type:** `C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset)` and `(Enum.GameRule.RPRuleset)`. Both inactive means Normal, RP only means Role-Playing, PvP only means PvP, both means RP-PvP. The realm name suffix (`PvE`) is a second check. Only Normal was tested; the others follow from the rule names.
- **Saved-character key:** `Name-SecondName` (unique per region), with play type, realm ID and GUID stored as fields. The UI shows the play type, never the realm.

## 8. Bank — **works for the character bank; account bank not testable yet**

- **In game:** at the bank, `C_Bank.FetchPurchasedBankTabIDs(Character)` → bag 6 (`CharacterBankTab_1`, 48 slots), readable with `C_Container`. The account bank isn't bought on this account (`canView=false`), and its tabs are bags 15-23. Tradebook scans both bank types generically on `BANKFRAME_OPENED`, `BANK_TABS_CHANGED` and slot changes, saving the character bank per character and the account bank once per account.
- `C_Item.GetItemCount(id, true)` away from the bank gave the same number as without the flag. Inconclusive (the sample item may not have been in the bank). Tradebook uses its own saved bank snapshot, so this doesn't matter.

## 9. Minimap button and Professions key — **works**

- No key override needed; the `ProfessionsFrame.Show` hook covers the key and micro button.
- **In game:** `C_TradeSkillUI.OpenTradeSkill(skillLineID)` **works from a button click** and is **blocked without a hardware event** (`ADDON_ACTION_BLOCKED` from the timer variant). The secure cast button also works. So clicking a profession tab in Tradebook calls `OpenTradeSkill` directly; nothing may open a profession automatically.
- Minimap: LibDBIcon + LibDataBroker. `AddonCompartmentFrame` and `Settings` are available.

## 10. Recipe source data — **decided: copy LibProfessionDB data**

- LibProfessionDB is MIT-licensed but needs Ace3 at runtime. Decision: copy its data into `Data/` at build time, with credit, and no runtime dependency.
- The client gives no source text (item 4), so this is the only source of trainer, vendor, drop and quest information. Its Forever source data is "borrowed from Vanilla, unconfirmed", and the UI will say so.

## Icon

- **In game:** the spike's TOC `IconTexture` is a `.png` and it showed in the AddOns list, so **PNG works for the TOC icon**. In the panel, `.png` with extension and uncompressed `.tga` showed; the **PNG path without an extension did not**. Tradebook always uses explicit `.png` paths.
- `assets/` has `tradebook_icon_512.jpg` (not `.png`) plus the SVG. Tradebook's PNGs (64×64 TOC/minimap icon) will be made from it.

## Summary of fallbacks still in play

| Spike | Result | Fallback needed? |
|---|---|---|
| Replace default frame | Works (alpha, keep open) | No |
| Crafting | Works from a click; blocked from timers | No |
| Unlearned recipes | List yes, sources no | Sources from bundled LibProfessionDB data |
| Legacy | Works | No |
| Camp cooldowns | Not exposed | Leave out of Camp tab |
