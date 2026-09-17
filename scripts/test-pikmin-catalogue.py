#!/usr/bin/env python3
"""Checks the bundled Pikmin catalogue is what the app expects to read.

The catalogue is generated from another repository, so nothing in this one
reviews it. That already went wrong once: the source files four kinds of
report — 菇點, 花點, 探測器 and a few 未知 — and the build script labelled
every record 菇點. It stayed wrong until the source grew from 417 rows to
3,525 and someone noticed 899 flower spots under a mushroom heading. Nothing
failed; the app simply said something untrue.

So this asserts the shape the app relies on rather than the contents, which
change every time the source is scraped again. It runs against the bundled
file, because that is what ships, and cross-checks the source only when the
source happens to be present.
"""
import json
import pathlib
import sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / "RoamControl/Resources/PikminSpots.json"
PIKI = pathlib.Path("/Users/chung/piki/tools/out")

# Taiwan plus the countries the postcards and field reports cover: a
# coordinate outside this is a parsing error, not a place.
LAT_RANGE = (-90.0, 90.0)
LON_RANGE = (-180.0, 180.0)
SOURCES = {"p", "c", "m"}

failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def main():
    check(CATALOGUE.exists(), f"{CATALOGUE.name} is missing")
    if failures:
        report()

    doc = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    spots = doc.get("spots", [])
    decorations = doc.get("decorations", [])

    check(len(spots) > 5000, f"only {len(spots)} spots; the catalogue should hold thousands")
    check(len(decorations) == 41, f"{len(decorations)} decorations, expected 41")

    # Every spot has to be somewhere, and be called something.
    bad_coordinates = [
        s for s in spots
        if not (LAT_RANGE[0] <= s.get("la", 999) <= LAT_RANGE[1])
        or not (LON_RANGE[0] <= s.get("lo", 999) <= LON_RANGE[1])
        or (s.get("la") == 0 and s.get("lo") == 0)
    ]
    check(not bad_coordinates, f"{len(bad_coordinates)} spots have impossible coordinates")

    unnamed = [s for s in spots if not str(s.get("n", "")).strip()]
    check(not unnamed, f"{len(unnamed)} spots have no name")

    untyped = [s for s in spots if not str(s.get("t", "")).strip()]
    check(not untyped, f"{len(untyped)} spots have no type")

    unknown_sources = {s.get("s") for s in spots} - SOURCES
    check(not unknown_sources, f"unknown source markers: {sorted(unknown_sources)}")

    # The bug this file exists for. A source that files several kinds must
    # still have several kinds after the build script has read it.
    by_source = Counter((s.get("s"), s.get("t")) for s in spots)
    for source in SOURCES:
        kinds = {t for (src, t) in by_source if src == source}
        count = sum(n for (src, _), n in by_source.items() if src == source)
        if count > 1000:
            check(
                len(kinds) > 1,
                f"source '{source}' has {count:,} spots but only one type "
                f"({kinds}) — a kind is being discarded, as 菇點 was",
            )

    # Every decoration has to resolve to a place type that exists, or the
    # decoration list offers somewhere a reader cannot go.
    spot_types = {s.get("t") for s in spots}
    unresolved = [d["n"] for d in decorations if d.get("t") not in spot_types]
    check(
        not unresolved,
        f"{len(unresolved)} decorations name a place type no spot has: {unresolved[:5]}",
    )

    # Cross-check the source when it is here. It usually is not, and the
    # catalogue still has to stand on its own when it is not.
    if PIKI.exists():
        totals = 0
        for name, lat_key in (("purespots.json", "Lat"),
                              ("postcards.json", "緯度"),
                              ("pikoohiong.json", "緯度")):
            path = PIKI / name
            if not path.exists():
                continue
            rows = json.loads(path.read_text(encoding="utf-8"))
            totals += sum(1 for r in rows if r.get(lat_key) is not None)
        if totals:
            check(
                len(spots) == totals,
                f"catalogue holds {len(spots):,} spots, the source has {totals:,} "
                f"with coordinates — regenerate with scripts/build-pikmin-spots.py",
            )

    report(spots, decorations)


def report(spots=None, decorations=None):
    if failures:
        print("Pikmin catalogue checks failed:\n")
        for message in failures:
            print(f"  - {message}")
        sys.exit(1)

    kinds = Counter(s["t"] for s in spots if s["s"] == "m")
    print(
        f"Pikmin catalogue checks passed; {len(spots):,} spots, "
        f"{len(decorations)} decorations, all resolving. "
        f"Field reports keep {len(kinds)} kinds."
    )


if __name__ == "__main__":
    main()
