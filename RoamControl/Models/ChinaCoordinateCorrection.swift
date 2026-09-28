import CoreLocation
import Foundation

/// Undoes the offset Chinese mapping data carries.
///
/// Inside mainland China, map data is published in GCJ-02 rather than WGS-84:
/// a deliberate, non-linear offset of a few hundred metres. MapKit returns
/// GCJ-02 coordinates there, and draws its tiles in the same system, so a
/// place looks correct on the map. Handing that coordinate to location
/// simulation does not correct it, and the iPhone then reports a position a
/// few hundred metres from the place that was chosen.
///
/// The failure hides itself. The map agrees with the pin, because both are
/// offset by the same amount; only something reading the reported position
/// against the real world disagrees.
///
/// The transform is the published one. It is defined in the forward direction
/// — WGS-84 to GCJ-02 — so the reverse is found by applying it to a guess and
/// correcting the guess by the error, which converges to well under a metre in
/// a handful of passes.
enum ChinaCoordinateCorrection {
    /// Krasovsky 1940, which is what the published transform is defined on.
    private static let semiMajorAxis = 6_378_245.0
    private static let eccentricitySquared = 0.006_693_421_622_965_943

    /// Five is past the point where the result stops moving; the correction is
    /// sub-millimetre by the third.
    private static let passes = 5

    // MARK: - Whether to

    /// What to do about the offset.
    ///
    /// Three settings rather than a switch, because the boundary is a
    /// rectangle standing in for a border and a rectangle is sometimes wrong
    /// in both directions.
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        /// Correct inside mainland China and nowhere else.
        case automatic
        /// Never correct. For somewhere the guess is wrong, or for data that
        /// was already in WGS-84 before it reached the map.
        case off
        /// Always correct, wherever the place is. For somewhere inside the
        /// box that the exclusions wrongly exempt.
        case force

        var id: String { rawValue }

        var title: String {
            switch self {
            case .automatic: .appText("Automatic")
            case .off: .appText("Off")
            case .force: .appText("Always")
            }
        }
    }

    static let modeKey = "chinaCoordinateCorrectionMode"

    static var mode: Mode {
        get {
            Mode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .automatic
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: modeKey) }
    }

    /// The place to report, given the place that was chosen.
    ///
    /// Only the coordinate handed to the device moves. What the map shows
    /// stays where it was put, because that is where the reader pointed and
    /// the map draws in the offset system anyway — correcting the marker would
    /// move the pin off the building it names.
    static func correctedForDevice(_ target: LocationTarget) -> LocationTarget {
        // A number somebody typed is the number they meant. The map never
        // touched it, so there is nothing to undo.
        guard target.isLiteralCoordinate != true else { return target }

        switch mode {
        case .off:
            return target
        case .automatic where !isOffset(target.coordinate):
            return target
        case .automatic, .force:
            let corrected = wgs84(fromMapCoordinate: target.coordinate)
            return LocationTarget(
                id: target.id,
                name: target.name,
                subtitle: target.subtitle,
                latitude: corrected.latitude,
                longitude: corrected.longitude,
                group: target.group,
                isLiteralCoordinate: target.isLiteralCoordinate
            )
        }
    }

    // MARK: - Where it applies

    /// A box around mainland China, less the places served in WGS-84.
    ///
    /// Taiwan, Hong Kong and Macau sit inside the box and are not offset, so
    /// correcting there would introduce the error it exists to remove. The
    /// boundary is approximate by nature — this is a rectangle standing in for
    /// a border — which is why the choice can be overridden either way.
    static func isOffset(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard
            (73.5...135.1).contains(coordinate.longitude),
            (3.8...53.6).contains(coordinate.latitude)
        else { return false }

        for exclusion in servedInWGS84 where exclusion.contains(coordinate) {
            return false
        }
        return true
    }

    private struct Box {
        let latitudes: ClosedRange<Double>
        let longitudes: ClosedRange<Double>

        func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
            latitudes.contains(coordinate.latitude)
                && longitudes.contains(coordinate.longitude)
        }
    }

    private static let servedInWGS84 = [
        // Taiwan, including Penghu.
        Box(latitudes: 21.5...25.5, longitudes: 119.2...122.1),
        // Hong Kong.
        Box(latitudes: 22.1...22.6, longitudes: 113.8...114.5),
        // Macau.
        Box(latitudes: 22.0...22.3, longitudes: 113.5...113.7),
    ]

    // MARK: - The transform

    /// The coordinate to report, given one that came from the map.
    static func wgs84(fromMapCoordinate coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        var guess = coordinate
        for _ in 0..<passes {
            let offset = gcj02(fromWGS84: guess)
            guess = CLLocationCoordinate2D(
                latitude: guess.latitude - (offset.latitude - coordinate.latitude),
                longitude: guess.longitude - (offset.longitude - coordinate.longitude)
            )
        }
        return guess
    }

    /// The published direction, used to find the other one.
    static func gcj02(fromWGS84 coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let x = coordinate.longitude - 105.0
        let y = coordinate.latitude - 35.0
        var latitudeShift = latitudePolynomial(x: x, y: y)
        var longitudeShift = longitudePolynomial(x: x, y: y)

        let radians = coordinate.latitude / 180.0 * .pi
        var magic = sin(radians)
        magic = 1 - eccentricitySquared * magic * magic
        let rootMagic = sqrt(magic)

        latitudeShift = (latitudeShift * 180.0)
            / ((semiMajorAxis * (1 - eccentricitySquared)) / (magic * rootMagic) * .pi)
        longitudeShift = (longitudeShift * 180.0)
            / (semiMajorAxis / rootMagic * cos(radians) * .pi)

        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latitudeShift,
            longitude: coordinate.longitude + longitudeShift
        )
    }

    private static func latitudePolynomial(x: Double, y: Double) -> Double {
        var result = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y
            + 0.1 * x * y + 0.2 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        result += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        result += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return result
    }

    private static func longitudePolynomial(x: Double, y: Double) -> Double {
        var result = 300.0 + x + 2.0 * y + 0.1 * x * x
            + 0.1 * x * y + 0.1 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        result += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        result += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return result
    }
}
