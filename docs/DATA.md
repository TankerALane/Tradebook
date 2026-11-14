# Bundled data and keeping it current

Tradebook ships two generated data files. Never edit them by hand; re-run the scripts.

| File | What | Source | How it's updated |
|---|---|---|---|
| `Tradebook/Data/SkillLevels.lua` | Skill-up thresholds (where each recipe turns yellow, green, grey) | WoW Forever's own `SkillLineAbility` table, via wago.tools | **Automatically checked every week** (GitHub Actions "Game data check"); a pull request opens when a new build changes anything |
| `Tradebook/Data/SourceData.lua` | Where recipes are learned (trainer, vendor, drop, quest, container), NPC names, skill needed to learn | LibProfessionDB (MIT, by Pimptasty) | By hand when LibProfessionDB releases a new version |

## Skill-up thresholds (every Forever build)

- Rule (checked in game against every colour the game reported: 166 of 166 matched): yellow from `TrivialSkillLineRankLow`, grey from `TrivialSkillLineRankHigh`, green from `floor((low + high) / 2)`, orange below yellow.
- **Automatic:** `.github/workflows/game-data.yml` runs every Tuesday at 3pm Pacific (23:00 UTC), after weekly maintenance, (and on demand from the Actions tab, optionally for a specific build). It regenerates the file, runs lint and tests, and opens a PR titled "Game data update: Forever <build>" listing added, removed and changed recipes. It also warns if the build suggests a new TOC `## Interface` number.
- **By hand:** `python -I scripts/update_game_data.py [build]`.
- **In the game:** every time a profession is opened, Tradebook compares these numbers with the game's own colours. Any recipe that disagrees is flagged (`TradebookDB.badThresholds`); its "until" lines are hidden and the game's colour is used. `/tb debug` reports how many disagreed. If that number isn't 0 after a patch, run the update.

## Recipe sources (LibProfessionDB releases)

1. Download the new LibProfessionDB zip from CurseForge (project 1558781) into an empty folder and unzip it.
2. `python -I scripts/build_source_data.py "<folder>/ProfessionDB/Data/Forever/_core" "<ProfessionDB version>"`
3. Run the tests, check `git diff`, commit.

LibProfessionDB's Forever sources are borrowed from classic and flagged unconfirmed; Tradebook says so in the recipe details. Its skill-up thresholds are not used (they were wrong for ~400 recipes).

## Profession trainers (seen in game, Forever 1.60.1, Undercity, 2026-11-13)

Read from the trainer windows by Core/Trainers.lua (all filters on). Costs shown were 10% lower
than base (reputation discount): base prices are Journeyman 5s, Expert 50s, Artisan 5g.

| Trainer | Profession | Ranks taught | Notes |
|---|---|---|---|
| Lavinia Crowe (4616), "Expert Enchanter" | Enchanting | Apprentice, Journeyman (level 10) | No Expert, despite the title; recipes up to 150 |
| Malcomb Wynn (11067) | Enchanting | Apprentice | Recipes up to 70 |
| Eunice Burch (4552) | Cooking | Apprentice, Journeyman | No Expert (book) or Artisan; no level requirement |
| Martha Alliestar (4614) | Herbalism | Apprentice, Journeyman, Expert, Artisan | No level requirement |

Service names are "<Rank> <profession>" ("Journeyman Enchanting", "Journeyman Cook"); the game
flags only Apprentice as a profession service. NPC titles don't say which ranks a trainer teaches.
