import CoreLocation
import SwiftUI

/// Browse the bundled Pikmin Bloom catalogue.
///
/// Three ways in, because they answer different questions: by decoration for
/// "where do I get a taco", by county for "what is near me", and by country
/// for the postcards and mushroom spots. Searching cuts across all of them.
///
/// Selecting a spot does what picking a place on the map does — it becomes the
/// selected location. Starting a session stays a separate, deliberate step.
struct PikminSpotsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var tab: Tab = .decorations
    @State private var finder = PlaceFinder()
    @State private var ask = ""
    @FocusState private var isAsking: Bool

    /// Where the map is looking, so a list can answer "which of these is
    /// nearest" rather than leaving the reader to work it out.
    let origin: CLLocationCoordinate2D?
    let onSelect: (LocationTarget) -> Void
    let onShowOnMap: (PikminSpotFilter) -> Void
    /// Plan one walk that calls at all of these, nearest first. The reason a
    /// decoration list exists is that the decoration comes from any of them,
    /// and going to one of them five times is a different errand.
    let onPlanWalk: ([LocationTarget]) -> Void

    enum Tab: String, CaseIterable, Identifiable {
        case decorations, counties, world, ask
        var id: String { rawValue }

        var title: String {
            switch self {
            case .decorations: String(localized: "By decoration")
            case .counties: String(localized: "By county")
            case .world: String(localized: "Worldwide")
            case .ask: String(localized: "Ask")
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResults
                } else {
                    browser
                }
            }
            .sproutListBackground()
            .navigationTitle("Pikmin Spots")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("Search spots"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Browsing

    @ViewBuilder
    private var browser: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                // Always here. Hiding it was twice wrong: it left someone
                // unable to tell a missing feature from a broken one, and it
                // hid the very fact that would explain which.
                ForEach(Tab.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            switch tab {
            case .decorations: decorationList
            case .counties: countyList
            case .world: worldList
            case .ask: askList
            }
        }
    }

    private var decorationList: some View {
        List {
            Section {
                ForEach(PikminSpotCatalogue.decorationsByRarity, id: \.decoration.id) { entry in
                    NavigationLink {
                        SpotList(
                            title: entry.decoration.name,
                            spots: PikminSpotCatalogue.spots(ofType: entry.decoration.placeType),
                            origin: origin,
                            onSelect: select,
                            onShowOnMap: {
                                onShowOnMap(
                                    .type(entry.decoration.placeType, label: entry.decoration.name)
                                )
                                dismiss()
                            },
                            onPlanWalk: onPlanWalk
                        )
                    } label: {
                        row(
                            title: entry.decoration.name,
                            subtitle: entry.decoration.placeType,
                            count: entry.count
                        )
                    }
                }
            } footer: {
                Text("Rarest first. A decoration with few spots is the one worth travelling for.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var countyList: some View {
        List {
            ForEach(PikminSpotCatalogue.areas(for: .pureSpot), id: \.area) { entry in
                NavigationLink {
                    SpotList(
                        title: entry.area,
                        spots: PikminSpotCatalogue.spots(source: .pureSpot, area: entry.area),
                        origin: origin,
                        onSelect: select,
                        onShowOnMap: nil,
                        onPlanWalk: onPlanWalk
                    )
                } label: {
                    row(title: entry.area, subtitle: nil, count: entry.count)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var worldList: some View {
        List {
            Section {
                ForEach(PikminSpotCatalogue.areas(for: .postcard), id: \.area) { entry in
                    NavigationLink {
                        SpotList(
                            title: entry.area,
                            spots: PikminSpotCatalogue.spots(source: .postcard, area: entry.area),
                            origin: origin,
                            onSelect: select,
                            onShowOnMap: nil,
                            onPlanWalk: onPlanWalk
                        )
                    } label: {
                        row(title: entry.area, subtitle: nil, count: entry.count)
                    }
                }
            } header: {
                Text("Postcards")
            }

            Section {
                ForEach(PikminSpotCatalogue.areas(for: .mushroom), id: \.area) { entry in
                    NavigationLink {
                        SpotList(
                            title: entry.area,
                            spots: PikminSpotCatalogue.spots(source: .mushroom, area: entry.area),
                            origin: origin,
                            onSelect: select,
                            onShowOnMap: nil,
                            onPlanWalk: onPlanWalk
                        )
                    } label: {
                        row(title: entry.area, subtitle: nil, count: entry.count)
                    }
                }
            } header: {
                // Not only mushrooms: this source files flowers and detectors
                // too, and each row says which it is.
                Text("Mushrooms, flowers and detectors")
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Runs entirely on the device, which is why it is here at all: the rest
    /// of this catalogue is bundled and offline so that where someone wants to
    /// be stays on their phone.
    private var askList: some View {
        List {
            if let reason = finder.unavailableReason {
                Section {
                    Text(reason)
                        .font(SproutTheme.font(.subheadline))
                        .foregroundStyle(SproutTheme.textSecondary)
                }
            }

            Section {
                HStack(spacing: 10) {
                    TextField("What are you looking for?", text: $ask, axis: .vertical)
                        .focused($isAsking)
                        .submitLabel(.search)
                        .onSubmit { runAsk() }
                        .disabled(!finder.isAvailable)

                    if finder.isSearching {
                        ProgressView()
                    } else {
                        Button("Ask", systemImage: "arrow.up.circle.fill") { runAsk() }
                            .labelStyle(.iconOnly)
                            .font(SproutTheme.font(.title3))
                            .foregroundStyle(SproutTheme.primary)
                            .disabled(ask.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            } footer: {
                Text("Answered on this iPhone, from the bundled catalogue. Nothing is sent anywhere.")
            }

            if let explanation = finder.explanation, !explanation.isEmpty {
                Section {
                    Text(explanation)
                        .font(SproutTheme.font(.subheadline))
                        .foregroundStyle(SproutTheme.textSecondary)
                }
            }

            if let failure = finder.failure {
                Section {
                    Text(failure)
                        .font(SproutTheme.font(.subheadline))
                        .foregroundStyle(SproutTheme.accent)
                }
            }

            if !finder.results.isEmpty {
                Section {
                    ForEach(finder.results) { spot in
                        SpotRow(spot: spot, origin: origin) { select(spot) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func runAsk() {
        isAsking = false
        Task { await finder.find(ask, near: origin) }
    }

    private var searchResults: some View {
        let results = PikminSpotCatalogue.search(query)
        return Group {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    ForEach(results) { spot in
                        SpotRow(spot: spot, origin: origin) { select(spot) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Pieces

    private func row(title: String, subtitle: String?, count: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SproutTheme.font(.body, weight: .medium))
                    .foregroundStyle(SproutTheme.text)
                if let subtitle, subtitle != title {
                    Text(subtitle)
                        .font(SproutTheme.font(.caption))
                        .foregroundStyle(SproutTheme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            Text(count.formatted())
                .font(SproutTheme.font(.caption, weight: .medium).monospacedDigit())
                .foregroundStyle(count == 0 ? SproutTheme.textSecondary : SproutTheme.primary)
        }
    }

    private func select(_ spot: PikminSpot) {
        onSelect(spot.target)
        dismiss()
    }
}

// MARK: - Spot list

private struct SpotList: View {
    /// Nearest first is already the order, so a count is the whole choice.
    static let stopCounts = [3, 5, 8]

    let title: String
    let spots: [PikminSpot]
    let origin: CLLocationCoordinate2D?
    let onSelect: (PikminSpot) -> Void
    let onShowOnMap: (() -> Void)?
    let onPlanWalk: ([LocationTarget]) -> Void

    /// Nearest first when the map has told us where it is looking. Five taco
    /// spots in the country is only useful once you know which one is yours.
    private var ordered: [PikminSpot] {
        guard let origin else { return spots }
        return spots.sorted { $0.distance(from: origin) < $1.distance(from: origin) }
    }

    var body: some View {
        Group {
            if spots.isEmpty {
                ContentUnavailableView(
                    "No spots recorded",
                    systemImage: "mappin.slash",
                    description: Text("Nothing in the catalogue yields this yet.")
                )
            } else {
                List {
                    ForEach(ordered) { spot in
                        SpotRow(spot: spot, origin: origin) { onSelect(spot) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sproutListBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onShowOnMap, !spots.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Show on map", systemImage: "map") { onShowOnMap() }
                }
            }
            if ordered.count >= 2 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Counts rather than a free number. Each stop is a
                        // separate directions request, and MapKit throttles;
                        // a walk through forty places would spend longer being
                        // planned than walked.
                        ForEach(Self.stopCounts.filter { $0 <= ordered.count }, id: \.self) { count in
                            Button {
                                onPlanWalk(ordered.prefix(count).map(\.target))
                            } label: {
                                Text(String(format: .appText("Through %lld stops"), count))
                            }
                        }
                    } label: {
                        Label("Plan a walk", systemImage: "figure.walk.circle")
                    }
                }
            }
        }
    }
}

private struct SpotRow: View {
    let spot: PikminSpot
    let origin: CLLocationCoordinate2D?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(SproutTheme.font(.body))
                    .foregroundStyle(SproutTheme.primary)
                    .frame(width: 26)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(spot.name)
                        .font(SproutTheme.font(.body, weight: .medium))
                        .foregroundStyle(SproutTheme.text)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(SproutTheme.font(.caption))
                        .foregroundStyle(SproutTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let origin {
                    Text(distanceText(from: origin))
                        .font(SproutTheme.font(.caption, weight: .medium).monospacedDigit())
                        .foregroundStyle(SproutTheme.textSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(spot.name), \(subtitle)")
    }

    private var subtitle: String {
        [spot.type, spot.area, spot.detail]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func distanceText(from origin: CLLocationCoordinate2D) -> String {
        let metres = spot.distance(from: origin)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = metres < 1000 ? 0 : 1
        return formatter.string(from: Measurement(value: metres, unit: UnitLength.meters))
    }

    private var symbolName: String {
        switch spot.source {
        case .pureSpot: "leaf.fill"
        case .postcard: "photo.on.rectangle.angled"
        case .mushroom: "circle.hexagongrid.fill"
        }
    }
}
