import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// The watch's end of the link.
///
/// It holds the last snapshot the phone sent and nothing else. There is no
/// local copy of a session here, and deliberately so: the session runs on the
/// phone, and a watch that remembered its own version of one would eventually
/// disagree with it — always at the moment the link dropped, which is exactly
/// when a reading is least worth trusting.
@MainActor
@Observable
final class WatchLink: NSObject {
    private(set) var state: WatchSessionState = .idle
    /// Whether anything has arrived yet. A session that is genuinely idle and
    /// a phone that has not answered look identical in the state alone, and
    /// they are not the same thing to report.
    private(set) var hasHeardFromPhone = false
    private(set) var isReachable = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sent as a message when the phone is reachable, because a pause is only
    /// useful immediately. Nothing is queued for later: a pause that arrives
    /// ten minutes after it was asked for is a surprise, not a delayed action.
    func togglePause() {
        let session = WCSession.default
        guard session.isReachable else { return }
        session.sendMessage(
            [WatchSessionCommand.messageKey: WatchSessionCommand.togglePause.rawValue],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    fileprivate func apply(_ payload: [String: Any]) {
        guard
            let data = payload[WatchSessionCommand.stateKey] as? Data,
            let decoded = try? JSONDecoder().decode(WatchSessionState.self, from: data)
        else { return }

        // Only on the change, and only if there was something to change from.
        // The system delivers the stored context whenever the app wakes, so a
        // watch opened an hour after the walk ended would otherwise announce
        // an arrival that happened while it was asleep.
        if hasHeardFromPhone, decoded.hasArrived, !state.hasArrived {
            WKInterfaceDevice.current().play(.notification)
        }
        state = decoded
        hasHeardFromPhone = true
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let reachable = session.isReachable
        let context = session.receivedApplicationContext
        Task { @MainActor [weak self] in
            self?.isReachable = reachable
            self?.apply(context)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isReachable = reachable
        }
    }

    /// The context is the reliable half: the system keeps the latest one and
    /// delivers it when it can, so a watch that was asleep still opens with
    /// the truth rather than with nothing.
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.apply(applicationContext)
        }
    }

    /// The prompt half, for while both are awake.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.apply(message)
        }
    }
}
