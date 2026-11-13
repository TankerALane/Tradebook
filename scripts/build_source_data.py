"""Build Tradebook/Data/SourceData.lua.

Inputs:
  * LibProfessionDB's WoW Forever data (recipe sources, NPC names, required skill).
    LibProfessionDB (c) 2026 Pimptasty, MIT License. Parsed as TEXT; nothing executed.
  * Forever's own SkillLineAbility table (skill-up thresholds), exported as CSV from
    https://wago.tools/db2/SkillLineAbility/csv?build=<forever build>
    Yellow starts at TrivialSkillLineRankLow, grey at TrivialSkillLineRankHigh, green at
    floor((low + high) / 2). Checked in game: matched all 166 colours the game reported.
    (LibProfessionDB derived yellow from MinSkillLineRank, which Forever sets to 1 for
    every recipe, so ~400 of its thresholds were wrong.)

usage: python -I scripts/build_source_data.py <ProfessionDB/Data/Forever/_core> <version> \
           <SkillLineAbility.csv> <forever build>
"""
import csv
import re
import sys
from pathlib import Path

CORE = Path(sys.argv[1])
VERSION = sys.argv[2] if len(sys.argv) > 2 else "unknown"
SLA_CSV = Path(sys.argv[3]) if len(sys.argv) > 3 else None
SLA_BUILD = sys.argv[4] if len(sys.argv) > 4 else "unknown"
SKILL_LINES = {171, 164, 333, 202, 165, 197, 185, 129, 356, 182, 186, 393}
OUT = Path(__file__).resolve().parent.parent / "Tradebook" / "Data" / "SourceData.lua"

PROFESSION_FILES = {
    "Alchemy": 171, "Blacksmithing": 164, "Cooking": 185, "Enchanting": 333, "Engineering": 202,
    "Firstaid": 129, "Fishing": 356, "Leatherworking": 165, "Mining": 186, "Tailoring": 197,
}

MIT = """MIT License

Copyright (c) 2026 Pimptasty

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."""


def read(name):
    return (CORE / name).read_text(encoding="utf-8")


def borrowed(text, field):
    out = set()
    for m in re.finditer(r'LoadBorrowed\("%s",\s*"[^"]*",\s*\{([\d,\s]*)\}\)' % field, text):
        out.update(int(x) for x in m.group(1).split(",") if x.strip())
    return out


def parse_sources():
    text = read("Sources.lua")
    sources = {}
    for m in re.finditer(r"^\[(\d+)\]=\{(.*)\},?\s*$", text, re.M):
        rid = int(m.group(1))
        body = m.group(2)
        entry = {}
        for km in re.finditer(r"([a-z])=\{([\d,]*)\}", body):
            entry[km.group(1)] = [int(x) for x in km.group(2).split(",") if x]
        for km in re.finditer(r"([a-z])n=(\d+)", body):
            entry[km.group(1) + "n"] = int(km.group(2))
        sources[rid] = entry
    return sources, borrowed(text, "sources")


def parse_names():
    text = read("SourceNames.lua")
    names = {}
    for m in re.finditer(r'^\[(\d+)\]="((?:[^"\\]|\\.)*)",?\s*$', text, re.M):
        names[int(m.group(1))] = m.group(2)
    return names


def parse_acquire():
    text = read("AcquireMethods.lua")
    return {int(a): int(b) for a, b in re.findall(r"^\[(\d+)\]=(\d+),?\s*$", text, re.M)}


def parse_levels():
    """recipeID -> (skillLine, requiredSkill, [orange, yellow, green, grey]); plus borrowed requiredSkill ids."""
    levels, borrowed_req = {}, set()
    entry_re = re.compile(r"^\t\t\[(\d+)\] = \{\s*$")
    for fname, skill in PROFESSION_FILES.items():
        path = CORE / (fname + ".lua")
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        borrowed_req |= borrowed(text, "requiredSkill")
        lines = text.splitlines()
        i = 0
        while i < len(lines):
            m = entry_re.match(lines[i])
            if not m:
                i += 1
                continue
            rid = int(m.group(1))
            j = i + 1
            req, diff = None, []
            while j < len(lines) and lines[j] != "\t\t},":
                rm = re.match(r'^\t\t\t\["requiredSkill"\] = (\d+),', lines[j])
                if rm:
                    req = int(rm.group(1))
                if lines[j].startswith('\t\t\t["difficulty"] = {'):
                    k = j + 1
                    while not lines[k].strip().startswith("}"):
                        num = lines[k].strip().rstrip(",")
                        if num.isdigit():
                            diff.append(int(num))
                        k += 1
                j += 1
            levels[rid] = (skill, req, diff)
            i = j + 1
    return levels, borrowed_req


