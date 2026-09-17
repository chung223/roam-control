import SwiftUI
import UIKit

struct LocationSelectionCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let location: LocationTarget?
    let isFavourite: Bool
    let isPaired: Bool
    let sessionPhase: DeviceSessionPhase
    let localDevVPNInstallURL: URL
    let isPreviewingWalkingRoute: Bool
    let walkingRouteError: String?
    let onToggleFavourite: () -> Void
    let onClearSelection: () -> Void
    let onPreviewWalkingRoute: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void

    @State private var didCopyCoordinates = false
    @State private var isConfirmingStop = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    cardContent
                }
                .frame(maxHeight: 460)
            } else {
                cardContent
            }
        }
        .sproutCard()
        .confirmationDialog(
            "Stop the simulated location and restore your real location?",
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button("Stop & Restore", role: .destructive, action: onStop)
            Button("Keep Simulated Location", role: .cancel) {}
        } message: {
            Text("Roam Control will end the simulated location and restore this iPhone's real location.")
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let location {
                locationHeader(for: location)

                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        if isWorking {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: primarySymbol)
                        }
                        Text(primaryTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: SproutTheme.Radius.control))
                .controlSize(.large)
                .font(SproutTheme.font(.body, weight: .semibold))
                .tint(SproutTheme.primary)
                .disabled(isPrimaryDisabled)

                if canPreviewWalkingRoute {
                    Button(action: onPreviewWalkingRoute) {
                        HStack(spacing: 8) {
                            if isPreviewingWalkingRoute {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "figure.walk")
                            }
                            Text(isPreviewingWalkingRoute ? "Planning Walking Route…" : "Preview Walking Route")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isPreviewingWalkingRoute)
                }

                if let walkingRouteError {
                    Text(SessionMessage.localized(walkingRouteError))
                        .font(SproutTheme.font(.caption))
                        .foregroundStyle(SproutTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isActive {
                    Button("Stop & Restore", role: .destructive) {
                        isConfirmingStop = true
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: SproutTheme.Radius.control))
                    .controlSize(.large)
                    .tint(SproutTheme.accent)
                    .font(SproutTheme.font(.body, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }

                Text(statusMessage)
                    .font(SproutTheme.font(.caption))
                    .foregroundStyle(isFailure ? SproutTheme.accent : SproutTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)

                if shouldOfferLocalDevVPN {
                    Link(destination: localDevVPNInstallURL) {
                        Label("Get LocalDevVPN", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.title2)
                        .foregroundStyle(SproutTheme.primary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Choose a location")
                            .font(SproutTheme.font(.headline, weight: .semibold))
                            .foregroundStyle(SproutTheme.text)
                        Text("Search above or tap anywhere on the map.")
                            .font(SproutTheme.font(.subheadline))
                            .foregroundStyle(SproutTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func locationHeader(for location: LocationTarget) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                locationSummary(for: location)
                HStack(spacing: 4) {
                    Spacer()
                    locationActions
                }
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                locationSummary(for: location)
                Spacer(minLength: 0)
                locationActions
            }
        }
    }

    private func locationSummary(for location: LocationTarget) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.title2)
                .foregroundStyle(SproutTheme.primary)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(SproutTheme.font(.headline, weight: .semibold))
                    .foregroundStyle(SproutTheme.text)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

                HStack(spacing: 7) {
                    Text(locationDescription(for: location))
                        .font(SproutTheme.font(.subheadline))
                        .foregroundStyle(SproutTheme.textSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)

                    Button {
                        copyLocation(for: location)
                    } label: {
                        Image(systemName: didCopyCoordinates ? "checkmark" : "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(didCopyCoordinates ? SproutTheme.positive : SproutTheme.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: didCopyCoordinates ? .appText("Location copied") : .appText("Copy location")))
                }
            }
        }
    }

    @ViewBuilder
    private var locationActions: some View {
        Button(action: onToggleFavourite) {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(isFavourite ? SproutTheme.accent : SproutTheme.textSecondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: isFavourite ? .appText("Remove from favourites") : .appText("Add to favourites")))

        if canClearSelection {
            Button(action: onClearSelection) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear selected location")
        }
    }

    private func locationDescription(for location: LocationTarget) -> String {
        let name = location.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = location.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subtitle.isEmpty else { return name }

        if subtitle.lowercased().hasPrefix(name.lowercased()) {
            let remainder = subtitle.dropFirst(name.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            if !remainder.isEmpty {
                return remainder
            }
        }

        return subtitle
    }

    private func copyLocation(for location: LocationTarget) {
        let name = location.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = location.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if subtitle.isEmpty || subtitle.caseInsensitiveCompare(name) == .orderedSame {
            UIPasteboard.general.string = name
        } else if subtitle.lowercased().hasPrefix(name.lowercased()) {
            UIPasteboard.general.string = subtitle
        } else {
            UIPasteboard.general.string = "\(name), \(subtitle)"
        }
        didCopyCoordinates = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            didCopyCoordinates = false
        }
    }

    private var isActive: Bool {
        if case .active = sessionPhase { return true }
        return false
    }

    private var isShowingActiveTarget: Bool {
        guard
            let location,
            case .active(let activeTarget) = sessionPhase
        else { return false }
        return location.isSamePlace(as: activeTarget)
    }

    private var isWorking: Bool {
        switch sessionPhase {
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            true
        case .idle, .active, .failed:
            false
        }
    }

    private var isFailure: Bool {
        if case .failed = sessionPhase { return true }
        return false
    }

    private var shouldOfferLocalDevVPN: Bool {
        guard case .failed(let message) = sessionPhase else { return false }
        return message.localizedCaseInsensitiveContains("Install LocalDevVPN")
    }

    private var primaryTitle: String {
        switch sessionPhase {
        case .openingLocalDevVPN:
            .appText("Opening LocalDevVPN…")
        case .discovering:
            .appText("Finding This iPhone…")
        case .connecting:
            .appText("Starting Location…")
        case .active:
            isShowingActiveTarget ? .appText("This Place Is Active") : .appText("Update Location")
        case .stopping:
            .appText("Restoring Real Location…")
        case .failed:
            .appText("Try Again")
        case .idle:
            .appText("Start Location")
        }
    }

    private var primarySymbol: String {
        switch sessionPhase {
        case .active: isShowingActiveTarget ? "checkmark.circle.fill" : "location.fill"
        case .failed: "arrow.clockwise"
        case .idle: "location.fill"
        case .openingLocalDevVPN, .discovering, .connecting, .stopping: "hourglass"
        }
    }

    private var isPrimaryDisabled: Bool {
        // Re-sending the place already being reported does nothing.
        if isActive, isShowingActiveTarget { return true }
        return isWorking || (!isPaired && !isActive)
    }

    private var canClearSelection: Bool {
        switch sessionPhase {
        case .idle, .failed:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
            false
        }
    }

    private var canPreviewWalkingRoute: Bool {
        switch sessionPhase {
        case .idle, .active:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .stopping, .failed:
            false
        }
    }

    private var statusMessage: String {
        switch sessionPhase {
        case .idle:
            return isPaired
                ? .appText("Start when ready. Stop restores this iPhone's real location.")
                : .appText("Pair this iPhone before starting location control.")
        case .openingLocalDevVPN:
            return .appText("Roam Control will return automatically after the tunnel starts.")
        case .discovering:
            return .appText("Finding the paired iPhone through the private local tunnel.")
        case .connecting:
            return .appText("Opening the secure location session.")
        case .active(let target):
            if !isShowingActiveTarget, let location {
                return String(
                    localized: "Currently using \(target.name). Update to move to \(location.name)."
                )
            }
            return String(
                localized: "This iPhone is using \(target.name). Stop & Restore ends the simulation and restores its real location."
            )
        case .stopping:
            return .appText("Restoring this iPhone's real location. Keep Roam Control open until this finishes.")
        case .failed(let message):
            // Native and session failures stay English internally; translate
            // only here, on the way to the screen.
            return SessionMessage.localized(message)
        }
    }

    private func primaryAction() {
        onStart()
    }
}
