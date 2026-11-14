"""Merge the 2026-11-14 deep dive into docs/research/recipe_vendors.json:

1. drops for every recipe (key "drops"): who drops the recipe item, with the drop chance where a
   Forever source has one:
     - forever.warcraftdb.com loot counts (players' recorded loots: drops / times looted);
       confirmed when QuestieDB Forever also lists the NPC;
     - the deep-dive agents' droppers (QuestieDB / Wowhead Forever / wow.gg, with drop % when
       wow.gg had one);
   plus "world drop" level ranges for items QuestieDB lists 20+ droppers for.
2. sources for recipes that had none (key "recipes", set "deep"): vendors, quests, trainer,
   learned automatically, notes, or "not in WoW Forever" (Season of Discovery / unreleased items).
   Recipes the earlier checks already decided keep that decision.

    python -I scripts/research/merge_deep.py <scratchpad/recipes> docs/research/recipe_vendors.json
"""
import json, os, sys, collections

D, OUT = sys.argv[1], sys.argv[2]
def load(n, default=None):
    p = os.path.join(D, n)
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else default

wdb = load("wdb_sources.json", [])
npcs = load(os.path.join("qdb", "qdb_npc.json"), {})
qitems = load(os.path.join("qdb", "qdb_item.json"), {})
deep = []
for f in ("deep_blacksmithing.json", "deep_leatherworking.json", "deep_eng_cook_fa.json", "deep_tailoring_enchanting.json"):
    deep += load(f, []) or []
doc = json.load(open(OUT, encoding="utf-8"))
decided = {r["recipeSpellID"] for r in doc["recipes"] if r.get("set") != "deep"}

def level(nid):
    v = npcs.get(str(nid), {})
    return v.get("4"), v.get("5")

def pct(text):
    try:
        return float(str(text).strip().rstrip("%"))
    except (TypeError, ValueError):
        return None

# ---- 1. drops per recipe
drops = {}
for r in wdb:
    rows = {}
    for it in r["items"]:
        for d in it.get("droppedBy") or []:
            m = d.get("sample", "").split("/")
            dr, lo = (int(m[0]), int(m[1])) if len(m) == 2 and m[0].strip().isdigit() and m[1].strip().isdigit() else (0, 0)
            rows[d["npcID"]] = {"npc": d["npcID"], "name": d["name"], "chance": round(d["chance"], 2),
                                "zone": npcs.get(str(d["npcID"]), {}).get("9"),
                                "drops": dr, "loots": lo, "confirmed": bool(d.get("questieAgrees")),
                                "source": "warcraftdb"}
        # World drop: QuestieDB lists many droppers for the item.
        q = qitems.get(str(it["itemID"]), {})
        listed = q.get("2") or []
        if len(listed) >= 20:
            lv = sorted(x for n in listed for x in level(n) if x)
            if lv:
                # The middle 80% of the droppers' levels (a few odd mobs stretch the full range).
                lo, hi = lv[int(len(lv) * 0.1)], lv[min(len(lv) - 1, int(len(lv) * 0.9))]
                drops.setdefault(r["recipeSpellID"], {})["world"] = [lo, hi, len(listed)]
    if rows:
        drops.setdefault(r["recipeSpellID"], {})["npcs"] = rows

for r in deep:
    for s in r.get("sources", []):
        if s.get("kind") not in ("drop", "worldDrop"):
            continue
        if s["kind"] == "worldDrop" and s.get("levelRange"):
            lr = s["levelRange"]
            if isinstance(lr, (list, tuple)) and len(lr) == 2:
                drops.setdefault(r["recipeSpellID"], {})["world"] = [lr[0], lr[1], 0]
        rows = drops.setdefault(r["recipeSpellID"], {}).setdefault("npcs", {})
        for n in s.get("npcs") or []:
            nid = n.get("npcID")
            if not nid or nid in rows:
                continue
            rows[nid] = {"npc": nid, "name": n.get("name"), "chance": pct(n.get("dropChance")) or 0,
                         "zone": npcs.get(str(nid), {}).get("9"),
                         "drops": 0, "loots": 0, "confirmed": s.get("confidence") == "confirmed",
                         "source": "deep"}

for rid, d in drops.items():
    if "npcs" in d:
        # Highest chance first (confirmed first among equal chances), top 5.
        d["npcs"] = sorted(d["npcs"].values(), key=lambda x: (-x["chance"], not x["confirmed"], x["name"] or ""))[:5]

# ---- 2. sources for recipes that had none
added, counts = [], collections.Counter()
for r in deep:
    rid = r["recipeSpellID"]
    if rid in decided:
        counts["kept earlier decision"] += 1
        continue
    e = {"recipeSpellID": rid, "recipeName": r.get("recipeName"), "profession": r.get("profession"),
         "recipeItems": [r["itemID"]] if r.get("itemID") else [], "status": "vendor", "set": "deep",
         "vendors": [], "removed": [], "drops": [], "quests": [], "trainer": False, "auto": False,
         "notes": [], "costText": None, "webOther": [], "webNotes": r.get("notes") if isinstance(r.get("notes"), str) else None}
    if r.get("obtainable") is False:
        e["status"] = "notInForever"
        counts["not in Forever"] += 1
        added.append(e)
        continue
    for s in r.get("sources", []):
        k, conf = s.get("kind"), s.get("confidence") == "confirmed"
        if k == "vendor":
            for n in s.get("npcs") or []:
                if n.get("npcID"):
                    e["vendors"].append({"npc": n["npcID"], "name": n.get("name"), "zone": n.get("zone"),
                                         "confirmed": conf, "evidence": ["deep"], "sources": s.get("urls", [])})
            if s.get("cost"):
                e["costText"] = s["cost"] if isinstance(s["cost"], str) else None
        elif k == "quest":
            ids = [int(x) for x in __import__("re").findall(r"quest (\d{3,6})", s.get("detail", ""))]
            for q in ids:
                e["quests"].append({"quest": q, "name": None})
            if not ids and conf:
                e["notes"].append("Learned from a quest.")
        elif k == "trainer" and conf:
            e["trainer"] = True
        elif k == "auto":
            e["auto"] = True
    has = e["vendors"] or e["quests"] or e["trainer"] or e["auto"] or e["notes"] or rid in drops
    if not has:
        counts["still unknown"] += 1
        continue
    counts["resolved"] += 1
    added.append(e)

doc["recipes"] = [r for r in doc["recipes"] if r.get("set") != "deep"] + added
doc["drops"] = {str(k): v for k, v in sorted(drops.items())}
json.dump(doc, open(OUT, "w", encoding="utf-8", newline="\n"), indent=1, ensure_ascii=False)
print(dict(counts))
print("recipes with droppers:", sum(1 for d in drops.values() if d.get("npcs")),
      "with a drop chance:", sum(1 for d in drops.values() if any(n["chance"] for n in d.get("npcs", []))),
      "world drops:", sum(1 for d in drops.values() if d.get("world")))
