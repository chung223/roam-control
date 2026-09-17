import AlarmKit
import Foundation
import SwiftUI

/// Wakes someone when a simulated walk reaches its destination.
///
/// A forty-minute walk is not something you watch. A notification is the
/// obvious answer and the wrong one: it is silenced by the switch and by a
/// Focus, which is exactly the state a phone is in while it is being left to
/// walk somewhere. An alarm is not.
///
/// Off unless asked for. Scheduling an alarm on someone's behalf because they
/// started a walk would be a surprise, and a loud one.
@MainActor
@Observable
final class ArrivalAlarm {
    static let enabledKey = "wakesOnWalkArrival"

    /// Metadata is required by the type, and there is nothing to carry: the
    /// alarm says one thing and the app is where the detail lives.
    private struct Metadata: AlarmMetadata {}

    private var scheduled: Alarm.ID?

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    var isAuthorized: Bool {
        AlarmManager.shared.authorizationState == .authorized
    }

    /// Asked for only when the setting is switched on, so the prompt arrives
    /// with a reason attached rather than at launch.
    func requestAuthorization() async -> Bool {
        if AlarmManager.shared.authorizationState == .authorized { return true }
        do {
            return try await AlarmManager.shared.requestAuthorization() == .authorized
        } catch {
            return false
        }
    }

    /// Replaces any alarm already set: a walk that turns round, or is
    /// retargeted, has a new arrival time and only one of them is true.
    func schedule(arrivingAt date: Date, destination: String) async {
        cancel()
        guard isEnabled, date > .now, isAuthorized else { return }

        let alert = AlarmPresentation.Alert(
            title: "Arrived at \(destination)",
            stopButton: AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.fill"
            )
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: Metadata(),
            tintColor: SproutTheme.primary
        )
        let id = Alarm.ID()

        do {
            _ = try await AlarmManager.shared.schedule(
                id: id,
                configuration: .alarm(schedule: .fixed(date), attributes: attributes)
            )
            scheduled = id
        } catch {
            scheduled = nil
        }
    }

    /// Called whenever the walk stops being on its way there — paused,
    /// stopped, failed, or arrived early. An alarm for an arrival that has
    /// already happened is worse than none.
    func cancel() {
        guard let scheduled else { return }
        try? AlarmManager.shared.cancel(id: scheduled)
        self.scheduled = nil
    }
}
