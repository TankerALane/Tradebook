import json, os, sys, csv
D = sys.argv[1]  # scratchpad/recipes
d = json.load(open(os.path.join(D, "wdb_sources.json"), encoding="utf-8"))
npcs = json.load(open(os.path.join(D, "qdb", "qdb_npc.json"), encoding="utf-8"))
area = {int(r["ID"]): r["AreaName_lang"] for r in csv.DictReader(open(os.path.join(D, "wago", "AreaTable.csv"), encoding="utf-8"))}
def has(r):
    return any(it.get("droppedBy") or it.get("soldBy") or it.get("rewardFrom") or it.get("objects") or it.get("other")
               for it in r["items"])
out = []
for r in d:
    if r["status"] != "unknown" or has(r):
        continue
    items = []
    for it in r["items"]:
        qd = []
        for n in (it.get("questieOnlyDroppers") or [])[:15]:
            nid = n if isinstance(n, int) else n.get("npcID")
            v = npcs.get(str(nid), {})
            qd.append({"npcID": nid, "name": v.get("1"), "zone": area.get(int(v.get("9") or 0)),
                       "level": v.get("4")})
        items.append({"itemID": it["itemID"], "name": it.get("wdbName") or it.get("questieName"),
                      "onWarcraftdb": it.get("exists"), "questieDroppers": qd,
                      "questieDropperCount": len(it.get("questieOnlyDroppers") or [])})
    out.append({"recipeSpellID": r["recipeSpellID"], "recipeName": r["recipeName"], "profession": r["profession"],
                "items": items})
json.dump(out, open(os.path.join(D, "unknown_recipes.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
import collections
print(len(out), collections.Counter(r["profession"] for r in out))
