import Foundation

/// What the watch is told about a running session.
///
/// A simulated walk is something you leave running for forty minutes, which is
/// exactly the situation in which taking the phone out to see how far it has
/// got is the annoying part. This is the smallest description of a session that
/// answers that question.
///
/// Deliberately not the Live Activity's attributes, though it carries much the
/// same facts. Those are drawn by iOS from a fixed shape that cannot change
/// without ending the activity; this crosses a link that may drop, arrive late
/// or arrive twice, so it is a whole snapshot each time rather than a diff.
public struct WatchSessionState: Codable, Sendable, Equatable {
    public enum Phase: String, Codable, Sendable {
        case idle
        case connecting
        case active
        case stopping
        case failed
    }

    public var phase: Phase
    public var placeName: String
    public var isWalking: Bool
    public var isPaused: Bool
    /// 0...1 along the route, or `nil` for a fixed location.
    public var progress: Double?
    public var metresRemaining: Double?
    public var arrivesAt: Date?
    public var startedAt: Date?
    /// Already translated. The English a session produces is its
    /// classification key, and the phone holds every translation of it, so it
    /// localises before sending rather than making the watch carry a second
    /// copy of all fifty-five.
    public var message: String?

    public init(
        phase: Phase = .idle,
        placeName: String = "",
        isWalking: Bool = false,
        isPaused: Bool = false,
        progress: Double? = nil,
        metresRemaining: Double? = nil,
        arrivesAt: Date? = nil,
        startedAt: Date? = nil,
        message: String? = nil
    ) {
        self.phase = phase
        self.placeName = placeName
        self.isWalking = isWalking
        self.isPaused = isPaused
        self.progress = progress
        self.metresRemaining = metresRemaining
        self.arrivesAt = arrivesAt
        self.startedAt = startedAt
        self.message = message
    }

    public static let idle = WatchSessionState()

    public var isRunning: Bool {
        phase == .active || phase == .connecting || phase == .stopping
    }
}

/// What the watch may ask for.
///
/// Pausing and resuming only. Stopping has to restore the real location and
/// confirm the device accepted it, and a wrist is the wrong place to start
/// something that must be watched to its end — the same reason the Live
/// Activity carries no stop button.
public enum WatchSessionCommand: String, Codable, Sendable {
    case togglePause

    /// The key both sides agree on. A literal in two places is a bug waiting
    /// for one of them to be edited.
    public static let messageKey = "command"
    public static let stateKey = "state"
}
