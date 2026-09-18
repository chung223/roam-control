# Build and Release Guide

This guide covers development builds and the TestFlight upload workflow.

## Current release identity

- Marketing version: `0.10.0`
- Current build: `62`
- Bundle identifier: supplied by `ROAMCONTROL_BUNDLE_ID` in the ignored private configuration
- Minimum deployment target: iOS 27.0
- Supported device family: iPhone
- Display name: Sprout

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

## Native pairing engine

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

Upload from Organizer, not from the command line:

**Xcode → Window → Organizer → Archives → the archive → Distribute App → App Store Connect → Upload**

`xcodebuild -exportArchive` fails here with `No Accounts` and `No signing
certificate "iOS Distribution" found`, because the App Store Connect session
lives in the Xcode GUI and `xcodebuild` cannot see it. An export can succeed
once and still leave no certificate behind for the next one, so treat Organizer
as the route rather than a fallback.

Two validation failures arrive partway through an upload rather than at build
time, which is why both now have a script:

- **Export compliance.** App Store Connect asks the encryption question once per
  build unless `ITSAppUsesNonExemptEncryption` is declared in
  `Configuration/RoamControl-Info.plist`. It is. Note that the app does use
  encryption the operating system does not provide: the Rust bridge carries its
  own standard implementations for pair-verify and the TLS-PSK tunnel.
- **Error 90626.** An App Intent title, description or shortcut phrase may not
  name an Apple product. `scripts/test-intent-metadata.py` checks every intent
  string and every localisation of it, because the metadata Apple reads is built
  from the String Catalog and a translation is rejected on its own.

A build number cannot be reused once App Store Connect has accepted it. A build
rejected during validation does not consume its number.

Do not treat an Xcode Debug `.app` folder renamed to `.ipa` as a release package. Use the verified Release archive workflow.

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
