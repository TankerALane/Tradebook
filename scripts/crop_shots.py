"""Crop the screenshots taken by /tb shots down to the Tradebook window.

After /tb shots, /reload (or log out) so TradebookDB.dev.shots is written, then run:

    python -I scripts/crop_shots.py "<WoW>/_forever_" [account folder]

It reads the window position saved for each step, finds the screenshots taken during that
run in _forever_/Screenshots (in order), and writes cropped PNGs to assets/screenshots/
as 01-recipe.png, 02-skillup-filter.png, ... Needs ffmpeg/ffprobe and luajit on PATH.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "screenshots"
PAD = 1  # pixels of margin around the window (more picks up chat text at the edges)


def find_saved_variables(wow, account):
    base = wow / "WTF" / "Account"
    accounts = [base / account] if account else [p for p in base.iterdir() if p.is_dir() and p.name != "SavedVariables"]
    for acc in accounts:
        sv = acc / "SavedVariables" / "Tradebook.lua"
        if sv.exists():
            return sv
    sys.exit("Tradebook.lua saved variables not found under %s" % base)


LUA_DUMP = r"""
dofile(arg[1])
local s = TradebookDB and TradebookDB.dev and TradebookDB.dev.shots
if not s then os.exit(2) end
print(s.startedAt)
for i, step in ipairs(s.steps or {}) do
  local r = step.rect
  print(string.format("%s %.6f %.6f %.6f %.6f", step.name, r.left, r.right, r.top, r.bottom))
end
"""


def read_shots(sv):
    """Load the saved variables with LuaJIT (Tradebook's own file) and read dev.shots."""
    script = Path(__file__).with_name("_dump_shots.lua")
    script.write_text(LUA_DUMP, encoding="utf-8")
    try:
        out = subprocess.run(["luajit", str(script), str(sv)], capture_output=True, text=True)
    finally:
        script.unlink(missing_ok=True)
    if out.returncode == 2:
        sys.exit("no shots recorded: run /tb shots, then /reload")
    if out.returncode != 0:
        sys.exit("could not read %s: %s" % (sv, out.stderr.strip()))
    lines = out.stdout.split("\n")
    started = int(lines[0])
    steps = []
    for line in lines[1:]:
        parts = line.split()
        if len(parts) == 5:
            steps.append((parts[0], dict(zip(("left", "right", "top", "bottom"), map(float, parts[1:])))))
    return started, steps


def image_size(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=width,height", "-of", "json", str(path)], capture_output=True, text=True, check=True)
    s = json.loads(out.stdout)["streams"][0]
    return s["width"], s["height"]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    wow = Path(sys.argv[1])
    sv = find_saved_variables(wow, sys.argv[2] if len(sys.argv) > 2 else None)
    started, steps = read_shots(sv)
    shots = sorted((p for p in (wow / "Screenshots").iterdir()
                    if p.suffix.lower() in (".jpg", ".png", ".tga") and p.stat().st_mtime >= started - 5),
                   key=lambda p: p.stat().st_mtime)
    if len(shots) < len(steps):
        sys.exit("found %d screenshots after the run started, expected %d" % (len(shots), len(steps)))
    # The newest ones: a later run without /reload keeps the same window rects (fixed size,
    # centred), so its pictures still crop correctly.
    shots = shots[-len(steps):]
    OUT.mkdir(parents=True, exist_ok=True)
    for i, ((name, r), shot) in enumerate(zip(steps, shots), start=1):
        w, h = image_size(shot)
        x0 = max(0, int(r["left"] * w) - PAD)
        y0 = max(0, int(r["top"] * h) - PAD)
        x1 = min(w, int(r["right"] * w) + PAD)
        y1 = min(h, int(r["bottom"] * h) + PAD)
        dest = OUT / ("%02d-%s.png" % (i, name))
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(shot), "-vf",
                        "crop=%d:%d:%d:%d" % (x1 - x0, y1 - y0, x0, y0), str(dest)], check=True)
        print("%s  <-  %s" % (dest.relative_to(ROOT), shot.name))


if __name__ == "__main__":
    main()
