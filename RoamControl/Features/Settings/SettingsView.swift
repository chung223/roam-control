import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private static let bugReportURL = URL(
        string: "https://github.com/chung223/roam-control/issues/new?template=bug_report.yml"
    )!
    private static let featureRequestURL = URL(
        string: "https://github.com/chung223/roam-control/issues/new?template=feature_request.yml"
    )!

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isShowingDeviceSetup = false
    @State private var isReplayingOnboarding = false
    @State private var isConfirmingReset = false
    @State private var resetError: String?
    @State private var isExportingPlaces = false
    @State private var isImportingPlaces = false
    @State private var placesTransferMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Theme")
                            .font(.subheadline.weight(.medium))

                        themePicker
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Map Style")
                            .font(.subheadline.weight(.medium))

                        mapStylePicker
                    }
                    .padding(.vertical, 4)
                }

                Section("Device") {
                    NavigationLink {
                        ConnectionHealthView()
                            .environment(appModel)
                    } label: {
                        Label("Connection Health", systemImage: "stethoscope")
                    }

                    NavigationLink {
                        SessionHistoryView()
                            .environment(appModel)
                    } label: {
                        Label("Session History", systemImage: "clock.arrow.circlepath")
                    }

                    Button {
                        isShowingDeviceSetup = true
                    } label: {
                        Label {
                            pairingConnectionLabel
                        } icon: {
                            Image(systemName: "iphone.and.arrow.forward")
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    Toggle("Share Anonymous Usage Statistics",
                        isOn: anonymousUsageStatisticsBinding
                    )

                    NavigationLink {
                        UsageStatisticsPrivacyView()
                    } label: {
                        Label("What Is Shared", systemImage: "hand.raised.fill")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Optional and off by default. Helps estimate activity from participating installations. Locations, searches and pairing data are never included.")
                }

                Section("About") {
                    NavigationLink {
                        AboutRoamControlView()
                    } label: {
                        Label("About Roam Control", systemImage: "info.circle")
                    }

                    LabeledContent("Version", value: versionText)
                    LabeledContent("Build", value: buildNumberText)
                    LabeledContent("Built", value: buildDateText)

                    Button {
                        isReplayingOnboarding = true
                    } label: {
                        Label("Replay Introduction", systemImage: "sparkles")
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    Button {
                        isExportingPlaces = true
                    } label: {
                        Label("Export Favourites", systemImage: "square.and.arrow.up")
                    }
                    .foregroundStyle(.primary)
                    .disabled(appModel.favouriteLocations.isEmpty)

                    Button {
                        isImportingPlaces = true
                    } label: {
                        Label("Import Favourites", systemImage: "square.and.arrow.down")
                    }
                    .foregroundStyle(.primary)

                    if let placesTransferMessage {
                        Text(placesTransferMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Saved Places")
                } footer: {
                    Text("Favourites live on this iPhone and nowhere else, so nothing holds a copy to restore from. An exported file is that copy, and it goes only where you put it. Importing adds places you do not already have and never removes one.")
                }

                Section {
                    Link(destination: Self.bugReportURL) {
                        Label("Report a Bug", systemImage: "ladybug")
                    }

                    Link(destination: Self.featureRequestURL) {
                        Label("Request a Feature", systemImage: "lightbulb")
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("GitHub may ask you to choose Bug Report or Feature Request first. For pairing or connection problems, open Connection Health and use Copy Diagnostics. Do not include pairing records, credentials or private locations.")
                }

                Section {
                    Button("Reset Roam Control", role: .destructive) {
                        isConfirmingReset = true
                    }
                } footer: {
                    Text("This clears the pairing record and local app settings, then shows onboarding again. It does not remove or change LocalDevVPN.")
                }
            }
            .sproutListBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: $isShowingDeviceSetup) {
            PairingSetupView()
                .environment(appModel)
        }
        .fullScreenCover(isPresented: $isReplayingOnboarding) {
            OnboardingView(isReplay: true)
                .environment(appModel)
        }
        .confirmationDialog(
            "Reset Roam Control?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset App", role: .destructive) {
                Task { await resetApp() }
            }
        } message: {
            Text("Your pairing record and local choices will be removed. You will return to the welcome screen.")
        }
        .fileExporter(
            isPresented: $isExportingPlaces,
            document: PlacesFile(document: appModel.exportedPlaces()),
            contentType: .json,
            defaultFilename: .appText("Sprout Favourites")
        ) { result in
            switch result {
            case .success:
                placesTransferMessage = .appText("Favourites exported.")
            case .failure:
                placesTransferMessage = .appText("Could not export favourites.")
            }
        }
        .fileImporter(
            isPresented: $isImportingPlaces,
            allowedContentTypes: [.json]
        ) { result in
            placesTransferMessage = importPlaces(from: result)
        }
        .alert("Reset could not finish", isPresented: isShowingResetError) {
            Button("OK", role: .cancel) {
                resetError = nil
            }
        } message: {
            Text(resetError ?? .appText("Please try again."))
        }
    }

    private var connectionLabel: String {
        switch appModel.connectionState {
        case .notConfigured: .appText("Not paired")
        case .ready: .appText("Ready")
        case .connecting: .appText("Connecting")
        case .active: .appText("Active")
        case .failed: .appText("Problem")
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appModel.appearance {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { appModel.appearance },
            set: appModel.setAppearance
        )
    }

    @ViewBuilder
    private var themePicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("Theme", selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label(appearance.title, systemImage: appearance.systemImage)
                        .tag(appearance)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker("Theme", selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label(appearance.title, systemImage: appearance.systemImage)
                        .tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var mapStylePicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("Map Style", selection: mapStyleBinding) {
                ForEach(MapDisplayStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker("Map Style", selection: mapStyleBinding) {
                ForEach(MapDisplayStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var pairingConnectionLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 3) {
                Text("Pairing & Connection")
                Text(connectionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text("Pairing & Connection")
                Spacer()
                Text(connectionLabel)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var mapStyleBinding: Binding<MapDisplayStyle> {
        Binding(
            get: { appModel.mapDisplayStyle },
            set: appModel.setMapDisplayStyle
        )
    }

    private var anonymousUsageStatisticsBinding: Binding<Bool> {
        Binding(
            get: { appModel.sharesAnonymousUsageStatistics },
            set: appModel.setSharesAnonymousUsageStatistics
        )
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0"
    }

    private var buildNumberText: String {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build ?? .appText("Unknown")
    }

    private var buildDateText: String {
        if
            let timestamp = Bundle.main.object(
                forInfoDictionaryKey: "RoamControlBuildTimestamp"
            ) as? String,
            let buildDate = ISO8601DateFormatter().date(from: timestamp)
        {
            return buildDate.formatted(date: .abbreviated, time: .shortened)
        }

        guard
            let executableURL = Bundle.main.executableURL,
            let values = try? executableURL.resourceValues(forKeys: [.contentModificationDateKey]),
            let buildDate = values.contentModificationDate
        else { return .appText("Unknown") }

        return buildDate.formatted(date: .abbreviated, time: .shortened)
    }

    /// The file arrives as a security-scoped URL, which has to be opened and
    /// closed around the read or its contents are simply unavailable.
    private func importPlaces(from result: Result<URL, any Error>) -> String {
        guard case .success(let url) = result else {
            return .appText("Could not read that file.")
        }
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard
            let data = try? Data(contentsOf: url),
            let document = try? decoder.decode(PlacesDocument.self, from: data)
        else {
            return .appText("That file is not a Sprout favourites file.")
        }
        guard document.isSupported else {
            return .appText("That file was made by a newer version of Sprout.")
        }

        let added = appModel.importPlaces(document)
        if added == 0 {
            return .appText("Every place in that file was already saved.")
        }
        return String(format: .appText("Added %lld favourites."), added)
    }

    private var isShowingResetError: Binding<Bool> {
        Binding(
            get: { resetError != nil },
            set: { if !$0 { resetError = nil } }
        )
    }

    @MainActor
    private func resetApp() async {
        do {
            try await appModel.resetApp()
            dismiss()
        } catch {
            resetError = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
}
