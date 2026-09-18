import CoreLocation
import Foundation

struct LocationTarget: Codable, Hashable, Identifiable, Sendable {
    /// A stable identity, independent of the coordinates. Two saved places may
    /// share a coordinate, and the same place may be reported with slightly
    /// different coordinates, so position cannot serve as identity.
    let id: UUID
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    /// Which group a saved favourite belongs to, or `nil` for none. It lives
    /// here rather than in a parallel map so that a favourite and its group
    /// cannot drift apart, and so that an exported file carries both.
    ///
    /// It means nothing on a history entry or on the target handed to the
    /// device, and nothing reads it there.
    var group: String?

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        latitude: Double,
        longitude: Double,
        group: String? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
        self.group = group
    }

    /// Favourites and history saved before identities were stored carry no
    /// `id`. Those records decode with a new identity rather than failing.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        group = try container.decodeIfPresent(String.self, forKey: .group)
    }

    /// Everything that identifies the place, with a different group. Used when
    /// a favourite is moved, so identity and position survive the move.
    func inGroup(_ group: String?) -> LocationTarget {
        LocationTarget(
            id: id,
            name: name,
            subtitle: subtitle,
            latitude: latitude,
            longitude: longitude,
            group: group
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension LocationTarget {
    /// About 1.1 metres of latitude. Reverse geocoding, a dropped pin and a
    /// search result rarely agree to the last digit for one place, so an exact
    /// comparison would save the same place repeatedly.
    static let samePlaceToleranceDegrees = 1e-5

    /// Whether two targets describe the same physical place, regardless of
    /// identity or name. Use this for favourite matching and history
    /// de-duplication; use `id` when a specific saved row is meant.
    func isSamePlace(as other: LocationTarget) -> Bool {
        let latitudeDelta = abs(latitude - other.latitude)
        guard latitudeDelta < Self.samePlaceToleranceDegrees else { return false }

        // Longitude wraps at the antimeridian, where 179.999999 and -179.999999
        // are neighbours rather than a world apart.
        let longitudeDelta = abs(longitude - other.longitude)
        return min(longitudeDelta, 360 - longitudeDelta) < Self.samePlaceToleranceDegrees
    }
}
