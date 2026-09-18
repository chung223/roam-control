# Roam Control Regression Checklist

Use this checklist before uploading a build to TestFlight or declaring a development build stable. Test on the physical iPhone unless a row explicitly says the simulator is sufficient.

An unchecked row means untested, not failing. Rows added for a release stay unchecked until someone has actually seen the behaviour on hardware.

## Install and launch

- [ ] A clean install opens the four-page introduction.
- [ ] Introduction pages swipe and advance with Continue.
- [ ] The final page clearly shows the anonymous-statistics switch before setup completes.
- [ ] A clean install initially shows sharing disabled and sends nothing before affirmative opt-in.
- [ ] An existing installation preserves its previously saved sharing choice after updating.
- [ ] Set Up This iPhone opens Device Setup instead of dropping directly onto an unexplained map.
- [ ] An update install preserves pairing, favourites, history, appearance and map style.
- [ ] Settings shows the expected version and build. The built date is pinned in the project rather than generated, so it does not distinguish one build from another and cannot be used to tell whether an install is current.

## Pairing

- [ ] Pair This iPhone starts without crashing.
- [ ] The six-digit PIN is readable and accepted by iOS Settings.
- [ ] Successful pairing persists after relaunch.
- [ ] Import Existing File accepts a valid pairing record.
- [ ] An invalid record produces a readable error.
- [ ] Removing pairing requires confirmation and returns the app to Not paired.

## Map and search

- [ ] Live suggestions appear after two or more characters.
- [ ] Choosing a result dismisses the keyboard and clears the search text.
- [ ] Search accepts valid latitude/longitude coordinates.
- [ ] Invalid coordinates produce a readable error without changing location.
- [ ] Tapping the map drops a pin with one non-duplicated address description.
- [ ] Clear removes the selected pin/card state.
- [ ] Done dismisses the keyboard without covering the location card.
- [ ] The compass appears only when the map is rotated, tracks heading and returns north when tapped.
- [ ] Current location returns smoothly to the real position and north-up.

## Saved places

- [ ] Adding and removing a favourite updates immediately.
- [ ] A favourite can be renamed with a trailing swipe.
- [ ] Individual favourites and history rows can be deleted with a swipe.
- [ ] Clear Favourites and Clear History each require confirmation and affect only their own list.
- [ ] Choosing a saved place closes the list and selects it on the map.
- [ ] Resume Last Location works and its dismissal remains dismissed.

## Catalogue, Ask and Shortcuts

- [ ] Pikmin spots open from the map and list decorations, counties and countries.
- [ ] Spot lists sort nearest first, measured from wherever the map is looking.
- [ ] Sending a decoration to the map pins the spots that yield it.
- [ ] Searching the catalogue matches a place by its English or Chinese name.
- [ ] Landmarks show both languages, and search matches either spelling.
- [ ] The Ask tab is always present. On an ineligible iPhone it explains why it cannot answer instead of disappearing.
- [ ] Ask returns places that exist in the catalogue rather than invented ones.
- [ ] Ask answers in the language of the question.
- [ ] Pasting a coordinate pair into search selects that point.
- [ ] A `roamcontrol://location?lat=&lon=` link selects that point.
- [ ] Start Location, Start Location at Coordinates and Stop Location appear in Shortcuts and run without opening the app where they say they will not.
- [ ] The Action button and Siri run the same actions.
- [ ] A saved favourite appears as a choice in the Shortcuts action.

## Arrival alarm

- [ ] Session history records a fixed session and a walk, with plausible durations.
- [ ] A failed session is recorded as failed, with the message that caused it, translated.
- [ ] Force-closing during a session leaves that record as interrupted on the next launch.
- [ ] Restoring the real location does not add a record of its own.
- [ ] Clearing session history leaves favourites, history and pairing untouched.
- [ ] A favourite can be put in a group, moved between groups and taken out of one by clearing the name.
- [ ] A group disappears when its last member leaves it.
- [ ] Renaming a favourite keeps its group.
- [ ] Reordering inside a group still reorders, and survives relaunch.
- [ ] Exporting produces a readable file; importing it into a fresh install restores the favourites and their groups.
- [ ] Importing a file whose places are already saved adds nothing and says so.
- [ ] The watch app shows a running session, its progress and the countdown.
- [ ] Pause and resume on the watch act on the walk without opening the iPhone app.
- [ ] The watch says the iPhone is unreachable rather than showing a stale reading.
- [ ] The watch reads in Traditional Chinese, failure messages included.

- [ ] The setting is off on a clean install.
- [ ] Switching it on asks for alarm permission, and declining leaves the switch off rather than silently on.
- [ ] An alarm fires on arrival with the phone silenced.
- [ ] An alarm fires on arrival with a Focus active.
- [ ] Retargeting a walk replaces the alarm rather than leaving two.
- [ ] Pausing, stopping or arriving early cancels the alarm.

## Fixed location on Wi-Fi

- [ ] Before the first session attempt, copied diagnostics show location-task configuration `Not checked` and registration `Not attempted`.
- [ ] After a session reaches task submission, copied diagnostics show a matched permitted identifier and whether iOS accepted or rejected registration.
- [ ] Cancelling during connection cannot let an obsolete location-task callback start a replacement session.
- [ ] With LocalDevVPN connected, Start Location becomes active without mobile-data guidance.
- [ ] With LocalDevVPN disconnected, Roam Control opens it quickly and resumes automatically.
- [ ] Selecting another place and tapping Update Location changes the active location without restarting the flow.
- [ ] The active location persists while using another app.
- [ ] Stop & Restore requires confirmation, then restores the real location.
- [ ] The Dynamic Island activity has no accidental stop button.

