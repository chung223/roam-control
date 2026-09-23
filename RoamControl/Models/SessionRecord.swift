import Foundation

/// What was done, rather than where. The existing history records places, so
/// it answers "where have I been" and cannot answer "did that walk finish", or
/// "how long was the session that failed", or "when did this last work".
///
/// That gap matters more here than it would elsewhere. Every feature depends on
/// a connection that can fail in fifty-five distinguishable ways, and the app
/// already classifies each one for telemetry — while the person holding the
/// phone, whose session it was, could see none of it after the message
/// disappeared.
struct SessionRecord: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case fixed
        case walkingRoute
    }

    enum Outcome: String, Codable, Sendable {
        case completed
        case failed
        /// Closed on a later launch because the app went away while it was
        /// still open. The session may well have kept running on the device;
        /// what is known is only that this app stopped watching it.
        case interrupted
    }

    let id: UUID
    let target: LocationTarget
    let kind: Kind
    let startedAt: Date

    /// The device's time zone when the session began.
    ///
    /// Simulating a distant location makes iOS move the device's own zone to
    /// match it, so a session run in Florida and read back at home would
    /// otherwise be shown at a time nobody was awake. A record of when
    /// something happened is worth nothing if it cannot be compared with a
    /// memory of it.
    ///
    /// Optional because records written before this decode without it, and
    /// the only honest thing to show for those is whatever zone is current.
    var timeZoneIdentifier: String?
    var endedAt: Date?
    var outcome: Outcome?

    /// Kept in the English the session produced, because that string is also
    /// the classification key `FailureStage` matches on. `SessionMessage`
    /// translates it on the way to the screen.
    var failureMessage: String?

    init(
        id: UUID = UUID(),
        target: LocationTarget,
        kind: Kind,
        startedAt: Date = .now,
        timeZoneIdentifier: String? = TimeZone.current.identifier,
        endedAt: Date? = nil,
        outcome: Outcome? = nil,
        failureMessage: String? = nil
    ) {
        self.id = id
        self.target = target
        self.kind = kind
        self.startedAt = startedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.endedAt = endedAt
        self.outcome = outcome
        self.failureMessage = failureMessage
    }

    var isOpen: Bool { outcome == nil }

    /// The zone this session's times should be read in, falling back to the
    /// current one for records that predate this being stored.
    var timeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    /// Absent while the session is open: a duration that grows each time it is
    /// read is a timer, not a record, and nothing here wants one.
    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}
