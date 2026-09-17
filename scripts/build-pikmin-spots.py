#!/usr/bin/env python3
"""Builds the bundled Pikmin spot catalogue from the piki knowledge base.

The app ships the result rather than fetching it: choosing a place is the one
thing that has to keep working with no network, which is the same reason the
landmark catalogue is bundled. Nothing here is read at runtime from anywhere
but the app bundle.

Usage: python3 scripts/build-pikmin-spots.py [path-to-piki]
"""
import json, sys, pathlib

PIKI = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/Users/chung/piki")
OUT = pathlib.Path(__file__).resolve().parent.parent / "RoamControl/Resources/PikminSpots.json"

# The two sources name the same place type differently. Keeping the spot
# spelling as canonical, because that is what the coordinates are filed under.
ALIASES = {
    "橋梁": "橋樑", "漢堡店": "漢堡", "咖啡廳": "咖啡杯", "化妝品商店": "化妝品",
    "咖哩餐廳": "咖哩", "自助洗衣店與乾洗店": "自助洗衣店&乾洗店", "日本神社": "神社和寺廟",
    "文具": "文具店", "壽司餐廳": "壽司", "大學與學院": "大學&學院",
}

def load(name):
    return json.load(open(PIKI / "tools/out" / name, encoding="utf-8"))

spots, types = [], set()
for r in load("purespots.json"):
    if r.get("Lat") is None or r.get("Lon") is None: continue
    t = r.get("Type") or "其他"
    types.add(t)
    spots.append({"n": r["Name"], "la": round(r["Lat"], 6), "lo": round(r["Lon"], 6),
                  "t": t, "c": r.get("City") or "", "d": r.get("District") or "", "s": "p"})

for r in load("postcards.json"):
    if r.get("緯度") is None: continue
    spots.append({"n": r["名稱"], "la": round(r["緯度"], 6), "lo": round(r["經度"], 6),
                  "t": "明信片", "c": r.get("國家") or "", "d": r.get("種類") or "", "s": "c"})

for r in load("pikoohiong.json"):
    if r.get("緯度") is None: continue
    spots.append({"n": r["名稱"], "la": round(r["緯度"], 6), "lo": round(r["經度"], 6),
                  "t": "菇點", "c": r.get("國家") or "", "d": r.get("地點") or "", "s": "m"})

decorations = []
for d in load("decor.json"):
    t = ALIASES.get(d["地點類型"], d["地點類型"])
    decorations.append({"n": d["飾品"], "t": t, "matched": t in types})

unmatched = [d["n"] for d in decorations if not d["matched"]]
doc = {"version": 1,
       "decorations": [{"n": d["n"], "t": d["t"]} for d in decorations],
       "spots": spots}
OUT.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
print(f"{len(spots):,} spots, {len(decorations)} decorations, "
      f"{len(unmatched)} unmatched -> {OUT.name} ({OUT.stat().st_size/1024:.0f} KB)")
if unmatched: print("unmatched:", unmatched)