## Fixed location on mobile data

- [ ] Roam Control opens LocalDevVPN when needed.
- [ ] Turn Mobile Data Off appears only for the mobile-data path.
- [ ] Turning mobile data off is detected automatically.
- [ ] Continue works as a manual fallback.
- [ ] Turn Mobile Data Back On appears only after the location session is active.
- [ ] The location remains active after 4G/5G is restored.
- [ ] An active location can be updated again without repeating startup.
- [ ] Stop restores the real location.

## Walking routes

- [ ] Preview Walking Route draws a plausible Apple Maps route.
- [ ] Distance uses yards/miles under UK regional settings.
- [ ] Pace changes update timing before the walk starts.
- [ ] Start Walking advances location along the route.
- [ ] Pause holds the current point and Resume continues from it.
- [ ] The walk continues while Apple Maps or another app is in front.
- [ ] Arrival holds the destination location.
- [ ] The Live Activity's pause button holds the walk without bringing the app forward, and resumes it.
- [ ] The Live Activity ends when the session ends, including when it ends in failure.
- [ ] Arrival stops the Live Activity's timer rather than letting it keep counting.
- [ ] A looping walk turns round and walks the route again.
- [ ] Walk Route Back reverses the journey.
- [ ] New Location allows a new destination without restoring the real location first.
- [ ] Stop & Restore requires confirmation and restores the real location.

## Recovery

- [ ] Force-closing during a fixed session shows interrupted-session recovery on relaunch.
- [ ] Resume Location reconnects to the saved location.
- [ ] Restore Real Location requires confirmation, clears the simulated location and leaves no new session active.
- [ ] Cancelling recovery restoration preserves the interrupted-session recovery options.
- [ ] Stop & Restore shows restoration progress for at least a moment before returning to Ready.
- [ ] My Real Location Is Already Back dismisses the recovery state.
- [ ] Force-closing during a walk offers Resume Walking from a recent saved point.
- [ ] Mobile-data recovery waits until data can be restored before finishing.

## Settings, diagnostics and reset

- [ ] Automatic, Light and Dark update the Settings screen immediately.
- [ ] Standard, Satellite and Hybrid update the map.
- [ ] Connection Health reports pairing, LocalDevVPN and location-session state accurately.
- [ ] Feedback links open the correct Bug Report and Feature Request forms.
- [ ] Share Diagnostics opens the iOS share sheet and contains no keys or PINs.
- [ ] About Sprout describes the current controls and flows.
- [ ] Replay Introduction does not delete app data.
- [ ] Privacy shows the sharing toggle and the complete What Is Shared disclosure.
- [ ] Disabling sharing takes effect immediately and remains disabled after relaunch.
- [x] Existing telemetry test build: with sharing disabled, two relaunches produced no new self-hosted event (9 events, maximum ID 9 and unchanged latest timestamp before and after).
- [x] Build 56 SideStore-installed release candidate: with sharing explicitly disabled, force-close and relaunch produced no new self-hosted event; after sharing was enabled, participation and activation events were accepted by the self-hosted backend.
- [ ] Separately verify that no TelemetryDeck request is produced while sharing is disabled.
- [ ] Disabling sharing while requests are in progress cancels them where possible and no later action sends until sharing is enabled again.
- [ ] A failed first participation request is retried on the next activation.
- [ ] An app activation is counted when the app returns from the background, without a duplicate cold-launch event.
- [ ] A failed active-location update does not send an active-location-updated event.
- [ ] A build without any complete private analytics destination sends no requests.
- [ ] A self-hosted-only build sends only to the self-hosted endpoint; a TelemetryDeck-only build sends only to TelemetryDeck; a fully configured build sends to both.
- [ ] Usage events never contain coordinates, place names, searches, routes, pairing data or diagnostics.
- [ ] The built app contains `PrivacyInfo.xcprivacy` with tracking disabled.
- [ ] Reset Roam Control clears app data, returns to onboarding and does not alter LocalDevVPN.

## Language

- [ ] Every screen reads in Traditional Chinese with the device set to it, including onboarding, empty states and the Lock Screen.
- [ ] Permission prompts read in Traditional Chinese.
- [ ] The Live Activity reads in Traditional Chinese.
- [ ] Failure messages read in Traditional Chinese while still classifying correctly in diagnostics, which stay English deliberately.

## Accessibility and layout

- [ ] Normal text size retains the intended clean layout.
- [ ] Accessibility text sizes keep every primary control reachable by scrolling.
- [ ] Walking metrics and compact controls stack rather than clip at large sizes.
- [ ] VoiceOver gives meaningful names to icon-only buttons and status rows.
- [ ] Touch targets are comfortably usable.
- [ ] Reduce Motion removes nonessential map, card and onboarding animations.
- [ ] Light and dark appearances retain readable contrast.
- [ ] Every glass control over the map responds to a tap. Glass alone is not hit-testable, so a control that looks right can still be dead.
- [ ] Map controls stay legible over both a pale street map and a dark satellite photograph.

## Final result

- [ ] No crash, hang or unexpected real-location restore occurred.
- [ ] No stale red error remained after a successful retry.
- [ ] Build succeeded in Release configuration.
- [ ] Version/build values match the planned package.
- [ ] Any known issue is recorded before distribution.
