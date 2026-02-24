// c11App.swift
// c11 — Zone-based day planner with gamification
// Main entry point — assembles all VIPER modules, routing, and root navigation

import SwiftUI

@main
struct c11App: App {
    var body: some Scene {
        WindowGroup {
            MissionControl()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Mission Control (Root)

/// The root view that manages launch → onboarding → main app flow.
struct MissionControl: View {

    @StateObject private var router = MissionRouter()
    @StateObject private var vault = DataVault.shared

    @State private var phase: AppPhase = .launching

    enum AppPhase {
        case launching
        case onboarding
        case operational
    }

    var body: some View {
        let _ = MissionRouter.register(router)
        ZStack {
            switch phase {
            case .launching:
                LaunchSequenceView(onComplete: advanceFromLaunch)

            case .onboarding:
                BriefingOnboardView(onFinish: advanceToOperational)
                    .transition(.opacity)

            case .operational:
                OperationsHub()
                    .environmentObject(router)
                    .transition(.opacity)
            }

            // ── Global toast overlay ─────────────────────────────
            if phase == .operational {
                FieldToast(
                    message: router.toastMessage ?? "",
                    isVisible: router.showToast,
                    showUndo: router.showUndoButton,
                    onUndo: {
                        if vault.executeUndo() {
                            router.dismissToast()
                            router.flashToast("Undone ✓")
                            Pulse.light()
                        }
                    }
                )
                .allowsHitTesting(router.showUndoButton)
            }

            CelebrationOverlay(
                emoji: router.celebrationEmoji,
                isVisible: router.showCelebration
            )
        }
        .animation(.easeInOut(duration: 0.4), value: phase)
    }

    private func advanceFromLaunch() {
        if vault.config.hasCompletedBriefing {
            phase = .operational
        } else {
            phase = .onboarding
        }
    }

    private func advanceToOperational() {
        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .operational
        }
    }
}

// MARK: - Operations Hub (TabView + Sheet/Alert routing)

/// Main tab-based container with all VIPER module assembly.
struct OperationsHub: View {

    @EnvironmentObject var router: MissionRouter

    // ── VIPER module assembly ────────────────────────────────────
    @StateObject private var zonesPresenter: ZonesHubPresenter = {
        let interactor = ZonesHubInteractor()
        let router = MissionRouter.resolve()
        return ZonesHubPresenter(interactor: interactor, router: router)
    }()

    @StateObject private var todayPresenter: TodayMissionPresenter = {
        let interactor = TodayMissionInteractor()
        let router = MissionRouter.resolve()
        return TodayMissionPresenter(interactor: interactor, router: router)
    }()

    @StateObject private var commandPresenter: CommandCenterPresenter = {
        let interactor = CommandCenterInteractor()
        let router = MissionRouter.resolve()
        return CommandCenterPresenter(interactor: interactor, router: router)
    }()

    var body: some View {
        ZStack {
            TabView(selection: $router.activeTab) {
                // ── Tab 1: Zones ─────────────────────────────────
                ZonesHubView(presenter: zonesPresenter)
                    .tabItem {
                        Label(OperationsTab.zones.label, systemImage: OperationsTab.zones.iconGlyph)
                    }
                    .tag(OperationsTab.zones)

                // ── Tab 2: Today ─────────────────────────────────
                TodayMissionView(presenter: todayPresenter)
                    .tabItem {
                        Label(OperationsTab.today.label, systemImage: OperationsTab.today.iconGlyph)
                    }
                    .tag(OperationsTab.today)

                // ── Tab 3: HQ ────────────────────────────────────
                CommandCenterView(presenter: commandPresenter)
                    .tabItem {
                        Label(OperationsTab.command.label, systemImage: OperationsTab.command.iconGlyph)
                    }
                    .tag(OperationsTab.command)
            }
            .accentColor(Palette.ambitionGold)
            .onAppear(perform: configureTabBarAppearance)
        }

        // ── Sheet routing ────────────────────────────────────────
        .sheet(item: $router.activeBriefing) { briefing in
            sheetContent(for: briefing)
        }

        // ── Alert routing ────────────────────────────────────────
        .alert(item: $router.activeAlert) { alert in
            alertContent(for: alert)
        }
    }

    // MARK: - Tab Bar Appearance

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Palette.deepOpsBase)

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Palette.ambitionGold)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Palette.ambitionGold)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Palette.dormantGray)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Palette.dormantGray)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    // MARK: - Sheet Content Builder

    @ViewBuilder
    private func sheetContent(for briefing: Briefing) -> some View {
        switch briefing {

        case .addZone:
            AddZoneSheet(
                mode: .create,
                onCommit: { title, icon in
                    zonesPresenter.handleCreateZone(title: title, icon: icon)
                },
                onDismiss: { router.dismissBriefing() }
            )

        case .editZone(let zoneId):
            AddZoneSheet(
                mode: .edit(zoneId: zoneId),
                onCommit: { title, icon in
                    zonesPresenter.handleRenameZone(id: zoneId, newTitle: title)
                    // Also update icon
                    if var zone = DataVault.shared.zone(by: zoneId) {
                        zone.iconSymbol = icon
                        DataVault.shared.updateZone(zone)
                    }
                    router.dismissBriefing()
                },
                onDismiss: { router.dismissBriefing() }
            )

        case .addGroundPoint(let zoneId):
            let detailPresenter = makeZoneDetailPresenter(zoneId: zoneId)
            AddGroundPointSheet(
                mode: .create(zoneId: zoneId),
                onCommit: { title, tag, dur, buf, memo, icon in
                    detailPresenter.handleCreatePlace(
                        title: title, tag: tag, durationMin: dur,
                        bufferMin: buf, memo: memo, icon: icon
                    )
                },
                onDismiss: { router.dismissBriefing() }
            )

        case .editGroundPoint(let zoneId, let pointId):
            let detailPresenter = makeZoneDetailPresenter(zoneId: zoneId)
            AddGroundPointSheet(
                mode: .edit(zoneId: zoneId, pointId: pointId),
                onCommit: { title, tag, dur, buf, memo, icon in
                    guard let zone = DataVault.shared.zone(by: zoneId),
                          let existing = zone.groundPoints.first(where: { $0.id == pointId }) else { return }
                    var point = existing
                    point.title = title
                    point.tag = tag
                    point.durationMin = dur
                    point.bufferMin = buf
                    point.memo = memo
                    point.iconSymbol = icon
                    detailPresenter.handleUpdatePlace(point)
                },
                onDismiss: { router.dismissBriefing() }
            )

        case .pickZoneForToday:
            ZonePickerSheet(
                zones: todayPresenter.allZones,
                currentZoneId: todayPresenter.mission?.assignedZoneId,
                onSelect: { zoneId in
                    todayPresenter.handleReassignZone(newZoneId: zoneId)
                },
                onDismiss: { router.dismissBriefing() }
            )

        case .addStopFromCatalog(_, _):
            AddFromCatalogSheet(
                availablePlaces: todayPresenter.availablePlaces,
                onDeploy: { point in
                    todayPresenter.handleDeployFromCatalog(point: point)
                },
                onDismiss: { router.dismissBriefing() }
            )

        case .quickAddStop(_):
            QuickAddStopSheet(
                onCommit: { title, tag, dur, buf, memo in
                    todayPresenter.handleQuickDeploy(
                        title: title, tag: tag,
                        durationMin: dur, bufferMin: buf, memo: memo
                    )
                },
                onDismiss: { router.dismissBriefing() }
            )

        case .dayEditor(_):
            DayEditorSheet(
                breakdown: todayPresenter.breakdown,
                onCompressBuffers: {
                    todayPresenter.handleCompressBuffers()
                    router.dismissBriefing()
                },
                onCreateLightVariant: {
                    todayPresenter.handleCreateLightVariant()
                    router.dismissBriefing()
                },
                onClearAll: {
                    todayPresenter.handleClearAll()
                    router.dismissBriefing()
                },
                onChangeZone: {
                    router.presentBriefing(.pickZoneForToday)
                },
                onDismiss: { router.dismissBriefing() }
            )

        case .achievementUnlocked(let medalId):
            if let medal = DataVault.shared.medals.first(where: { $0.id == medalId }) {
                AchievementUnlockedSheet(
                    medal: medal,
                    onDismiss: { router.dismissBriefing() }
                )
            }

        case .rankUpCelebration(let rankIndex):
            if let rank = OperatorRank.ladder[safe: rankIndex] {
                RankUpSheet(
                    rank: rank,
                    onDismiss: { router.dismissBriefing() }
                )
            }

        case .intelReport:
            // Handled inside CommandCenterView, but as fallback:
            EmptyView()

        case .avatarPicker:
            AvatarPickerSheet(
                currentAvatar: commandPresenter.editAvatar,
                currentCallSign: commandPresenter.editCallSign,
                onSelectAvatar: { commandPresenter.handleUpdateAvatar($0) },
                onSaveCallSign: { callSign in commandPresenter.handleUpdateCallSign(callSign) },
                onDismiss: { router.dismissBriefing() }
            )

        case .dangerZone:
            // Handled inline in CommandCenter actions
            EmptyView()
        }
    }

    // MARK: - Alert Content Builder

    private func alertContent(for alert: FieldAlert) -> Alert {
        switch alert {
        case .confirmWithdrawZone(let zoneId):
            return Alert(
                title: Text("Delete Zone?"),
                message: Text("This will permanently remove the zone and all its stops."),
                primaryButton: .destructive(Text("Delete")) {
                    zonesPresenter.handleConfirmDelete(zoneId: zoneId)
                },
                secondaryButton: .cancel { router.dismissAlert() }
            )

        case .confirmClearToday(let dayId):
            return Alert(
                title: Text("Clear Today?"),
                message: Text("All stops will be removed from today's plan."),
                primaryButton: .destructive(Text("Clear")) {
                    if dayId == UUID() {
                        // From HQ reset
                        commandPresenter.handleConfirmResetToday()
                    } else {
                        todayPresenter.handleConfirmClear(dayId: dayId)
                    }
                },
                secondaryButton: .cancel { router.dismissAlert() }
            )

        case .confirmNuclearReset:
            return Alert(
                title: Text("Erase Everything?"),
                message: Text("This will permanently delete all zones, stops, plans, medals, and settings. This cannot be undone."),
                primaryButton: .destructive(Text("Erase All")) {
                    commandPresenter.handleConfirmNuclearReset()
                },
                secondaryButton: .cancel { router.dismissAlert() }
            )

        case .confirmReassignZone(let dayId, let newZoneId):
            return Alert(
                title: Text("Change Today's Zone?"),
                message: Text("Current stops will be cleared. The principle is: one day — one zone."),
                primaryButton: .default(Text("Change Zone")) {
                    todayPresenter.handleConfirmReassign(dayId: dayId, newZoneId: newZoneId)
                },
                secondaryButton: .cancel { router.dismissAlert() }
            )

        case .undoAvailable(let message):
            return Alert(
                title: Text("Undo"),
                message: Text(message),
                dismissButton: .default(Text("OK")) {
                    router.dismissAlert()
                }
            )
        }
    }

    // MARK: - Factory Helpers

    private func makeZoneDetailPresenter(zoneId: UUID) -> ZoneDetailPresenter {
        let interactor = ZoneDetailInteractor()
        return ZoneDetailPresenter(zoneId: zoneId, interactor: interactor, router: router)
    }
}

// MARK: - Router Resolution (for @StateObject initialization)

extension MissionRouter {
    /// Shared instance for VIPER assembly during @StateObject init.
    /// In production, use proper DI container.
    private static var _shared: MissionRouter?

    static func resolve() -> MissionRouter {
        if let existing = _shared { return existing }
        let new = MissionRouter()
        _shared = new
        return new
    }

    /// Call once from MissionControl to register the actual instance.
    static func register(_ router: MissionRouter) {
        _shared = router
    }
}

// MARK: - Zone Detail Integration in ZonesHubView

/// Replace the placeholder in ZonesHubView with real zone detail.
extension ZoneDetailPlaceholder {
    /// Factory to create a fully wired ZoneDetailView.
    static func makeReal(zoneId: UUID, router: MissionRouter) -> some View {
        let interactor = ZoneDetailInteractor()
        let presenter = ZoneDetailPresenter(zoneId: zoneId, interactor: interactor, router: router)
        return ZoneDetailView(presenter: presenter)
            .environmentObject(router)
    }
}

// MARK: - Equatable for AppPhase

extension MissionControl.AppPhase: Equatable {}
