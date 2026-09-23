# Roam Control User Guide

Roam Control lets you choose where your iPhone reports its location. You can hold one fixed place or simulate a walk along an Apple Maps route.

## First-time setup

You need your physical iPhone, Developer Mode and LocalDevVPN.

1. Open Roam Control and complete the four-page introduction.
2. On **Device Setup**, tap **Pair This iPhone**.
3. Allow Local Network access when iOS asks.
4. Open **Settings → Privacy & Security → Developer Mode → Pair with Roam Control**.
5. Enter the six-digit code shown by Roam Control.
6. Install LocalDevVPN from the Device Setup screen if it is not already installed.
7. Open LocalDevVPN and connect its local tunnel.

Pairing is normally required only once. Roam Control stores the pairing record in this iPhone's Keychain and does not upload it.

## Choose a location

Use any of these methods:

- Type a place into the search box and choose a live result.
- Enter coordinates such as `51.50740, -0.12780`.
- Tap anywhere on the map to drop a precise pin.
- Open the heart/list button to choose a favourite or recent location.
- Open the globe button to pick from the bundled landmark list.
- Open the Pikmin spots button to browse the bundled spot catalogue.
- Paste a coordinate pair straight into the search box.
- Use **Resume** when Roam Control offers the last used location.

Choosing a search result clears the search box automatically. The close button on a selected-location card clears a dropped pin or selection. The copy button copies the readable place and address.

### Landmarks

The globe button opens a searchable list of well-known places grouped by region. The list is bundled with the app, so it works without a network connection and sends nothing anywhere. Choosing one selects it on the map exactly as a search result would: it can be previewed, saved as a favourite or used as a walking destination, and starting a session remains a separate step.

Landmarks are named in both languages: the reader's own, with the English kept beside it, since that is what the signage and every other app call these places. Search matches either spelling.

### Pikmin spots

Any spot list offers **Plan a walk** through its nearest three, five or eight. The list is already sorted by distance from wherever the map is looking, so the count is the whole choice. Each stop is a separate directions request and Apple throttles them, which is why the counts are fixed rather than free.

The walk names the stop it is heading for, not the last one — the card, the Live Activity and the watch all move on as each is passed. A looping walk turns round at the end and calls at them again in reverse.

A second bundled catalogue holds Pikmin Bloom spots. Four tabs sort the same places different ways:

- **Decorations** lists what each decoration comes from, so a decoration can be sent to the map to pin the spots that yield it.
- **Counties** and **World** group spots by where they are.
- **Ask** answers a question about them, described below.

Lists sort nearest first, measured from wherever the map is currently looking rather than from the real location, so panning the map to a city re-sorts them around it.

### Ask

On iPhones that can run Apple Intelligence, the Ask tab takes a question such as "where do I get a taco" and answers it from the bundled catalogue.

The searching is done locally and the model only chooses among what was found, so an answer is a choice among real places rather than an invented one. The question, the candidates and the answer all stay on the iPhone; nothing is sent anywhere.

Where the on-device model is unavailable, the tab stays visible and says why rather than disappearing.

### Coordinates

### Building a walk yourself

The path control on the map opens the walk being planned, and shows how many stops are waiting.

Add to it from anywhere: choose a place — by searching, by tapping the map, from favourites, from landmarks, from the spot catalogue — and tap **Add to Walk** on its card. A spot list can add its nearest three, five or eight in one go. Stops are walked in the order they were added, and can be dragged to reorder or swiped away.

**Follow streets** decides what the line between two stops means:

- **On**: each leg is an Apple Maps walking route. This is the ordinary case, and it fails where Apple will not route — inside a park, a campus, open country.
- **Off**: the line goes straight from each place to the next, through whatever is in between. Nothing is asked of Apple Maps, so anywhere can be walked.

The setting is remembered, because it describes how you walk rather than any one walk.

### Walking a GPX file

**Import a GPX File** in the same screen walks a track recorded or drawn somewhere else, exactly as it was given. It replaces whatever stops were being assembled, since a file says where to go completely.

A coordinate pair typed or pasted into the search box, such as `28.472262, -81.473574`, selects that point directly. The same pair can be given to the Shortcuts action below, and a `roamcontrol://location?lat=28.472262&lon=-81.473574` link does the same thing from anywhere a link can be tapped.

Remember that such a link contains the coordinate. Sharing the link shares the place.

## Start a fixed location

1. Choose the location.
2. Tap **Start Location**.
3. Follow the LocalDevVPN guidance if it appears.
4. Wait for the status to show that the location is active.

There is no separate confirmation step after choosing a location.

To move an active session, choose another place and tap **Update Location**. Roam Control keeps the existing secure session and changes the location directly.

Tap **Stop & Restore** when you want iOS to return to the real location, then confirm the choice. Keep Roam Control open while it restores the real location. Roam Control deliberately does not place a stop control in the Dynamic Island, which helps prevent accidental stops while using another app.

