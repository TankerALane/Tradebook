"""Add the new WoW Forever recipe vendors (Merchant's Favor supply camps and other new vendors)
to docs/research/recipe_vendors.json. Run after make_research.py (which rewrites the file).

Inputs (from the 2026-11-13 research pass):
  new_vendor_recipes.json   recipes QuestieDB Forever says a vendor sells that had no vendor
                            in Tradebook, with the game item data's reputation requirement
  favor_lw_tailoring.json, favor_other.json, new_other_vendors.json
                            web checks: per vendor webConfirmed + sources, cost, reputation
Rules: a vendor is confirmed when QuestieDB and a Forever web source naming the vendor agree;
QuestieDB alone (or one web source alone) is unconfirmed.

    python -I scripts/research/make_new_research.py <folder with the inputs> docs/research/recipe_vendors.json
"""
import json, os, sys

D, OUT = sys.argv[1], sys.argv[2]
def load(name):
    p = os.path.join(D, name)
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}

base = json.load(open(os.path.join(D, "new_vendor_recipes.json"), encoding="utf-8"))
web, extras, not_in_forever = {}, [], set()
for f in ("favor_lw_tailoring.json", "favor_other.json", "new_other_vendors.json"):
    d = load(f)
    for r in d.get("recipes", []):
        web.setdefault(r["recipeSpellID"], []).append(r)
        # Season of Discovery / AQ-era recipe items QuestieDB still lists, with no Forever
        # source (Wowhead Forever: "not available to players", or no item at all): skipped.
        if r.get("likelyNotInForever"):
            not_in_forever.add(r["recipeSpellID"])
    extras += d.get("extraRecipes", [])

STANDINGS = ("Neutral", "Friendly", "Honored", "Revered", "Exalted")

def standing_of(text):
    for s in STANDINGS:
        if text and s.lower() in str(text).lower():
            return s
    return None

out = []
# Recipes the classic-vendor check already decided (e.g. Kithas doesn't sell Enchant Chest -
# Lesser Intellect, seen in game) keep that decision.
checked = {r["recipeSpellID"] for r in json.load(open(OUT, encoding="utf-8"))["recipes"] if r.get("set") != "forever-new"}
skipped = 0
for r in base:
    sp = r["recipeSpellID"]
    if sp in checked:
        continue
    if sp in not_in_forever:
        skipped += 1
        continue
    checks = web.get(sp, [])
    named = {}
    for c in checks:
        for v in c.get("vendors", []):
            if v.get("webConfirmed"):
                named[v.get("npcID")] = v.get("sources", [])
    vendors = []
    for v in r["questieVendors"]:
        ok = v["npcID"] in named
        vendors.append({"npc": v["npcID"], "name": v["name"], "zone": v.get("zone"), "faction": None,
                        "confirmed": ok, "evidence": ["questie"] + (["web"] if ok else []),
                        "sources": named.get(v["npcID"], []), "limited": False, "inClassicList": False})
    # Vendors only the web names (QuestieDB doesn't): one source, unconfirmed.
    have = {v["npc"] for v in vendors}
    for c in checks:
        for v in c.get("vendors", []):
            if v.get("webConfirmed") and v.get("npcID") and v["npcID"] not in have:
                have.add(v["npcID"])
                vendors.append({"npc": v["npcID"], "name": v.get("name"), "zone": v.get("zone"), "faction": None,
                                "confirmed": False, "evidence": ["web"], "sources": v.get("sources", []),
                                "limited": False, "inClassicList": False})
    favor = standing = skill = None
    for c in checks:
        cost = c.get("cost") if isinstance(c.get("cost"), dict) else {}  # text costs: other currencies
        favor = favor or cost.get("favor")
        rep = c.get("reputation") if isinstance(c.get("reputation"), dict) else {}
        if rep and ("Supply" in str(rep.get("faction")) or "Commerce" in str(rep.get("faction"))):
            standing = standing or standing_of(rep.get("standing"))
        skill = skill or c.get("requiredSkill")
    camp = any(v["npc"] in range(248196, 248203) or v["npc"] in range(256729, 256736) for v in vendors)
    out.append({"recipeSpellID": sp, "recipeName": r["recipeName"], "profession": r["profession"],
                "recipeItems": r["recipeItemIDs"], "status": "vendor", "set": "forever-new",
                "vendors": vendors, "removed": [], "drops": [], "quests": [],
                "favor": favor if camp else None,
                "campStanding": standing if (camp and standing in ("Friendly", "Honored", "Revered", "Exalted")) else None,
                "reputation": r.get("reputation"), "requiredSkill": skill,
                "webOther": [], "webNotes": "; ".join(c.get("notes") for c in checks if isinstance(c.get("notes"), str)) or None})

# Extra recipes the web lists for these vendors that QuestieDB doesn't (one source: unconfirmed).
known = {r["recipeSpellID"] for r in out}
for e in extras:
    sp = e.get("recipeSpellID")
    if not sp or sp in known:
        continue
    vendors = [{"npc": v["npcID"], "name": v.get("name"), "zone": None, "faction": None, "confirmed": False,
                "evidence": ["web"], "sources": e.get("sources", []), "limited": False, "inClassicList": False}
               for v in e.get("vendors", []) if v.get("npcID")]
    if not vendors:
        continue
    cost = e.get("cost") or {}
    out.append({"recipeSpellID": sp, "recipeName": e.get("itemName"), "profession": e.get("profession"),
                "recipeItems": [e["itemID"]] if e.get("itemID") else [], "status": "vendor", "set": "forever-new",
                "vendors": vendors, "removed": [], "drops": [], "quests": [], "favor": cost.get("favor"),
                "campStanding": None, "reputation": None, "requiredSkill": None, "webOther": [],
                "webNotes": e.get("notes")})
    known.add(sp)

doc = json.load(open(OUT, encoding="utf-8"))
doc["recipes"] = [r for r in doc["recipes"] if r.get("set") != "forever-new"] + out
doc["about"] = ("WoW Forever recipe vendors, checked 2026-11-13: classic list (LibProfessionDB) vs QuestieDB "
                "Forever vs Forever web sources, plus the new Forever vendors (Merchant's Favor supply camps "
                "and others). See docs/DATA.md.")
json.dump(doc, open(OUT, "w", encoding="utf-8", newline="\n"), indent=1, ensure_ascii=False)
conf = sum(1 for r in out if any(v["confirmed"] for v in r["vendors"]))
print(skipped, "skipped (not in Forever);", len(out), "new recipes,", conf, "with a confirmed vendor,",
      sum(1 for r in out if r["favor"]), "with a Favor cost,", sum(1 for r in out if r["campStanding"]), "need camp standing")
