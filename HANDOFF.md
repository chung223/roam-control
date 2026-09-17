# Handoff — branch `claude/project-understanding-whv1v7`

A working note for whoever picks this branch up on a Mac. Not a release
document; delete it before this branch is ever merged anywhere public.

## The one thing to know first

**None of this has been compiled.** There is no macOS or Xcode in the environment
the changes were written in. What *was* verified:

- All five scripts in `scripts/` pass (the four needing `xcrun` had only their
  compile step stubbed; every source-level assertion ran).
- `project.pbxproj` parses structurally: 32 object ids defined, 32 referenced,
  none dangling, braces and sections balanced.
- 212 localisable keys referenced in source, 212 present in the catalogue.
- All 54 failure messages the native bridge and session code can produce have
  translations, and their English is unchanged in the source.

That is not the same as building. Expect the first build to need fixes.

## First build

```sh
git checkout claude/project-understanding-whv1v7

cat > Configuration/Local.private.xcconfig <<'EOF'
DEVELOPMENT_TEAM = YOUR-TEAM-ID
ROAMCONTROL_BUNDLE_ID = com.yourname.sprout
EOF

open RoamControl.xcodeproj
```

`Local.private.xcconfig` is gitignored. Both targets derive their bundle
identifier from `ROAMCONTROL_BUNDLE_ID`, so setting it once covers the app and
the Live Activity extension. An extension identifier that is not prefixed by
its host app's is rejected at install time, which is why they are tied together.

### Check these four things, in this order

1. **`RoamControlShared` must belong to both targets.** It is listed in
   `fileSystemSynchronizedGroups` for `RoamControl` and for
   `RoamControlLiveActivity`. If Xcode does not honour a synchronised folder
   shared by two targets, the symptom is the extension failing with
   `cannot find 'RoamSessionActivityAttributes' in scope`. Fix by ticking the
   folder into the extension's target membership. This is the single most
   likely thing to be wrong — the pbxproj was hand-edited.

2. **The `RoamControlLiveActivity` target should exist** as an app extension,
   embedded in the app via an *Embed Foundation Extensions* phase. 14 pbxproj
   objects were added by hand to create it.

3. **`SproutTheme` resolves everywhere.** It is new and referenced from
   `HomeView`, `LocationSelectionCard`, `ConnectionBadge`, `LandmarksView` and
   `ConnectionHealthView`, plus the `sproutCard()` / `sproutMapControl()` view
   modifiers.

4. **Traditional Chinese appears.** Project → Info → Localizations should list
   Chinese (Traditional). To see it: Scheme → Run → Options → App Language →
   繁體中文. The simulator is fine for checking the interface; it cannot pair or
   start a session.

## The experiment this branch was written for

**Settings → Connection Health → Direct Path Experiment → Run.**

Needs a physical iPhone. The simulator reports so and stops.

### Why it exists

The session path connects to a hardcoded `10.7.0.1` — the address LocalDevVPN
provides — and never uses the addresses Bonjour already resolved for the pairing
service. See `LocalDeviceSessionCoordinator.verifyServiceIsReachable`: it
resolves the service to get the port and TXT record, then throws the resolved
addresses away and dials `Self.localDevVPNPeerAddress`.

Everything *after* that first hop already runs inside the app: pair-verify, the
TLS-PSK tunnel, the userspace TCP stack (`tcp::adapter::Adapter` from idevice's
`tunnel_tcp_stack` feature), the RSD handshake and DVT. So LocalDevVPN's entire
job is providing a route for one TCP connection.

The experiment asks whether that route is actually necessary.

### What it does

Resolves `_remotepairing._tcp`, verifies device identity with the same
`rc_pairing_record_matches_service` check the session path uses, then opens a TCP
connection to each resolved address and to `10.7.0.1` as a control, recording
which answered. Loopback addresses are skipped; they prove nothing.

It is read-only by construction — no session control, no location calls, no
telemetry, every connection closed without a byte sent. The verification pass
asserts those symbols are absent from `DirectPathProbe.swift` rather than
trusting the intention.

### Reading the result

| Result | Meaning | Next step |
| --- | --- | --- |
| A Bonjour address answered | LocalDevVPN may be unnecessary for this hop | Confirm with a full session before relying on it. If it holds, the dependency can be removed entirely — no entitlement, no network extension |
| Only `10.7.0.1` answered | The tunnel app is required | Question settled. Do **not** spend weeks on a `NEPacketTunnelProvider`: it would still occupy the one packet-tunnel slot iOS allows, so it would not let Surge coexist either |
| Nothing answered | Not a result | Check LocalDevVPN is connected and the paired iPhone is awake, then re-run |

A split result is informative on its own. If IPv6 link-local answers but IPv4
does not, the service is bound to a specific interface, and that says a lot about
where a hand-built tunnel would have to sit.

The expectation going in is that only `10.7.0.1` answers — LocalDevVPN existing
at all is decent evidence the direct path does not work. Worth one button press
to know rather than assume.

### What to capture

Tap **Copy Experiment Result**. It contains local network addresses, so glance at
it before pasting anywhere. It is deliberately kept out of *Copy Diagnostics*,
which promises to contain no such thing.

## What is on this branch

| Commit | |
| --- | --- |
| `6b2f3c8` | `LocationTarget` identity fix, Live Activity, landmark catalogue |
| `3b30313` | Extension bundle identifier derived from one value |
| `7693ef7` | Traditional Chinese localisation |
| `e78a114` | Sprout rebrand and botanical visual system |
| `cdfbd2d` | Direct path experiment |

Two structural decisions worth knowing before changing anything:

- **Failure messages stay English in the source.** `FailureStage.classify`
  matches them exactly to classify telemetry, the session coordinator matches
  them to decide recoverability, and `scripts/test-failure-stages.py` asserts on
  them. `SessionMessage.localized` translates on the way to the screen instead.
  Translating at the source breaks all three silently.

- **The rebrand is display-only.** `CFBundleDisplayName` changed and the String
  Catalog carries an `en` value for the 57 keys naming the product. Target names,
  folders and the native strings still say Roam Control on purpose, for the
  reason above.

## Still open

- The app icon is still the old `RoamControl-AppIcon.png`.
- `SettingsView`, `ConnectionHealthView`, `AboutRoamControlView`,
  `PairingSetupView`, `WalkingRoutePreviewCard`, `SavedPlacesView` and
  `OnboardingView` still use system blue rather than the Sprout palette.
- 14 interpolated accessibility labels are in the catalogue in `%@` placeholder
  form, with the placeholder types inferred. A wrong type means that one label
  shows English; nothing breaks.
- There is still no test target. Adding one remains the highest-value next step:
  `coordinate(at:)`, `cumulativeDistanceValues`, `FailureStage.classify`,
  `LocationTarget.isSamePlace` and the identity migration are all pure logic.
