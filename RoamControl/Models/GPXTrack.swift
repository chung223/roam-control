import CoreLocation
import Foundation

/// A route someone already has, as a file.
///
/// Planning a walk asks Apple where the streets are, and choosing every point
/// by hand asks a lot of taps. A GPX file is the third answer: a path recorded
/// or drawn somewhere else, walked exactly as it was given.
///
/// It reads track points first, then route points, then waypoints. A file
/// usually has one of the three, and a file with several means the track is
/// the path and the rest describes it.
struct GPXTrack {
    let name: String
    let coordinates: [CLLocationCoordinate2D]

    /// A recorded track is sampled every second or two, so an hour of walking
    /// is a few thousand points describing a line the map draws identically
    /// with far fewer. Thinning evenly keeps the shape and the endpoints.
    static let maximumPoints = 4_000

    init?(data: Data, fallbackName: String) {
        let parser = TrackParser()
        guard parser.parse(data) else { return nil }

        let points = parser.trackPoints.isEmpty
            ? (parser.routePoints.isEmpty ? parser.waypoints : parser.routePoints)
            : parser.trackPoints
        guard points.count >= 2 else { return nil }

        coordinates = Self.thinned(points)
        let parsedName = parser.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        name = (parsedName?.isEmpty ?? true) ? fallbackName : parsedName!
    }

    private static func thinned(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard points.count > maximumPoints else { return points }
        let stride = Double(points.count - 1) / Double(maximumPoints - 1)
        var kept = (0..<(maximumPoints - 1)).map { points[Int((Double($0) * stride).rounded(.down))] }
        // The last point is the destination, so it is kept exactly rather than
        // being whichever sample happened to land near it.
        kept.append(points[points.count - 1])
        return kept
    }
}

/// XMLParser rather than a regular expression: a GPX file is XML, attributes
/// can be quoted either way, and a file that is slightly malformed should fail
/// rather than be half-read into a walk that goes somewhere unintended.
private final class TrackParser: NSObject, XMLParserDelegate {
    private(set) var trackPoints: [CLLocationCoordinate2D] = []
    private(set) var routePoints: [CLLocationCoordinate2D] = []
    private(set) var waypoints: [CLLocationCoordinate2D] = []
    private(set) var name: String?

    private var isReadingName = false
    private var nameText = ""

    func parse(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        switch elementName {
        case "name" where name == nil:
            isReadingName = true
            nameText = ""
        case "trkpt", "rtept", "wpt":
            guard
                let latitude = attributes["lat"].flatMap(Double.init),
                let longitude = attributes["lon"].flatMap(Double.init),
                CLLocationCoordinate2DIsValid(
                    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                )
            else { return }
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            switch elementName {
            case "trkpt": trackPoints.append(coordinate)
            case "rtept": routePoints.append(coordinate)
            default: waypoints.append(coordinate)
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isReadingName else { return }
        nameText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        guard elementName == "name", isReadingName else { return }
        isReadingName = false
        name = nameText
    }
}
