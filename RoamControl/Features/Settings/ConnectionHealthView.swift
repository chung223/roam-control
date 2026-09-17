import SwiftUI
import UIKit

struct ConnectionHealthView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var diagnostics = ConnectionDiagnosticsCoordinator()
    @State private var directPath = DirectPathProbe()
    @State private var didCopyDirectPath = false
    @State private var isShowingDeviceSetup = false
    @State private var didCopyDiagnostics = false

    var body: some View {
        List {
            Section("Connection Health") {
                healthRow(
                    title: "Pairing",
                    value: pairingValue,
                    symbol: pairingSymbol,
                    color: pairingColor
                )

                healthRow(
                    title: "LocalDevVPN",
                    value: localDevVPNValue,
                    symbol: localDevVPNSymbol,
                    color: localDevVPNColor
                )

                healthRow(
                    title: "Location Session",
                    value: sessionValue,
                    symbol: sessionSymbol,
                    color: sessionColor
                )
            }

            Section("Restoration") {
                Text(appModel.deviceSession.restorationStatus)
                Text("An inactive session means Roam Control's worker has ended. Other apps may need time to acquire a fresh real location.")
                    .foregroundStyle(.secondary)
            }

            Section("Current Location") {
                LabeledContent("Place", value: activeTarget?.name ?? "None")
                LabeledContent("Coordinates", value: coordinatesValue)

                if let activeTarget, !activeTarget.subtitle.isEmpty {
                    LabeledContent("Area", value: activeTarget.subtitle)
                }
            }

            Section {
                Button {
                    Task { await runConnectionCheck() }
                } label: {
                    HStack {
                        Label("Run Connection Check", systemImage: "stethoscope")
                        Spacer()
                        if diagnostics.state == .running {
                            ProgressView()
                        }
                    }
                }
                .disabled(diagnostics.state == .running)

                if let resultMessage {
                    Label(resultMessage, systemImage: resultSymbol)
                        .font(.subheadline)
                        .foregroundStyle(resultColor)
                }

                if let lastChecked = diagnostics.lastChecked {
                    LabeledContent(
                        "Last checked",
                        value: lastChecked.formatted(date: .omitted, time: .shortened)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Connection Check")
            } footer: {
                Text("This checks the saved pairing record and whether the paired iPhone is visible through LocalDevVPN. It never starts, changes, or stops your location.")
            }

            Section {
                Button {
                    UIPasteboard.general.string = diagnosticsText
                    didCopyDiagnostics = true
                } label: {
                    Label(
                        didCopyDiagnostics ? "Diagnostics Copied" : "Copy Diagnostics",
                        systemImage: didCopyDiagnostics ? "checkmark" : "doc.on.doc"
                    )
                }
                .foregroundStyle(didCopyDiagnostics ? SproutTheme.positive : SproutTheme.text)
            } header: {
                Text("Support")
            } footer: {
                Text("Copies a status-only report you can paste into a bug report. It never includes locations, searches, pairing records, PINs, device names or error text.")
            }

            Section("Other VPNs") {
                Text("Another VPN may affect local device connections. If it is appropriate for your network, compare a test with that VPN paused. Keep LocalDevVPN enabled when starting a location session.")
                Text("Roam Control has not detected another VPN. This is a troubleshooting check, not a diagnosis; an iOS scheduler rejection happens before the pairing connection starts.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { @MainActor in
                        let record = try? await appModel.pairingService.pairingRecordData()
                        directPath.run(pairingRecord: record)
                    }
                } label: {
                    HStack {
                        Label("Run Direct Path Experiment", systemImage: "point.3.connected.trianglepath.dotted")
                        Spacer()
                        if directPath.state == .searching || directPath.state == .probing {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .foregroundStyle(.primary)
                .disabled(directPath.state == .searching || directPath.state == .probing)

                if case .failed(let message) = directPath.state {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(SproutTheme.accent)
                }

                ForEach(directPath.candidates) { candidate in
                    DirectPathRow(candidate: candidate)
                }

                if directPath.state == .finished {
                    Text(directPathConclusion)
                        .font(.footnote)
                        .foregroundStyle(
                            directPath.directPathWorks ? SproutTheme.positive : SproutTheme.textSecondary
                        )

                    Button {
                        UIPasteboard.general.string = directPathReport
                        didCopyDirectPath = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            didCopyDirectPath = false
                        }
                    } label: {
                        Label(
                            didCopyDirectPath ? "Copied" : "Copy Experiment Result",
                            systemImage: didCopyDirectPath ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text("Direct Path Experiment")
            } footer: {
                Text("Checks whether this iPhone's pairing service answers on the addresses Bonjour resolved, instead of only through LocalDevVPN. It opens a TCP connection and closes it without sending anything, and never starts, changes or stops a location session. The result includes local network addresses, so review it before sharing.")
            }

            Section("Help") {
                Button {
                    isShowingDeviceSetup = true
                } label: {
                    Label("Pairing & Connection", systemImage: "iphone.and.arrow.forward")
                }
                .foregroundStyle(.primary)

                Link(destination: appModel.localDevVPNInstallURL) {
                    Label("Open LocalDevVPN in App Store", systemImage: "arrow.up.right.square")
                }
            }
        }
        .sproutListBackground()
        .navigationTitle("Connection Health")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            diagnostics.cancel()
            directPath.cancel()
        }
        .sheet(isPresented: $isShowingDeviceSetup) {
            PairingSetupView()
                .environment(appModel)
        }
    }

    private var activeTarget: LocationTarget? {
        if case .active(let target) = appModel.deviceSession.phase {
            return target
        }
        return nil
    }

    private var coordinatesValue: String {
        guard let activeTarget else { return "None" }
        return String(format: "%.5f, %.5f", activeTarget.latitude, activeTarget.longitude)
    }

    private var pairingValue: String {
        switch appModel.pairingStatus {
        case .checking: "Checking"
        case .importing: "Importing"
        case .notPaired: "Not paired"
        case .paired: "Ready"
        case .failed: "Problem"
        }
    }

    private var pairingSymbol: String {
        switch appModel.pairingStatus {
        case .checking, .importing: "arrow.triangle.2.circlepath"
        case .notPaired: "exclamationmark.circle"
        case .paired: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private var pairingColor: Color {
        switch appModel.pairingStatus {
        case .checking, .importing: SproutTheme.primary
        case .notPaired: SproutTheme.accent
        case .paired: SproutTheme.positive
        case .failed: SproutTheme.accent
        }
    }

    private var localDevVPNValue: String {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return "Connected" }
            return "Not checked"
        case .running: return "Checking"
        case .passed: return "Reachable"
        case .failed: return "Not reachable"
        }
    }

    private var localDevVPNSymbol: String {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return "checkmark.circle.fill" }
            return "questionmark.circle"
        case .running: return "arrow.triangle.2.circlepath"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var localDevVPNColor: Color {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return SproutTheme.positive }
            return .secondary
        case .running: return SproutTheme.primary
        case .passed: return SproutTheme.positive
        case .failed: return SproutTheme.accent
        }
    }

    private var sessionValue: String {
        switch appModel.deviceSession.phase {
        case .idle: "Inactive"
        case .openingLocalDevVPN: "Opening LocalDevVPN"
        case .discovering: "Finding this iPhone"
        case .connecting: "Connecting"
        case .active: "Active"
        case .stopping: "Stopping"
        case .failed: "Failed"
        }
    }

    private var sessionSymbol: String {
        switch appModel.deviceSession.phase {
        case .idle: "pause.circle"
        case .openingLocalDevVPN, .discovering, .connecting: "arrow.triangle.2.circlepath"
        case .active: "location.circle.fill"
        case .stopping: "stop.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var sessionColor: Color {
        switch appModel.deviceSession.phase {
        case .idle: .secondary
        case .openingLocalDevVPN, .discovering, .connecting, .stopping: SproutTheme.primary
        case .active: SproutTheme.positive
        case .failed: SproutTheme.accent
        }
    }

    private var resultMessage: String? {
        switch diagnostics.state {
        case .notRun, .running: nil
        case .passed(let message), .failed(let message): message
        }
    }

    private var resultSymbol: String {
        switch diagnostics.state {
        case .passed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .notRun, .running: "circle"
        }
    }

    private var resultColor: Color {
        switch diagnostics.state {
        case .passed: SproutTheme.positive
        case .failed: SproutTheme.accent
        case .notRun, .running: .secondary
        }
    }

    private func healthRow(
        title: String,
        value: String,
        symbol: String,
        color: Color
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                        Text(value)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                        .frame(width: 22)
                    Text(title)
                    Spacer()
                    Text(value)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }

    @MainActor
    private func runConnectionCheck() async {
        do {
            let pairingRecord = try await appModel.pairingService.pairingRecordData()
            diagnostics.run(
                pairingRecord: pairingRecord,
                sessionPhase: appModel.deviceSession.phase
            )
        } catch {
            diagnostics.run(pairingRecord: nil, sessionPhase: appModel.deviceSession.phase)
        }
    }

    private var directPathConclusion: String {
        if directPath.directPathWorks {
            return String(
                localized: "A directly resolved address answered. LocalDevVPN may not be needed for this hop — worth confirming with a full session before relying on it."
            )
        }
        if directPath.localDevVPNWorks {
            return String(
                localized: "Only the LocalDevVPN address answered. The tunnel app is required for this hop."
            )
        }
        return String(
            localized: "Nothing answered. Check that LocalDevVPN is connected and the paired iPhone is awake, then run it again."
        )
    }

    private var directPathReport: String {
        var lines = ["Direct path experiment"]
        for candidate in directPath.candidates {
            let outcome: String
            switch candidate.outcome {
            case .pending: outcome = "not probed"
            case .reachable(let milliseconds): outcome = "REACHABLE in \(milliseconds)ms"
            case .refused(let reason): outcome = "refused (\(reason))"
            case .timedOut: outcome = "timed out"
            }
            lines.append("\(candidate.source.label): \(candidate.host):\(candidate.port) -> \(outcome)")
        }
        lines.append("Direct path works: \(directPath.directPathWorks)")
        lines.append("LocalDevVPN works: \(directPath.localDevVPNWorks)")
        return lines.joined(separator: "\n")
    }

    private var diagnosticsText: String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let runtimeBundleIdentifier = Bundle.main.bundleIdentifier ?? "Unknown"
        let permittedBackgroundTasks = (
            Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        )?.joined(separator: ", ") ?? "None"
        let checked = diagnostics.lastChecked?.formatted(date: .numeric, time: .standard) ?? "Not run"

        return """
        Roam Control Diagnostics
        Generated: \(Date().formatted(date: .numeric, time: .standard))
        App: \(appVersion) (\(build))
        iOS: \(UIDevice.current.systemVersion)
        Runtime bundle identifier: \(runtimeBundleIdentifier)
        Runtime permitted background tasks: \(permittedBackgroundTasks)
        Pairing: \(pairingValue)
        Last pairing failure stage (this launch): \(appModel.onDevicePairing.lastFailureStage?.rawValue ?? "None")
        Pairing scheduler reason (this launch): \(appModel.onDevicePairing.schedulerFailureReason?.rawValue ?? "None")
        Pairing task configuration: \(appModel.onDevicePairing.taskConfigurationStatus.rawValue)
        Pairing task registration: \(appModel.onDevicePairing.taskRegistrationStatus.rawValue)
        LocalDevVPN: \(localDevVPNValue)
        Session: \(sessionValue)
        Last session issue stage (this launch): \(appModel.deviceSession.lastFailureStage?.rawValue ?? "None")
        Last session issue disposition: \(appModel.deviceSession.lastFailureDisposition?.rawValue ?? "None")
        Session scheduler reason (this launch): \(appModel.deviceSession.schedulerFailureReason?.rawValue ?? "None")
        Location task configuration: \(appModel.deviceSession.taskConfigurationStatus.rawValue)
        Location task registration: \(appModel.deviceSession.taskRegistrationStatus.rawValue)
        Location scheduler mode: Registration observation only (no task submitted)
        Background keep-alive: coreLocation
        Background keep-alive status: \(appModel.deviceSession.backgroundKeepAlive.status.rawValue)
        Background keep-alive started: \(appModel.deviceSession.backgroundKeepAlive.started)
        Location BG scheduler available: \(appModel.deviceSession.backgroundTelemetry.schedulerAvailable)
        Restoration: \(appModel.deviceSession.restorationStatus)
        Last connection check: \(checked)
        Connection check result: \(diagnosticResultStatus)
        Appearance: \(appModel.appearance.title)
        Map style: \(appModel.mapDisplayStyle.title)
        Location data: Not included
        """
    }

    private var diagnosticResultStatus: String {
        switch diagnostics.state {
        case .notRun: "Not run"
        case .running: "Running"
        case .passed: "Passed"
        case .failed: "Failed"
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionHealthView()
            .environment(AppModel())
    }
}

/// One probed address and what happened when a TCP connection was opened to it.
private struct DirectPathRow: View {
    let candidate: DirectPathProbe.Candidate

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.source.label)
                    .font(SproutTheme.font(.subheadline, weight: .medium))
                Text("\(candidate.host):\(String(candidate.port))")
                    .font(.caption.monospaced())
                    .foregroundStyle(SproutTheme.textSecondary)
            }

            Spacer(minLength: 0)

            Text(outcomeText)
                .font(SproutTheme.font(.caption))
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(candidate.source.label), \(outcomeText)")
    }

    private var outcomeText: String {
        switch candidate.outcome {
        case .pending: String(localized: "Waiting")
        case .reachable(let milliseconds): String(localized: "Reachable · \(milliseconds) ms")
        case .refused(let reason): reason
        case .timedOut: String(localized: "Timed out")
        }
    }

    private var symbolName: String {
        switch candidate.outcome {
        case .pending: "circle.dashed"
        case .reachable: "checkmark.circle.fill"
        case .refused, .timedOut: "xmark.circle"
        }
    }

    private var tint: Color {
        switch candidate.outcome {
        case .pending: SproutTheme.textSecondary
        case .reachable: SproutTheme.positive
        case .refused, .timedOut: SproutTheme.textSecondary
        }
    }
}
