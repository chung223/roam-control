import CoreLocation
import Foundation
import MapKit

/// A Pikmin Bloom point of interest from the bundled catalogue.
///
/// Bundled rather than fetched, for the same reason the landmark catalogue is:
/// choosing a place has to keep working with no network, and a static file
/// sends nothing anywhere. The file is built by
/// `scripts/build-pikmin-spots.py` from the piki knowledge base.
struct PikminSpot: Identifiable, Hashable, Sendable {
    enum Source: String, Sendable {
        case pureSpot = "p"
        case postcard = "c"
        case mushroom = "m"
    }

    let id: Int
    let name: String
    /// The place type a pure spot is filed under, or a source's own label.
    let type: String
    /// County for a Taiwanese pure spot, country for the other two.
    let area: String
    /// District, or the postcard's kind, or the mushroom's place.
    let detail: String
    let latitude: Double
    let longitude: Double
    let source: Source

    var target: LocationTarget {
        LocationTarget(
            name: name,
            subtitle: [area, detail].filter { !$0.isEmpty }.joined(separator: " · "),
            latitude: latitude,
            longitude: longitude
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(from origin: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: origin.latitude, longitude: origin.longitude))
    }

    func matches(_ query: String) -> Bool {
        let haystack = "\(name) \(type) \(area) \(detail)"
        return haystack.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }
}

/// What the map is being asked to show. Nothing until a reader picks
/// something: 7,000 pins would say less than none.
enum PikminSpotFilter: Equatable, Sendable {
    case type(String, label: String)

    var label: String {
        switch self { case .type(_, let label): label }
    }

    func includes(_ spot: PikminSpot) -> Bool {
        switch self { case .type(let type, _): spot.type == type }
    }
}

/// A decoration and the place type that yields it.
struct PikminDecoration: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let placeType: String
}

/// Loads the bundled catalogue once, on first use.
///
/// Reading 7,000-odd records is not free, so nothing touches the file until a
/// reader opens the browser. The app starts, pairs and runs a session without
/// ever loading it.
@MainActor
enum PikminSpotCatalogue {
    private static var loaded: (spots: [PikminSpot], decorations: [PikminDecoration])?

    private struct File: Decodable {
        struct Spot: Decodable {
            let n: String, t: String, c: String, d: String
            let la: Double, lo: Double, s: String
        }
        struct Decoration: Decodable {
            let n: String, t: String
        }
        let spots: [Spot]
        let decorations: [Decoration]
    }

    private static func load() -> (spots: [PikminSpot], decorations: [PikminDecoration]) {
        if let loaded { return loaded }

        guard
            let url = Bundle.main.url(forResource: "PikminSpots", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            let empty: (spots: [PikminSpot], decorations: [PikminDecoration]) = ([], [])
            loaded = empty
            return empty
        }

        let spots = file.spots.enumerated().map { index, s in
            PikminSpot(
                id: index,
                name: s.n,
                type: s.t,
                area: s.c,
                detail: s.d,
                latitude: s.la,
                longitude: s.lo,
                source: PikminSpot.Source(rawValue: s.s) ?? .pureSpot
            )
        }
        let decorations = file.decorations.map {
            PikminDecoration(name: $0.n, placeType: $0.t)
        }

        let result = (spots: spots, decorations: decorations)
        loaded = result
        return result
    }

    static var spots: [PikminSpot] { load().spots }

    /// Decorations with the number of spots that yield each, rarest first —
    /// the rare ones are the reason to have this list at all.
    static var decorationsByRarity: [(decoration: PikminDecoration, count: Int)] {
        let all = load()
        var counts: [String: Int] = [:]
        for spot in all.spots where spot.source == .pureSpot {
            counts[spot.type, default: 0] += 1
        }
        return all.decorations
            .map { ($0, counts[$0.placeType] ?? 0) }
            .sorted { $0.1 == $1.1 ? $0.0.name < $1.0.name : $0.1 < $1.1 }
    }

    static func spots(ofType type: String) -> [PikminSpot] {
        load().spots.filter { $0.type == type }
    }

    /// Areas for one source, with a count each, largest first.
    static func areas(for source: PikminSpot.Source) -> [(area: String, count: Int)] {
        var counts: [String: Int] = [:]
        for spot in load().spots where spot.source == source && !spot.area.isEmpty {
            counts[spot.area, default: 0] += 1
        }
        return counts.map { ($0.key, $0.value) }.sorted {
            $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1
        }
    }

    static func spots(source: PikminSpot.Source, area: String? = nil) -> [PikminSpot] {
        load().spots.filter {
            $0.source == source && (area == nil || $0.area == area)
        }
    }

    /// Spots inside a map's visible area, nearest the centre first.
    ///
    /// Capped, and deliberately low: past a certain density the pins cover the
    /// map they are meant to describe, and the reader is better served zooming
    /// in than being shown everything at once.
    static func spots(
        in region: MKCoordinateRegion,
        matching filter: PikminSpotFilter,
        limit: Int = 120
    ) -> [PikminSpot] {
        let latMin = region.center.latitude - region.span.latitudeDelta / 2
        let latMax = region.center.latitude + region.span.latitudeDelta / 2
        let lonMin = region.center.longitude - region.span.longitudeDelta / 2
        let lonMax = region.center.longitude + region.span.longitudeDelta / 2

        let inside = load().spots.filter {
            filter.includes($0)
                && $0.latitude >= latMin && $0.latitude <= latMax
                && $0.longitude >= lonMin && $0.longitude <= lonMax
        }
        guard inside.count > limit else { return inside }
        return Array(
            inside
                .sorted { $0.distance(from: region.center) < $1.distance(from: region.center) }
                .prefix(limit)
        )
    }

    /// Capped: a query like "台" matches thousands, and a list that long is
    /// slower to draw than it is useful to read.
    static func search(_ query: String, limit: Int = 200) -> [PikminSpot] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var found: [PikminSpot] = []
        for spot in load().spots where spot.matches(trimmed) {
            found.append(spot)
            if found.count == limit { break }
        }
        return found
    }
}
