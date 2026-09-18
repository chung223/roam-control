import CoreLocation
import Foundation
import MapKit
import Observation

enum WalkingPace: Double, CaseIterable, Identifiable {
    case relaxed = 1.0
    case normal = 1.4
    case brisk = 1.8

    var id: Self { self }

    var title: String {
        switch self {
        case .relaxed: .appText("Relaxed")
        case .normal: .appText("Normal")
        case .brisk: .appText("Brisk")
        }
    }

    var metresPerSecond: Double { rawValue }
}

enum WalkingSimulationPhase: Equatable {
    case idle
    case preparing
    case walking
    case paused
    case arrived
    case stopping
    case failed(String)
}

@MainActor
@Observable
final class WalkingSimulationController {
    private(set) var phase: WalkingSimulationPhase = .idle
    private(set) var currentCoordinate: CLLocationCoordinate2D?
    private(set) var distanceTravelled: CLLocationDistance = 0
    private(set) var totalDistance: CLLocationDistance = 0
    var pace: WalkingPace = .normal

    @ObservationIgnored
    private var routePoints: [MKMapPoint] = []
    @ObservationIgnored
    private var cumulativeDistances: [CLLocationDistance] = []
    @ObservationIgnored
    private(set) var destination: LocationTarget?
    /// Where a multi-stop walk calls, and how far along each one sits. Empty
    /// for an ordinary walk, which is a walk with one stop that never needed
    /// to say so.
    @ObservationIgnored
    private(set) var stops: [LocationTarget] = []
    @ObservationIgnored
    private var stopDistances: [CLLocationDistance] = []
    /// Observed, because the number of stops behind you is the one part of a
    /// multi-stop walk that has to redraw as it changes.
    private(set) var stopsReached = 0
    @ObservationIgnored
    private var routeStart: LocationTarget?
    @ObservationIgnored
    private var movementTask: Task<Void, Never>?
    @ObservationIgnored
    private var pauseRequestObserver: (any NSObjectProtocol)?
    @ObservationIgnored
    let arrivalAlarm = ArrivalAlarm()

    init() {
        observePauseRequests()
    }

    deinit {
        if let pauseRequestObserver {
            NotificationCenter.default.removeObserver(pauseRequestObserver)
        }
    }

    var progress: Double {
        guard totalDistance > 0 else { return 0 }
        return min(max(distanceTravelled / totalDistance, 0), 1)
    }

    var remainingDistance: CLLocationDistance {
        max(totalDistance - distanceTravelled, 0)
    }

    var remainingDuration: TimeInterval {
        remainingDistance / pace.metresPerSecond
    }

    var locksDestination: Bool {
        switch phase {
        case .preparing, .walking, .paused, .arrived, .stopping:
            true
        case .idle, .failed:
            false
        }
    }

    /// A walk that calls at several places. The simulation walks one line
    /// either way; the stops only decide what it is called on the way there.
    func prepare(_ plan: MultiStopRoute) {
        guard let destination = plan.destination else { return }
        movementTask?.cancel()
        movementTask = nil

        routePoints = plan.points
        cumulativeDistances = cumulativeDistanceValues(for: routePoints)
        totalDistance = cumulativeDistances.last ?? plan.totalDistance
        distanceTravelled = 0
        currentCoordinate = nil
        stops = plan.stops
        stopDistances = plan.stopDistances
        stopsReached = 0
        // The first stop, not the last: a walk through five places is on its
        // way to the first of them, and naming the fifth would be describing
        // somewhere it will not reach for an hour.
        self.destination = plan.stops.first
        setRouteStart(named: destination.name)
        phase = routePoints.count >= 2 ? .idle : .failed("This walking route does not contain enough detail to simulate movement.")
    }

    /// The stop it is heading for now, which is the destination until it is
    /// reached and then the one after it.
    var nextStop: LocationTarget? {
        guard !stops.isEmpty else { return destination }
        return stops.indices.contains(stopsReached) ? stops[stopsReached] : stops.last
    }

    var stopsRemaining: Int {
        max(stops.count - stopsReached, 0)
    }

    /// Moves the named destination on as each stop is passed. Everything that
    /// shows where a walk is going reads `destination`, so this is all it
    /// takes for the card, the Live Activity and the watch to keep up.
    ///
    /// Returns whether a stop was passed, since that is worth redrawing for.
    private func advanceStopsIfNeeded() -> Bool {
        guard !stops.isEmpty else { return false }
        let before = stopsReached
        while stopsReached < stopDistances.count, distanceTravelled >= stopDistances[stopsReached] {
            stopsReached += 1
        }
        guard stopsReached != before else { return false }
        destination = stops.indices.contains(stopsReached) ? stops[stopsReached] : stops.last
        return true
    }

