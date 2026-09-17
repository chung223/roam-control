#!/usr/bin/env python3
"""Fails when an App Intent names an Apple product where Apple forbids it.

App Store Connect rejects a build whose App Intent titles, descriptions,
shortcut phrases or entity names mention a product:

    90626: Invalid Siri Support. App Intent description "Reports a pair of
    coordinates as this iPhone's location." cannot contain "iphone"

Nothing local catches this. The code compiles, the intent works on the device,
the archive builds, and the rejection arrives partway through an upload — after
the archive, after the export, after waiting for the delivery to validate. This
repository lost an upload to exactly that.

Every localisation is checked, not just the source. The metadata Apple reads is
built from the String Catalog, so a description rewritten in English while its
zh-Hant translation still says iPhone is rejected on the translation alone —
and the error quotes the English, which is by then correct, so the reason is
not obvious from the message.

Intent files are found by what they conform to rather than listed, so an intent
added in a new file is covered without anyone remembering to come back here.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# What marks a file as carrying intent metadata. AppEntity is here because its
# display representation is metadata too, and AppShortcutsProvider because the
# spoken phrases are the most visible part of it.
CONFORMANCES = (
    "AppIntent",
    "LiveActivityIntent",
    "AppEntity",
    "EntityQuery",
    "AppShortcutsProvider",
)

# Product names as the rejection matches them: case-insensitively, on a word
# boundary. `Mac` needs the boundary or it fires on "Machine"; `Apple` catches
# the hardware names not listed separately, and Siri is named in the rule.
PRODUCTS = (
    "iPhone", "iPad", "iPod", "Apple Watch", "Apple TV", "AirPods",
    "HomePod", "Apple Vision Pro", "Mac", "Apple", "Siri",
)
PRODUCT_RE = re.compile(
    r"\b(" + "|".join(re.escape(p) for p in PRODUCTS) + r")\b", re.IGNORECASE
)

STRING_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')

CATALOGUES = (
    "RoamControl/Resources/Localizable.xcstrings",
    "RoamControl/Resources/InfoPlist.xcstrings",
)


def intent_files():
    for path in sorted(ROOT.rglob("*.swift")):
        if ".build" in path.parts or "DerivedData" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        if any(c in text for c in CONFORMANCES):
            yield path, text


def main():
    offences = []
    literals = set()

    for path, text in intent_files():
        rel = path.relative_to(ROOT).as_posix()
        for number, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("///"):
                continue
            for match in STRING_RE.finditer(line):
                literal = match.group(1)
                literals.add(literal)
                found = PRODUCT_RE.search(literal)
                if found:
                    offences.append((rel, number, literal, found.group(1)))

    # The same strings, as every language ships them.
    for catalogue in CATALOGUES:
        path = ROOT / catalogue
        if not path.exists():
            continue
        entries = json.loads(path.read_text(encoding="utf-8")).get("strings", {})
        for key, entry in entries.items():
            if key not in literals:
                continue
            for lang, loc in sorted(entry.get("localizations", {}).items()):
                value = loc.get("stringUnit", {}).get("value", "")
                found = PRODUCT_RE.search(value)
                if found:
                    offences.append((f"{catalogue} [{lang}]", 0, value, found.group(1)))

    if offences:
        print(
            f"{len(offences)} App Intent strings name an Apple product. App Store "
            f"Connect rejects the build with error 90626, partway through the "
            f"upload. Say 'device' instead:\n"
        )
        for rel, number, literal, product in offences:
            where = f"{rel}:{number}" if number else rel
            print(f"  {where}\n      contains {product!r}: {literal[:90]}")
        print()
        sys.exit(1)

    print(
        f"Intent metadata checks passed; {len(literals)} strings across "
        f"{len(list(intent_files()))} files name no Apple product."
    )


if __name__ == "__main__":
    main()
