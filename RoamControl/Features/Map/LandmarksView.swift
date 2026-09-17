import SwiftUI

/// Browse and search the bundled landmark catalogue.
///
/// Selecting a landmark does the same thing as picking a place on the map: it
/// becomes the selected location, and starting a session remains a separate,
/// deliberate step. Nothing here starts simulating on its own.
struct LandmarksView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    let onSelect: (LocationTarget) -> Void

    private var groups: [(region: LandmarkRegion, landmarks: [Landmark])] {
        LandmarkCatalogue.grouped(matching: query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List {
                        ForEach(groups, id: \.region) { group in
                            Section {
                                ForEach(group.landmarks) { landmark in
                                    LandmarkRow(landmark: landmark) {
                                        onSelect(landmark.target)
                                        dismiss()
                                    }
                                }
                            } header: {
                                Label(
                                    group.region.displayName,
                                    systemImage: group.region.symbolName
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .sproutListBackground()
            .navigationTitle("Landmarks")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search landmarks"
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct LandmarkRow: View {
    let landmark: Landmark
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: landmark.symbolName)
                    .font(.body)
                    .foregroundStyle(SproutTheme.primary)
                    .frame(width: 28)
                    .padding(6)
                    .background(SproutTheme.primarySoft, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(landmark.localizedName)
                        .font(SproutTheme.font(.body, weight: .medium))
                        .foregroundStyle(SproutTheme.text)

                    HStack(spacing: 5) {
                        if landmark.showsOriginalName {
                            Text(landmark.name)
                            Text(verbatim: "·")
                        }
                        Text(landmark.localizedLocality)
                    }
                    .font(SproutTheme.font(.caption))
                    .foregroundStyle(SproutTheme.textSecondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(landmark.localizedName), \(landmark.localizedLocality)")
        .accessibilityHint("Selects this place on the map")
    }
}