    func prepare(route: MKRoute, destination: LocationTarget) {
        movementTask?.cancel()
        movementTask = nil

        let polyline = route.polyline
        let points = polyline.points()
        routePoints = (0..<polyline.pointCount).map { points[$0] }
        cumulativeDistances = cumulativeDistanceValues(for: routePoints)
        totalDistance = cumulativeDistances.last ?? route.distance
        stops = []
        stopDistances = []
        stopsReached = 0
        distanceTravelled = 0
        currentCoordinate = nil
        self.destination = destination
        setRouteStart(named: destination.name)
        phase = routePoints.count >= 2 ? .idle : .failed("This walking route does not contain enough detail to simulate movement.")
    }

    /// Where the route begins, kept so a walk can turn round and come back.
    private func setRouteStart(named destinationName: String) {
        guard let startCoordinate = routePoints.first?.coordinate else {
            routeStart = nil
            return
        }
        routeStart = LocationTarget(
            name: .appText("Route Start"),
            subtitle: String(
                format: .appText("Starting point for %@"),
                SessionMessage.localized(destinationName)
            ),
            latitude: startCoordinate.latitude,
            longitude: startCoordinate.longitude
        )
    }

    /// Keep walking after arriving, turning round and going back, over and
    /// over. A one-way walk stops as soon as it arrives, which is not what a
    /// walk is for when the point of it is to keep moving.
    static let loopsWalkKey = "loopsWalkAfterArrival"

    var loopsWalk: Bool {
        get { UserDefaults.standard.bool(forKey: Self.loopsWalkKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.loopsWalkKey) }
    }

    /// Reverses the route in place without leaving the walk.
    ///
    /// Unlike `prepareReturnTrip`, which ends at `.idle` for someone to start
    /// again, this keeps the phase and the session as they are — the walk has
    /// not stopped, it has turned round.
    private func turnAround() -> Bool {
        guard let previousDestination = destination, let returnDestination = routeStart,
              routePoints.count >= 2
        else { return false }

        routePoints.reverse()
        cumulativeDistances = cumulativeDistanceValues(for: routePoints)
        totalDistance = cumulativeDistances.last ?? totalDistance
        distanceTravelled = 0
        routeStart = previousDestination

        guard !stops.isEmpty else {
            destination = returnDestination
            return true
        }

        // The line is reversed, so a stop that was `d` along is now
        // `totalDistance - d` along. The one being stood on is dropped — it
        // has just been reached — and the start becomes the final stop.
        let returning = Array(stops.dropLast().reversed())
        let returningDistances = Array(stopDistances.dropLast().reversed().map { totalDistance - $0 })
        stops = returning + [returnDestination]
        stopDistances = returningDistances + [totalDistance]
        stopsReached = 0
        destination = stops.first
        return true
    }

    func prepareReturnTrip() -> LocationTarget? {
        guard
            phase == .arrived,
            let returnDestination = routeStart,
            let previousDestination = destination,
            routePoints.count >= 2
        else { return nil }

        movementTask?.cancel()
        movementTask = nil
        routePoints.reverse()
        cumulativeDistances = cumulativeDistanceValues(for: routePoints)
        totalDistance = cumulativeDistances.last ?? totalDistance
        distanceTravelled = 0
        currentCoordinate = nil
        destination = returnDestination
        routeStart = previousDestination
        phase = .idle
        return returnDestination
    }

    func start(using appModel: AppModel) async {
        guard
            !routePoints.isEmpty,
            let destination,
            phase == .idle || isFailed
        else { return }
        liveActivity = appModel.liveActivity
        guard case .paired = appModel.pairingStatus else {
            phase = .failed("Pair this iPhone before starting a walking session.")
            return
        }

        movementTask?.cancel()
        distanceTravelled = 0
        currentCoordinate = routePoints[0].coordinate
        phase = .preparing

        await appModel.startWalkingLocationSession(
            at: movementTarget(at: routePoints[0].coordinate, destination: destination),
            destination: destination,
            paceMetresPerSecond: pace.metresPerSecond
        )

        if case .idle = appModel.deviceSession.phase, phase == .preparing {
            phase = .failed("Roam Control could not start the walking session.")
        }
    }

