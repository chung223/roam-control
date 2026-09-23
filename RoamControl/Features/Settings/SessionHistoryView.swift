import SwiftUI

/// What was done, listed. Deliberately not in Saved Places: every row there is
/// a place to choose, and a row here is something that happened. Mixing the two
/// would make a tap mean one thing in one list and another in the next.
///
/// It sits beside Connection Health for the same reason both exist — when a
/// session does not work, the next question is always whether it worked before.
struct SessionHistoryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isConfirmingClear = false

    var body: some View {
        List {
            if appModel.sessionHistory.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Sessions appear here once one reaches the iPhone.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(appModel.sessionHistory) { record in
                        SessionRow(record: record)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            appModel.removeSessionRecord(appModel.sessionHistory[index])
                        }
                    }
                } footer: {
                    Text("The last 50 sessions are kept on this iPhone. They are never sent anywhere and are not included in usage statistics.")
                }

                Section {
                    Button("Clear Session History", role: .destructive) {
                        isConfirmingClear = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SproutTheme.background)
        .navigationTitle("Session History")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Clear session history?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear Session History", role: .destructive) {
                appModel.clearSessionHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the record of past sessions. It does not affect favourites, history or pairing.")
        }
    }
}

private struct SessionRow: View {
    let record: SessionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: record.kind == .walkingRoute ? "figure.walk" : "mappin.circle.fill")
                    .foregroundStyle(SproutTheme.primary)
                Text(SessionMessage.localized(record.target.name))
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(outcomeLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(outcomeColour)
            }

            Text(startedText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let duration = record.duration {
                Text(durationText(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = SessionMessage.localized(record.failureMessage) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(SproutTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    /// Shown in the zone the session happened in, with the zone named when it
    /// is not the one being read in — otherwise the reading is a claim about a
    /// time that never happened anywhere.
    private var startedText: String {
        let formatter = DateFormatter()
        formatter.timeZone = record.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let time = formatter.string(from: record.startedAt)

        guard record.timeZone.identifier != TimeZone.current.identifier else { return time }
        let zone = record.timeZone.localizedName(for: .shortGeneric, locale: .current)
            ?? record.timeZone.identifier
        return "\(time) (\(zone))"
    }

    private var outcomeLabel: String {
        switch record.outcome {
        case .completed: .appText("Finished")
        case .failed: .appText("Failed")
        case .interrupted: .appText("Interrupted")
        case nil: .appText("Running")
        }
    }

    private var outcomeColour: Color {
        switch record.outcome {
        case .completed: SproutTheme.positive
        case .failed: SproutTheme.accent
        case .interrupted, nil: SproutTheme.textSecondary
        }
    }

    /// Whole units only. A session's worth is "about twenty minutes", and
    /// seconds of precision on a forty-minute walk is noise pretending to be
    /// information.
    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.allowedUnits = seconds < 60 ? [.second] : [.hour, .minute]
        formatter.maximumUnitCount = 2
        return formatter.string(from: TimeInterval(seconds)) ?? ""
    }
}
