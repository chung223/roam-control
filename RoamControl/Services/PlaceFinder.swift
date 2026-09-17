import CoreLocation
import Foundation
import FoundationModels

/// Answers "where do I get a taco" against the bundled catalogue.
///
/// The model runs on the device. That is not a detail here, it is the reason
/// this is allowed to exist at all: everything else in this app is bundled and
/// offline precisely so that nothing about where someone wants to be leaves
/// their phone, and a cloud model would undo that in one call.
///
/// It is also the reason this is optional. Apple Intelligence needs hardware
/// the app's own minimum does not, so `availability` decides whether any of
/// this is offered — a button that does nothing is worse than no button.
@MainActor
@Observable
final class PlaceFinder {
    enum Availability: Equatable {
        case ready
        case deviceNotEligible
        case notEnabled
        case notReady
        case unavailable
    }

    private(set) var isSearching = false
    private(set) var results: [PikminSpot] = []
    private(set) var explanation: String?
    private(set) var failure: String?

    var availability: Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .notEnabled
            case .modelNotReady: return .notReady
            @unknown default: return .unavailable
            }
        @unknown default:
            return .unavailable
        }
    }

    var isAvailable: Bool { availability == .ready }

    /// For the diagnostics report, which is where a question like "why is
    /// this not offered" should be answerable without guessing.
    var availabilityDescription: String {
        switch availability {
        case .ready: "Available"
        case .deviceNotEligible: "Unavailable: device not eligible"
        case .notEnabled: "Unavailable: Apple Intelligence not enabled"
        case .notReady: "Unavailable: model not ready"
        case .unavailable: "Unavailable: unknown reason"
        }
    }

    var unavailableReason: String? {
        switch availability {
        case .ready:
            return nil
        case .notEnabled:
            return .appText("Turn on Apple Intelligence in Settings to ask questions here.")
        case .notReady:
            return .appText("Apple Intelligence is still preparing. Try again shortly.")
        case .deviceNotEligible, .unavailable:
            return .appText("This iPhone cannot run the on-device model.")
        }
    }

    func clear() {
        results = []
        explanation = nil
        failure = nil
    }

    func find(_ request: String, near origin: CLLocationCoordinate2D?) async {
        guard isAvailable else { return }
        let trimmed = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }
        clear()

        let tool = CatalogueTool(origin: origin)
        let session = LanguageModelSession(tools: [tool]) {
            """
            You help someone choose where to put their iPhone's reported \
            location, using only the bundled catalogue.

            Always call findPlaces before answering; you have no knowledge of \
            this catalogue otherwise. It answers with numbered candidates.

            Reply with the numbers of the candidates that fit, best first, at \
            most five of them, and one short sentence saying why. If nothing \
            fits, reply with no numbers and say so.
            """
        }

        do {
            let answer = try await session.respond(to: trimmed, generating: Answer.self).content
            results = answer.numbers.compactMap { tool.candidate(number: $0) }
            explanation = answer.reason
            if results.isEmpty, answer.reason.isEmpty {
                failure = .appText("Nothing in the catalogue matched that.")
            }
        } catch {
            failure = .appText("The on-device model could not answer that.")
        }
    }
}

/// What the model has to come back with. Numbers rather than names: a name it
/// retypes may not match anything, an index either resolves or does not.
@Generable
private struct Answer {
    @Guide(description: "Candidate numbers that fit, best first, at most five.")
    var numbers: [Int]
    @Guide(description: "One short sentence saying why, in the language of the request.")
    var reason: String
}

/// The catalogue, as something the model can look things up in.
///
/// It does the searching. The model only chooses, which is the part it is
/// good at — and it means a wrong answer is a wrong choice among real places
/// rather than an invented one.
private final class CatalogueTool: Tool {
    let name = "findPlaces"
    let description = """
        Searches the bundled catalogue of Pikmin Bloom spots and well-known \
        landmarks. Search by decoration name, place type, town, country or \
        place name. Answers with numbered candidates.
        """

    @Generable
    struct Arguments {
        @Guide(description: "What to look for: a decoration, a place type, a town, or a name.")
        var query: String
    }

    private let origin: CLLocationCoordinate2D?
    private let found = Box()

    init(origin: CLLocationCoordinate2D?) {
        self.origin = origin
    }

    /// Holds what was offered, so a number in the answer can be resolved back
    /// to the place it stood for.
    private final class Box: @unchecked Sendable {
        var spots: [PikminSpot] = []
    }

    func candidate(number: Int) -> PikminSpot? {
        let index = number - 1
        guard found.spots.indices.contains(index) else { return nil }
        return found.spots[index]
    }

    func call(arguments: Arguments) async throws -> String {
        let spots = await MainActor.run { () -> [PikminSpot] in
            var matches = PikminSpotCatalogue.search(arguments.query, limit: 60)

            // A decoration names a place type rather than matching a spot, so
            // "taco" has to become 墨西哥餐廳 before anything is found.
            let decorations = PikminSpotCatalogue.decorationsByRarity
            for entry in decorations where entry.decoration.name.localizedCaseInsensitiveContains(arguments.query)
                || arguments.query.localizedCaseInsensitiveContains(entry.decoration.name) {
                matches += PikminSpotCatalogue.spots(ofType: entry.decoration.placeType)
            }

            var seen = Set<Int>()
            var unique = matches.filter { seen.insert($0.id).inserted }
            if let origin {
                unique.sort { $0.distance(from: origin) < $1.distance(from: origin) }
            }
            return Array(unique.prefix(12))
        }

        found.spots = spots
        guard !spots.isEmpty else { return "No candidates." }

        return spots.enumerated().map { index, spot in
            let distance = origin.map { " about \(Int(spot.distance(from: $0) / 1000)) km away" } ?? ""
            return "\(index + 1). \(spot.name) — \(spot.type), \(spot.area)\(distance)"
        }
        .joined(separator: "\n")
    }
}
