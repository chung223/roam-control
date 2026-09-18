import CoreLocation
import MapKit

/// A walk that calls at several places on the way.
///
/// The catalogue holds ten thousand spots and the walk could reach one of
/// them, which made the two halves of this app strangers: the reason to want
/// five restaurants is that a decoration comes from restaurants, and going to
/// one of them five times is not the same errand.
///
/// MapKit will only route between two points, so a walk through five is five
/// routes with their lines laid end to end. What the simulation needs is the
/// one sequence that results; what the reader needs is to know which stop is
/// next. Both come from the same chain, which is why they are held together
/// rather than recomputed from the legs.
struct MultiStopRoute {
    /// Every point of every leg, in order, with the seam between legs closed.
    let points: [MKMapPoint]

    /// Where it calls, in the order it calls there. The last one is the
    /// destination in the sense the rest of the app means it.
    let stops: [LocationTarget]

    /// How far along `points` each stop sits. Same count as `stops`, so the
    /// walk can say which one is next without measuring anything again.
    let stopDistances: [CLLocationDistance]

    let totalDistance: CLLocationDistance

    /// Summed from the legs. Apple's estimate for each is better than anything
    /// derivable from the distance, and the stops themselves cost nothing —
    /// nobody is being simulated as stopping to look around.
    let expectedTravelTime: TimeInterval

    var destination: LocationTarget? { stops.last }

    var polyline: MKPolyline {
        points.map(\.coordinate).withUnsafeBufferPointer { buffer in
            MKPolyline(coordinates: buffer.baseAddress!, count: buffer.count)
        }
    }

    /// Built from the legs in order.
    ///
    /// A leg begins where the previous one ended, so its first point repeats
    /// the last. Dropping it keeps the distances honest — a repeated point is
    /// a zero-length step, and enough of them would make the walk appear to
    /// stall at every stop.
    init?(legs: [MKRoute], stops: [LocationTarget]) {
        guard !legs.isEmpty, legs.count == stops.count else { return nil }

        var chained: [MKMapPoint] = []
        var distances: [CLLocationDistance] = []

        for leg in legs {
            let polyline = leg.polyline
            let buffer = polyline.points()
            var legPoints = (0..<polyline.pointCount).map { buffer[$0] }
            if !chained.isEmpty, let first = legPoints.first, first.equals(chained[chained.count - 1]) {
                legPoints.removeFirst()
            }
            chained += legPoints
            distances.append(Self.length(of: chained))
        }

        guard chained.count >= 2 else { return nil }
        points = chained
        self.stops = stops
        stopDistances = distances
        totalDistance = distances.last ?? 0
        expectedTravelTime = legs.reduce(0) { $0 + $1.expectedTravelTime }
    }

    private static func length(of points: [MKMapPoint]) -> CLLocationDistance {
        guard points.count >= 2 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
    }
}

private extension MKMapPoint {
    /// Within a millimetre or so at map scale. Two legs meeting at a place do
    /// not necessarily agree to the last bit about where it is.
    func equals(_ other: MKMapPoint) -> Bool {
        distance(to: other) < 0.5
    }
}
