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

    /// How far the arrival has to move before it is worth rescheduling.
    ///
    /// The walk recalculates its arrival every second, and every one of those
    /// used to become an alarm. They raced: each finished task overwrote the
    /// stored identifier, so the alarms it had raced against were left
    /// scheduled with nothing holding their identifiers, and went off at times
    /// the walk had long since moved past. Pausing could only cancel the last
    /// one of them.
    private static let rescheduleWindow: TimeInterval = 30

    private var scheduled: Alarm.ID?
    /// Claimed before the scheduling is awaited, so the tick a second later
    /// sees this one in flight rather than starting another beside it.
    private var claimedFor: Date?
    private var claimedDestination: String?

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
    ///
    /// Called once a second by the walk, so most calls do nothing: an arrival
    /// that has moved by less than half a minute is the same arrival, and the
    /// alarm already scheduled for it is the right one.
    func schedule(arrivingAt date: Date, destination: String) async {
        guard isEnabled, date > .now, isAuthorized else {
            cancel()
            return
        }

        if
            let claimedFor,
            claimedDestination == destination,
            abs(claimedFor.timeIntervalSince(date)) < Self.rescheduleWindow
        {
            return
        }

        let previous = scheduled
        claimedFor = date
        claimedDestination = destination

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
            // Cancelled only once its replacement exists, so a walk is never
            // briefly without an alarm it is meant to have.
            if let previous {
                try? AlarmManager.shared.cancel(id: previous)
            }
        } catch {
            claimedFor = nil
            claimedDestination = nil
        }
    }

    /// Called whenever the walk stops being on its way there — paused,
    /// stopped, failed, or arrived early. An alarm for an arrival that has
    /// already happened is worse than none.
    func cancel() {
        if let scheduled {
            try? AlarmManager.shared.cancel(id: scheduled)
        }
        scheduled = nil
        claimedFor = nil
        claimedDestination = nil
    }
}
