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

    /// The catalogue is written in English. A reader sees their own language
    /// with the English kept beside it, because that is what the signage, the
    /// map and every other app will call the place.
    var localizedName: String { SessionMessage.localized(name) }

    var localizedLocality: String { SessionMessage.localized(locality) }

    /// True when the translation says something different from the English,
    /// so the English line can be left out rather than printed twice.
    var showsOriginalName: Bool { localizedName != name }

    var target: LocationTarget {
        LocationTarget(
            name: localizedName,
            subtitle: localizedLocality,
            latitude: latitude,
            longitude: longitude
        )
    }

    /// Case- and diacritic-insensitive match across the name and locality, so
    /// "sao paulo" finds "São Paulo" and "tokyo" finds the Tokyo entries.
    func matches(_ query: String) -> Bool {
        // Both languages, so either spelling finds the place.
        let haystack = "\(name) \(locality) \(localizedName) \(localizedLocality) \(region.displayName)"
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
        case .africa: .appText("Africa")
        case .asia: .appText("Asia")
        case .europe: .appText("Europe")
        case .northAmerica: .appText("North America")
        case .oceania: .appText("Oceania")
        case .southAmerica: .appText("South America")
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
