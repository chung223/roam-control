import Foundation
import Observation
import WatchConnectivity

/// The phone's end of the link to the watch.
///
/// Two ways across, because they fail differently. The application context is
/// the reliable one: the system keeps only the latest and delivers it when it
/// can, so a watch that was asleep for twenty minutes opens showing the truth
/// rather than nothing. A message is the prompt one, delivered only while both
/// are awake, which is what makes a progress reading feel live.
///
/// Both carry the whole snapshot rather than a change to one. A link that can
/// drop, reorder or repeat cannot be sent diffs and be expected to arrive at
/// the same picture.
@MainActor
@Observable
final class WatchSessionBridge: NSObject {
    /// Progress moves continuously while a walk runs, and sending every step
    /// of it would be a message every few hundred milliseconds for forty
    /// minutes. Anything that changes the shape of the screen goes at once;
    /// anything that only moves a number waits its turn.
    private static let progressInterval: TimeInterval = 5

    private(set) var isWatchAppInstalled = false

    @ObservationIgnored
    private var lastSent: WatchSessionState?
    @ObservationIgnored
    private var lastSentAt: Date?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ state: WatchSessionState) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        if let lastSent, !isStructural(change: state, from: lastSent) {
            let elapsed = lastSentAt.map { Date.now.timeIntervalSince($0) } ?? .infinity
            guard elapsed >= Self.progressInterval else { return }
        }
        guard let data = try? JSONEncoder().encode(state) else { return }

        lastSent = state
        lastSentAt = .now
        let payload: [String: Any] = [WatchSessionCommand.stateKey: data]
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    /// Whether this is a change the watch should see immediately, as opposed
    /// to a number that has moved a little.
    private func isStructural(change new: WatchSessionState, from old: WatchSessionState) -> Bool {
        new.phase != old.phase
            || new.isWalking != old.isWalking
            || new.isPaused != old.isPaused
            || new.hasArrived != old.hasArrived
            || new.placeName != old.placeName
            || new.message != old.message
    }
}

extension WatchSessionBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let installed = session.isWatchAppInstalled
        Task { @MainActor [weak self] in
            self?.isWatchAppInstalled = installed
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Reactivated rather than left inactive: switching watches otherwise
    /// leaves the link dead until the app is relaunched.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let installed = session.isWatchAppInstalled
        Task { @MainActor [weak self] in
            self?.isWatchAppInstalled = installed
        }
    }

    /// The only thing the watch may ask for. It is delivered as the same
    /// notification the Live Activity's button posts, so a pause is one path
    /// however it was asked for — and the walking controller stays unaware
    /// that a watch exists.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard
            let raw = message[WatchSessionCommand.messageKey] as? String,
            let command = WatchSessionCommand(rawValue: raw)
        else { return }

        Task { @MainActor in
            switch command {
            case .togglePause:
                NotificationCenter.default.post(name: ToggleWalkPauseIntent.requested, object: nil)
            }
        }
    }
}