## Wi-Fi connection flow

When Wi-Fi is connected, Roam Control looks for the iPhone through LocalDevVPN immediately.

- If LocalDevVPN is already connected, the location should start without mobile-data instructions.
- If its tunnel is unavailable, Roam Control opens LocalDevVPN automatically and returns to the pending session.
- If the connection still is not visible, the **Still Connecting** screen offers **Try Again** and **Open LocalDevVPN**.

Do not choose **I'm Using Mobile Data** while connected to Wi-Fi.

## Mobile-data connection flow

When the iPhone is using 4G or 5G:

1. Start the selected location.
2. Roam Control opens LocalDevVPN if necessary.
3. When **Turn Mobile Data Off** appears, temporarily switch mobile data off.
4. Return to Roam Control. It detects the local iPhone connection automatically.
5. If automatic detection does not continue, tap **Continue** as the manual backup.
6. When **Turn Mobile Data Back On** appears, restore mobile data and tap **Done**.

Only startup needs this temporary change. After the secure location session is active, it can continue while mobile data is back on.

## Walking routes

1. Choose a destination.
2. Tap **Preview Walking Route**.
3. Check the route, distance, estimated time and arrival time.
4. Choose a walking pace.
5. Tap **Start Walking**.

During the walk:

- **Pause** holds the current simulated point.
- **Resume** continues from that point.
- The walk can continue while another app is in front.
- **Stop & Restore** ends the walk and restores the real location after confirmation.

At the destination:

- **Walk Route Back** reverses the journey.
- **New Location** keeps the active connection and lets you choose another destination.
- **Stop & Restore** ends the session and restores the real location.

For UK regional settings, short distances are shown in yards and longer distances in miles.

## Map controls

- **Current location** flies to the iPhone's real position and turns the map north-up. It is unavailable while a simulated location is active.
- **Compass** appears after the map is rotated. It shows N, E, S and W; tap it to face north again.
- **Connection status** opens pairing and connection setup.
- **Favourites and history** opens saved places. Swipe an item to delete it; swipe a favourite to rename it.
- **Settings** controls appearance, map style, diagnostics, pairing, feedback, help and reset.

## Shortcuts, Siri and the Action button

Three actions are available to Shortcuts, Siri and the Action button:

- **Start Location** reports a saved favourite. It asks which one if a shortcut does not name it.
- **Start Location at Coordinates** takes a coordinate pair as text, which also covers the Share sheet.
- **Stop Location** ends the session and restores the real location.

Saved favourite names are offered to the system so a shortcut can choose among them. Coordinates are not.

### Running a Shortcut around a session

A workflow that turns something off before a session and back on afterwards splits in two, and only one half needs this app.

The first half is your own Shortcut, and the order matters:

```
Proxy: off  →  Tracker: off  →  Sprout: Start Location
```

LocalDevVPN is not a step. Sprout opens it itself when a session needs it.

The second half is **Settings → When a Session Ends**, where naming a Shortcut runs it after the real location is restored and when a walk reaches its destination. This is where turning those apps back on belongs, because that moment can arrive without you.

Two things are worth knowing. An app in the background cannot launch Shortcuts, so a walk that arrives while the iPhone is in a pocket runs yours the next time you open Sprout — the setting says when one is waiting. And Sprout cannot run anything *before* it connects, so a Shortcut named here is no use for turning a proxy off; that belongs in the first half.

## Feedback

Under **Settings → Session History**, past sessions are listed with where they went, how long they lasted and whether they finished, failed or were interrupted. A failure keeps the message that caused it. The last 50 are kept on the iPhone and are never sent anywhere.

Under **Settings → Feedback**, **Report a Bug** and **Request a Feature** open the matching GitHub form. Do not include pairing records, credentials or private locations in a report.

Updates arrive through TestFlight, which says when a new build is available. The app has no update check of its own.

## Interrupted-session recovery

If Roam Control closes without receiving a normal end signal, the next launch explains that the previous session may still be active.

- **Resume Location** reconnects to a fixed location.
- **Resume Walking** prepares the remaining route from the most recently saved point.
- **Restore Real Location** reconnects only long enough to clear the simulated location.
- **My Real Location Is Already Back** dismisses the recovery record without reconnecting.

Nothing starts automatically from this screen.

## Appearance and accessibility

Settings offers automatic, light and dark appearance plus standard, satellite and hybrid maps. Roam Control follows iOS Dynamic Type, VoiceOver and Reduce Motion settings. At accessibility text sizes, cards and pop-ups can scroll so their controls remain reachable.

## Background sessions

An active location session uses an iOS continued-processing task so it can remain reliable while Roam Control is in the background. iOS shows this task in the Dynamic Island and controls its presentation. You can swipe it up to keep it compact, but Roam Control continues to report task progress so iOS can keep the session running reliably.

### Live Activity

