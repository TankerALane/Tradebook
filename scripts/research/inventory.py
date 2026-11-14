"""Inventory every recipe the game knows (Tradebook's saved recipe cache) and what Tradebook
knows about where it comes from. Writes recipes_inventory.json for the research agents."""
import json, os, re, sys, collections
SV, ROOT, Q, OUT = sys.argv[1:5]
sv = open(SV, encoding="utf-8").read()
# TradebookDB.recipes: [id] = { ["n"] = "name", ["s"] = skill, ["o"] = output, ... }
i = sv.index('["recipes"] = {', sv.index("TradebookDB"))
# the top-level recipes table is the one followed by categories; find entries with n= and s=
rec = {}
for m in re.finditer(r'\[(\d+)\] = \{\s*((?:[^{}]|\{[^{}]*\})*?)\}', sv[i:i + 3_000_000]):
    body = m.group(2)
    n = re.search(r'\["n"\] = "((?:[^"\\]|\\.)*)"', body)
    s = re.search(r'\["s"\] = (\d+)', body)
    if n and s:
        rec[int(m.group(1))] = {"name": n.group(1), "skill": int(s.group(1)),
                                "camp": '["camp"] = true' in body, "extra": '["x"] = true' in body}
src = open(os.path.join(ROOT, "Tradebook/Data/SourceData.lua"), encoding="utf-8").read()
srcd = {int(a): b for a, b in re.findall(r"^\[(\d+)\]=\{(.*)\},?$", src.split("ns.SourceNames")[0], re.M)}
rv = open(os.path.join(ROOT, "Tradebook/Data/RecipeVendors.lua"), encoding="utf-8").read()
rvd = {int(a): b for a, b in re.findall(r"^\[(\d+)\]=\{(.*?)\},", rv.split("ns.RecipeVendorNames")[0], re.M)}
ri = {}
for a, b in re.findall(r"\[(\d+)\]=(\d+),", open(os.path.join(ROOT, "Tradebook/Data/RecipeItems.lua"), encoding="utf-8").read()):
    ri.setdefault(int(b), []).append(int(a))
items = json.load(open(os.path.join(Q, "qdb_item.json"), encoding="utf-8"))
PROF = {165: "Leatherworking", 185: "Cooking", 197: "Tailoring", 164: "Blacksmithing", 171: "Alchemy",
        333: "Enchanting", 202: "Engineering", 129: "First Aid", 356: "Fishing", 182: "Herbalism", 186: "Mining", 393: "Skinning"}

def kinds(rid):
    k = set()
    s = srcd.get(rid, "")
    for key, name in (("t", "trainer"), ("v", "vendor"), ("d", "drop"), ("q", "quest"), ("c", "container"), ("a", "auto")):
        if re.search(r"\b%s=" % key, s): k.add(name)
    o = rvd.get(rid)
    if o is not None:
        k -= {"vendor"}
        if re.search(r"\b[vu]=", o): k.add("vendor")
        if re.search(r"\bd=", o): k.add("drop")
        if re.search(r"\bq=", o): k.add("quest")
        if "x=1" in o: k.add("notYet")
    return k

rows, c = [], collections.Counter()
for rid, r in sorted(rec.items()):
    if r["camp"] or r["extra"]:
        continue
    k = kinds(rid)
    its = ri.get(rid, [])
    q = {}
    for it in its:
        d = items.get(str(it), {})
        for f, name in (("14", "vendors"), ("2", "npcDrops"), ("3", "objectDrops"), ("6", "questRewards"), ("4", "itemDrops")):
            if d.get(f): q.setdefault(name, []).extend(d[f] if isinstance(d[f], list) else [d[f]])
    status = "known" if (k - {"notYet"}) else ("notYet" if "notYet" in k else "unknown")
    c[(status, bool(its))] += 1
    rows.append({"recipeSpellID": rid, "recipeName": r["name"], "profession": PROF.get(r["skill"], r["skill"]),
                 "tradebookKinds": sorted(k), "status": status, "recipeItemIDs": its, "questie": q})
json.dump(rows, open(OUT, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print(len(rec), "cached recipes;", len(rows), "after camp/extra filter")
for k, v in sorted(c.items(), key=str): print(k, v)
u = [r for r in rows if r["status"] == "unknown"]
print("unknown by profession:", collections.Counter(r["profession"] for r in u))
print("unknown with questie sources:", sum(1 for r in u if r["questie"]))
d = [r for r in rows if r["recipeItemIDs"]]
print("recipes with a recipe item (possible drops/AH):", len(d))
