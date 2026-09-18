# Installation

This fork is distributed through TestFlight as **Sprout**. The upstream project published unsigned IPA files for users to sign themselves; that route still works if you build your own archive, but no IPA is published here.

## Requirements

- An iPhone running iOS 27 or newer. On-device pairing does not exist below 27: the six-digit code never appears in Settings, which has been tested rather than assumed.
- Developer Mode enabled under **Settings → Privacy & Security**.
- [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044) installed on the iPhone.
- TestFlight, or Xcode 26.6 or newer on a Mac with an Apple development team.

Two features need more than the minimum. Ask is offered only on iPhones that can run Apple Intelligence, and the arrival alarm asks for permission the first time it is switched on. Everything else works on any supported iPhone, and the app says so rather than hiding the control.

## Install with TestFlight

1. Accept the invitation and install TestFlight if it is not already installed.
2. Install Sprout from TestFlight.
3. Open it and complete the introduction and device-pairing flow.
4. Open LocalDevVPN and enable its local tunnel before starting a location.

TestFlight delivers updates itself and tells you when one is available. The app has no update check of its own.

A TestFlight build expires 90 days after it is uploaded. When it does, install the newer build rather than reinstalling the expired one; installing over the existing copy preserves pairing, favourites, history and settings. Deleting the app first also deletes its local settings and requires pairing again.

## Build with Xcode

1. Clone the repository and open `RoamControl.xcodeproj`.
2. Select the RoamControl target and choose your own team under **Signing & Capabilities**.
3. Select a connected iPhone and press **Run**.

The tracked build configuration has no Apple team, bundle identifier or TelemetryDeck destination of its own. Copy `Configuration/Local.private.xcconfig.example` to `Configuration/Local.private.xcconfig` and set yours there. That file is ignored by git and must never be committed, along with any other signing material.

The simulator can test the interface but cannot complete the physical iPhone pairing handshake or start a real location session.

## Check the project before building

Eight scripts assert invariants the compiler cannot. They are ordinary Python and need no simulator:

```sh
for s in scripts/test-*.py; do python3 "$s" || break; done
```

They cover background-session and task-identifier rules, failure-stage classification, failure telemetry, localisation reachability, the bundled spot catalogue, App Intent metadata and release invariants. A failure explains what it found and why it matters.

See the [user guide](UserGuide.md) for pairing and everyday operation, and the [build and release guide](BuildAndRelease.md) for archiving and uploading.
