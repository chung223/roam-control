import SwiftUI

struct SavedPlacesView: View {
    private enum ClearTarget: String, Identifiable {
        case favourites
        case history

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var favouriteBeingRenamed: LocationTarget?
    @State private var favouriteName = ""
    @State private var favouriteBeingGrouped: LocationTarget?
    @State private var groupName = ""
    @State private var clearTarget: ClearTarget?
    @State private var editMode: EditMode = .inactive

    let favourites: [LocationTarget]
    let history: [LocationTarget]
    let shouldShowFavouriteReorderHint: Bool
    let isFavourite: (LocationTarget) -> Bool
    let onSelect: (LocationTarget) -> Void
    let onToggleFavourite: (LocationTarget) -> Void
    let onDeleteFavourite: (LocationTarget) -> Void
    let onMoveFavourites: (IndexSet, Int) -> Void
    let onDismissFavouriteReorderHint: () -> Void
    let onRenameFavourite: (LocationTarget, String) -> Void
    let onSetFavouriteGroup: (LocationTarget, String?) -> Void
    let onDeleteHistory: (LocationTarget) -> Void
    let onClearFavourites: () -> Void
    let onClearHistory: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if favourites.isEmpty {
                    Section {
                        EmptyFavouritesRow(
                            message: .appText("Tap the heart on any selected place to save it.")
                        )
                    } header: {
                        Text("Favourites")
                    }
                } else {
                    ForEach(favouriteSections, id: \.title) { section in
                        Section {
                            ForEach(section.locations) { location in
                                SavedPlaceRow(
                                    location: location,
                                    symbol: "heart.fill",
                                    isFavourite: true,
                                    onSelect: { select(location) },
                                    onToggleFavourite: { onToggleFavourite(location) }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        onDeleteFavourite(location)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        beginRenaming(location)
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .tint(SproutTheme.primary)

                                    Button {
                                        beginGrouping(location)
                                    } label: {
                                        Label("Group", systemImage: "folder")
                                    }
                                    .tint(SproutTheme.Pair.sage)
                                }
                            }
                            .onMove { source, destination in
                                move(in: section, from: source, to: destination)
                            }
                        } header: {
                            HStack {
                                Text(section.heading)
                                Spacer()
                                if section.isFirst {
                                    Button("Clear") {
                                        clearTarget = .favourites
                                    }
                                    .textCase(nil)
                                }
                            }
                        } footer: {
                            if section.isLast, shouldShowFavouriteReorderHint, favourites.count >= 2 {
                                Text("Tap Edit to rearrange favourites. Swipe one to put it in a group.")
                            }
                        }
                    }
                }

