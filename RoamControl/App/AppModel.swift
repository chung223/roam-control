import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private static let onboardingKey = "hasCompletedOnboarding"
    /// Not private: the Shortcuts query reads the same store, because it runs
    /// when there is no AppModel to ask.
    static let favouritesDefaultsKey = "favouriteLocations"
    private static let hasSeenFavouriteReorderHintKey = "hasSeenFavouriteReorderHint"
    private static let historyKey = "locationHistory"
    private static let appearanceKey = "appAppearance"
    private static let mapDisplayStyleKey = "mapDisplayStyle"
    private static let activeSessionRecoveryKey = "activeSessionRecovery"
    private static let anonymousUsageStatisticsKey = "sharesAnonymousUsageStatistics"

    private let preferences: UserDefaults

    private(set) var hasCompletedOnboarding: Bool
    private(set) var shouldPresentDeviceSetup = false
    private(set) var connectionState: ConnectionState = .notConfigured
    private(set) var pairingStatus: PairingStatus = .checking
    private(set) var selectedTarget: LocationTarget?
    private(set) var favouriteLocations: [LocationTarget]
    private(set) var hasSeenFavouriteReorderHint: Bool
    private(set) var locationHistory: [LocationTarget]
    private(set) var appearance: AppAppearance
    private(set) var mapDisplayStyle: MapDisplayStyle
    private(set) var sharesAnonymousUsageStatistics: Bool
    private(set) var interruptedSession: SessionRecoveryRecord?
    private(set) var isRestoringInterruptedSession = false
    private(set) var interruptedSessionError: String?

    private var activeSessionRecovery: SessionRecoveryRecord?
    private var lastRecoverySaveDate: Date?
    private var restorationReachedActiveSession = false
    private var restorationWasCancelled = false
    private var isStoppingLocationSessionForRestoration = false
    private var pendingSessionAnalyticsEvent: UsageAnalyticsEvent?
    private var activeSessionIsWalkingRoute = false

    let pairingService: any PairingService
    let onDevicePairing: OnDevicePairingCoordinator
    let deviceSession: LocalDeviceSessionCoordinator
    let liveActivity = RoamSessionLiveActivityController()
    private let usageAnalytics: UsageAnalyticsService
    let localDevVPNInstallURL = URL(string: "https://apps.apple.com/app/localdevvpn/id6755608044")!

    init(
        pairingService: any PairingService = SecurePairingService(),
        preferences: UserDefaults = .standard
    ) {
        self.pairingService = pairingService
        self.onDevicePairing = .shared
        self.deviceSession = LocalDeviceSessionCoordinator()
        self.usageAnalytics = UsageAnalyticsService(preferences: preferences)
        self.preferences = preferences
        let hasCompletedOnboarding = preferences.bool(forKey: Self.onboardingKey)
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.favouriteLocations = Self.locations(forKey: Self.favouritesDefaultsKey, in: preferences)
        self.hasSeenFavouriteReorderHint = preferences.bool(forKey: Self.hasSeenFavouriteReorderHintKey)
        self.locationHistory = Self.locations(forKey: Self.historyKey, in: preferences)
        self.appearance = AppAppearance(
            rawValue: preferences.string(forKey: Self.appearanceKey) ?? ""
        ) ?? .automatic
        self.mapDisplayStyle = MapDisplayStyle(
            rawValue: preferences.string(forKey: Self.mapDisplayStyleKey) ?? ""
        ) ?? .standard
        self.sharesAnonymousUsageStatistics = Self.initialUsageStatisticsPreference(
            in: preferences
        )
        self.interruptedSession = Self.recoveryRecord(in: preferences)

        onDevicePairing.onFailure = { [weak self] diagnostic in
            guard let self else { return }
            self.usageAnalytics.recordFailure(
                diagnostic,
                context: .pairing,
                enabled: self.sharesAnonymousUsageStatistics
            )
        }
        deviceSession.onFailure = { [weak self] diagnostic in
            guard let self else { return }
            let restoring = self.isRestoringInterruptedSession || self.isStoppingLocationSessionForRestoration
            self.usageAnalytics.recordFailure(
                diagnostic,
                context: restoring ? .restoration : .location,
                enabled: self.sharesAnonymousUsageStatistics
            )
        }

        deviceSession.onRecoveryNeeded = { [weak self] diagnostic in
            guard let self else { return }
            let restoring = self.isRestoringInterruptedSession || self.isStoppingLocationSessionForRestoration
            self.usageAnalytics.recordFailure(
                diagnostic,
                context: restoring ? .restoration : .location,
                enabled: self.sharesAnonymousUsageStatistics
            )
        }
        usageAnalytics.backgroundSession = { [weak self] in
            self?.deviceSession.backgroundTelemetry ?? BackgroundSessionTelemetry(
                status: .idle, started: false, schedulerAvailable: false
            )
        }
        deviceSession.onBackgroundEvent = { [weak self] event, _ in
            guard let self else { return }
            self.usageAnalytics.record(event, enabled: self.sharesAnonymousUsageStatistics)
        }
        deviceSession.onConnectionEvent = { [weak self] event in
            guard let self else { return }
            self.usageAnalytics.record(event, enabled: self.sharesAnonymousUsageStatistics)
        }
        deviceSession.onPhaseChange = { [weak self] phase in
            self?.applyDeviceSessionPhase(phase)
        }
        onDevicePairing.onPhaseChange = { [weak self] phase in
            guard case .failed = phase else { return }
            self?.usageAnalytics.record(
                .pairingFailed,
                enabled: self?.sharesAnonymousUsageStatistics ?? false
            )
        }

        if hasCompletedOnboarding {
            usageAnalytics.recordActivation(enabled: sharesAnonymousUsageStatistics)
        }
    }

    func chooseTarget(_ target: LocationTarget) {
        selectedTarget = target
        addToHistory(target)
    }

    func isFavourite(_ target: LocationTarget) -> Bool {
        favouriteLocations.contains { $0.isSamePlace(as: target) }
    }

    func toggleFavourite(_ target: LocationTarget) {
        if let index = favouriteLocations.firstIndex(where: { $0.isSamePlace(as: target) }) {
            favouriteLocations.remove(at: index)
        } else {
            favouriteLocations.insert(target, at: 0)
        }
        save(favouriteLocations, forKey: Self.favouritesDefaultsKey)
    }

    func removeFavourite(_ target: LocationTarget) {
        favouriteLocations.removeAll { $0.id == target.id }
        save(favouriteLocations, forKey: Self.favouritesDefaultsKey)
    }

    func moveFavouriteLocations(from source: IndexSet, to destination: Int) {
        favouriteLocations.move(fromOffsets: source, toOffset: destination)
        save(favouriteLocations, forKey: Self.favouritesDefaultsKey)
        dismissFavouriteReorderHint()
    }

    func dismissFavouriteReorderHint() {
        guard !hasSeenFavouriteReorderHint else { return }
        hasSeenFavouriteReorderHint = true
        preferences.set(true, forKey: Self.hasSeenFavouriteReorderHintKey)
    }

    func renameFavourite(_ target: LocationTarget, to proposedName: String) {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !name.isEmpty,
            let index = favouriteLocations.firstIndex(where: { $0.id == target.id })
        else { return }

        let renamed = LocationTarget(
            id: target.id,
            name: name,
            subtitle: target.subtitle,
            latitude: target.latitude,
            longitude: target.longitude
        )
        favouriteLocations[index] = renamed
        if selectedTarget?.id == target.id {
            selectedTarget = renamed
        }
        save(favouriteLocations, forKey: Self.favouritesDefaultsKey)
    }

    func removeFromHistory(_ target: LocationTarget) {
        locationHistory.removeAll { $0.id == target.id }
        save(locationHistory, forKey: Self.historyKey)
    }

    func clearLocationHistory() {
        locationHistory = []
        preferences.removeObject(forKey: Self.historyKey)
    }

    func clearFavouriteLocations() {
        favouriteLocations = []
        preferences.removeObject(forKey: Self.favouritesDefaultsKey)
    }

    func setAppearance(_ appearance: AppAppearance) {
        self.appearance = appearance
        preferences.set(appearance.rawValue, forKey: Self.appearanceKey)
    }

    func setMapDisplayStyle(_ style: MapDisplayStyle) {
        mapDisplayStyle = style
        preferences.set(style.rawValue, forKey: Self.mapDisplayStyleKey)
    }

    func setSharesAnonymousUsageStatistics(_ enabled: Bool) {
        sharesAnonymousUsageStatistics = enabled
        preferences.set(enabled, forKey: Self.anonymousUsageStatisticsKey)

        if enabled, hasCompletedOnboarding {
            usageAnalytics.recordActivation(enabled: true)
        } else if !enabled {
            usageAnalytics.revokeLocalIdentity()
        }
    }

    func completeOnboarding() {
        preferences.set(
            sharesAnonymousUsageStatistics,
            forKey: Self.anonymousUsageStatisticsKey
        )
        preferences.set(true, forKey: Self.onboardingKey)
        shouldPresentDeviceSetup = true
        hasCompletedOnboarding = true
        usageAnalytics.record(
            .onboardingCompleted,
            enabled: sharesAnonymousUsageStatistics
        )
        usageAnalytics.recordActivation(enabled: sharesAnonymousUsageStatistics)
    }

    func deviceSetupWasPresented() {
        shouldPresentDeviceSetup = false
    }

    func resetApp() async throws {
        onDevicePairing.reset()
        deviceSession.reset()
        liveActivity.end()
        try await pairingService.removeRecord()

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            preferences.removePersistentDomain(forName: bundleIdentifier)
        } else {
            preferences.removeObject(forKey: Self.onboardingKey)
        }

        selectedTarget = nil
        favouriteLocations = []
        locationHistory = []
        appearance = .automatic
        mapDisplayStyle = .standard
        sharesAnonymousUsageStatistics = false
        interruptedSession = nil
        activeSessionRecovery = nil
        activeSessionIsWalkingRoute = false
        isRestoringInterruptedSession = false
        interruptedSessionError = nil
        restorationWasCancelled = false
        pairingStatus = .notPaired
        connectionState = .notConfigured
        shouldPresentDeviceSetup = false
        hasCompletedOnboarding = false
        usageAnalytics.revokeLocalIdentity()
    }

    func restorePairingStatus() async {
        pairingStatus = .checking

        do {
            if let summary = try await pairingService.storedRecord() {
                pairingStatus = .paired(summary)
                if deviceSession.phase == .idle {
                    connectionState = .ready
                }
            } else {
                pairingStatus = .notPaired
                connectionState = .notConfigured
            }
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
            usageAnalytics.record(.pairingFailed, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.recordFailure(.pairingRead, context: .pairing, enabled: sharesAnonymousUsageStatistics)
        }
    }

    func importPairingRecord(from url: URL) async {
        pairingStatus = .importing

        do {
            let summary = try await pairingService.importRecord(from: url)
            pairingStatus = .paired(summary)
            connectionState = .ready
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
            usageAnalytics.record(.pairingFailed, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.recordFailure(.pairingImport, context: .pairing, enabled: sharesAnonymousUsageStatistics)
        }
    }

    func startOnDevicePairing() {
        onDevicePairing.start { [weak self] record, hostAltIRK in
            guard let self else {
                throw PairingServiceError.corruptStoredRecord
            }

            let summary = try await self.pairingService.storeGeneratedRecord(
                record,
                hostAltIRK: hostAltIRK
            )
            self.pairingStatus = .paired(summary)
            self.connectionState = .ready
            self.usageAnalytics.record(
                .pairingCompleted,
                enabled: self.sharesAnonymousUsageStatistics
            )
            return summary
        }
    }

    func cancelOnDevicePairing() {
        onDevicePairing.cancel()
    }

    func startLocationSession(at target: LocationTarget) async {
        await startLocationSession(
            at: target,
            selectedTarget: target,
            historyTarget: target,
            recovery: .fixed(at: target)
        )
    }

    func startWalkingLocationSession(
        at initialTarget: LocationTarget,
        destination: LocationTarget,
        paceMetresPerSecond: Double
    ) async {
        await startLocationSession(
            at: initialTarget,
            selectedTarget: destination,
            historyTarget: destination,
            recovery: .walking(
                from: initialTarget,
                to: destination,
                paceMetresPerSecond: paceMetresPerSecond
            )
        )
    }

    private func startLocationSession(
        at deviceTarget: LocationTarget,
        selectedTarget: LocationTarget,
        historyTarget: LocationTarget,
        recovery: SessionRecoveryRecord
    ) async {
        guard case .paired = pairingStatus else {
            connectionState = .notConfigured
            return
        }

        self.selectedTarget = selectedTarget
        dismissInterruptedSessionRecovery()
        activeSessionIsWalkingRoute = recovery.kind == .walkingRoute
        activeSessionRecovery = recovery
        lastRecoverySaveDate = nil
        addToHistory(historyTarget)
        switch deviceSession.updateLocation(deviceTarget) {
        case .updated:
            if !activeSessionIsWalkingRoute {
                liveActivity.updateFixedLocation(named: deviceTarget.name)
            }
            usageAnalytics.record(
                .activeLocationUpdated,
                enabled: sharesAnonymousUsageStatistics
            )
            return
        case .failed:
            return
        case .unavailable:
            break
        }

        do {
            guard let pairingRecord = try await pairingService.pairingRecordData() else {
                activeSessionRecovery = nil
                pendingSessionAnalyticsEvent = nil
                pairingStatus = .notPaired
                connectionState = .notConfigured
                usageAnalytics.recordFailure(.locationPreparation, context: .location, enabled: sharesAnonymousUsageStatistics)
                usageAnalytics.record(
                    .locationPreparationFailed,
                    enabled: sharesAnonymousUsageStatistics
                )
                return
            }
            pendingSessionAnalyticsEvent = recovery.kind == .walkingRoute
                ? .walkingStarted
                : .fixedLocationStarted
            deviceSession.start(pairingRecord: pairingRecord, target: deviceTarget)
        } catch {
            activeSessionRecovery = nil
            pendingSessionAnalyticsEvent = nil
            connectionState = .failed(message: error.localizedDescription)
            usageAnalytics.recordFailure(.locationPreparation, context: .location, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.record(
                .locationPreparationFailed,
                enabled: sharesAnonymousUsageStatistics
            )
        }
    }

    func restoreRealLocationFromInterruptedSession() async {
        guard let recovery = interruptedSession else { return }
        guard case .paired = pairingStatus else {
            interruptedSessionError = .appText("Pair this iPhone before restoring its real location.")
            return
        }

        interruptedSessionError = nil
        isRestoringInterruptedSession = true
        restorationReachedActiveSession = false
        restorationWasCancelled = false

        do {
            guard let pairingRecord = try await pairingService.pairingRecordData() else {
                isRestoringInterruptedSession = false
                interruptedSessionError = .appText("The saved pairing record is unavailable. Pair this iPhone again.")
                usageAnalytics.recordFailure(.locationPreparation, context: .restoration, enabled: sharesAnonymousUsageStatistics)
                usageAnalytics.record(.locationRestoreFailed, enabled: sharesAnonymousUsageStatistics)
                return
            }
            deviceSession.start(
                pairingRecord: pairingRecord,
                target: recovery.lastReportedLocation
            )
        } catch {
            isRestoringInterruptedSession = false
            interruptedSessionError = error.localizedDescription
            usageAnalytics.recordFailure(.locationPreparation, context: .restoration, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.record(.locationRestoreFailed, enabled: sharesAnonymousUsageStatistics)
        }
    }

    func cancelInterruptedSessionRestoration() {
        guard isRestoringInterruptedSession else { return }
        restorationWasCancelled = true
        deviceSession.stop()
    }

    func completeInterruptedSessionRestorationAfterMobileData() {
        guard isRestoringInterruptedSession, restorationReachedActiveSession else { return }
        deviceSession.dismissMobileDataGuidance()
        deviceSession.stop()
    }

    func dismissInterruptedSessionRecovery() {
        interruptedSession = nil
        interruptedSessionError = nil
        preferences.removeObject(forKey: Self.activeSessionRecoveryKey)
    }

    func stopLocationSession() {
        isStoppingLocationSessionForRestoration = true
        deviceSession.stop()
    }

    func handleOpenURL(_ url: URL) {
        if startLocationFromLink(url) { return }
        deviceSession.handleOpenURL(url)
    }

    /// `roamcontrol://location?lat=28.472262&lon=-81.473574`, so a coordinate
    /// can arrive as a plain link — from a note, a message, a web page, or a
    /// Shortcut that would rather open a URL than call an intent.
    ///
    /// Returns whether it was one, since the same scheme is LocalDevVPN's
    /// callback and that has to keep working.
    private func startLocationFromLink(_ url: URL) -> Bool {
        guard
            url.scheme?.lowercased() == "roamcontrol",
            url.host()?.lowercased() == "location",
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return false }

        let values = Dictionary(
            items.compactMap { item in item.value.map { (item.name.lowercased(), $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        guard
            let latitude = values["lat"].flatMap(Double.init),
            let longitude = values["lon"].flatMap(Double.init),
            let coordinate = CoordinateText.parse("\(latitude),\(longitude)")
        else { return false }

        Task { await startLocationSession(at: target(at: coordinate)) }
        return true
    }

    /// A place with no name but its own numbers, which is all a pasted
    /// coordinate ever carries.
    private func target(at coordinate: CLLocationCoordinate2D) -> LocationTarget {
        LocationTarget(
            name: .appText("Entered Location"),
            subtitle: CoordinateText.describe(coordinate),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    func appBecameActive() {
        guard hasCompletedOnboarding else { return }
        usageAnalytics.recordActivation(enabled: sharesAnonymousUsageStatistics)
        performPendingLocationIntent()
    }

    /// Carries out whatever the Action button, Siri or a Shortcut asked for.
    ///
    /// An intent cannot run a session itself — pairing, the tunnel and the
    /// location worker all live here — so it records the request and brings
    /// the app forward, and this is where it lands.
    func performPendingLocationIntent() {
        guard hasCompletedOnboarding, let request = LocationIntentRequest.take() else { return }

        switch request.kind {
        case .start:
            if let coordinate = request.coordinate {
                Task { await startLocationSession(at: target(at: coordinate)) }
                return
            }
            guard
                let id = request.targetID,
                let target = favouriteLocations.first(where: { $0.id == id })
            else { return }
            Task { await startLocationSession(at: target) }
        case .stop:
            stopLocationSession()
        }
    }

    func removePairingRecord() async {
        onDevicePairing.reset()
        deviceSession.reset()
        do {
            try await pairingService.removeRecord()
            pairingStatus = .notPaired
            connectionState = .notConfigured
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    private func addToHistory(_ target: LocationTarget) {
        locationHistory.removeAll { $0.isSamePlace(as: target) }
        locationHistory.insert(target, at: 0)
        locationHistory = Array(locationHistory.prefix(30))
        save(locationHistory, forKey: Self.historyKey)
    }

    private func applyDeviceSessionPhase(_ phase: DeviceSessionPhase) {
        switch phase {
        case .idle:
            pendingSessionAnalyticsEvent = nil
            activeSessionIsWalkingRoute = false
            liveActivity.end()
            isStoppingLocationSessionForRestoration = false
            if isRestoringInterruptedSession {
                let didRestore = restorationReachedActiveSession && !restorationWasCancelled
                isRestoringInterruptedSession = false
                restorationReachedActiveSession = false
                restorationWasCancelled = false
                if didRestore {
                    dismissInterruptedSessionRecovery()
                }
            }
            clearActiveSessionRecovery()
            if case .paired = pairingStatus {
                connectionState = .ready
            } else {
                connectionState = .notConfigured
            }
        case .openingLocalDevVPN, .discovering, .connecting:
            connectionState = .connecting
        case .stopping:
            connectionState = .connecting
            liveActivity.markStopping(
                isRestoringRealLocation: isRestoringInterruptedSession
                    || isStoppingLocationSessionForRestoration
            )
        case .active(let target):
            connectionState = .active
            isStoppingLocationSessionForRestoration = false
            if let event = pendingSessionAnalyticsEvent {
                usageAnalytics.record(event, enabled: sharesAnonymousUsageStatistics)
                pendingSessionAnalyticsEvent = nil
            }
            if !activeSessionIsWalkingRoute, !isRestoringInterruptedSession {
                if liveActivity.isRunning {
                    liveActivity.updateFixedLocation(named: target.name)
                } else {
                    liveActivity.startFixedLocation(named: target.name)
                }
            }
            if isRestoringInterruptedSession {
                restorationReachedActiveSession = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(400))
                    guard
                        let self,
                        self.isRestoringInterruptedSession,
                        !self.restorationWasCancelled
                    else { return }
                    if self.deviceSession.mobileDataGuidance != .turnBackOn {
                        self.deviceSession.stop()
                    }
                }
            } else {
                persistActiveSessionRecovery(at: target)
            }
        case .failed(let message):
            pendingSessionAnalyticsEvent = nil
            activeSessionIsWalkingRoute = false
            liveActivity.end()
            connectionState = .failed(message: message)
            if isRestoringInterruptedSession || isStoppingLocationSessionForRestoration {
                let wasRestoringInterruptedSession = isRestoringInterruptedSession
                if !restorationWasCancelled {
                    usageAnalytics.record(.locationRestoreFailed, enabled: sharesAnonymousUsageStatistics)
                }
                isRestoringInterruptedSession = false
                restorationReachedActiveSession = false
                restorationWasCancelled = false
                isStoppingLocationSessionForRestoration = false
                if wasRestoringInterruptedSession {
                    interruptedSessionError = message
                }
            } else {
                usageAnalytics.record(
                    analyticsEvent(forLocationStartFailure: message),
                    enabled: sharesAnonymousUsageStatistics
                )
                if deviceSession.lastFailureStage != .locationRestore {
                    clearActiveSessionRecovery()
                }
            }
        }
    }

    private func analyticsEvent(forLocationStartFailure message: String) -> UsageAnalyticsEvent {
        let normalizedMessage = message.lowercased()
        if normalizedMessage.contains("localdevvpn") {
            return .localDevVPNUnreachable
        }
        if normalizedMessage.contains("prepare") {
            return .locationPreparationFailed
        }
        return .locationStartFailed
    }

    private func persistActiveSessionRecovery(at target: LocationTarget) {
        guard var recovery = activeSessionRecovery else { return }
        let now = Date.now

        if
            recovery.kind == .walkingRoute,
            let destination = recovery.destination,
            destination.id == target.id
        {
            recovery = .fixed(at: destination)
        } else {
            recovery.lastReportedLocation = target
            recovery.updatedAt = now
        }
        activeSessionRecovery = recovery

        let shouldSave = lastRecoverySaveDate == nil
            || now.timeIntervalSince(lastRecoverySaveDate ?? .distantPast) >= 5
            || recovery.kind == .fixedLocation
        guard shouldSave, let data = try? JSONEncoder().encode(recovery) else { return }
        preferences.set(data, forKey: Self.activeSessionRecoveryKey)
        lastRecoverySaveDate = now
    }

    private func clearActiveSessionRecovery() {
        guard activeSessionRecovery != nil else { return }
        activeSessionRecovery = nil
        lastRecoverySaveDate = nil
        preferences.removeObject(forKey: Self.activeSessionRecoveryKey)
    }

    private func save(_ locations: [LocationTarget], forKey key: String) {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        preferences.set(data, forKey: key)
    }

    private static func locations(forKey key: String, in preferences: UserDefaults) -> [LocationTarget] {
        guard
            let data = preferences.data(forKey: key),
            let locations = try? JSONDecoder().decode([LocationTarget].self, from: data)
        else {
            return []
        }

        // Records saved before identities were stored decode with a new
        // identity each launch. Write them back once so the identity settles.
        if
            storedLocationsNeedIdentities(data),
            let migrated = try? JSONEncoder().encode(locations)
        {
            preferences.set(migrated, forKey: key)
        }
        return locations
    }

    private static func storedLocationsNeedIdentities(_ data: Data) -> Bool {
        guard
            let elements = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return false
        }
        return elements.contains { $0["id"] == nil }
    }

    private static func recoveryRecord(in preferences: UserDefaults) -> SessionRecoveryRecord? {
        guard
            let data = preferences.data(forKey: Self.activeSessionRecoveryKey),
            let recovery = try? JSONDecoder().decode(SessionRecoveryRecord.self, from: data)
        else { return nil }
        return recovery
    }

    private static func initialUsageStatisticsPreference(
        in preferences: UserDefaults
    ) -> Bool {
        if preferences.object(forKey: Self.anonymousUsageStatisticsKey) != nil {
            return preferences.bool(forKey: Self.anonymousUsageStatisticsKey)
        }

        // A missing preference is never treated as consent. Existing saved
        // choices continue unchanged when the app is upgraded.
        return false
    }
}

enum PairingStatus: Equatable {
    case checking
    case importing
    case notPaired
    case paired(PairingRecordSummary)
    case failed(message: String)
}

enum ConnectionState: Equatable {
    case notConfigured
    case ready
    case connecting
    case active
    case failed(message: String)
}
