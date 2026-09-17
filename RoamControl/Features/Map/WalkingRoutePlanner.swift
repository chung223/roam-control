import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class WalkingRoutePlanner {
    private(set) var route: MKRoute?
    private(set) var destination: LocationTarget?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private var directions: MKDirections?

    func preview(to target: LocationTarget, from source: LocationTarget? = nil) async -> MKRoute? {
        directions?.cancel()
        route = nil
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
