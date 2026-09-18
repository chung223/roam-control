// ActivityKit is not on watchOS, and the watch target compiles this folder
// too. Guarding the file rather than splitting the folder keeps one shared
// place for shared types; what is inside is iOS-only because Live Activities
// are, not because of how the targets happen to be arranged.
#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Describes the Live Activity for a running location session.
///
/// The app target starts and updates the activity; the widget extension renders
/// it. Both targets compile this file, so it must not depend on either.
///
/// Coordinates are deliberately absent. A Live Activity is visible on the Lock
/// Screen without authentication, and the place name the user chose is the
/// least that still tells them a session is running. Nothing here leaves the
/// device.
struct RoamSessionActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        enum Mode: String, Codable, Hashable, Sendable {
            case fixedLocation
            case walkingRoute
        }

        /// Mirrors the parts of the session lifecycle a person can act on.
        /// Discovery, tunnelling and pairing all read as "connecting" here;
        /// the app remains the place to diagnose a failure.
        enum Stage: String, Codable, Hashable, Sendable {
            case connecting
            case running
            case paused
            case arrived
            case stopping
            case restoring
        }

        var mode: Mode
        var stage: Stage
        /// The place the iPhone is reporting, or the destination while walking.
        var placeName: String
        /// 0...1 along the walking route. Always 0 for a fixed location.
        var progress: Double
        /// Metres left to walk. Always 0 for a fixed location.
        var remainingDistance: Double
        /// When the walk is expected to finish, so the widget can count down
        /// locally instead of being pushed an update every second.
        var expectedArrival: Date?

        static func fixedLocation(
            stage: Stage,
            placeName: String
        ) -> ContentState {
            ContentState(
                mode: .fixedLocation,
                stage: stage,
                placeName: placeName,
                progress: 0,
                remainingDistance: 0,
                expectedArrival: nil
            )
        }
    }

    /// When the session started, for the elapsed-time counter.
    var startedAt: Date
}

extension RoamSessionActivityAttributes.ContentState {
    var isWalking: Bool { mode == .walkingRoute }

    /// The Lock Screen headline. Kept short enough for the Dynamic Island.
    var statusText: String {
        switch stage {
        case .connecting: "Connecting…"
        case .running: isWalking ? "Walking" : "Location set"
        case .paused: "Paused"
        case .arrived: "Arrived"
        case .stopping: "Stopping…"
        case .restoring: "Restoring real location…"
        }
    }

    /// Simulation is active whenever the iPhone is reporting a chosen place.
    /// A person glancing at the Lock Screen needs that distinction more than
    /// they need the exact stage.
    var isSimulating: Bool {
        switch stage {
        case .running, .paused, .arrived: true
        case .connecting, .stopping, .restoring: false
        }
    }

    var symbolName: String {
        switch stage {
        case .connecting: "antenna.radiowaves.left.and.right"
        case .running: isWalking ? "figure.walk" : "location.fill"
        case .paused: "pause.circle.fill"
        case .arrived: "flag.checkered"
        case .stopping: "stop.circle"
        case .restoring: "location.slash"
        }
    }
}
#endif
