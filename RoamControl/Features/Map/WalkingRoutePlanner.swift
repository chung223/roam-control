import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class WalkingRoutePlanner {
    private(set) var route: MKRoute?
    /// Set instead of `route` when the walk calls at more than one place.
    /// Only ever one of the two is non-nil.
    private(set) var plan: MultiStopRoute?
    private(set) var destination: LocationTarget?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private var directions: MKDirections?

    func preview(to target: LocationTarget, from source: LocationTarget? = nil) async -> MKRoute? {
        directions?.cancel()
        route = nil
        plan = nil
        destination = target
        errorMessage = nil
        isLoading = true

        let request = MKDirections.Request()
        if let source {
            request.source = MKMapItem(
                location: CLLocation(latitude: source.latitude, longitude: source.longitude),
                address: nil
            )
        } else {
            request.source = .forCurrentLocation()
        }
        request.destination = MKMapItem(
            location: CLLocation(latitude: target.latitude, longitude: target.longitude),
            address: nil
        )
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        let calculation = MKDirections(request: request)
        directions = calculation

        defer {
            if directions === calculation {
                directions = nil
                isLoading = false
            }
        }

        do {
            let response = try await calculation.calculate()
            guard directions === calculation else { return nil }
            guard let preferredRoute = response.routes.first else {
                errorMessage = .appText("No walking route was found for this destination.")
                return nil
            }

            route = preferredRoute
            return preferredRoute
        } catch is CancellationError {
            return nil
        } catch {
            guard directions === calculation else { return nil }
            errorMessage = Self.message(for: error)
            return nil
        }
    }

    /// A walk that calls at several places, planned as one leg per stop and
    /// laid end to end.
    ///
    /// Sequential on purpose, and not only because each leg starts where the
    /// last finished: MapKit throttles directions requests, and five at once
    /// is how you find that out. A leg that fails ends the plan rather than
    /// being skipped — a walk that quietly misses the stop it was for is
    /// worse than one that says it could not be planned.
    func preview(through stops: [LocationTarget], from source: LocationTarget? = nil) async -> MultiStopRoute? {
        directions?.cancel()
        directions = nil
        route = nil
        plan = nil
        errorMessage = nil
        destination = stops.last

        guard !stops.isEmpty else { return nil }
        isLoading = true
        defer { isLoading = false }

        var legs: [MKRoute] = []
        var legSource = source

        for stop in stops {
            guard let leg = await leg(to: stop, from: legSource) else {
                // `leg` has already said why. Keep the first reason: a later
                // one is a consequence of stopping, not the cause.
                if errorMessage == nil {
                    errorMessage = .appText("No walking route was found for this destination.")
                }
                return nil
            }
            legs.append(leg)
            legSource = stop
        }

        guard let plan = MultiStopRoute(legs: legs, stops: stops) else {
            errorMessage = .appText("This walking route does not contain enough detail to simulate movement.")
            return nil
        }
        self.plan = plan
        return plan
    }

    /// What the preview card needs, from whichever kind of route was planned.
    var previewDistance: CLLocationDistance? { plan?.totalDistance ?? route?.distance }
    var previewDuration: TimeInterval? { plan?.expectedTravelTime ?? route?.expectedTravelTime }
    var hasRoute: Bool { plan != nil || route != nil }

    /// One leg, without touching the published route or the loading flag:
    /// a multi-stop plan owns both for the whole chain.
    private func leg(to target: LocationTarget, from source: LocationTarget?) async -> MKRoute? {
        let request = MKDirections.Request()
        if let source {
            request.source = MKMapItem(
                location: CLLocation(latitude: source.latitude, longitude: source.longitude),
                address: nil
            )
        } else {
            request.source = .forCurrentLocation()
        }
        request.destination = MKMapItem(
            location: CLLocation(latitude: target.latitude, longitude: target.longitude),
            address: nil
        )
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let first = response.routes.first else {
                errorMessage = .appText("No walking route was found for this destination.")
                return nil
            }
            return first
        } catch is CancellationError {
            return nil
        } catch {
            errorMessage = Self.message(for: error)
            return nil
        }
    }

    /// MKDirections reports "no such route exists" by throwing
    /// `MKError.directionsNotFound`, not by returning an empty `routes`
    /// array. Without separating the cases, a destination nobody could walk
    /// to — which is most of them, for an app whose point is being somewhere
    /// else — told the reader to go and check their network.
    private static func message(for error: any Error) -> String {
        guard let mapKitError = error as? MKError else {
            return .appText("Walking directions are unavailable. Check Location access and your internet connection, then try again.")
        }

        switch mapKitError.code {
        case .directionsNotFound, .placemarkNotFound:
            return .appText("No walking route was found for this destination.")
        case .loadingThrottled:
            return .appText("Too many route requests just now. Wait a moment, then try again.")
        default:
            return .appText("Walking directions are unavailable. Check Location access and your internet connection, then try again.")
        }
    }

    func clear() {
        directions?.cancel()
        directions = nil
        route = nil
        plan = nil
        destination = nil
        isLoading = false
        errorMessage = nil
    }

    func retargetExistingRoute(to target: LocationTarget) {
        guard route != nil else { return }
        destination = target
        errorMessage = nil
    }
}
