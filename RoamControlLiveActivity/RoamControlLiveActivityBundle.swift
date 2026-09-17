import SwiftUI
import WidgetKit

/// The extension exists only to render the session Live Activity. It holds no
/// Home Screen widgets, reads no app data and has no network access.
@main
struct RoamControlLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        RoamSessionLiveActivity()
    }
}
