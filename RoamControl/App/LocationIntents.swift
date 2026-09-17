import AppIntents
import Foundation

/// Starting and stopping a session from outside the app: the Action button,
/// Siri, a Shortcut, an automation.
///
/// An intent cannot reach `AppModel`, which the app owns as view state, and it
/// should not: a session needs the app in front, because pairing, the tunnel
/// and the location worker all run in-process. So an intent records what was
/// asked for and brings the app forward, and the app carries it out on the way
/// in. That is also why every intent here sets `openAppWhenRun`.
enum LocationIntentRequest {
    private static let key = "pendingLocationIntentRequest"

    enum Kind: String {
        case start
        case stop
    }

    /// Posted for the case where the app is already in front, so there is no
    /// scene change to act on.
    static let posted = Notification.Name("LocationIntentRequestPosted")

    static func record(_ kind: Kind, targetID: UUID? = nil) {
        var request: [String: String] = ["kind": kind.rawValue]
        if let targetID {
            request["target"] = targetID.uuidString
        }
        UserDefaults.standard.set(request, forKey: key)
        NotificationCenter.default.post(name: posted, object: nil)
    }

    /// Reads and clears in one step. A request is acted on once; a stale one
    /// left behind would start a session the next time the app opened.
    static func take() -> (kind: Kind, targetID: UUID?)? {
        guard
            let request = UserDefaults.standard.dictionary(forKey: key) as? [String: String],
            let kind = Kind(rawValue: request["kind"] ?? "")
        else { return nil }

        UserDefaults.standard.removeObject(forKey: key)
        return (kind, request["target"].flatMap(UUID.init(uuidString:)))
    }
}

// MARK: - Favourites as an entity

/// A saved place, offered to Shortcuts so a person picks from their own
/// favourites rather than typing a name that has to match.
struct FavouriteLocationEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Favourite Place")
    )
    static let defaultQuery = FavouriteLocationQuery()

    let id: UUID
    let name: String
    let subtitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: subtitle.isEmpty ? nil : "\(subtitle)"
        )
    }
}

struct FavouriteLocationQuery: EntityQuery {
    /// Read from the same store the app writes, rather than from AppModel,
    /// which does not exist when Shortcuts is the one asking.
    private func favourites() -> [LocationTarget] {
        guard
            let data = UserDefaults.standard.data(forKey: AppModel.favouritesDefaultsKey),
            let saved = try? JSONDecoder().decode([LocationTarget].self, from: data)
        else { return [] }
        return saved
    }

    func entities(for identifiers: [UUID]) async throws -> [FavouriteLocationEntity] {
        let wanted = Set(identifiers)
        return favourites()
            .filter { wanted.contains($0.id) }
            .map { FavouriteLocationEntity(id: $0.id, name: $0.name, subtitle: $0.subtitle) }
    }

    func suggestedEntities() async throws -> [FavouriteLocationEntity] {
        favourites().map {
            FavouriteLocationEntity(id: $0.id, name: $0.name, subtitle: $0.subtitle)
        }
    }
}

// MARK: - Intents

struct StartLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Location"
    static let description = IntentDescription(
        "Reports a saved place as this iPhone's location."
    )
    /// A session cannot run without the app in front, so there is nothing to
    /// gain by pretending otherwise.
    static let openAppWhenRun = true

    @Parameter(title: "Place")
    var place: FavouriteLocationEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        LocationIntentRequest.record(.start, targetID: place.id)
        return .result()
    }
}

struct StopLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Location"
    static let description = IntentDescription(
        "Ends the session and restores this iPhone's real location."
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        LocationIntentRequest.record(.stop)
        return .result()
    }
}

// MARK: - Shortcuts

struct SproutShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartLocationIntent(),
            phrases: [
                "Start a location in \(.applicationName)",
                "Set my location with \(.applicationName)",
            ],
            shortTitle: "Start Location",
            systemImageName: "location.fill"
        )
        AppShortcut(
            intent: StopLocationIntent(),
            phrases: [
                "Stop the location in \(.applicationName)",
                "Restore my location with \(.applicationName)",
            ],
            shortTitle: "Stop Location",
            systemImageName: "location.slash"
        )
    }
}
