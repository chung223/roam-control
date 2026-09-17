import CoreLocation
import Foundation

/// Reads a coordinate a person copied from somewhere else.
///
/// Coordinates arrive by being pasted — out of a message, a web page, another
/// app — so this takes the shapes they are written in rather than one format,
/// and says no to anything it is not sure about instead of guessing.
///
/// Shared because three things now read them: the search field, the Shortcuts
/// action, and a `roamcontrol://location` link.
enum CoordinateText {
    /// Brackets and whitespace are stripped, so "(28.472262, -81.473574)"
    /// works as well as the bare pair.
    static func parse(_ text: String) -> CLLocationCoordinate2D? {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "()[]"))
        )
        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        guard
            let latitude = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
            let longitude = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)),
            (-90...90).contains(latitude),
            (-180...180).contains(longitude)
        else { return nil }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Whether the text was meant to be a coordinate at all, so a search for
    /// "Taipei 101" is not answered with a complaint about latitude.
    static func looksLikeCoordinates(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "()[]"))
        )
        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return parts.allSatisfy {
            Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        }
    }

    /// Six decimal places is roughly a tenth of a metre; more is noise.
    static func describe(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }
}
