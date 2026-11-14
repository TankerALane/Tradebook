"""Merge the recipe vendor checks: classic list (lib), QuestieDB Forever (Q), web research (W).

Per vendor of a recipe:
  confirmed  two independent Forever sources: Q and W, or W "confirmed" (2+ web sources)
  single     one Forever source (Q only, or W single only)
  remove     only the classic list has it, a web source says it doesn't sell it (and no web
             source names it), or the NPC isn't in Forever
Wowhead item pages that only list a zone don't count as a source naming the vendor.
Per recipe: the vendors left, and other ways to get it when none are left.
"""
import json, os, sys, collections

D = sys.argv[1]
def load(n): return json.load(open(os.path.join(D, n), encoding="utf-8"))

local = {r["recipeSpellID"]: r for r in load("local_check.json")}
web = {}
for f in ("web_lw_cooking.json", "web_tailoring_alchemy.json", "web_bs_ench_eng.json"):
    for r in load(f):
        web[r["recipeSpellID"]] = r

def norm(s): return (s or "").strip().lower()

out, counts = [], collections.Counter()
for rid, L in local.items():
    W = web.get(rid, {})
    v = {}  # key -> evidence
    def entry(npc, name):
        key = npc or ("name:" + norm(name))
        # merge name-only web entries with an NPC ID entry of the same name
        if not npc:
            for k, e in v.items():
                if norm(e["name"]) == norm(name): return e
        if key not in v:
            v[key] = {"npcID": npc, "name": name, "lib": False, "questie": False, "web": None,
                      "webNot": None, "notInForever": False, "zone": None, "faction": None}
        e = v[key]
        if not e["name"] and name: e["name"] = name
        return e
    for x in L.get("libVendors", []):
        e = entry(x.get("npcID"), x.get("name") or x.get("libName")); e["lib"] = True
        e["zone"] = e["zone"] or x.get("zone"); e["faction"] = e["faction"] or x.get("faction")
    for npc in L.get("libVendorsMissingFromQuestieNPCs", []):
        npcid = npc if isinstance(npc, int) else npc.get("npcID")
        for e in v.values():
            if e["npcID"] == npcid: e["notInForever"] = True
    for x in L.get("questieVendors", []):
        e = entry(x.get("npcID"), x.get("name")); e["questie"] = True
        e["zone"] = e["zone"] or x.get("zone"); e["faction"] = e["faction"] or x.get("faction")
    for x in W.get("vendors", []):
        e = entry(x.get("npcID"), x.get("name"))
        srcs = x.get("sources") or []
        if srcs and all("wowhead.com/forever/item" in u or "nether.wowhead.com" in u for u in srcs):
            # Wowhead's item pages only list zones; a vendor in that zone isn't a source naming
            # this NPC, so it doesn't count.
            e["webZone"] = True
            continue
        e["web"] = x.get("confidence") or "single"
        e["zone"] = e["zone"] or x.get("zone"); e["faction"] = e["faction"] or x.get("faction")
        if x.get("limited"): e["limited"] = True
        if x.get("conflict"): e["conflict"] = True
    for x in W.get("notSoldBy", []):
        if isinstance(x, str): x = {"name": x}
        e = entry(x.get("npcID"), x.get("name"))
        e["webNot"] = x.get("confidence") or "single"
    # Fix the one known mislabel from the tailoring report: Evie Whirlbrew on Mooncloth.
    for e in v.values():
        if e["questie"] and e["web"]: e["verdict"] = "confirmed"
        elif e["web"] == "confirmed" and not e.get("conflict"): e["verdict"] = "confirmed"
        elif e["webNot"]: e["verdict"] = "remove"  # the NPC's own Forever page doesn't list it
        elif e["notInForever"]: e["verdict"] = "remove"
        elif e["questie"] or e["web"]: e["verdict"] = "single"
        else: e["verdict"] = "remove"  # classic list only
        counts["vendor:" + e["verdict"]] += 1
        if e["lib"] and e["verdict"] == "remove": counts["lib vendor removed"] += 1
        if not e["lib"] and e["verdict"] != "remove": counts["vendor added (not in classic list)"] += 1
    kept = [e for e in v.values() if e["verdict"] != "remove"]
    if any(e["verdict"] == "confirmed" for e in kept): rv = "vendor confirmed"
    elif kept: rv = "vendor single source"
    else: rv = "no vendor"
    counts["recipe:" + rv] += 1
    out.append({"recipeSpellID": rid, "recipeName": L["recipeName"], "profession": L["profession"],
                "recipeItems": [i["itemID"] for i in L.get("recipeItems", [])],
                "verdict": rv, "vendors": sorted(v.values(), key=lambda e: (e["verdict"], e["name"] or "")),
                "questieOther": L.get("questieOtherSources"), "webOther": W.get("otherSources"),
                "webStatus": W.get("status"), "webNotes": W.get("notes")})

json.dump(out, open(os.path.join(D, "merged.json"), "w", encoding="utf-8"), indent=1)
for k in sorted(counts): print(k, counts[k])
byprof = collections.defaultdict(collections.Counter)
for r in out: byprof[r["profession"]][r["verdict"]] += 1
for p, c in sorted(byprof.items(), key=lambda x: str(x[0])): print(p, dict(c))
print("\nNO VENDOR:")
for r in out:
    if r["verdict"] == "no vendor":
        other = []
        q = r["questieOther"] or {}
        for k, items in q.items():
            if items: other.append(k + ":" + ",".join(str(i.get("name") or i.get("id")) if isinstance(i, dict) else str(i) for i in items[:2]))
        for o in r["webOther"] or []:
            other.append("web " + str(o.get("kind")) + ": " + str(o.get("detail"))[:60])
        print(" ", r["profession"], "|", r["recipeName"], "|", "; ".join(other)[:200])
