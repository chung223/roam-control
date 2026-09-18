// A LiveActivityIntent is unavailable on watchOS, and the watch target
// compiles this folder. The watch asks for a pause over the link instead,
// which is a different mechanism for the same request.
#if !os(watchOS)
import AppIntents
import Foundation

/// Pausing a walk from the Live Activity.
///
/// The activity carries no other controls, deliberately: stopping has to
/// restore the real location and confirm the device accepted it, and that is
/// not something to fire off from a Lock Screen tap. Pausing is the opposite
/// kind of action — it changes nothing that cannot be changed straight back,
/// and the guidance names pause and resume as the case controls are for.
///
/// It lives here because both targets need the type: the extension draws the
/// button, the app runs it. A LiveActivityIntent runs in the app's process
/// without bringing it forward, which is the point — a walk is something you
/// leave running.
public struct ToggleWalkPauseIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Pause or Resume Walk"
    public static let description = IntentDescription(
        "Holds the walk where it is, or starts it moving again."
    )
    /// Not opened: the walk is already running, and bringing the app forward
    /// to press pause would defeat having the button here at all.
    public static let openAppWhenRun = false

    /// The walking controller is view state, which an intent cannot reach, so
    /// it listens for this instead. Same process, so the post arrives.
    public static let requested = Notification.Name("WalkPauseToggleRequested")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: Self.requested, object: nil)
        return .result()
    }
}
#endif
