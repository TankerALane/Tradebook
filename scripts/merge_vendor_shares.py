"""Merge /tb share submissions into the community vendor database.

Sources (any mix):
  --issues            open GitHub issues labelled "vendor-data" (needs the gh CLI); merged issues
                      are listed so they can be closed
  --file PATH         a text file with one or more pasted shares (starting with TBV1)
Stored databases: docs/research/community_vendors.json and community_trainers.json (in git).
Generated: Tradebook/Data/CommunityVendors.lua and CommunityTrainers.lua (what the addon loads).

Trainers (T and S lines): a trainer's name, profession and location come from its newest
report; each service (recipe or rank) keeps its newest fields, with the highest cost reported
(the price before reputation discounts).

Merge rules, per vendor and item:
  - a vendor's name and location come from its newest report;
  - an item's stock and token cost come from its newest report;
  - the gold price is the highest price reported (players with a reputation discount report less;
    the highest is the price before discounts);
  - items aren't removed when a later report lacks them (limited stock can be sold out), but each
    keeps the date it was last seen.
Every field is checked (numbers in range, names without markup); bad lines are skipped.

    python -I scripts/merge_vendor_shares.py --issues
    python -I scripts/merge_vendor_shares.py --file shares.txt
"""
import argparse, json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "docs", "research", "community_vendors.json")
OUT = os.path.join(ROOT, "Tradebook", "Data", "CommunityVendors.lua")
TDB = os.path.join(ROOT, "docs", "research", "community_trainers.json")
TOUT = os.path.join(ROOT, "Tradebook", "Data", "CommunityTrainers.lua")
SERVICE_OK = re.compile(r"^[^\x00-\x1f|~\\\"]{0,80}$")

NAME_OK = re.compile(r"^[^\x00-\x1f|~\\\"]{1,64}$")
COST_OK = re.compile(r"^((currency|item):\d{1,7}:\d{1,7};?)+$")


def parse(text):
    """Vendors and trainers from share text: ({ npc: { name, loc, seenAt, items } },
    { npc: { name, skill, loc, seenAt, services: { key: fields } } })."""
    vendors, cur, ok = {}, None, False
    trainers, tcur = {}, None
    for raw in text.splitlines():
        line = raw.strip().strip("`")
        f = line.split("~")
        if f[0] == "TBV1":
            ok = True
        elif f[0] == "V" and len(f) >= 7 and f[1].isdigit():
            npc = int(f[1])
            name = f[2].strip()
            if not (0 < npc < 10_000_000 and NAME_OK.match(name)):
                cur = None
                continue
            loc = None
            try:
                m, x, y = int(f[3]), float(f[4]), float(f[5])
                if 0 < m < 100_000 and 0 <= x <= 100 and 0 <= y <= 100:
                    loc = {"m": m, "x": round(x, 1), "y": round(y, 1)}
            except ValueError:
                pass
            seen = int(f[6]) if f[6].isdigit() else 0
            cur = vendors.setdefault(npc, {"name": name, "loc": loc, "seenAt": seen, "items": {}})
        elif f[0] == "T" and len(f) >= 8 and f[1].isdigit():
            npc, name = int(f[1]), f[2].strip()
            cur = None
            if not (0 < npc < 10_000_000 and NAME_OK.match(name)):
                tcur = None
                continue
            loc = None
            try:
                m, x, y = int(f[4]), float(f[5]), float(f[6])
                if 0 < m < 100_000 and 0 <= x <= 100 and 0 <= y <= 100:
                    loc = {"m": m, "x": round(x, 1), "y": round(y, 1)}
            except ValueError:
                pass
            tcur = trainers.setdefault(npc, {"name": name, "skill": int(f[3]) if f[3].isdigit() else None,
                                             "loc": loc, "seenAt": int(f[7]) if f[7].isdigit() else 0, "services": {}})
        elif f[0] == "S" and tcur is not None and len(f) >= 7:
            fields = [x.strip() for x in f[1:8]]
            while len(fields) < 7:
                fields.append("")
            if not all(SERVICE_OK.match(x) for x in fields):
                continue
            if fields[5] and not fields[5].isdigit():
                continue
            tcur["services"][fields[0] + "|" + fields[1]] = fields
        elif f[0] == "I" and cur is not None and len(f) >= 5 and f[1].isdigit():
            item = int(f[1])
            if not 0 < item < 10_000_000:
                continue
            p = int(f[2]) if f[2].isdigit() and 0 < int(f[2]) < 100_000_000 else None
            s = int(f[3]) if re.match(r"^-?\d+$", f[3]) and -1 <= int(f[3]) < 100_000 else -1
            c = f[4].strip() if COST_OK.match(f[4].strip()) else None
            cur["items"][item] = {"p": p, "s": s, "c": c, "seenAt": cur["seenAt"]}
    return (vendors, trainers) if ok else ({}, {})


def merge(db, vendors):
    added = 0
    for npc, v in vendors.items():
        key = str(npc)
        old = db.setdefault(key, {"name": v["name"], "loc": v["loc"], "seenAt": 0, "reports": 0, "items": {}})
        old["reports"] = old.get("reports", 0) + 1
        if v["seenAt"] >= old.get("seenAt", 0):
            old["name"] = v["name"]
            old["loc"] = v["loc"] or old.get("loc")
            old["seenAt"] = v["seenAt"]
        for item, it in v["items"].items():
            ik = str(item)
            o = old["items"].get(ik)
            if not o:
                old["items"][ik] = it
                added += 1
                continue
            if it["p"] and (not o.get("p") or it["p"] > o["p"]):
                o["p"] = it["p"]
            if it["seenAt"] >= o.get("seenAt", 0):
                o["s"], o["c"], o["seenAt"] = it["s"], it["c"] or o.get("c"), it["seenAt"]
    return added


