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

    let onSelect: (LocationTarget) -> Void

    enum Tab: String, CaseIterable, Identifiable {
        case decorations, counties, world
        var id: String { rawValue }

        var title: String {
            switch self {
            case .decorations: String(localized: "By decoration")
            case .counties: String(localized: "By county")
            case .world: String(localized: "Worldwide")
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
                ForEach(Tab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            switch tab {
            case .decorations: decorationList
            case .counties: countyList
            case .world: worldList
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
                            onSelect: select
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
                        onSelect: select
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
                            onSelect: select
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
                            onSelect: select
                        )
                    } label: {
                        row(title: entry.area, subtitle: nil, count: entry.count)
                    }
                }
            } header: {
                Text("Mushroom spots")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var searchResults: some View {
        let results = PikminSpotCatalogue.search(query)
        return Group {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    ForEach(results) { spot in
                        SpotRow(spot: spot) { select(spot) }
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
    let title: String
    let spots: [PikminSpot]
    let onSelect: (PikminSpot) -> Void

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
                    ForEach(spots) { spot in
                        SpotRow(spot: spot) { onSelect(spot) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sproutListBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SpotRow: View {
    let spot: PikminSpot
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

                Spacer(minLength: 0)
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

    private var symbolName: String {
        switch spot.source {
        case .pureSpot: "leaf.fill"
        case .postcard: "photo.on.rectangle.angled"
        case .mushroom: "circle.hexagongrid.fill"
        }
    }
}
