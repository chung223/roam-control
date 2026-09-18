# Roam Control Privacy

Roam Control is designed to keep sensitive location and pairing information on the iPhone.

## Information that stays on the iPhone

Roam Control does not send:

- Coordinates, selected places or addresses.
- Search text, favourites or location history.
- Walking routes, route progress or pace.
- Pairing records, pairing PINs or cryptographic material.
- Apple ID, device name or personal details.
- Full connection diagnostic reports or support reports.

Pairing records are stored in the device-only Keychain. App preferences and saved places remain in local app storage.

### Live Activity

While a session runs, Roam Control shows a Live Activity on the Lock Screen and in the Dynamic Island. It displays the name of the chosen place, the session stage and, for a walk, progress and remaining time. It contains no coordinates.

That information is handed to iOS so the system can draw it, and it is visible on the Lock Screen without unlocking the iPhone. It is not sent anywhere and is not included in usage statistics. The activity ends when the session ends, including when a session fails. Live Activities can be turned off in **Settings → Sprout → Live Activities**; sessions run normally without it.

### The bundled catalogue

The landmark and Pikmin Bloom catalogues are files inside the app. Browsing them, searching them and sorting them by distance are local operations. No request is made for them, and which places are looked at is not recorded or sent.

### Ask

Ask is answered by Apple's on-device model. The question text is given to that model on the iPhone, along with the candidate places a local search over the bundled catalogue returned. Nothing about the question, the candidates or the answer leaves the device, and no request is made.

This is the reason the feature is allowed to exist here at all. Everything else in the app is bundled and offline precisely so that nothing about where someone wants to be is disclosed, and a cloud model would undo that in a single call.

Ask is offered only where the on-device model is available. Where it is not, the app says why rather than hiding the tab.

### Arrival alarm

The optional arrival alarm is scheduled with AlarmKit and is off unless switched on. The alert it schedules carries the destination's name, because an alarm that does not say what it is for is not useful. That name is handed to iOS so the system can show and sound the alarm, in the same way the Live Activity's place name is. It is not sent anywhere and is not included in usage statistics.

### Shortcuts, the Action button and links

### Session history

The record of past sessions — where, how long, and whether it finished — is kept on the iPhone. The last 50 are held and older ones are dropped. It is never sent anywhere and is not included in usage statistics. It can be cleared from **Settings → Session History**, and Reset removes it with everything else.

### Exported favourites

An exported file is made only when asked for and written only where you put it. Nothing uploads it, and the app keeps no copy of where it went. It is plain JSON, so its contents can be read before it is handed to anything. It carries saved places and their groups, and nothing else — no pairing material, no history, no diagnostics.

### Apple Watch

When a watch app is installed, the iPhone sends it what a running session looks like: the place name, how far along a walk is, the distance left and the arrival time. That goes between the two devices over Apple's own device-to-device link and reaches nothing else. The watch keeps only the last thing it was sent, and the only thing it can ask for in return is a pause.

The app offers actions to Shortcuts and Siri. So that the Shortcuts action can offer a saved place to choose from, saved favourite names are made available to the system's App Intents infrastructure on the device. Coordinates are not included in what is offered.

A `roamcontrol://location?lat=&lon=` link carries a coordinate in the link itself. A link you create therefore contains that coordinate, and sharing the link shares it. The app neither creates nor transmits such links on its own.

A Shortcut named under **When a Session Ends** is run by name through the Shortcuts app. Sprout passes it nothing — no place, no coordinate, no session detail — and receives nothing back beyond being reopened. What that Shortcut then does is between it and the apps it acts on.

## Optional anonymous usage statistics

The app offers **Share Anonymous Usage Statistics**. It is off by default. New users see the switch before finishing setup, and nothing is sent unless they affirmatively switch it on. Existing installations keep their previously saved choice when upgrading. The setting can be changed at any time under **Settings → Privacy**.

When sharing is enabled, the app may count:

- A participating installation opening the app or returning it to the foreground.
- Onboarding or pairing being completed.
- A fixed-location or walking session successfully starting.
- A location being updated during an active session.
- The app version and build associated with an event.
- An event time generated by Roam Control for the self-hosted service; TelemetryDeck adds its own approximate event time.
- Fixed failure context, stage, disposition and scheduler-reason categories when an operation fails or needs recovery.
- Fixed pairing- and location-task configuration and registration states for relevant scheduler failures.
- Background keep-alive method, requested/running status, permission or service failure category, and location scheduler registration availability. No location values are included.
- iOS version in events sent to the self-hosted service.
- The installed app bundle identifier and permitted background-task identifiers, sent only to the self-hosted service for scheduler registration or submission failures.

These are activity signals only. They do not contain the location, route or other user content involved in an action.

## Installation counting

The app creates a random identifier for the installation in its local app storage. It sends an irreversible SHA-256 hash so participating installations can be counted approximately without using a name, Apple ID, advertising identifier or hardware identifier. No per-launch session identifier is sent.

Turning sharing off prevents new events, cancels requests still in progress where possible and deletes the locally stored identifier. Turning it on again creates a new identifier, so activity before and after the opt-out cannot be linked by Roam Control. Turning sharing off cannot withdraw anonymous events already accepted by either destination. Those events do not contain a location or personal identity.

Statistics therefore describe participating installations, not every download or every person using Roam Control.

## Destinations and data minimisation

Roam Control uses its own narrow HTTPS sender rather than embedding a third-party analytics SDK. This keeps the request body limited to the fixed fields listed above and prevents an SDK from automatically adding device metadata.

A configured beta build sends the same consent-gated event in parallel to:

- A maintainer-operated, self-hosted Roam Control ingestion service running on a Raspberry Pi.
- TelemetryDeck's Ingest API.

The self-hosted service necessarily receives ordinary HTTPS connection metadata such as the source IP address, although Roam Control does not include it in the event body. Daily maintenance deletes events older than 90 days from the live SQLite database. No fixed deletion schedule is currently promised for database backups or web-server access logs.

TelemetryDeck states that it does not store IP addresses. It also states that cold-storage event retention is roughly 7–10 years and that an exact deletion schedule is not guaranteed. Its privacy information is available at [telemetrydeck.com/docs/guides/privacy-faq](https://telemetrydeck.com/docs/guides/privacy-faq/).

The tracked project includes the self-hosted endpoint URL but no ingestion token or TelemetryDeck identifiers. Each destination remains inactive unless its complete private build configuration is supplied. If neither destination is configured, the statistics client sends nothing.

## Changes

Any future change to the information collected must be reflected in this document and in the in-app **What Is Shared** screen before release.