                Section {
                    if history.isEmpty {
                        EmptySavedPlacesRow(
                            symbol: "clock",
                            message: .appText("Places you use will appear here.")
                        )
                    } else {
                        ForEach(history) { location in
                            SavedPlaceRow(
                                location: location,
                                symbol: "clock.fill",
                                isFavourite: isFavourite(location),
                                onSelect: { select(location) },
                                onToggleFavourite: { onToggleFavourite(location) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteHistory(location)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("History")
                        Spacer()
                        if !history.isEmpty {
                            Button("Clear") {
                                clearTarget = .history
                            }
                                .textCase(nil)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .sproutListBackground()
            .navigationTitle("Saved Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !favourites.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(editMode.isEditing ? "Done" : "Edit") {
                            if !editMode.isEditing {
                                onDismissFavouriteReorderHint()
                            }
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                            .accessibilityLabel("Reorder favourites")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Rename Favourite",
                isPresented: Binding(
                    get: { favouriteBeingRenamed != nil },
                    set: { if !$0 { favouriteBeingRenamed = nil } }
                )
            ) {
                TextField("Favourite name", text: $favouriteName)
                Button("Cancel", role: .cancel) {
                    favouriteBeingRenamed = nil
                }
                Button("Save") {
                    guard let favouriteBeingRenamed else { return }
                    onRenameFavourite(favouriteBeingRenamed, favouriteName)
                    self.favouriteBeingRenamed = nil
                }
                .disabled(favouriteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Give this saved place a name that is easy to recognise.")
            }
            .alert(
                "Group Favourite",
                isPresented: Binding(
                    get: { favouriteBeingGrouped != nil },
                    set: { if !$0 { favouriteBeingGrouped = nil } }
                )
            ) {
                TextField("Group name", text: $groupName)
                Button("Cancel", role: .cancel) {
                    favouriteBeingGrouped = nil
                }
                // Clearing the field is how a favourite leaves a group, so
                // this is deliberately not disabled when it is empty.
                Button("Save") {
                    guard let favouriteBeingGrouped else { return }
                    onSetFavouriteGroup(favouriteBeingGrouped, groupName)
                    self.favouriteBeingGrouped = nil
                }
            } message: {
                Text("Favourites with the same group name are listed together. Leave it empty to remove this one from its group.")
            }
            .confirmationDialog(
                clearConfirmationTitle,
                isPresented: Binding(
                    get: { clearTarget != nil },
                    set: { if !$0 { clearTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(clearConfirmationButton, role: .destructive) {
                    performClear()
                }
                Button("Cancel", role: .cancel) {
                    clearTarget = nil
                }
            } message: {
                Text(clearConfirmationMessage)
            }
        }
    }

    private func select(_ location: LocationTarget) {
        onSelect(location)
        dismiss()
    }

    private func beginRenaming(_ location: LocationTarget) {
        favouriteName = location.name
        favouriteBeingRenamed = location
    }

    private func beginGrouping(_ location: LocationTarget) {
        groupName = location.group ?? ""
        favouriteBeingGrouped = location
    }

    /// One section per group, in name order, with the ungrouped ones last.
    /// A group exists only for as long as something is in it, so there is
    /// nothing to create beforehand and nothing left empty afterwards.
    private var favouriteSections: [FavouriteSection] {
        var byGroup: [String: [LocationTarget]] = [:]
        var ungrouped: [LocationTarget] = []
        for location in favourites {
            if let group = location.group {
                byGroup[group, default: []].append(location)
            } else {
                ungrouped.append(location)
            }
        }

        var sections = byGroup.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { FavouriteSection(title: $0, isGrouped: true, locations: byGroup[$0] ?? []) }
        if !ungrouped.isEmpty || sections.isEmpty {
            sections.append(
                FavouriteSection(
                    title: "",
                    isGrouped: false,
                    // Without a group, the heading is the list's own, so it
                    // reads as Favourites rather than as a nameless group.
                    locations: ungrouped
                )
            )
        }
        for index in sections.indices {
            sections[index].isFirst = index == 0
            sections[index].isLast = index == sections.count - 1
        }
        return sections
    }

    /// A move inside a section is a move of the flat list, since the flat
    /// order is what is stored and the sections are only how it is read.
    /// Translating here keeps `onMoveFavourites` unchanged and unaware.
    private func move(in section: FavouriteSection, from source: IndexSet, to destination: Int) {
        let positions = section.locations.compactMap { location in
            favourites.firstIndex { $0.id == location.id }
        }
        guard positions.count == section.locations.count else { return }

        let globalSource = IndexSet(source.compactMap { offset in
            positions.indices.contains(offset) ? positions[offset] : nil
        })
        let globalDestination = destination < positions.count
            ? positions[destination]
            : (positions.last.map { $0 + 1 } ?? favourites.count)
        onMoveFavourites(globalSource, globalDestination)
    }

    private var clearConfirmationTitle: String {
        switch clearTarget {
        case .favourites: .appText("Clear all favourites?")
        case .history: .appText("Clear location history?")
        case nil: .appText("Clear saved places?")
        }
    }

    private var clearConfirmationButton: String {
        switch clearTarget {
        case .favourites: .appText("Clear Favourites")
        case .history: .appText("Clear History")
        case nil: .appText("Clear")
        }
    }

    private var clearConfirmationMessage: String {
        switch clearTarget {
        case .favourites: .appText("Every favourite will be removed. Your history will be kept.")
        case .history: .appText("Every recently used location will be removed. Your favourites will be kept.")
        case nil: .appText("This cannot be undone.")
        }
    }

    private func performClear() {
        switch clearTarget {
        case .favourites:
            onClearFavourites()
        case .history:
            onClearHistory()
        case nil:
            break
        }
        clearTarget = nil
    }
}

private struct FavouriteSection {
    let title: String
    let isGrouped: Bool
    var locations: [LocationTarget]
    var isFirst = false
    var isLast = false

    var heading: String {
        isGrouped ? title : .appText("Favourites")
    }
}

private struct SavedPlaceRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let location: LocationTarget
    let symbol: String
    let isFavourite: Bool
    let onSelect: () -> Void
    let onToggleFavourite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(symbol.hasPrefix("heart") ? SproutTheme.accent : SproutTheme.primary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(location.name)
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        Text(location.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(locationAccessibilityLabel)
            .accessibilityHint("Selects this location")

            Button(action: onToggleFavourite) {
                Image(systemName: isFavourite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavourite ? SproutTheme.accent : SproutTheme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: isFavourite ? .appText("Remove from favourites") : .appText("Add to favourites")))
        }
    }

    private var locationAccessibilityLabel: String {
        guard !location.subtitle.isEmpty else { return location.name }
        return "\(location.name), \(location.subtitle)"
    }
}

/// The favourites list is empty for every new reader, so it is the one
/// moment the mascot is doing a job rather than decorating.
private struct EmptyFavouritesRow: View {
    let message: String

    var body: some View {
        HStack(spacing: 14) {
            Image("SproutMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 60)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(SproutTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

private struct EmptySavedPlacesRow: View {
    let symbol: String
    let message: String

    var body: some View {
        Label(message, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }
}
