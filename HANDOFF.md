# Handoff — branch `claude/project-understanding-whv1v7`

A working note for whoever picks this branch up on a Mac. Not a release
document; delete it before this branch is ever merged anywhere public.

## Status

**Built and installed.** Debug and Release both compile for simulator and device,
and all five scripts in `scripts/` pass under a real `xcrun swiftc`. One compile
error in roughly 2,000 new lines: `DirectPathProbe.shortReason` needed
`nonisolated`, since it is called from `NWConnection`'s handler on the
connection's own queue.

The four structural checks that used to be listed here as risks all passed
untouched. In particular **Xcode 26.6 does accept one synchronised folder shared
by two targets**, so `RoamControlShared` needed no manual target membership — the
warning that used to be at the top of this note was wrong.

**Still unverified: the section 4 smoke test.** It needs a physical device and
manual interaction, and the Mac had no iOS 27 simulator runtime, so even
interface-only checks were blocked. Identity migration, the stop button, Live
Activity lifecycle, offline landmark search, the Chinese error path and dark mode
are all still waiting on a person.

Environment note: on a Homebrew Python 3.14, two scripts fail to `import plistlib`
because its `pyexpat` links a newer `libexpat` than the system one. Use
`/usr/bin/python3`.

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

### Result so far

The direct path answered. Run twice; the second with the USB cable unplugged, to
rule out the connection riding a USB bridge:

```
Bonjour IPv4: 10.0.0.120:49152        -> REACHABLE in 1ms
Bonjour IPv6: fe80::...%en0:49152     -> REACHABLE in 0ms
LocalDevVPN (control): 10.7.0.1:49152 -> REACHABLE in 1ms
```

On Wi-Fi, with no cable, the pairing service answers on the iPhone's own LAN
address. The prediction written here — that only `10.7.0.1` would answer — was
wrong.

### What that does not yet establish

Three things, in order of how cheaply they settle it:

1. **LocalDevVPN was connected during both runs**, because it is the control. If
   it is doing something that makes the listener reachable at all, the result is
   an artefact. Disconnect it completely and re-run: `10.7.0.1` should fail, and
   the question is whether the Bonjour rows still pass.
2. **Loopback is now probed too.** If a resolved address answers but `127.0.0.1`
   does not, the service wants a real interface address — which would explain why
   LocalDevVPN exists at all, and means the direct path depends on having a
   routable local address.
3. **Mobile data has no LAN address.** The app already has a separate mobile-data
   flow. Run the experiment with Wi-Fi off; LocalDevVPN is likely still required
   there, which would make this a Wi-Fi-only simplification rather than a
   removed dependency.

A probe proves one TCP connection. **Settings → Connection Health → Use the
direct path for sessions** carries it through a whole session — pair-verify, the
tunnel, RSD, DVT — which is the only thing that settles it. It is off by default
and appears only once a direct address has answered. Turn it off if a session
fails to start.

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
- 14 interpolated accessibility labels are in the catalogue in `%@` placeholder
  form, with the placeholder types inferred. A wrong type means that one label
  shows English; nothing breaks.
- There is still no test target. Adding one remains the highest-value next step:
  `coordinate(at:)`, `cumulativeDistanceValues`, `FailureStage.classify`,
  `LocationTarget.isSamePlace` and the identity migration are all pure logic.
