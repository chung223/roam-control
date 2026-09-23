import SwiftUI
import UniformTypeIdentifiers

/// The walk being put together: which places, in which order, and whether the
/// line between them belongs to Apple or to the person drawing it.
struct WalkPlannerView: View {
    @Environment(\.dismiss) private var dismiss

    let draft: WalkPlanDraft
    let isPlanning: Bool
    let errorMessage: String?
    let onPlan: () -> Void
    let onImport: (URL) -> Void

    @State private var isImporting = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                if draft.isEmpty {
                    Section {
                        EmptyPlanRow()
                    }
                } else {
                    Section {
                        ForEach(Array(draft.stops.enumerated()), id: \.element.id) { index, stop in
                            StopRow(number: index + 1, stop: stop)
                        }
                        .onDelete { draft.remove(atOffsets: $0) }
                        .onMove { draft.move(fromOffsets: $0, toOffset: $1) }
                    } header: {
                        HStack {
                            Text("Stops")
                            Spacer()
                            Button("Clear") { draft.clear() }
                                .textCase(nil)
                        }
                    } footer: {
                        Text("Walked in this order, starting from where the map is looking. Drag to reorder, swipe to remove.")
                    }
                }

                Section {
                    Toggle("Follow streets", isOn: followsStreetsBinding)
                } footer: {
                    // The straight-line case is not an eccentric preference:
                    // Apple declines to route through a park's interior, a
                    // campus, or most private land, and a walk there is simply
                    // impossible to plan the ordinary way.
                    Text(draft.followsStreets ? Self.streetsFooter : Self.straightFooter)
                }

                Section {
                    Button(action: onPlan) {
                        HStack(spacing: 8) {
                            if isPlanning {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "figure.walk")
                            }
                            Text(isPlanning ? "Planning…" : "Plan This Walk")
                        }
                    }
                    .disabled(draft.isEmpty || isPlanning)

                    Button {
                        isImporting = true
                    } label: {
                        Label("Import a GPX File", systemImage: "square.and.arrow.down")
                    }
                    .foregroundStyle(.primary)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(SproutTheme.accent)
                    }
                } footer: {
                    Text("A GPX file is walked exactly as recorded and replaces the stops above.")
                }
            }
            .sproutListBackground()
            .navigationTitle("Plan a Walk")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar {
                if !draft.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(editMode.isEditing ? "Done" : "Edit") {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: Self.gpxTypes
            ) { result in
                guard case .success(let url) = result else { return }
                onImport(url)
            }
        }
    }

    private static var streetsFooter: String {
        .appText("Each leg follows an Apple Maps walking route. Places Apple will not route to — inside a park, a campus, open country — cannot be planned this way.")
    }

    private static var straightFooter: String {
        .appText("The line goes straight from each place to the next, through whatever is in between. Nothing is asked of Apple Maps, so anywhere can be walked.")
    }

    /// GPX has no type of its own on iOS, so a file arrives as XML or as plain
    /// data depending on where it came from. Accepting all three is the
    /// difference between the file being pickable and being greyed out.
    private static let gpxTypes: [UTType] = [
        UTType(filenameExtension: "gpx") ?? .xml,
        .xml,
        .data,
    ]

    private var followsStreetsBinding: Binding<Bool> {
        Binding(
            get: { draft.followsStreets },
            set: { draft.followsStreets = $0 }
        )
    }
}

private struct StopRow: View {
    let number: Int
    let stop: LocationTarget

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(SproutTheme.primary)
                .frame(width: 22, height: 22)
                .background(SproutTheme.primarySoft, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(SessionMessage.localized(stop.name))
                    .font(.body)
                    .lineLimit(1)
                if !stop.subtitle.isEmpty {
                    Text(SessionMessage.localized(stop.subtitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct EmptyPlanRow: View {
    var body: some View {
        ContentUnavailableView(
            "No stops yet",
            systemImage: "point.topleft.down.to.point.bottomright.curvepath",
            description: Text("Choose a place on the map, then tap Add to Walk. Do it again for each place you want to pass.")
        )
        .listRowBackground(Color.clear)
    }
}