    /// Listens for the Live Activity's pause button, which cannot reach this
    /// object directly: it is view state, and the intent is a free function
    /// running in the same process.
    private func observePauseRequests() {
        pauseRequestObserver = NotificationCenter.default.addObserver(
            forName: ToggleWalkPauseIntent.requested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.togglePause() }
        }
    }

    func togglePause() {
        switch phase {
        case .walking:
            phase = .paused
            publishWalkingActivity(stage: .paused)
        case .paused:
            phase = .walking
            publishWalkingActivity(stage: .running)
        case .idle, .preparing, .arrived, .stopping, .failed:
            break
        }
    }

    func stop(using deviceSession: LocalDeviceSessionCoordinator) {
        arrivalAlarm.cancel()
        guard locksDestination || isFailed else { return }
        movementTask?.cancel()
        movementTask = nil

        if case .idle = deviceSession.phase {
            currentCoordinate = nil
            distanceTravelled = 0
            phase = .idle
            return
        }

        phase = .stopping
        deviceSession.stop()
    }

    func handleDeviceSessionPhase(
        _ devicePhase: DeviceSessionPhase,
        deviceSession: LocalDeviceSessionCoordinator
    ) {
        switch devicePhase {
        case .active:
            guard phase == .preparing else { return }
            phase = .walking
            startWalkingActivity()
            beginMovement(using: deviceSession)

        case .stopping:
            if locksDestination || isFailed {
                movementTask?.cancel()
                movementTask = nil
                phase = .stopping
            }

        case .idle:
            guard phase == .stopping else { return }
            movementTask?.cancel()
            movementTask = nil
            currentCoordinate = nil
            distanceTravelled = 0
            phase = .idle

        case .failed(let message):
            guard locksDestination || phase == .preparing else { return }
            movementTask?.cancel()
            movementTask = nil
            currentCoordinate = nil
            phase = .failed(message)

        case .openingLocalDevVPN, .discovering, .connecting:
            break
        }
    }

    func reset() {
        movementTask?.cancel()
        movementTask = nil
        routePoints = []
        cumulativeDistances = []
        destination = nil
        routeStart = nil
        stops = []
        stopDistances = []
        stopsReached = 0
        currentCoordinate = nil
        distanceTravelled = 0
        totalDistance = 0
        phase = .idle
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    /// Set when a walk starts. The activity itself is owned by AppModel, which
    /// ends it when the device session ends.
    @ObservationIgnored
    private weak var liveActivity: RoamSessionLiveActivityController?

    private func startWalkingActivity() {
        guard let destination else { return }
        liveActivity?.startWalk(
            destinationName: destination.name,
            remainingDistance: remainingDistance,
            expectedArrival: expectedArrival
        )
    }

    private func publishWalkingActivity(
        stage: RoamSessionActivityAttributes.ContentState.Stage
    ) {
        guard let destination else { return }
        updateArrivalAlarm(stage: stage, destination: destination)
        liveActivity?.updateWalk(
            stage: stage,
            destinationName: destination.name,
            progress: progress,
            remainingDistance: remainingDistance,
            expectedArrival: stage == .running ? expectedArrival : nil
        )
    }

    /// The walk stopped but the location session did not: the iPhone still
    /// reports its last coordinate. Say that plainly instead of leaving a walk
    /// in progress on the Lock Screen.
    private func reportWalkNoLongerMoving(named placeName: String) {
        liveActivity?.updateFixedLocation(named: placeName)
    }

    /// The alarm follows the walk rather than being set once: pausing, turning
    /// round or retargeting all change when arrival happens, and an alarm for
    /// an arrival that already passed is worse than none.
    private func updateArrivalAlarm(
        stage: RoamSessionActivityAttributes.ContentState.Stage,
        destination: LocationTarget
    ) {
        guard stage == .running, let expectedArrival else {
            arrivalAlarm.cancel()
            return
        }
        Task { await arrivalAlarm.schedule(arrivingAt: expectedArrival, destination: destination.name) }
    }

    /// Only meaningful while moving; a paused walk has no arrival time.
    private var expectedArrival: Date? {
        guard remainingDuration.isFinite, remainingDuration > 0 else { return nil }
        return Date.now.addingTimeInterval(remainingDuration)
    }

    private func beginMovement(using deviceSession: LocalDeviceSessionCoordinator) {
        movementTask?.cancel()
        movementTask = Task { @MainActor [weak self, weak deviceSession] in
            var lastTick = Date.now

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, let deviceSession else { return }

                let now = Date.now
                let elapsed = now.timeIntervalSince(lastTick)
                lastTick = now

                if self.phase == .paused {
                    continue
                }
                guard self.phase == .walking, self.destination != nil else { return }

                self.distanceTravelled = min(
                    self.totalDistance,
                    self.distanceTravelled + (self.pace.metresPerSecond * elapsed)
                )

                // Passing a stop renames where the walk is going, and every
                // screen showing that reads it from here.
                if self.advanceStopsIfNeeded() {
                    self.publishWalkingActivity(stage: .running)
                }
                guard let destination = self.destination else { return }

                guard let coordinate = self.coordinate(at: self.distanceTravelled) else {
                    self.phase = .failed("Roam Control could not follow this walking route.")
                    self.reportWalkNoLongerMoving(named: destination.name)
                    return
                }

                self.currentCoordinate = coordinate
                let reachedDestination = self.distanceTravelled >= self.totalDistance
                let target = reachedDestination
                    ? destination
                    : self.movementTarget(at: coordinate, destination: destination)

                guard deviceSession.updateLocation(target) == .updated else {
                    self.phase = .failed("The active location session ended before the walk finished.")
                    self.reportWalkNoLongerMoving(named: destination.name)
                    return
                }

                if reachedDestination, self.loopsWalk, self.turnAround() {
                    // Arrived, and going straight back. The route is the same
                    // line, so the map needs nothing; only the destination the
                    // activity names has changed.
                    self.publishWalkingActivity(stage: .running)
                    continue
                }

                if reachedDestination {
                    self.currentCoordinate = destination.coordinate
                    self.phase = .arrived
                    NotificationCenter.default.post(
                        name: ShortcutRunner.sessionFinished,
                        object: nil
                    )
                    // The walk is over, the session is not: the iPhone still
                    // reports the destination. Presenting it as a held location
                    // says that; leaving the walk on screen kept a progress bar
                    // and a running clock up over a walk that had finished.
                    // The phase stays .arrived so a return trip is still offered.
                    self.reportWalkNoLongerMoving(named: destination.name)
                    return
                }

                self.publishWalkingActivity(stage: .running)
            }
        }
    }

    private func cumulativeDistanceValues(for points: [MKMapPoint]) -> [CLLocationDistance] {
        guard !points.isEmpty else { return [] }

        var values: [CLLocationDistance] = [0]
        values.reserveCapacity(points.count)
        for index in 1..<points.count {
            values.append(
                values[index - 1] + points[index - 1].distance(to: points[index])
            )
        }
        return values
    }

    private func coordinate(at distance: CLLocationDistance) -> CLLocationCoordinate2D? {
        guard let first = routePoints.first else { return nil }
        guard routePoints.count > 1, totalDistance > 0 else { return first.coordinate }
        if distance <= 0 { return first.coordinate }
        if distance >= totalDistance { return routePoints.last?.coordinate }

        guard let upperIndex = firstIndex(atOrBeyond: distance) else {
            return routePoints.last?.coordinate
        }
        let lowerIndex = max(upperIndex - 1, 0)
        let lowerDistance = cumulativeDistances[lowerIndex]
        let upperDistance = cumulativeDistances[upperIndex]
        let segmentLength = upperDistance - lowerDistance
        guard segmentLength > 0 else { return routePoints[upperIndex].coordinate }

        let fraction = (distance - lowerDistance) / segmentLength
        let start = routePoints[lowerIndex]
        let end = routePoints[upperIndex]
        return MKMapPoint(
            x: start.x + ((end.x - start.x) * fraction),
            y: start.y + ((end.y - start.y) * fraction)
        ).coordinate
    }

    /// `cumulativeDistances` is ascending, so the first entry at or beyond a
    /// distance can be found by bisection rather than by scanning the whole
    /// route on every tick.
    private func firstIndex(atOrBeyond distance: CLLocationDistance) -> Int? {
        var low = 0
        var high = cumulativeDistances.count
        while low < high {
            let middle = low + ((high - low) / 2)
            if cumulativeDistances[middle] >= distance {
                high = middle
            } else {
                low = middle + 1
            }
        }
        return low < cumulativeDistances.count ? low : nil
    }

    private func movementTarget(
        at coordinate: CLLocationCoordinate2D,
        destination: LocationTarget
    ) -> LocationTarget {
        LocationTarget(
            name: String(
                format: .appText("Walking to %@"),
                SessionMessage.localized(destination.name)
            ),
            subtitle: String(
                format: .appText("%lld%% complete"),
                Int((progress * 100).rounded())
            ),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}
