import SwiftUI

@main
struct RoamControlWatchApp: App {
    @State private var link = WatchLink()

    var body: some Scene {
        WindowGroup {
            WatchSessionView()
                .environment(link)
        }
    }
}
