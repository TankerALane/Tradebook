# Decisions

One line per significant decision. Newest at the bottom.

- 2026-11-13 — Interface `16001`, TOC pattern `Tradebook_Forever.toc` plus a fallback `Tradebook.toc` (`## Interface: 00000`) that only prints "unsupported client". Same pattern as Tanksign and Fellowship Ledger; it keeps Tradebook off Classic and Retail.
- 2026-11-13 — API facts are checked against Blizzard's UI source for the exact client build (`Gethe/wow-ui-source`, branch `forever`, 1.60.1.70938). It is read only and never copied into the addon.
- 2026-11-13 — Phase 0 runs as a throwaway addon (`spikes/TradebookSpike`) that writes its findings to SavedVariables, so results come straight from the client rather than from screenshots.
- 2026-11-13 — Proposed: take over the default window at `EventRegistry "ProfessionsFrame.Show"` and keep the default frame open (hidden) instead of closing it, because closing it ends the trade-skill session. Pending the spike result.
- 2026-11-13 — Proposed: saved-character key = `Name-SecondName` (`UnitFullName` / `GetNormalizedRealmName`, which return the second name in Forever), with the GUID stored as a field. The UI never shows a realm.
- 2026-11-13 — LibProfessionDB: copy its MIT data into `Data/` at build time, crediting it, with no runtime dependency (so no Ace3). Its Forever source data is marked "borrowed from Vanilla, unconfirmed", and the UI will say so.
- 2026-11-13 — Default-frame takeover: keep `ProfessionsFrame` open at alpha 0 behind Tradebook (confirmed in game). Hiding it closes the trade skill.
- 2026-11-13 — Character key `Name-SecondName` from `UnitFullName`. Play type from `Enum.GameRule.PvPRuleset` / `RPRuleset`. `GetRealmName()` is a server name ("CAMWOW US1 Realm 3 PvE"), stored but never shown.
- 2026-11-13 — Camp recipes = recipes in each profession's "Camping" subcategory, matched by category ID in `Data/Camp.lua`. Camp cooldowns are left out (not exposed).
- 2026-11-13 — Recipes under the top-level "SEASON OF DISCOVERY" category are hidden by default.
- 2026-11-13 — Profession tabs call `C_TradeSkillUI.OpenTradeSkill` only from a click (blocked without a hardware event).
- 2026-11-13 — Crafting from Tradebook: one `CraftRecipe(id, n)` call per click, only when the recipe's profession is open. No queued or delayed crafts (blocked without a hardware event).
- 2026-11-13 — Textures use explicit `.png` paths (an extensionless PNG path fails to load).
- 2026-11-13 — ~~Hidden default frame uses alpha 0 + scale 0.001~~ Replaced: the panel manager scales ProfessionsFrame to fit (`checkFit`) and some buttons size from text width, so the tiny scale broke its layout. Now: alpha 0 + moved off-screen, with the panel manager's anchors restored on show (re-applied after `UpdateUIPanelPositions`).
- 2026-11-13 — Tab order: crafting primaries, secondaries, then Herbalism/Mining/Skinning grouped at the right, Camp last. Gathering tabs can be hidden (setting, on by default); their data is still saved. Tabs shrink to fit the window.
- 2026-11-13 — Window scale 1.0 = 1.25x native (user preference); DB migration v2 converts saved scales.
- 2026-11-13 — No account bank in Forever: account-bank scanning and text removed.
- 2026-11-13 — Login "quick scan": learned recipes of each profession are found with `C_SpellBook.IsSpellKnown` against the bundled recipe list, without opening the profession. It only adds recipes; opening the profession does the full scan.
- 2026-11-13 — When only the profession is closed, Craft becomes "Open <profession>" (one click opens, the next crafts), on both the details pane and the Camp tab.
- 2026-11-13 — One extra global frame name, `TradebookFrame`, so ESC closes the window (`UISpecialFrames` needs a name). Also one `StaticPopupDialogs` entry for delete confirmation.
- 2026-11-13 — Addon lives in `Tradebook/` in the repo; `.pkgmeta` moves it into place and pulls the four libs as externals. Local dev copies go in the git-ignored `Tradebook/Libs` via `scripts/dev-libs.sh`.
- 2026-11-13 — LibProfessionDB data is copied at build time by `scripts/build_source_data.py` into `Data/SourceData.lua` (sources, NPC names, required skill, skill-up thresholds), with the MIT notice in the file header. Thresholds also recolour alts' recipes from their current rank.
- 2026-11-13 — Recipe cache (`TradebookDB.recipes`) is shared by all characters; each character stores only learned recipe IDs plus difficulty, to keep memory modest.
- 2026-11-13 — Camp tab: no cooldowns (not exposed), and nothing about what's active at the camp (out of scope).
- 2026-11-13 — Git setup (link to `TankerALane/Tradebook`, first commits) waits until the spike is done.
