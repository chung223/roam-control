import MapKit
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mapModel = MapViewModel()
    @State private var walkingRoutePlanner = WalkingRoutePlanner()
    @State private var walkingSimulation = WalkingSimulationController()
    @State private var isShowingDeviceSetup: Bool
    @State private var isShowingSettings: Bool
    @State private var isShowingSavedPlaces = false
    @State private var isShowingLandmarks = false
    @State private var isShowingPikminSpots = false
    @State private var pikminFilter: PikminSpotFilter?
    @State private var visibleMapRegion: MKCoordinateRegion?
    @State private var shouldRefreshRealLocationWhenActive = false
    @State private var shouldClearLocationAfterRestoration = false
    @State private var isLocatingRealLocationAfterRestoration = false
    @State private var visibleMapCamera: MapCamera?
    @State private var isPreparingRecoveredWalk = false
    @State private var recoveredWalkError: String?
    @FocusState private var isSearchFocused: Bool

    init(
        showDeviceSetupInitially: Bool = false,
        showSettingsInitially: Bool = false
    ) {
        _isShowingDeviceSetup = State(initialValue: showDeviceSetupInitially)
        _isShowingSettings = State(initialValue: showSettingsInitially)
    }

    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $mapModel.cameraPosition) {
                    if let route = walkingRoutePlanner.route {
                        MapPolyline(route)
                            .stroke(SproutTheme.primary, lineWidth: 6)
                    }

                    if shouldShowRealLocation {
                        UserAnnotation()
                    }

                    if let target = mapModel.selectedLocation {
                        Marker(target.name, coordinate: target.coordinate)
                            .tint(SproutTheme.primary)
                    }

                    ForEach(pikminSpotsInView) { spot in
                        Annotation(spot.name, coordinate: spot.coordinate) {
                            Image(systemName: "leaf.fill")
                                .font(SproutTheme.font(.caption2, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(SproutTheme.primary, in: Circle())
                                .onTapGesture {
                                    guard !walkingSimulation.locksDestination else { return }
                                    mapModel.show(spot.target)
                                }
                        }
                        .annotationTitles(.hidden)
                    }

                    if let coordinate = walkingSimulation.currentCoordinate {
                        Annotation("Walking location", coordinate: coordinate) {
                            Image(systemName: "leaf.circle.fill")
                                .font(.title.weight(.semibold))
                                .foregroundStyle(.white, SproutTheme.primary)
                                .padding(4)
                                .background(SproutTheme.surface, in: Circle())
                                .shadow(
                                    color: SproutTheme.controlShadow.color,
                                    radius: SproutTheme.controlShadow.radius,
                                    y: SproutTheme.controlShadow.y
                                )
                        }
                    }
                }
                .roamControlMapStyle(appModel.mapDisplayStyle)
                .mapControls {
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    visibleMapCamera = context.camera
                }
                // Only at rest: filtering the catalogue on every frame of a
                // drag would cost more than the pins are worth.
                .onMapCameraChange(frequency: .onEnd) { context in
                    visibleMapRegion = context.region
                }
                .onTapGesture { point in
                    if isSearchFocused {
                        isSearchFocused = false
                        return
                    }

                    guard !walkingSimulation.locksDestination else { return }
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    Task { await mapModel.selectDroppedPin(at: coordinate) }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                MapSearchBar(
                    query: Binding(
                        get: { mapModel.searchQuery },
                        set: { mapModel.updateSearchQuery($0) }
                    ),
                    isFocused: $isSearchFocused,
                    isSearching: mapModel.isSearching,
                    onSubmit: {
                        Task { await mapModel.search() }
                    },
                    onClear: mapModel.clearSearch
                )
                .disabled(walkingSimulation.locksDestination)

                if let pikminFilter {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(SproutTheme.font(.caption2, weight: .bold))
                        Text(pikminFilter.label)
                            .font(SproutTheme.font(.caption, weight: .medium))
                        Text(pikminSpotsInView.count.formatted())
                            .font(SproutTheme.font(.caption).monospacedDigit())
                            .foregroundStyle(SproutTheme.textSecondary)

                        Button {
                            self.pikminFilter = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(SproutTheme.font(.caption))
                                .foregroundStyle(SproutTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear spot filter")
                    }
                    .foregroundStyle(SproutTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if mapModel.isShowingSuggestions && !walkingSimulation.locksDestination {
                    SearchSuggestionsView(
                        suggestions: mapModel.searchSuggestions,
                        onSelect: { suggestion in
                            isSearchFocused = false
                            Task { await mapModel.selectSuggestion(suggestion) }
                        }
                    )
                }

                if !isSearchingForLocation {
                    HStack {
                    Button {
                        isShowingDeviceSetup = true
                    } label: {
                        ConnectionBadge(state: appModel.connectionState)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens device pairing setup")

                    Spacer()

                    HStack(spacing: 10) {
                        Button {
                            isShowingLandmarks = true
                        } label: {
                            Image(systemName: "globe.americas.fill")
                                .font(SproutTheme.font(.subheadline, weight: .semibold))
                                .foregroundStyle(SproutTheme.primary)
                                .sproutMapControl()
                        }
                        .buttonStyle(.plain)
                        .disabled(walkingSimulation.locksDestination)
                        .accessibilityLabel("Landmarks")
                        .accessibilityHint("Browse well-known places")

                        Button {
                            isShowingPikminSpots = true
                        } label: {
                            Image(systemName: "leaf.fill")
                                .font(SproutTheme.font(.subheadline, weight: .semibold))
                                .foregroundStyle(SproutTheme.primary)
                                .sproutMapControl()
                        }
                        .buttonStyle(.plain)
                        .disabled(walkingSimulation.locksDestination)
                        .accessibilityLabel("Pikmin Spots")
                        .accessibilityHint("Browse the bundled Pikmin Bloom catalogue")

                        Button {
                            isShowingSavedPlaces = true
                        } label: {
                            Image(systemName: "heart.text.square.fill")
                                .font(SproutTheme.font(.subheadline, weight: .semibold))
                                .foregroundStyle(SproutTheme.primary)
                                .sproutMapControl()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Favourites and history")

                        Button {
                            isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(SproutTheme.font(.subheadline, weight: .semibold))
                                .foregroundStyle(SproutTheme.primary)
                                .sproutMapControl()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    }
                    }

                    if needsPairingPrompt {
                    Button {
                        isShowingDeviceSetup = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone.and.arrow.forward")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(SproutTheme.primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pair this iPhone")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Required before location control")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .sproutCard(radius: SproutTheme.Radius.control, padding: 14)
                    }
                    .buttonStyle(.plain)
                    }

                    Spacer()

                    HStack {
                    Spacer()

                    VStack(spacing: 10) {
                        if shouldShowMapCompass {
                            Button(action: resetMapHeading) {
                                CompassRoseDial()
                                    .rotationEffect(.degrees(-normalisedMapHeading))
                                    .sproutMapControl()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Return map to north")
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        }

                        if canRequestRealLocation {
                            Button {
                                showCurrentLocationNorthUp()
                            } label: {
                                Group {
                                    if mapModel.isFindingRealLocation {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "location.fill")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(SproutTheme.primary)
                                    }
                                }
                                .sproutMapControl()
                            }
                            .buttonStyle(.plain)
                            .disabled(mapModel.isFindingRealLocation)
                            .accessibilityLabel("Show my current location")
                        }
                    }
                    }

                    if isLocatingRealLocationAfterRestoration {
                    RestoringRealLocationCard()
                    } else if let route = walkingRoutePlanner.route,
                   let destination = walkingRoutePlanner.destination {
                    WalkingRoutePreviewCard(
                        route: route,
                        destination: walkingSimulation.destination ?? destination,
                        simulation: walkingSimulation,
                        isPaired: isPaired,
                        onStart: {
                            Task { await walkingSimulation.start(using: appModel) }
                        },
                        onTogglePause: walkingSimulation.togglePause,
                        onWalkBack: {
                            guard let returnTarget = walkingSimulation.prepareReturnTrip() else { return }
                            walkingRoutePlanner.retargetExistingRoute(to: returnTarget)
                            mapModel.show(returnTarget)
                        },
                        onChooseNewLocation: {
                            walkingSimulation.reset()
                            walkingRoutePlanner.clear()
                            mapModel.clearSelectedLocation()
                        },
                        onStop: {
                            shouldClearLocationAfterRestoration = true
                            walkingSimulation.stop(using: appModel.deviceSession)
                        },
                        onDone: {
                            walkingSimulation.reset()
                            walkingRoutePlanner.clear()
                            mapModel.show(destination)
                        }
                    )
                    } else {
                    LocationSelectionCard(
                        location: mapModel.selectedLocation,
                        isFavourite: mapModel.selectedLocation.map(appModel.isFavourite) ?? false,
                        isPaired: isPaired,
                        sessionPhase: appModel.deviceSession.phase,
                        localDevVPNInstallURL: appModel.localDevVPNInstallURL,
                        isPreviewingWalkingRoute: walkingRoutePlanner.isLoading,
                        walkingRouteError: walkingRoutePlanner.errorMessage,
                        onToggleFavourite: {
                            guard let target = mapModel.selectedLocation else { return }
                            appModel.toggleFavourite(target)
                        },
                        onClearSelection: {
                            walkingSimulation.reset()
                            walkingRoutePlanner.clear()
                            mapModel.clearSelectedLocation()
                        },
                        onPreviewWalkingRoute: {
                            guard let target = mapModel.selectedLocation else { return }
                            Task {
                                if let route = await walkingRoutePlanner.preview(to: target) {
                                    walkingSimulation.prepare(route: route, destination: target)
                                    mapModel.show(route)
                                }
                            }
                        },
                        onStart: {
                            guard let target = mapModel.selectedLocation else { return }
                            shouldRefreshRealLocationWhenActive = false
                            mapModel.show(target)
                            Task { await appModel.startLocationSession(at: target) }
                        },
                        onStop: {
                            shouldClearLocationAfterRestoration = true
                            appModel.stopLocationSession()
                        }
                    )
                    }
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if let message = mapModel.errorMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(SproutTheme.accent, in: Capsule())
                        .padding(.bottom, 196)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            if let guidance = appModel.deviceSession.mobileDataGuidance {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    MobileDataGuidanceView(
                        guidance: guidance,
                        onOpenLocalDevVPN: appModel.deviceSession.openLocalDevVPN,
                        onRetry: appModel.deviceSession.retryConnection,
                        onUseMobileData: appModel.deviceSession.useMobileDataGuidance,
                        onMobileDataOff: appModel.deviceSession.confirmMobileDataIsOff,
                        onCancel: appModel.stopLocationSession,
                        onDone: {
                            if appModel.isRestoringInterruptedSession {
                                appModel.completeInterruptedSessionRestorationAfterMobileData()
                            } else {
                                appModel.deviceSession.dismissMobileDataGuidance()
                            }
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                .zIndex(10)
            }

            if
                let recovery = appModel.interruptedSession,
                appModel.deviceSession.mobileDataGuidance == nil
            {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    SessionRecoveryView(
                        recovery: recovery,
                        isPaired: isPaired,
                        isResuming: isPreparingRecoveredWalk,
                        isRestoring: appModel.isRestoringInterruptedSession,
                        errorMessage: recoveredWalkError ?? appModel.interruptedSessionError,
                        onResume: {
                            resumeInterruptedSession(recovery)
                        },
                        onRestore: {
                            recoveredWalkError = nil
                            walkingSimulation.reset()
                            walkingRoutePlanner.clear()
                            Task { await appModel.restoreRealLocationFromInterruptedSession() }
                        },
                        onAlreadyRestored: {
                            dismissInterruptedSessionRecovery()
                        },
                        onCancel: {
                            if appModel.isRestoringInterruptedSession {
                                appModel.cancelInterruptedSessionRestoration()
                            }
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                .zIndex(9)
            }
        }
        .task {
            await appModel.restorePairingStatus()
            if let interruptedLocation = appModel.interruptedSession?.lastReportedLocation {
                mapModel.center(on: interruptedLocation)
            }
            mapModel.prepareCurrentLocation(
                recenter: appModel.interruptedSession == nil
            )
            if isShowingDeviceSetup {
                appModel.deviceSetupWasPresented()
            }
        }
        .onChange(of: appModel.deviceSession.phase) { oldPhase, newPhase in
            walkingSimulation.handleDeviceSessionPhase(
                newPhase,
                deviceSession: appModel.deviceSession
            )

            switch newPhase {
            case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
                shouldRefreshRealLocationWhenActive = false
                mapModel.invalidateRealLocationCache()
            case .idle:
                if oldPhase == .stopping, shouldClearLocationAfterRestoration {
                    shouldClearLocationAfterRestoration = false
                    walkingSimulation.reset()
                    walkingRoutePlanner.clear()
                    mapModel.clearSelectedLocation()
                    shouldRefreshRealLocationWhenActive = false
                    isLocatingRealLocationAfterRestoration = true
                    mapModel.refreshRealLocationAfterRestoration()
                }
            case .failed:
                shouldClearLocationAfterRestoration = false
            }

            guard oldPhase == .stopping, newPhase == .idle else { return }
            guard !isLocatingRealLocationAfterRestoration else { return }
            shouldRefreshRealLocationWhenActive = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                guard shouldRefreshRealLocationWhenActive, scenePhase == .active else { return }
                shouldRefreshRealLocationWhenActive = false
                guard case .idle = appModel.deviceSession.phase else { return }
                mapModel.showRealLocationAfterSession()
            }
        }
        .onChange(of: mapModel.selectedLocation) { _, selectedLocation in
            guard !walkingSimulation.locksDestination else { return }
            guard let destination = walkingRoutePlanner.destination else { return }
            guard let selectedLocation, destination.isSamePlace(as: selectedLocation) else {
                walkingSimulation.reset()
                walkingRoutePlanner.clear()
                return
            }
        }
        .onChange(of: mapModel.isFindingRealLocation) { _, isFindingRealLocation in
            guard isLocatingRealLocationAfterRestoration, !isFindingRealLocation else { return }
            isLocatingRealLocationAfterRestoration = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            appModel.deviceSession.appDidBecomeActive()

            guard shouldRefreshRealLocationWhenActive else { return }
            shouldRefreshRealLocationWhenActive = false
            guard case .idle = appModel.deviceSession.phase else { return }
            mapModel.showRealLocationAfterSession()
        }
        .sheet(isPresented: $isShowingDeviceSetup) {
            PairingSetupView()
                .environment(appModel)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environment(appModel)
        }
        .sheet(isPresented: $isShowingPikminSpots) {
            PikminSpotsView(
                origin: visibleMapRegion?.center,
                onSelect: { target in
                    guard !walkingSimulation.locksDestination else { return }
                    mapModel.show(target)
                },
                onShowOnMap: { pikminFilter = $0 }
            )
        }
        .sheet(isPresented: $isShowingLandmarks) {
            LandmarksView { target in
                guard !walkingSimulation.locksDestination else { return }
                mapModel.show(target)
            }
        }
        .sheet(isPresented: $isShowingSavedPlaces) {
            savedPlacesSheet
        }
        .onChange(of: watchSessionSnapshot, initial: true) { _, snapshot in
            appModel.watchBridge.send(snapshot)
        }
    }

    /// The whole of what the watch is told, rebuilt whenever anything it
    /// depends on moves. Equatable, so an unchanged session sends nothing, and
    /// the bridge decides how often a moving number is worth a message.
    private var watchSessionSnapshot: WatchSessionState {
        let walking = walkingSimulation
        let isWalking = walking.locksDestination
        let phase: WatchSessionState.Phase = switch appModel.connectionState {
        case .active: .active
        case .connecting: .connecting
        case .failed: .failed
        case .ready, .notConfigured: .idle
        }

        return WatchSessionState(
            phase: walking.phase == .stopping ? .stopping : phase,
            placeName: walking.destination?.name ?? appModel.selectedTarget?.name ?? "",
            isWalking: isWalking,
            isPaused: walking.phase == .paused,
            hasArrived: walking.phase == .arrived,
            progress: isWalking ? walking.progress : nil,
            metresRemaining: isWalking ? walking.remainingDistance : nil,
            arrivesAt: isWalking && walking.phase == .walking
                ? Date.now.addingTimeInterval(walking.remainingDuration)
                : nil,
            startedAt: nil,
            message: watchFailureMessage
        )
    }

    /// Translated here, where the catalogue is. The watch shows what it is
    /// given and holds no failure strings of its own.
    private var watchFailureMessage: String? {
        if case .failed(let message) = walkingSimulation.phase {
            return SessionMessage.localized(message)
        }
        if case .failed(let message) = appModel.connectionState {
            return SessionMessage.localized(message)
        }
        return nil
    }

    /// Lifted out of `body` because the compiler could no longer type-check
    /// the whole of it in reasonable time. Fifteen closure arguments inside an
    /// already large view is past what inference will do in one piece.
    private var savedPlacesSheet: some View {
        SavedPlacesView(
            favourites: appModel.favouriteLocations,
            history: appModel.locationHistory,
            shouldShowFavouriteReorderHint: !appModel.hasSeenFavouriteReorderHint,
            isFavourite: appModel.isFavourite,
            onSelect: { target in
                guard !walkingSimulation.locksDestination else { return }
                mapModel.show(target)
            },
            onToggleFavourite: appModel.toggleFavourite,
            onDeleteFavourite: appModel.removeFavourite,
            onMoveFavourites: appModel.moveFavouriteLocations,
            onDismissFavouriteReorderHint: appModel.dismissFavouriteReorderHint,
            onRenameFavourite: appModel.renameFavourite,
            onSetFavouriteGroup: appModel.setFavouriteGroup,
            onDeleteHistory: appModel.removeFromHistory,
            onClearFavourites: appModel.clearFavouriteLocations,
            onClearHistory: appModel.clearLocationHistory
        )
    }

    /// Nothing until a filter is chosen: 7,000 pins would describe less than
    /// no pins at all.
    private var pikminSpotsInView: [PikminSpot] {
        guard let pikminFilter, let visibleMapRegion else { return [] }
        return PikminSpotCatalogue.spots(in: visibleMapRegion, matching: pikminFilter)
    }

    private var needsPairingPrompt: Bool {
        switch appModel.pairingStatus {
        case .notPaired, .failed:
            true
        case .checking, .importing, .paired:
            false
        }
    }

    private var isSearchingForLocation: Bool {
        isSearchFocused || mapModel.isShowingSuggestions
    }

    private var isPaired: Bool {
        if case .paired = appModel.pairingStatus {
            return true
        }
        return false
    }

    private var shouldShowRealLocation: Bool {
        switch appModel.deviceSession.phase {
        case .active, .stopping:
            false
        case .idle, .openingLocalDevVPN, .discovering, .connecting, .failed:
            true
        }
    }

    private var canRequestRealLocation: Bool {
        switch appModel.deviceSession.phase {
        case .idle, .failed:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
            false
        }
    }

    private var isLocationSessionActive: Bool {
        if case .active = appModel.deviceSession.phase { return true }
        return false
    }

    private var normalisedMapHeading: Double {
        guard let heading = visibleMapCamera?.heading else { return 0 }
        let remainder = heading.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }

    private var shouldShowMapCompass: Bool {
        let heading = normalisedMapHeading
        return min(heading, 360 - heading) > 1
    }

    private func resetMapHeading() {
        guard let camera = visibleMapCamera else { return }
        let northUpCamera = MapCamera(
            centerCoordinate: camera.centerCoordinate,
            distance: camera.distance,
            heading: 0,
            pitch: camera.pitch
        )

        if reduceMotion {
            mapModel.cameraPosition = .camera(northUpCamera)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                mapModel.cameraPosition = .camera(northUpCamera)
            }
        }
    }

    private func showCurrentLocationNorthUp() {
        if reduceMotion {
            mapModel.showCurrentLocation()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                mapModel.showCurrentLocation()
            }
        }
    }

    private func resumeInterruptedSession(_ recovery: SessionRecoveryRecord) {
        recoveredWalkError = nil

        guard recovery.isWalkingRoute, let destination = recovery.destination else {
            appModel.dismissInterruptedSessionRecovery()
            mapModel.show(recovery.lastReportedLocation)
            Task { await appModel.startLocationSession(at: recovery.lastReportedLocation) }
            return
        }

        isPreparingRecoveredWalk = true
        Task { @MainActor in
            let route = await walkingRoutePlanner.preview(
                to: destination,
                from: recovery.lastReportedLocation
            )
            guard let route else {
                recoveredWalkError = walkingRoutePlanner.errorMessage
                    ?? .appText("The remaining walking route could not be prepared.")
                isPreparingRecoveredWalk = false
                return
            }

            appModel.dismissInterruptedSessionRecovery()
            walkingSimulation.prepare(route: route, destination: destination)
            if
                let rawPace = recovery.walkingPaceMetresPerSecond,
                let recoveredPace = WalkingPace(rawValue: rawPace)
            {
                walkingSimulation.pace = recoveredPace
            }
            mapModel.show(route)
            isPreparingRecoveredWalk = false
            await walkingSimulation.start(using: appModel)
        }
    }

    private func dismissInterruptedSessionRecovery() {
        recoveredWalkError = nil
        isPreparingRecoveredWalk = false
        walkingSimulation.reset()
        walkingRoutePlanner.clear()
        appModel.dismissInterruptedSessionRecovery()
        mapModel.showRealLocationAfterSession()
    }
}

private struct CompassRoseDial: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.primary.opacity(0.06))

            Circle()
                .strokeBorder(.primary.opacity(0.28), lineWidth: 0.8)

            Text("N")
                .foregroundStyle(SproutTheme.accent)
                .offset(y: -10.5)

            Text("E")
                .offset(x: 10.5)

            Text("S")
                .offset(y: 10.5)

            Text("W")
                .offset(x: -10.5)

            Circle()
                .fill(.primary.opacity(0.65))
                .frame(width: 3, height: 3)
        }
        .font(.system(size: 7.5, weight: .bold, design: .rounded))
        .foregroundStyle(.primary.opacity(0.78))
        .frame(width: 34, height: 34)
    }
}

private extension View {
    @ViewBuilder
    func roamControlMapStyle(_ style: MapDisplayStyle) -> some View {
        switch style {
        case .standard:
            mapStyle(.standard(elevation: .realistic))
        case .satellite:
            mapStyle(.imagery(elevation: .realistic))
        case .hybrid:
            mapStyle(.hybrid(elevation: .realistic))
        }
    }
}

#Preview {
    HomeView()
        .environment(AppModel())
}
