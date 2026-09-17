import SwiftUI

struct AboutRoamControlView: View {
    var body: some View {
        List {
            appSummary
            quickStart

            Section("Choose a location") {
                guideRow(
                    .appText("Search"),
                    symbol: "magnifyingglass",
                    text: .appText("Find a place by name or enter latitude and longitude. Choosing a result also clears the search ready for the next one.")
                )
                guideRow(
                    .appText("Tap the map"),
                    symbol: "hand.tap",
                    text: .appText("Drop a precise pin anywhere on the map. The close button on its card clears that pin.")
                )
                guideRow(
                    .appText("Favourite"),
                    symbol: "heart",
                    text: .appText("Save the selected place for quick use later. Favourites can be renamed, reordered or removed from the saved-locations screen.")
                )
                guideRow(
                    .appText("Favourites & history"),
                    symbol: "list.bullet.rectangle",
                    text: .appText("Open saved favourites and recently used locations. Swipe an item to remove it.")
                )
            }

            Section("Map controls") {
                guideRow(
                    .appText("Current location"),
                    symbol: "location.fill",
                    text: .appText("Fly back to this iPhone’s real location and return the map to north-up.")
                )
                guideRow(
                    .appText("Compass"),
                    symbol: "safari",
                    text: .appText("Appears when the map is rotated. It shows the map heading; tap it to face north again.")
                )
                guideRow(
                    .appText("Connection status"),
                    symbol: "circle.fill",
                    text: .appText("Shows whether Roam Control is ready, connecting or active. Tap it for pairing and connection details.")
                )
                guideRow(
                    .appText("Settings"),
                    symbol: "gearshape.fill",
                    text: .appText("Change appearance and map style, check the connection, manage pairing and view app information.")
                )
            }

            Section("Location control") {
                guideRow(
                    .appText("Start Location"),
                    symbol: "location.fill",
                    text: .appText("Start reporting the selected place as this iPhone’s location. LocalDevVPN must be connected.")
                )
                guideRow(
                    .appText("Update Location"),
                    symbol: "arrow.triangle.2.circlepath",
                    text: .appText("Move an active location session to a newly selected place without restarting the whole connection flow.")
                )
                guideRow(
                    .appText("Stop & Restore"),
                    symbol: "location.slash.fill",
                    text: .appText("Confirm before ending the active session and restoring this iPhone’s real location.")
                )
                guideRow(
                    .appText("Mobile-data guidance"),
                    symbol: "antenna.radiowaves.left.and.right",
                    text: .appText("When using mobile data, temporarily turn it off when asked. Roam Control continues automatically once the local connection is available, and tells you when data can go back on.")
                )
                guideRow(
                    .appText("Interrupted-session recovery"),
                    symbol: "arrow.trianglehead.2.clockwise.rotate.90",
                    text: .appText("If Roam Control did not receive a normal end signal, the next launch offers to resume, reconnect briefly to restore the real location, or confirm that it is already back.")
                )
            }

            Section("Walking routes") {
                guideRow(
                    .appText("Preview Walking Route"),
                    symbol: "figure.walk",
                    text: .appText("Ask Apple Maps for a walking route from your current point to the selected destination before anything starts.")
                )
                guideRow(
                    .appText("Walking pace"),
                    symbol: "speedometer",
                    text: .appText("Choose how quickly the simulated location moves along the route.")
                )
                guideRow(
                    .appText("Start Walking"),
                    symbol: "figure.walk.motion",
                    text: .appText("Begin moving the reported location along the previewed route. The walk can continue while you use another app.")
                )
                guideRow(
                    .appText("Pause or Resume"),
                    symbol: "pause.fill",
                    text: .appText("Hold the current point on the route, then continue from exactly where it paused.")
                )
                guideRow(
                    .appText("Walk Route Back"),
                    symbol: "arrow.uturn.backward",
                    text: .appText("After arrival, reverse the journey and walk back along the route.")
                )
                guideRow(
                    .appText("New Location"),
                    symbol: "mappin.and.ellipse",
                    text: .appText("Keep the active session and return to the map so you can choose another destination.")
                )
                guideRow(
                    .appText("Stop & Restore"),
                    symbol: "stop.fill",
                    text: .appText("Stop walking, clear the route and restore the real location. A confirmation helps prevent accidental stops.")
                )
            }

            Section("Setup & support") {
                guideRow(
                    .appText("Pairing & Connection"),
                    symbol: "iphone.and.arrow.forward",
                    text: .appText("Pair this iPhone once so Roam Control can identify it through LocalDevVPN.")
                )
                guideRow(
                    .appText("Connection Health"),
                    symbol: "stethoscope",
                    text: .appText("Check pairing and the local connection without changing your location. You can also share a readable diagnostics report.")
                )
                guideRow(
                    .appText("Replay Introduction"),
                    symbol: "sparkles",
                    text: .appText("View onboarding again without deleting your pairing, favourites, history or preferences.")
                )
                guideRow(
                    .appText("Reset Roam Control"),
                    symbol: "arrow.counterclockwise",
                    text: .appText("Erase the pairing record and all saved app choices, then return to onboarding. LocalDevVPN itself is not changed.")
                )
            }
        }
        .sproutListBackground()
        .navigationTitle("About Roam Control")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appSummary: some View {
        Section {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(SproutTheme.Pair.moss)
                        .frame(width: 74, height: 74)

                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 5) {
                    Text("Roam Control")
                        .font(.title2.bold())

                    Text("Choose, test and move this iPhone’s reported location from one clean map.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
        }
    }

    private var quickStart: some View {
        Section {
            stepRow(1, .appText("Pair this iPhone once."))
            stepRow(2, .appText("Connect LocalDevVPN."))
            stepRow(3, .appText("Search, choose or drop a location."))
            stepRow(4, .appText("Start a fixed location or preview a walking route."))
        } header: {
            Text("How it works")
        } footer: {
            Text("Roam Control is intended for location-based app development and testing on your own device.")
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(SproutTheme.primary, in: Circle())

            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(number). \(text)")
    }

    private func guideRow(_ title: String, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(SproutTheme.primary)
                .frame(width: 26, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(text)")
    }
}

#Preview {
    NavigationStack {
        AboutRoamControlView()
    }
}
