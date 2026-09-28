# Build and Release Guide

This guide covers development builds and the TestFlight upload workflow.

## Current release identity

- Marketing version: `0.12.0`
- Current build: `70`
- Bundle identifier: supplied by `ROAMCONTROL_BUNDLE_ID` in the ignored private configuration
- Minimum deployment target: iOS 27.0
- Supported device family: iPhone
- Display name: Sprout
- Targets: `RoamControl`, `RoamControlLiveActivity` (embedded extension), `RoamControlWatch` (embedded watch app)

`scripts/test-release-invariants.py` counts the version settings, so the count
it expects is one Debug/Release pair per target. Adding a target means updating
that count; a target whose version drifts from its host app is rejected on
install.

The minimum is 27.0 because of a device capability, not a compiled API. On-device
pairing — an iPhone pairing with its own developer services through the six-digit
code in Settings — does not exist below iOS 27, which has been tested on an iOS 26
device: the code never appears.

This is worth stating because it is invisible to the compiler. The project builds
cleanly against the iOS 26 SDK with the target set to 26.0, and no availability
guard anywhere would have flagged it. Lowering the target therefore produces a
build that installs, launches and cannot pair, which makes every other feature
unreachable. Apple documents none of this; the pairing path is reached through a
third-party reimplementation of an undocumented protocol.

MapKit sets a lower floor of its own — `MKReverseGeocodingRequest` and
`MKMapItem.address` are iOS 26 APIs — but it is not the binding one.

The version and build are shown in **Settings** inside the app. The built date and time come from the timestamp embedded for that packaged build.

## Version and build rules

Roam Control uses two separate numbers:

- The **version** describes the public release. Increase it for each public beta or stable release; the first stable release will become `1.0.0`.
- The **build** identifies one exact install. Increase it once for every build installed on a test iPhone or packaged as an IPA.

Ordinary compile checks do not consume a build number. Build numbers must never move backwards for a later install or upload.

Both values are stored in the target build settings:

- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`

Keep the Debug and Release configurations identical.

## Build in Xcode

1. Open `RoamControl.xcodeproj`.
2. Select the **RoamControl** scheme.
3. Select the connected iPhone.
4. Open **Signing & Capabilities** and confirm the development team.
5. Press **Run**.

The simulator can validate most interface states, but it cannot perform the real RPPairing handshake or start a location session.

## Type-checking time

Debug builds warn when a function body or an expression takes longer than
250ms to type-check:

    OTHER_SWIFT_FLAGS = -Xfrontend -warn-long-function-bodies=250
                        -Xfrontend -warn-long-expression-type-checking=250

This exists because the compiler's own limit arrives as a cliff rather than a
slope. A SwiftUI `body` that grows past what inference will do in one piece
fails with "unable to type-check this expression in reasonable time", pointing
at an arbitrary line inside it, and the only remedy is to take the whole thing
apart. `HomeView` reached that point at around five hundred lines, having
absorbed additions on the limit for some time with no sign anything was wrong.

The threshold is set above everything in the project — the slowest is about
150ms — so it is silent today and speaks when something roughly doubles. Debug
only: it is a development aid, and a release build should not be measuring
itself.

## Native pairing engine

The spot catalogue is not in the repository either, and for a different reason:
it is generated from a collection that is not published with this project.
`scripts/build-pikmin-spots.py` writes
`RoamControl/Resources/PikminSpots.json` from that collection, and the file is
ignored by git.

A checkout without it builds and runs; the spot browser is empty and nothing
else changes. `scripts/test-pikmin-catalogue.py` says so and passes, because a
checkout legitimately has none. `scripts/test-release-invariants.py` refuses,
because a release built without one ships an empty browser and says nothing
about it.


The prebuilt `Frameworks/RoamPairingFFI.xcframework` should be committed with both arm64 iPhone and arm64 Apple Silicon simulator slices.

Only rebuild it after changing `Native/RoamPairingFFI`. The rebuild requires Rust targets for:

- `aarch64-apple-ios`
- `aarch64-apple-ios-sim`

Run `scripts/build-pairing-engine.sh` from the project directory. Confirm the app still builds for both a physical iPhone and the simulator afterwards.

## Archive preparation

Before creating an archive:

1. Run the invariant scripts. They are quick, they need no device, and two of
   them exist because their failures are only visible partway through an upload:

   ```sh
   for s in scripts/test-*.py; do python3 "$s" || break; done
   ```

   `test-release-invariants.py` pins the version and build deliberately, so it
   fails until step 3 is done. That is the point of it.
2. Finish the regression checklist.
3. Increase `CURRENT_PROJECT_VERSION` for the archive, and update the two
   assertions in `scripts/test-release-invariants.py` that pin it.
4. Confirm the public version.
5. Use the Release configuration.
6. Confirm the app icon and display name.
7. Set and verify the build timestamp.
8. For a configured public build, set the self-hosted ingestion token and any TelemetryDeck identifiers in the ignored private configuration.
9. Confirm no live ingestion token is tracked or shown in the staged diff.
10. Confirm `RoamPairingFFI.xcframework` is embedded and signed.
11. Build once for a physical iPhone.

Then select **Any iOS Device (arm64)** and choose **Product → Archive**. Xcode opens Organizer after a successful archive.

## Upload to TestFlight

Three things were tried. What each one does is recorded here because the
difference between them is not guessable, and guessing it cost this project
several days of repeating a wrong explanation.

### Exporting: the command line does this

    xcodebuild -exportArchive \
      -archivePath "~/Library/Developer/Xcode/Archives/<date>/Sprout <version> (<build>).xcarchive" \
      -exportPath <output directory> \
      -exportOptionsPlist <options>.plist \
      -allowProvisioningUpdates

with `method` set to `app-store-connect` and `destination` to `export` in the
options plist. This works, with no key and nothing else set up, as long as an
`Apple Distribution` certificate for the team is in the keychain. It produces
a signed `.ipa`.

An earlier attempt failed with `No signing certificate "iOS Distribution"
found`, which named the older certificate type rather than the `Apple
Distribution` one that exists now, and that failure was then repeated as an
explanation long after it had stopped being true. Retry before believing it.

### Uploading: Organizer does this

**Xcode → Window → Organizer → Archives → the archive → Distribute App → App
Store Connect → Upload**

The same `xcodebuild -exportArchive` with `destination` set to `upload` did not
work. Exporting reaches the developer website, for profiles and signing;
uploading reaches App Store Connect, which is a different service with its own
authentication, and the session that satisfies it belongs to Xcode.

### Uploading without anyone present: not yet tried

An App Store Connect API key should remove the need for Organizer, since
`xcodebuild -help` names `-authenticationKeyPath`, `-authenticationKeyID` and
`-authenticationKeyIssuerID` as an alternative to an account in Xcode's
settings. That is what the flags say; nobody here has run it.

Create the key in App Store Connect under **Users and Access → Integrations →
App Store Connect API** with the App Manager role. The private key downloads
once and never again. The tools look for it at:

    ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8

Keep the key, its identifier and the issuer identifier out of this repository.
Anything holding them can publish as its owner.

A build number cannot be reused once App Store Connect has accepted it. A build
refused during validation does not consume its number.

Do not treat an Xcode Debug `.app` folder renamed to `.ipa` as a release
package. Use the verified Release archive workflow.

## Privacy statistics configuration

Optional statistics are sent by Roam Control's narrow first-party client. A configured release sends in parallel to the maintainer-operated HTTPS endpoint and TelemetryDeck's Ingest API. Roam Control does not embed an analytics SDK and permits only the event names and fixed fields defined in `UsageAnalyticsService.swift`.

Three private build settings configure those destinations:

- `ROAMCONTROL_SELFHOSTED_TELEMETRY_TOKEN`
- `ROAMCONTROL_TELEMETRY_APP_ID`
- `ROAMCONTROL_TELEMETRY_NAMESPACE`

The self-hosted ingestion token is sensitive configuration and must never be committed, printed in release notes or included in a patch. The TelemetryDeck App ID and namespace are ingestion identifiers rather than account credentials, but they remain blank in tracked defaults. Copy `Configuration/Local.private.xcconfig.example` to the ignored `Configuration/Local.private.xcconfig` and set values only for a configured local or release build. The same private file can hold the local `DEVELOPMENT_TEAM`.

The self-hosted endpoint URL is public configuration in `RoamControl-Info.plist`; without its private token it sends nothing. TelemetryDeck requires both of its private values. If both destinations are configured, the same consent-gated fixed event is sent to each in parallel. If neither destination is fully configured, no request is made.

Before packaging a configured build, inspect the event structure, confirm the privacy disclosure still matches it, and run the privacy rows in the regression checklist. Never add coordinates, place text, searches, saved locations, routes, pairing material, device names, user-supplied text or diagnostic content to an event.

## Release records

For each distributed build, record:

- Version and build number.
- Date and time created.
- Xcode and iOS versions used.
- Signing method and distribution route.
- Device used for testing.
- Regression checklist result.
- Known issues.

This makes a problem report traceable to the exact binary shown in Roam Control's Settings screen.
