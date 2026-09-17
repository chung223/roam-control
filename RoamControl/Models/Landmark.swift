import Foundation

/// A well-known place that can be selected without a network search.
///
/// The catalogue is bundled rather than fetched: choosing a test location is
/// the one thing that should still work when MapKit search is unavailable, and
/// a static list sends nothing anywhere.
struct Landmark: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// City and country, shown under the name and included in search.
    let locality: String
    let region: LandmarkRegion
    let latitude: Double
    let longitude: Double
    /// SF Symbol shown in the list.
    let symbolName: String

    var target: LocationTarget {
        LocationTarget(
            name: name,
            subtitle: locality,
            latitude: latitude,
            longitude: longitude
        )
    }

    /// Case- and diacritic-insensitive match across the name and locality, so
    /// "sao paulo" finds "São Paulo" and "tokyo" finds the Tokyo entries.
    func matches(_ query: String) -> Bool {
        let haystack = "\(name) \(locality) \(region.displayName)"
        return haystack.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }
}

enum LandmarkRegion: String, CaseIterable, Identifiable, Sendable {
    case africa
    case asia
    case europe
    case northAmerica
    case oceania
    case southAmerica

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .africa: "Africa"
        case .asia: "Asia"
        case .europe: "Europe"
        case .northAmerica: "North America"
        case .oceania: "Oceania"
        case .southAmerica: "South America"
        }
    }

    var symbolName: String {
        switch self {
        case .africa, .europe: "globe.europe.africa.fill"
        case .asia, .oceania: "globe.asia.australia.fill"
        case .northAmerica, .southAmerica: "globe.americas.fill"
        }
    }
}
