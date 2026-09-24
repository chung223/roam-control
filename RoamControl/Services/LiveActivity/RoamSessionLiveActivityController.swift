import ActivityKit
import Foundation
import Observation

/// Starts, updates and ends the Lock Screen and Dynamic Island presentation of
/// a running location session.
///
/// A session can outlive the app being in the foreground, and a person who
/// forgets that their iPhone is reporting a chosen place is exactly the risk
/// the responsible-use policy asks the app to avoid. The activity exists to
/// keep that visible, so it is ended whenever simulation ends — including on
/// failure.
@MainActor
@Observable
final class RoamSessionLiveActivityController {
    /// ActivityKit throttles frequent updates. A walking session ticks once a
    /// second, which is far more often than a glanceable widget needs; the
    /// widget counts the arrival time down locally between pushes.
    private static let minimumUpdateInterval: TimeInterval = 4

    /// Marks the activity stale if the app stops updating it, so a session that
    /// died with the app does not sit on the Lock Screen looking healthy.
    private static let staleInterval: TimeInterval = 90

    private(set) var isRunning = false

    @ObservationIgnored
    private var activity: Activity<RoamSessionActivityAttributes>?
    @ObservationIgnored
    private var lastPushedState: RoamSessionActivityAttributes.ContentState?
    @ObservationIgnored
    private var lastPushDate: Date?
    /// Whether the activity being held was started by some earlier run rather
    /// than by this one. An adopted activity describes a session this process
    /// is not running, and only the app can decide whether that is still true.
    @ObservationIgnored
    private(set) var wasAdopted = false

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    init() {
        adoptExistingActivities()
    }

    /// Takes back whatever a previous run left on screen.
    ///
    /// An activity outlives the process that requested it; the reference to it
    /// does not. Without this, relaunching — or simply being killed — left one
    /// running that nothing could end, because ending one requires the handle
    /// that had just been lost. It sat there until iOS's own limit hours
    /// later, describing a session that had long since finished, and a new
    /// session started beside it rather than replacing it.
    private func adoptExistingActivities() {
        let existing = Activity<RoamSessionActivityAttributes>.activities
        guard let adopted = existing.first else { return }

        activity = adopted
        lastPushedState = adopted.content.state
        lastPushDate = .now
        isRunning = true
        wasAdopted = true

        // One session, one activity. Anything beyond the first is from a run
        // that ended without tidying up.
        for extra in existing.dropFirst() {
            Task { await extra.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Ends an adopted activity, for when the app has established that it is
    /// not simulating anything. Does nothing to one this run started.
    func endIfAdopted() {
        guard wasAdopted else { return }
        end()
    }

    // MARK: - Fixed sessions

    func startFixedLocation(named placeName: String) {
        start(with: .fixedLocation(stage: .running, placeName: placeName))
    }

    func updateFixedLocation(named placeName: String) {
        push(.fixedLocation(stage: .running, placeName: placeName))
    }

    // MARK: - Walking sessions

    func startWalk(
        destinationName: String,
        remainingDistance: Double,
        expectedArrival: Date?
    ) {
        start(
            with: RoamSessionActivityAttributes.ContentState(
                mode: .walkingRoute,
                stage: .running,
                placeName: destinationName,
                progress: 0,
                remainingDistance: remainingDistance,
                expectedArrival: expectedArrival
            )
        )
    }

    func updateWalk(
        stage: RoamSessionActivityAttributes.ContentState.Stage,
        destinationName: String,
        progress: Double,
        remainingDistance: Double,
        expectedArrival: Date?
    ) {
        push(
            RoamSessionActivityAttributes.ContentState(
                mode: .walkingRoute,
                stage: stage,
                placeName: destinationName,
                progress: min(max(progress, 0), 1),
                remainingDistance: max(remainingDistance, 0),
                expectedArrival: expectedArrival
            )
        )
    }

    // MARK: - Lifecycle

    /// Reports that the session is shutting down. The activity is ended rather
    /// than left showing a stale place.
    func end() {
        guard let activity else {
            isRunning = false
            wasAdopted = false
            return
        }

        self.activity = nil
        lastPushedState = nil
        lastPushDate = nil
        isRunning = false
        wasAdopted = false

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Shows the shutdown stage briefly before the activity disappears, so a
    /// slow stop does not look like a session that is still simulating.
    func markStopping(isRestoringRealLocation: Bool) {
        guard var state = lastPushedState else { return }
        state.stage = isRestoringRealLocation ? .restoring : .stopping
        push(state, force: true)
    }

    // MARK: - Private

    private func start(with state: RoamSessionActivityAttributes.ContentState) {
        guard areActivitiesEnabled else { return }

        // Replace rather than stack: one session, one activity.
        if activity != nil {
            end()
        }

        do {
            let activity = try Activity.request(
                attributes: RoamSessionActivityAttributes(startedAt: .now),
                content: content(for: state),
                pushType: nil
            )
            self.activity = activity
            lastPushedState = state
            lastPushDate = .now
            isRunning = true
            wasAdopted = false
        } catch {
            // A refused activity must never take the location session with it.
            self.activity = nil
            isRunning = false
        }
    }

    private func push(
        _ state: RoamSessionActivityAttributes.ContentState,
        force: Bool = false
    ) {
        guard let activity else { return }
        guard state != lastPushedState else { return }

        // A changed stage is always worth showing immediately; progress along a
        // route is not.
        let stageChanged = state.stage != lastPushedState?.stage
        if !force, !stageChanged, let lastPushDate {
            guard Date.now.timeIntervalSince(lastPushDate) >= Self.minimumUpdateInterval else {
                return
            }
        }

        lastPushedState = state
        lastPushDate = .now
        let content = content(for: state)

        Task {
            await activity.update(content)
        }
    }

    private func content(
        for state: RoamSessionActivityAttributes.ContentState
    ) -> ActivityContent<RoamSessionActivityAttributes.ContentState> {
        ActivityContent(
            state: state,
            staleDate: Date.now.addingTimeInterval(Self.staleInterval)
        )
    }
}