def merge_trainers(db, trainers):
    added = 0
    for npc, t in trainers.items():
        key = str(npc)
        old = db.setdefault(key, {"name": t["name"], "skill": t["skill"], "loc": t["loc"], "seenAt": 0,
                                  "reports": 0, "services": {}})
        old["reports"] = old.get("reports", 0) + 1
        if t["seenAt"] >= old.get("seenAt", 0):
            old["name"], old["skill"] = t["name"], t["skill"] or old.get("skill")
            old["loc"] = t["loc"] or old.get("loc")
            old["seenAt"] = t["seenAt"]
        for skey, fields in t["services"].items():
            o = old["services"].get(skey)
            if not o:
                old["services"][skey] = fields
                added += 1
                continue
            cost = max(int(fields[5] or 0), int(o[5] or 0))
            if t["seenAt"] >= old.get("seenAt", 0):
                o[:] = fields
            o[5] = str(cost) if cost else o[5]
    return added


def write_trainers_lua(db):
    out = [
        "-- Data/CommunityTrainers.lua",
        "-- PURE. GENERATED by scripts/merge_vendor_shares.py from docs/research/community_trainers.json",
        "-- (trainer windows players shared with /tb share). Do not hand-edit.",
        "--",
        "-- [npcID] = { name, skill = skillLineID, loc = { m = uiMapID, x, y }, seenAt,",
        "-- services = { \"name|subText|type|level|skill req|cost|prof\" } } (as Core/Trainers.lua saves them)",
        "",
        "local _, ns = ...",
        "",
        "ns.CommunityTrainers = {",
    ]
    for key in sorted(db, key=int):
        t = db[key]
        loc = t.get("loc")
        locs = "loc={m=%d,x=%s,y=%s}," % (loc["m"], loc["x"], loc["y"]) if loc else ""
        services = ",".join(lua_str("|".join(f)) for _, f in sorted(t["services"].items()))
        out.append("[%s]={name=%s,skill=%s,%sseenAt=%d,services={%s}}," % (
            key, lua_str(t["name"]), t.get("skill") or "nil", locs, t.get("seenAt", 0), services))
    out += ["}", ""]
    open(TOUT, "w", encoding="utf-8", newline="\n").write("\n".join(out))


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_lua(db):
    out = [
        "-- Data/CommunityVendors.lua",
        "-- PURE. GENERATED by scripts/merge_vendor_shares.py from docs/research/community_vendors.json",
        "-- (vendor scans players shared with /tb share). Do not hand-edit.",
        "--",
        "-- [npcID] = { name, loc = { m = uiMapID, x, y }, seenAt, items = { [itemID] = { p = gold price",
        "-- (highest reported, i.e. before reputation discounts), s = stock (-1 unlimited), c = token cost } } }",
        "",
        "local _, ns = ...",
        "",
        "ns.CommunityVendors = {",
    ]
    for key in sorted(db, key=int):
        v = db[key]
        loc = v.get("loc")
        locs = "loc={m=%d,x=%s,y=%s}," % (loc["m"], loc["x"], loc["y"]) if loc else ""
        items = []
        for ik in sorted(v["items"], key=int):
            it = v["items"][ik]
            parts = []
            if it.get("p"): parts.append("p=%d" % it["p"])
            parts.append("s=%d" % it.get("s", -1))
            if it.get("c"): parts.append("c=%s" % lua_str(it["c"]))
            items.append("[%s]={%s}" % (ik, ",".join(parts)))
        out.append("[%s]={name=%s,%sseenAt=%d,items={%s}}," % (key, lua_str(v["name"]), locs, v.get("seenAt", 0), ",".join(items)))
    out += ["}", ""]
    open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(out))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--issues", action="store_true")
    ap.add_argument("--file", action="append", default=[])
    args = ap.parse_args()
    db = json.load(open(DB, encoding="utf-8")) if os.path.exists(DB) else {}
    tdb = json.load(open(TDB, encoding="utf-8")) if os.path.exists(TDB) else {}
    texts = []
    for path in args.file:
        texts.append(("file " + path, open(path, encoding="utf-8").read()))
    if args.issues:
        raw = subprocess.run(["gh", "issue", "list", "--label", "vendor-data", "--state", "open", "--limit", "200",
                              "--json", "number,body"], capture_output=True, text=True, check=True).stdout
        for issue in json.loads(raw):
            texts.append(("issue #%d" % issue["number"], issue["body"]))
    for label, text in texts:
        # One paste can hold several shares.
        for chunk in re.split(r"(?=TBV1~)", text):
            vendors, trainers = parse(chunk)
            if vendors or trainers:
                added = merge(db, vendors)
                tadded = merge_trainers(tdb, trainers)
                print("%s: %d vendors (%d new items), %d trainers (%d new services)" % (
                    label, len(vendors), added, len(trainers), tadded))
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    json.dump(db, open(DB, "w", encoding="utf-8", newline="\n"), indent=1, sort_keys=True)
    write_lua(db)
    json.dump(tdb, open(TDB, "w", encoding="utf-8", newline="\n"), indent=1, sort_keys=True)
    write_trainers_lua(tdb)
    print("community database: %d vendors, %d items; %d trainers, %d services" % (
        len(db), sum(len(v["items"]) for v in db.values()), len(tdb), sum(len(t["services"]) for t in tdb.values())))


if __name__ == "__main__":
    main()
