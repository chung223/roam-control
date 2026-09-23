import Foundation
import Observation

/// The walk being put together, before there is a route.
///
/// Planning used to mean naming one destination and letting Apple decide the
/// rest, which is fine until the places worth walking between are ones Apple
/// will not route through, or until the order matters. This holds the places
/// and the one decision that changes what a route through them means.
@MainActor
@Observable
final class WalkPlanDraft {
    private static let followsStreetsKey = "walkPlanFollowsStreets"

    private(set) var stops: [LocationTarget] = []

    /// Whether the legs between stops follow streets or go straight.
    ///
    /// Remembered, because it is a property of how somebody walks rather than
    /// of any one walk: whoever needs straight lines needs them every time,
    /// and being asked again each walk would be asking the same question.
    var followsStreets: Bool {
        get { UserDefaults.standard.object(forKey: Self.followsStreetsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.followsStreetsKey) }
    }

    var isEmpty: Bool { stops.isEmpty }

    func contains(_ target: LocationTarget) -> Bool {
        stops.contains { $0.isSamePlace(as: target) }
    }

    /// Appended rather than inserted anywhere clever: the order stops are
    /// added in is the order somebody meant, and it can be dragged afterwards.
    /// The same place twice is allowed — a walk that passes a corner twice is
    /// a real walk — but adding the place already at the end is a double tap,
    /// not an intention.
    func add(_ target: LocationTarget) {
        if let last = stops.last, last.isSamePlace(as: target) { return }
        stops.append(target)
    }

    func add(contentsOf targets: [LocationTarget]) {
        for target in targets { add(target) }
    }

    func remove(atOffsets offsets: IndexSet) {
        stops.remove(atOffsets: offsets)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        stops.move(fromOffsets: source, toOffset: destination)
    }

    func clear() {
        stops = []
    }
}
