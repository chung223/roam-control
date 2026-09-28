import Foundation

/// Whether a spot catalogue is the shape the app relies on.
///
/// This is `scripts/test-pikmin-catalogue.py` brought inside. The script runs
/// on one Mac and refuses a build; it cannot say anything about a catalogue
/// that arrives after the build, which is what a catalogue served from
/// somewhere would be. The same reasoning has to run where that file lands.
///
/// It asserts shape rather than contents. The contents change every time the
/// source is scraped again, and a check that pinned them would fail on every
/// legitimate update — which is a check nobody keeps.
///
/// The failure it exists for is the quiet one. The source files four kinds of
/// field report and the build script once labelled every record as one of
/// them. Nothing broke: the app simply said something untrue, for as long as
/// it took somebody to notice nine hundred flower spots under a mushroom
/// heading. A downloaded catalogue can go wrong the same way with nobody
/// watching at all.
enum PikminCatalogueCheck {
    /// The whole globe, deliberately. This is here to catch a zero, a swapped
    /// pair or a parse that produced a number of the wrong magnitude — not to
    /// police geography. A first pass narrowed it to the latitudes that seemed
    /// plausible and promptly rejected the Svalbard seed vault, two Antarctic
    /// research stations and a chapel on King George Island, all of which are
    /// real places somebody has filed a report from.
    private static let latitudes: ClosedRange<Double> = -90...90
    private static let longitudes: ClosedRange<Double> = -180...180

    /// Below this a catalogue is not a catalogue. The bundled one holds five
    /// figures; something that decoded into a handful of rows is a truncated
    /// download or a different file entirely.
    private static let minimumSpots = 5_000

    /// How large a source has to be before having only one kind is evidence
    /// rather than coincidence. A small source legitimately files one kind.
    private static let singleKindIsSuspiciousAbove = 1_000

    struct Result {
        /// Each problem in the reader's language of record: English, because
        /// these go into a diagnostics report meant to be pasted into a bug.
        let problems: [String]

        var isSound: Bool { problems.isEmpty }

        var summary: String {
            isSound ? "Sound" : problems.joined(separator: "; ")
        }
    }

    static func inspect(
        spots: [PikminSpot],
        decorations: [PikminDecoration],
        unrecognisedSources: Int = 0
    ) -> Result {
        var problems: [String] = []

        if spots.count < minimumSpots {
            problems.append("only \(spots.count) spots")
        }
        if decorations.isEmpty {
            problems.append("no decorations")
        }
        if unrecognisedSources > 0 {
            problems.append("\(unrecognisedSources) spots have an unknown source marker")
        }

        let misplaced = spots.filter {
            !latitudes.contains($0.latitude)
                || !longitudes.contains($0.longitude)
                || ($0.latitude == 0 && $0.longitude == 0)
        }
        if !misplaced.isEmpty {
            problems.append("\(misplaced.count) spots have impossible coordinates")
        }

        let unnamed = spots.filter { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        if !unnamed.isEmpty {
            problems.append("\(unnamed.count) spots have no name")
        }

        let untyped = spots.filter { $0.type.trimmingCharacters(in: .whitespaces).isEmpty }
        if !untyped.isEmpty {
            problems.append("\(untyped.count) spots have no type")
        }

        // The one this exists for.
        for source in PikminSpot.Source.allCases {
            let ofSource = spots.filter { $0.source == source }
            guard ofSource.count > singleKindIsSuspiciousAbove else { continue }
            let kinds = Set(ofSource.map(\.type))
            if kinds.count <= 1 {
                problems.append(
                    "source '\(source.rawValue)' has \(ofSource.count) spots of one type "
                    + "(\(kinds.first ?? "none")) — a kind is being discarded"
                )
            }
        }

        // A decoration naming a type no spot has offers somewhere nobody can go.
        let types = Set(spots.map(\.type))
        let unresolved = decorations.filter { !types.contains($0.placeType) }
        if !unresolved.isEmpty {
            let named = unresolved.prefix(3).map(\.name).joined(separator: ", ")
            problems.append("\(unresolved.count) decorations name a missing place type: \(named)")
        }

        return Result(problems: problems)
    }
}