A running session also shows a Live Activity on the Lock Screen and in the Dynamic Island, so it stays obvious that the iPhone is reporting a chosen place rather than its real one. It shows the place name and session stage; a walk also shows progress, distance left and a countdown to arrival.

Tapping it opens the app. A walk's activity carries a pause button, which holds the walk where it is and starts it again without bringing the app forward. It carries no stop control: stopping has to restore the real location and confirm the iPhone accepted it, which belongs in the app. The activity disappears when the session ends, including when a session fails.

If the activity is missing, check **Settings → Sprout → Live Activities**. Sessions run normally either way.

### Arrival alarm

### On Apple Watch

If the iPhone has a paired Apple Watch, Sprout installs there too. The watch shows the place, how far along a walk is, the distance left and the countdown to arrival, and offers pause and resume.

It carries no stop control. Stopping has to restore the real location and confirm the iPhone accepted it, which belongs where it can be watched to the end.

The watch shows what the iPhone last told it. When the two are out of touch it says so rather than showing a stale reading as though it were current.

On a watch that supports the double tap gesture, tapping finger and thumb together twice holds the walk and starts it again, without touching the screen.

The watch taps your wrist when a walk arrives. That is separate from the arrival alarm in Settings, and neither one needs the other: an alarm sounds and is heard by the room, a tap is felt only by the person wearing the watch.

A walk of any length is not something to watch. Under Settings, an optional alarm can be set for when a simulated walk arrives.

It is an alarm rather than a notification deliberately: a notification is silenced by the ring switch and by a Focus, which is exactly the state a phone is in while it is being left to walk somewhere. It is off unless switched on, and switching it on asks for permission the first time.

The alarm follows the walk. Retargeting replaces it, and pausing, stopping or arriving early cancels it.

## Anonymous usage statistics

The final introduction page shows **Share Anonymous Usage Statistics** before setup completes. It is off by default and sends nothing unless you choose to switch it on. The choice can be changed at any time under **Settings → Privacy**.

When enabled, Roam Control reports only a small fixed list of activity counts: the app opening or returning to the foreground, app version/build, completed onboarding or pairing, starting a fixed or walking session, updating an already-active location, connection-help prompts, manual retries and successful sessions after retry, and fixed failure-stage, scheduler-reason, operation and recoverable/terminal categories (pairing, location or restoration). No raw error messages are sent. Roam Control adds an event time for its self-hosted service; TelemetryDeck adds its own approximate event time. Roam Control never includes coordinates, place names, searches, favourites, history, routes, pairing records, PINs, Apple ID, device name or diagnostics.

A random installation identifier is stored in local app storage and irreversibly hashed before sending. No per-launch session identifier is sent. Turning sharing off stops new reporting, cancels in-progress requests where possible and removes the local identifier, but it cannot withdraw anonymous events already received by either service. Configured beta builds send the same fixed event in parallel to Roam Control's maintainer-operated service and TelemetryDeck. The self-hosted HTTPS service necessarily receives ordinary connection metadata such as the source IP address, although it is not included in the event body. Daily maintenance deletes events older than 90 days from the live SQLite database; no fixed deletion schedule is promised for database backups or web-server access logs. TelemetryDeck says it does not store IP addresses and may retain anonymous events for roughly 7–10 years without guaranteeing an exact deletion date. Counts therefore describe participating installations rather than every installation.

Open **Settings → Privacy → What Is Shared** for the same disclosure inside the app. The complete policy is in [Privacy](Privacy.md).

## Favourites, history and reset

- Favourites remain until you delete them or reset the app.
- History stores the 30 most recently used locations.
- **Replay Introduction** shows onboarding without deleting anything.
- **Reset Roam Control** removes pairing, favourites, history and preferences, then returns to onboarding.
- Reset also removes the anonymous statistics identifier.
- Resetting Roam Control does not uninstall or reconfigure LocalDevVPN.

## Troubleshooting

### LocalDevVPN says Connected, but Roam Control cannot find the iPhone

Check whether you are using Wi-Fi or mobile data. On Wi-Fi, tap **Try Again**. On 4G or 5G, choose the mobile-data flow and briefly turn mobile data off. If the message mentions an outdated announcement, toggle LocalDevVPN off and on once to create a fresh device announcement.

### The discovered device does not match the paired iPhone

The saved pairing record belongs to a different device announcement. Toggle LocalDevVPN off and on. If the problem remains, open Device Setup, remove the pairing and pair this iPhone again.

### The real location is not visible after stopping

Keep Roam Control open for a few seconds while iOS obtains a fresh GPS result. Tap the current-location button after it becomes available. Also check that Location Services permission is allowed for Roam Control.

### A walking session ended unexpectedly

Reopen Roam Control and use the interrupted-session screen. Resume from the last saved point or choose **Restore Real Location**.

### I need a readable support report

Open **Settings → Connection Health**, run the connection check, then use **Share Diagnostics**. The report contains app, iOS and connection state information but no pairing keys or PINs.
