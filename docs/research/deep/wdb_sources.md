# warcraftdb (forever.warcraftdb.com) recipe sources

Fetched 2026-11-13/14. Output: `wdb_sources.json` (2081 recipes, 1698 distinct recipe items).
Scripts: `scratchpad\wdbsrc\fetch.py` (fetch + cache), `scratchpad\wdbsrc\build.py --npcs` (assemble).
Raw responses: `scratchpad\recipes\wdb_cache\` (one JSON per request; a 404 is cached as `{"_status":404}`).

## Method / endpoints
JSON API behind the pages (no browser needed), base `https://forever.warcraftdb.com/api/data/node/`:
- `item/<id>` – item data and a `tabs` list (slug + count). An item with no Forever page returns HTTP 404 (HTML).
- `item/<id>/tab/<slug>?page=N` – 50 rows per page, `pages` gives the page count. Slugs seen on recipe items:
  `teaches`, `sold-by`, `dropped-by`, `reward-from`, `created-by`, `required-for`, `can-be-placed-in`.
  No `contained-in` tab was seen on any recipe item.
- `npc/<id>` – `data.level`, `data.reaction`, `extra.npc_map` (`floors` = uiMap id + name, `pins` = spawn points). Used for each dropper NPC (102 NPCs).
About 0.55 s between requests, retry with backoff, generic User-Agent. No request failed.

`dropped-by` rows: `source_id`, `link_node` (npc/object), `loot_type` (Loot/Pickpocket/Skinning), `chance`, `drop_chance`,
`sample` ("drops / times looted"). **Drop chances are observed counts from looting in Forever (drops / times looted), not set
loot-table values.** Most samples are tiny (1/2, 1/3, 1/5 ... at most a few hundred looted), so the percentages are rough.
The item `source` field only ever says Vendor / Quest / "Vendor, Quest" / Crafted (561 items); it never marks drops.

QuestieDB comparison: `questieAgrees` = the NPC/object is in the qdb_item `2` (npcDrops) / `3` (objectDrops) list for that item.
`questieZone` = the area with the most Questie spawn points (AreaTable name). `questieOnlyDroppers` = Questie droppers that warcraftdb doesn't list.

## Counts
Items: 1698 distinct; 1569 have a page, 129 return 404 (85 of them from "unknown" recipes, 15 from "notYet").
76 of the 129 have IDs ≥ 200000 (the Season of Discovery / Forever-new ID range); 22 of the 129 are in QuestieDB; 128 are in the scratchpad wago Item.csv.
So a 404 means "warcraftdb has no page", which is not proof the item is missing from Forever.

The 582 "unknown" recipes (544 have a teaching item, 38 have none):
- 89 now have a warcraftdb source: vendor 50, NPC drop 25, quest reward 13, created-by 1 (Inlaid Mithril Cylinder ← "Inlaid Mithril Cylinder Plans"). Each recipe has only one kind.
- 73: every teaching item is 404.
- 382: the item page exists but has no source tab.

Drop rows overall: 112 NPC rows across 89 items (102 distinct NPCs), plus 2 object rows (Battered Chest).
Questie agrees on 68 of the 112 NPC rows. Many of the 44 disagreements are new Forever NPCs (IDs 246xxx–276xxx) or dungeon mobs.
Questie often lists hundreds of extra droppers (world drops) that warcraftdb lacks. warcraftdb has drop data for only a few world drops.
65 of the 112 dropper NPC pages have no level/map (mostly dungeon NPCs).
