"""Turn merged.json (scratchpad) into the committed research file docs/research/recipe_vendors.json.

Decisions applied here (see docs/DATA.md, "Recipe vendors"):
- confirmed: Questie + web, or 2+ web sources; single: one of them; removed: classic list only,
  web says not sold (and Questie doesn't list it), or NPC not in Forever.
- Name-only web vendors get their NPC ID from QuestieDB by name; "Unknown vendor" entries dropped.
- Evie Whirlbrew on Mooncloth dropped (single source that conflicts with her own vendor page).
- Expert books: vendors confirmed by the earlier trainer research (docs/DATA.md).
- Aendel's Cenarion Circle patterns and Vargus's Obsidian / Ironvine plans: no recipe item
  in Forever per the web sources, so "notYet".
- Alchemist's Stone: sources disagree (zone-only vendor vs unobtainable): "disputed".
"""
import json, os, sys

merged_path, npc_path, out_path = sys.argv[1:4]
merged = json.load(open(merged_path, encoding="utf-8"))
npcs = json.load(open(npc_path, encoding="utf-8"))
by_name = {}
for k, v in npcs.items():
    name = v.get("1")
    if name and v.get("7"):  # with spawns
        by_name.setdefault(name, int(k))

BOOKS = {3413, 7732, 7924}
NOT_YET_NAMES = {"Heavy Obsidian Belt", "Light Obsidian Belt", "Ironvine Breastplate", "Ironvine Gloves",
                 "Ironvine Belt"}
DISPUTED = {"Alchemist's Stone"}

out = []
for r in merged:
    vendors, removed = [], []
    for e in r["vendors"]:
        npc, name = e["npcID"], e["name"]
        if not npc and name in by_name:
            npc = by_name[name]
        if e["verdict"] == "remove" or not npc:
            if e["lib"]:
                reason = ("not in Forever" if e["notInForever"] else
                          "web sources say not sold" if e["webNot"] else "no Forever source")
                removed.append({"npc": e["npcID"], "name": name, "reason": reason})
            continue
        if r["recipeName"] == "Mooncloth" and name == "Evie Whirlbrew":
            continue
        evidence = []
        if e["questie"]: evidence.append("questie")
        if e["web"]: evidence.append("web:" + e["web"])
        confirmed = e["verdict"] == "confirmed" or r["recipeSpellID"] in BOOKS
        if r["recipeSpellID"] in BOOKS: evidence.append("trainer research 2026-11-13")
        vendors.append({"npc": npc, "name": name, "zone": e.get("zone"), "faction": e.get("faction"),
                        "confirmed": confirmed, "evidence": evidence, "limited": e.get("limited", False),
                        "inClassicList": e["lib"]})
    q = r.get("questieOther") or {}
    drops = [{"npc": x["id"], "name": x.get("name")} for x in q.get("npcDrops", []) if isinstance(x, dict)]
    quests = [{"quest": x["id"], "name": x.get("name")} for x in q.get("questRewards", []) if isinstance(x, dict)]
    aendel = any(v["name"] == "Aendel Windspear" for v in vendors)
    if r["recipeName"] in DISPUTED:
        status = "disputed"
    elif r["recipeName"] in NOT_YET_NAMES or aendel:
        status = "notYet"
    elif vendors:
        status = "vendor"
    else:
        status = "none"
    if status in ("notYet", "disputed"):
        for v in vendors:
            removed.append({"npc": v["npc"], "name": v["name"], "reason": "recipe " + status})
        vendors = []
    out.append({"recipeSpellID": r["recipeSpellID"], "recipeName": r["recipeName"], "profession": r["profession"],
                "recipeItems": r["recipeItems"], "status": status, "vendors": vendors, "removed": removed,
                "drops": drops, "quests": quests,
                "webOther": [{"kind": o.get("kind"), "detail": o.get("detail")} for o in (r.get("webOther") or [])],
                "webNotes": r.get("webNotes")})

os.makedirs(os.path.dirname(out_path), exist_ok=True)
json.dump({"about": "WoW Forever recipe vendors, checked 2026-11-13: classic list (LibProfessionDB) vs "
                    "QuestieDB Forever vs Forever web sources. See docs/DATA.md.",
           "recipes": out}, open(out_path, "w", encoding="utf-8", newline="\n"), indent=1, ensure_ascii=False)
import collections
print(collections.Counter(r["status"] for r in out))
print(sum(1 for r in out for v in r["vendors"] if not v["confirmed"]), "unconfirmed vendors")
