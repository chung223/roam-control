# Sprout 0.10.0 — Build 62

Build 62 is the current release of this fork: a source-available SwiftUI app for testing an iPhone's reported location from a clean Apple Maps interface. It supports fixed locations, simulated walking routes, favourites, history and native on-device pairing through LocalDevVPN.

It is the first release distributed through TestFlight, and the first to install as **Sprout** rather than Roam Control.

## Before installing

- Requires iOS 27 or newer.
- Requires Developer Mode and LocalDevVPN.
- Distributed through TestFlight. There is no public App Store listing and no published IPA.
- Intended only for development, quality assurance and responsible testing on a device the user owns and controls.

Read the [installation guide](Installation.md), [privacy explanation](Privacy.md) and [responsible-use policy](ResponsibleUse.md) before using it.

## What is new in 0.10.0

- A bundled catalogue of 10,505 Pikmin Bloom spots and 72 well-known landmarks, browsable by decoration, county or country and searchable with no network connection.
- Ask: a question like "where do I get a taco" answered against that catalogue by the on-device model, on iPhones that can run Apple Intelligence. A tool does the searching and the model only chooses, so a wrong answer is a wrong choice among real places rather than an invented one. Nothing is sent anywhere.
- Start and stop a session from the Action button, Siri, a Shortcut or the Share sheet, and from a `roamcontrol://location?lat=&lon=` link.
- Pause and resume a walk from the Live Activity. Stopping stays in the app, because it has to restore the real location and confirm the device accepted it.
- An optional alarm when a simulated walk arrives, which a notification cannot be relied on for while the phone is silenced or in a Focus.
- A walk can keep going after it arrives, turning round and walking the route again.
- Traditional Chinese throughout, including the Live Activity and the permission prompts. Landmarks read in both languages and search matches either spelling.
- The Sprout visual system, with the system's glass over the map in place of opaque cards.

## Changes worth knowing about

- Minimum iOS was briefly lowered to 26.0 and has been put back to 27.0. Pairing is the precondition for every other feature, and on iOS 26 the six-digit pairing code never appears in Settings, so the app would have installed and then been unusable — a worse outcome than not installing.
- Check for Updates is gone. It compared this app against a different project's releases, which was never a meaningful comparison, and TestFlight delivers updates now.
- Report a Bug and Request a Feature open issues on this repository rather than on the upstream project.

## Known gaps

Several device behaviours have not been verified on hardware yet: the quality of Ask's answers, the Live Activity pause button, the arrival alarm firing, and Live Activity dismissal when a session ends in failure. They are listed in the [regression checklist](RegressionChecklist.md) as unchecked rows rather than presented as tested.

## Reporting problems

Report ordinary bugs with the issue template, and security problems through a private GitHub security advisory. For pairing or connection problems, open **Connection Health** and use **Copy Diagnostics**. Never include pairing records, credentials or private locations.