def lua_list(nums):
    return "{" + ",".join(str(n) for n in nums) + "}"


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def apply_skill_line_ability(levels):
    """Replace thresholds with Forever's own SkillLineAbility values (and add missing recipes)."""
    if not SLA_CSV:
        return 0
    replaced = 0
    from_game = set()
    for row in csv.DictReader(SLA_CSV.open(encoding="utf-8")):
        skill = int(row["SkillLine"])
        low, high = int(row["TrivialSkillLineRankLow"]), int(row["TrivialSkillLineRankHigh"])
        if skill not in SKILL_LINES or high <= 0:
            continue
        rid = int(row["Spell"])
        _, req, _ = levels.get(rid, (skill, None, []))
        orange = max(1, min(req or 1, low))
        levels[rid] = (skill, req, [orange, low, (low + high) // 2, high])
        from_game.add(rid)
        replaced += 1
    # Only Forever's own numbers: drop thresholds for anything not in its table.
    for rid, (skill, req, _) in list(levels.items()):
        if rid not in from_game:
            levels[rid] = (skill, req, [])
    return replaced


def main():
    sources, borrowed_sources = parse_sources()
    names = parse_names()
    acquire = parse_acquire()
    levels, borrowed_req = parse_levels()
    from_game = apply_skill_line_ability(levels)

    used_npcs = set()
    for entry in sources.values():
        for k in ("t", "v", "d"):
            used_npcs.update(entry.get(k, []))

    out = []
    out.append("-- Data/SourceData.lua")
    out.append("-- PURE. GENERATED by scripts/build_source_data.py from LibProfessionDB %s (WoW Forever data)." % VERSION)
    out.append("-- Do not hand-edit; re-run the script instead.")
    out.append("--")
    out.append("-- Recipe sources, trainer/vendor/drop NPC names (English) and required skill from")
    out.append("-- LibProfessionDB; values marked borrowed come from Vanilla and are unconfirmed for Forever.")
    if from_game:
        out.append("-- Skill-up thresholds from Forever's own SkillLineAbility table, build %s (via wago.tools)." % SLA_BUILD)
    out.append("--")
    out.append("-- Source data adapted from LibProfessionDB:")
    for line in MIT.splitlines():
        out.append(("-- " + line).rstrip())
    out.append("")
    out.append("local _, ns = ...")
    out.append("")
    out.append("-- [recipeID] = { t/v/d = npc ids, q = quest ids, c = container item ids, <k>n = true count,")
    out.append("--                 a = acquire method (1 = learned with the profession), b = borrowed }")
    out.append("ns.SourceData = {")
    ids = sorted(set(sources) | {rid for rid, v in acquire.items() if v == 1})
    for rid in ids:
        entry = sources.get(rid, {})
        parts = []
        for k in ("t", "v", "d", "q", "c"):
            if k in entry:
                parts.append("%s=%s" % (k, lua_list(entry[k])))
            if k + "n" in entry:
                parts.append("%sn=%d" % (k, entry[k + "n"]))
        if acquire.get(rid) == 1:
            parts.append("a=1")
        if rid in borrowed_sources:
            parts.append("b=true")
        out.append("[%d]={%s}," % (rid, ",".join(parts)))
    out.append("}")
    out.append("")
    out.append("ns.SourceNames = {")
    for npc in sorted(used_npcs):
        if npc in names:
            out.append("[%d]=%s," % (npc, lua_str(names[npc])))
    out.append("}")
    out.append("")
    out.append("-- [recipeID] = { skillLine, requiredSkill, orange, yellow, green, grey, borrowedRequired }")
    out.append("ns.RecipeLevels = {")
    for rid in sorted(levels):
        skill, req, diff = levels[rid]
        diff = (diff + [0, 0, 0, 0])[:4]
        flag = ",true" if rid in borrowed_req else ""
        out.append("[%d]={%d,%d,%d,%d,%d,%d%s}," % (rid, skill, req or 0, diff[0], diff[1], diff[2], diff[3], flag))
    out.append("}")
    out.append("")
    OUT.write_text("\n".join(out), encoding="utf-8", newline="\n")
    print("wrote %s: %d sources, %d npc names, %d recipe levels (%d thresholds from the game table)"
          % (OUT, len(ids), len(used_npcs & set(names)), len(levels), from_game))


if __name__ == "__main__":
    main()
