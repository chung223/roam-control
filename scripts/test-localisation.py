#!/usr/bin/env python3
"""Fails when interface text cannot reach a reader in their own language.

There are two ways for that to happen, and this repository has produced both
repeatedly.

The first is a literal with no entry in the String Catalog. Nothing complains;
the key is shown instead, which is the English, so it looks like a translation
that was simply never done.

The second is subtler and caused most of the actual bugs. `Text("literal")`
localises itself through `LocalizedStringKey`, but the moment the same text is
passed as a `String` — to a `title:` parameter, or returned from a computed
property — it takes the verbatim overload and stays English no matter what the
catalogue says. Onboarding shipped four of these, the Lock Screen shipped two,
and the empty states shipped two more, all with translations sitting unused in
the catalogue. `String.appText` exists for exactly this, so a literal that needs
it and does not have it is what this looks for.

Deliberate English is listed below rather than inferred, because every case of
it is load-bearing: a message that classifies telemetry, a symbol name that is
API, or a report written to be pasted into a bug.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Files whose English is not interface text and must not be translated.
#
#   FailureStage.classify matches session failure messages exactly, the session
#   coordinator matches them to decide recoverability, and
#   scripts/test-failure-stages.py asserts on them. SessionMessage.localized
#   translates them on the way to the screen instead.
#
#   The diagnostics report and the direct-path experiment are written to be
#   pasted into a bug report, so they stay in one language.
EXEMPT_FILES = {
    "RoamControl/Services/UsageAnalyticsService.swift",
    "RoamControl/Services/BackgroundTaskIdentifier.swift",
    "RoamControl/Services/BackgroundLocationKeepAlive.swift",
    "RoamControl/Services/Pairing/PairingService.swift",
    "RoamControl/Services/Pairing/OnDevicePairingCoordinator.swift",
    "RoamControl/Services/Tunnel/LocalDeviceSessionCoordinator.swift",
    "RoamControl/Services/Tunnel/ConnectionDiagnosticsCoordinator.swift",
    "RoamControl/Services/Tunnel/DirectPathProbe.swift",
    "RoamControl/Services/Tunnel/ResolvedServiceAddress.swift",
    "RoamControl/Features/Settings/ConnectionHealthView.swift",
    "RoamControl/Resources/SessionMessage.swift",
    "RoamControl/Models/LandmarkCatalogue.swift",
    # Compiled into both targets, so it cannot use the app's appText. Its
    # English is the key the extension's own catalogue is looked up by.
    "RoamControlShared/RoamSessionActivityAttributes.swift",
    # Its English is addressed to the model, not to a reader: tool
    # descriptions, @Guide hints and the text a tool answers with. Translating
    # any of it would change what the model does. The two things it does say
    # to a reader go through appText like everything else.
    "RoamControl/Services/PlaceFinder.swift",
}

# Not text a reader sees: SF Symbol names, reverse-DNS identifiers, Info.plist
# and API keys, URLs, format specifiers, and single words that are code.
NOT_TEXT = re.compile(
    r"""^(
        [a-z][a-z0-9]*([._][a-z0-9]+)+          # sf.symbol.names, key.paths
      | (com|org|net)\.[A-Za-z0-9.\-]+          # reverse DNS
      | (CF|NS|UI|BG|LS)[A-Za-z]+               # framework plist keys
      | https?://.*
      | [A-Za-z0-9_\-]*(Key|Identifier|Domain|Token|Header|Timestamp)
      | [%$][@a-zA-Z0-9]*
      | [\s\W]*
    )$""",
    re.VERBOSE,
)

# Initialisers and modifiers that take a LocalizedStringKey: a literal here
# localises itself and must not be wrapped.
LOCALISING = (
    "Text|Label|Button|Picker|Toggle|Section|NavigationLink|TextField|Link|"
    "LabeledContent|ContentUnavailableView|Stepper|ProgressView|Annotation|"
    "Alert|Slider|Menu|DisclosureGroup"
)
LOCALISING_CALL = re.compile(r"\b(" + LOCALISING + r")\(")
LOCALISING_MODIFIER = re.compile(
    r"\.(navigationTitle|accessibilityLabel|accessibilityHint|help|alert|"
    r"confirmationDialog|searchable|textFieldStyle|tabItem)\("
)
# Argument labels that are themselves declared LocalizedStringKey.
LOCALISING_LABEL = re.compile(r"\b(prompt|titleKey|label|message|description):\s*$")
# Already a lookup; wrapping it again would look the translation up twice.
# `String(localized:` is often split over two lines, leaving `localized:`
# alone in front of the literal and `String(` on the line before. Either half
# means the lookup is happening.
ALREADY_LOOKED_UP = re.compile(
    r"String\(localized:\s*$|LocalizationValue\(\s*$|(^|[\s(])localized:\s*$"
)
# Matched against, not shown. Translating one of these breaks the comparison,
# which is the whole reason the failure messages stay English.
COMPARISON = re.compile(
    r"(==|!=|contains|hasPrefix|hasSuffix|range\(of|localizedCaseInsensitiveContains)"
    r"[\s(]*$"
)

LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
# Names of things, not text: an asset, a bundled file, an SF Symbol argument.
NAMING_CALL = re.compile(
    r"(Image|forResource|systemImage|named|withExtension|imageNamed|"
    r"NSLocalizedString|Notification\.Name|systemImageName)\(?\s*:?\s*$"
)
# App Intents localise their own text: anything typed LocalizedStringResource,
# and the titles and descriptions the framework reads, are translated by it.
INTENT_TEXT = re.compile(
    r"LocalizedStringResource|IntentDescription\(|TypeDisplayRepresentation\(|"
    r"DisplayRepresentation\(|@Parameter\(|AppShortcut\(|shortTitle:|"
    r"needsValueError\(|IntentDialog\(|requestValue\(|"
    r"AlarmButton\(|AlarmPresentation|LocalizedStringResource|phrases:"
)
# How far back to look for the marker. A Siri phrase list puts `AppShortcut(`
# and `phrases:` several lines above the phrases themselves, and every phrase
# after the first has only another phrase on the line before it.
INTENT_LOOKBACK = 6
# Session failure text: English is its identity, and SessionMessage.localized
# translates it on the way to the screen. Same reason as EXEMPT_FILES.
FAILURE_CALL = re.compile(r"\.(failed|fail)\(\s*$")
# Prose a person reads: at least one space between words, or a capitalised word.
PROSE = re.compile(r"^[A-Z“(]?[A-Za-z].*$")


# An interpolation in source and a format specifier in a catalogue key are
# the same hole seen from two sides. Both become this, so the two can be
# compared at all.
PLACEHOLDER = "\u0000"
INTERPOLATION = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
SPECIFIER = re.compile(r"%(?:@|lld|ld|lf|[dsf])")


def placeheld(text):
    """The shape of a string, with whatever varies reduced to one token.

    `Text("Page \\(n) of \\(total)")` is looked up by the key `Page %lld of
    %lld`, so neither form can be found by searching for the other. Reducing
    both to the same shape is the only comparison that means anything — and
    without it every interpolated string is uncheckable, which is how three of
    them sat untranslated on the busiest screen in the app.
    """
    text = text.replace("%%", "%")
    text = INTERPOLATION.sub(PLACEHOLDER, text)
    return SPECIFIER.sub(PLACEHOLDER, text)


def unescape(literal):
    """The text a Swift literal means, not the text it is written as.

    A catalogue key is the string's value, so `\\n` in source is a newline by
    the time anything is looked up. Comparing the written form against the
    catalogue reports every such string as missing while it is plainly there.
    """
    return (
        literal.replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace('\\"', '"')
        .replace("\\\\", "\\")
    )


def catalogue_keys(path):
    if not (ROOT / path).exists():
        return set()
    keys = set(json.loads((ROOT / path).read_text(encoding="utf-8"))["strings"])
    # Both spellings, so a lookup can use whichever it has.
    return keys | {placeheld(key) for key in keys}


def swift_files():
    # Every target with interface text. A folder missing from here is not
    # checked and passes silently, which is how the watch app shipped its
    # first screen in English only.
    for base in ("RoamControl", "RoamControlLiveActivity", "RoamControlShared", "RoamControlWatch"):
        for path in sorted((ROOT / base).rglob("*.swift")):
            yield path


def check():
    # Siri phrases live in their own catalogue, which is where the system
    # looks for them; a string translated in either is translated.
    app_keys = catalogue_keys("RoamControl/Resources/Localizable.xcstrings")
    app_keys |= catalogue_keys("RoamControl/Resources/AppShortcuts.xcstrings")
    widget_keys = catalogue_keys("RoamControlLiveActivity/Localizable.xcstrings")
    watch_keys = catalogue_keys("RoamControlWatch/Localizable.xcstrings")

    missing = []      # not in any catalogue
    unwrapped = []    # in the catalogue, but used where it cannot be looked up

    for path in swift_files():
        rel = str(path.relative_to(ROOT))
        if rel in EXEMPT_FILES:
            continue
        if "Watch" in rel:
            keys = watch_keys
        elif "LiveActivity" in rel or "Shared" in rel:
            keys = widget_keys
        else:
            keys = app_keys

        source = path.read_text(encoding="utf-8").splitlines()
        for number, line in enumerate(source, 1):
            stripped = line.strip()
            if stripped.startswith("//"):
                continue

            for match in LITERAL.finditer(line):
                text = match.group(1)
                if len(text) < 4 or NOT_TEXT.match(text) or not PROSE.match(text):
                    continue

                if " " not in text and not text[0].isupper():
                    continue

                before = line[: match.start()]
                if (
                    NAMING_CALL.search(before)
                    or FAILURE_CALL.search(before)
                    or ALREADY_LOOKED_UP.search(before)
                    # `String(\n    localized: "…")` puts the call on the line
                    # above, which is where multi-line ones always put it.
                    or ALREADY_LOOKED_UP.search(source[number - 2] if number >= 2 else "")
                    or COMPARISON.search(before)
                    or INTENT_TEXT.search(line)
                    or any(
                        INTENT_TEXT.search(source[index])
                        for index in range(max(0, number - 1 - INTENT_LOOKBACK), number - 1)
                    )
                ):
                    continue
                # The app wraps with appText; the extension has its own
                # ActivityText, since it compiles none of the app's code.
                trailing = before.rstrip()
                wrapped = trailing.endswith(".appText(") or trailing.endswith(
                    "ActivityText.localized("
                )
                # A multi-line call puts the opener on an earlier line, so the
                # line above counts as much as the text before the literal.
                above = source[number - 2].rstrip() if number >= 2 else ""
                localising = bool(
                    LOCALISING_CALL.search(before)
                    or LOCALISING_MODIFIER.search(before)
                    or LOCALISING_LABEL.search(before)
                    or (
                        (
                            before.strip() in ("", "?", ":")
                            or before.rstrip().endswith("?")
                            or before.rstrip().endswith(":")
                        )
                        and (
                            LOCALISING_CALL.search(above)
                            or LOCALISING_MODIFIER.search(above)
                            or LOCALISING_LABEL.search(above)
                            or above.endswith("?")
                            or above.endswith(":")
                        )
                    )
                )
                # A literal alone on its line belongs to the call above it.
                if not localising and re.match(r'^\s*"', line):
                    localising = False

                # Looked up by value rather than by the way it is written.
                # The heuristics above run on the written form on purpose: a
                # real newline in the middle defeats the prose test, and a
                # string skipped there is a string never checked at all.
                key = unescape(text)
                if key not in keys and placeheld(key) not in keys:
                    missing.append((rel, number, text))
                elif not wrapped and not localising:
                    unwrapped.append((rel, number, text))

    return missing, unwrapped


def main():
    missing, unwrapped = check()

    if missing:
        print(f"{len(missing)} interface strings are not in a String Catalog:\n")
        for rel, number, text in missing[:40]:
            print(f"  {rel}:{number}\n      {text[:90]}")
        if len(missing) > 40:
            print(f"  … and {len(missing) - 40} more")
        print()

    if unwrapped:
        print(
            f"{len(unwrapped)} strings are translated but reach the screen in "
            f"English, because they are passed as String rather than as a "
            f"LocalizedStringKey. Wrap them in .appText(…):\n"
        )
        for rel, number, text in unwrapped[:40]:
            print(f"  {rel}:{number}\n      {text[:90]}")
        if len(unwrapped) > 40:
            print(f"  … and {len(unwrapped) - 40} more")
        print()

    if missing or unwrapped:
        sys.exit(1)

    print("Localisation checks passed; no interface string reaches the screen untranslated.")


if __name__ == "__main__":
    main()
