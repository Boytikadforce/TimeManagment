// TodayMissionPresenter.swift
// c11 — Zone-based day planner with gamification
// VIPER Presenter — observable state for Today tab

import SwiftUI
import Combine

// MARK: - Presenter

final class TodayMissionPresenter: ObservableObject {

    // ── Published UI state ───────────────────────────────────────
    @Published var mission: FieldDay?
    @Published var zone: OperationsZone?
    @Published var stops: [DeploymentStop] = []
    @Published var pressure: PressureLevel = .steady
    @Published var breakdown: TimeBreakdown = TimeBreakdown(
        totalDurationMin: 0, totalBufferMin: 0, totalLoadMin: 0,
        thresholdMin: 0, deltaMin: 0, stopsCount: 0,
        recommendedMax: 0, pressure: .steady
    )
    @Published var gamification: TodayGamification = TodayGamification(
        streakDays: 0, rankTitle: "Recruit", rankBadge: "🔰",
        pointsToday: 0, missionsToNextRank: 0, progressToNextRank: 0
    )
    @Published var tooManyStops: Bool = false
    @Published var availablePlaces: [GroundPoint] = []

    // Track previous accomplished count for celebration detection
    private var previousAccomplishedCount: Int = -1
    private var previousRankIndex: Int = -1
    private var hasEstablishedBaseline: Bool = false

    // ── Dependencies ─────────────────────────────────────────────
    private let interactor: TodayMissionInteracting
    private let router: MissionRouter
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(interactor: TodayMissionInteracting, router: MissionRouter) {
        self.interactor = interactor
        self.router = router
        bindChanges()
    }

    // MARK: - Bindings

    private func bindChanges() {
        DataVault.shared.$fieldDays
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        DataVault.shared.$zones
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshZone() }
            .store(in: &cancellables)

        DataVault.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshGamification() }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func onAppear() {
        previousAccomplishedCount = mission?.accomplishedCount ?? 0
        previousRankIndex = DataVault.shared.config.currentRankIndex
        refreshAll()
    }

    private func refreshAll() {
        mission = interactor.fetchTodayMission()
        stops = mission?.deploymentQueue ?? []
        pressure = interactor.evaluateTodayPressure()
        breakdown = interactor.computeTimeBreakdown()
        tooManyStops = interactor.isTooManyStops()
        refreshZone()
        refreshGamification()
        refreshAvailablePlaces()
        detectCelebrations()
    }

    private func refreshZone() {
        zone = interactor.fetchTodayZone()
    }

    private func refreshGamification() {
        gamification = interactor.fetchTodayGamification()
    }

    private func refreshAvailablePlaces() {
        availablePlaces = interactor.fetchAvailablePlaces()
    }

    // =========================================================================
    // MARK: - Celebration Detection
    // =========================================================================

    private func detectCelebrations() {
        guard let day = mission else {
            hasEstablishedBaseline = true
            return
        }
        let currentDone = day.accomplishedCount
        let currentRank = DataVault.shared.config.currentRankIndex

        // Skip celebration on first load — establish baseline without triggering
        if !hasEstablishedBaseline {
            previousAccomplishedCount = currentDone
            previousRankIndex = currentRank
            hasEstablishedBaseline = true
            return
        }

        // Stop accomplished — celebrate only when count increased
        if currentDone > previousAccomplishedCount && previousAccomplishedCount >= 0 {
            if day.status == .accomplished && !day.deploymentQueue.isEmpty {
                router.celebrate(emoji: "🏆")
            }
        }
        previousAccomplishedCount = currentDone

        // Rank up
        if currentRank > previousRankIndex {
            router.announceRankUp(rankIndex: currentRank)
        }
        previousRankIndex = currentRank
    }

    // =========================================================================
    // MARK: - User Actions → Interactor
    // =========================================================================

    /// Toggle a stop as accomplished.
    func handleToggleAccomplished(stopId: UUID) {
        interactor.toggleAccomplished(stopId: stopId)
        Pulse.medium()
    }

    /// Reorder stops via drag-and-drop.
    func handleReorder(fromOffsets: IndexSet, toOffset: Int) {
        interactor.reorderStops(fromOffsets: fromOffsets, toOffset: toOffset)
        router.flashToast("Reordered", showUndo: true)
        Pulse.light()
    }

    /// Remove a stop.
    func handleWithdrawStop(stopId: UUID) {
        interactor.withdrawStop(stopId: stopId)
        router.flashToast("Stop withdrawn", showUndo: true)
        Pulse.light()
    }

    /// Deploy a place from catalog to today.
    func handleDeployFromCatalog(point: GroundPoint) {
        if interactor.deployStopFromCatalog(point: point) {
            router.flashToast("Deployed ✓")
            Pulse.success()
        } else {
            router.flashToast("Already in queue")
            Pulse.warning()
        }
    }

    /// Quick-add a new stop.
    func handleQuickDeploy(title: String, tag: ErrandTag, durationMin: Int, bufferMin: Int, memo: String = "") {
        interactor.quickDeployStop(title: title, tag: tag, durationMin: durationMin, bufferMin: bufferMin, memo: memo)
        router.dismissBriefing()
        router.flashToast("Quick stop deployed ✓")
        Pulse.success()
    }

    /// Reassign today to a different zone. Stops are preserved.
    func handleReassignZone(newZoneId: UUID) {
        interactor.reassignZone(newZoneId: newZoneId)
        router.dismissBriefing()
        router.flashToast("Zone reassigned ✓")
        Pulse.success()
    }

    /// Confirm reassign after alert.
    func handleConfirmReassign(dayId: UUID, newZoneId: UUID) {
        interactor.reassignZone(newZoneId: newZoneId)
        router.dismissAlert()
        router.dismissBriefing()
        router.flashToast("Zone reassigned ✓")
        Pulse.success()
    }

    /// Clear all stops.
    func handleClearAll() {
        router.raiseAlert(.confirmClearToday(dayId: mission?.id ?? UUID()))
    }

    /// Confirm clear after alert.
    func handleConfirmClear(dayId: UUID) {
        interactor.clearAllStops()
        router.dismissAlert()
        router.flashToast("Day cleared", showUndo: true)
        Pulse.warning()
    }

    /// Compress buffers (quick fix for overload).
    func handleCompressBuffers() {
        interactor.compressBuffers(count: 2)
        router.flashToast("Buffers compressed ✓")
        Pulse.success()
    }

    /// Create a light variant.
    func handleCreateLightVariant() {
        if let variant = interactor.createLightVariant() {
            router.flashToast("Light plan created: \(variant.stops.count) stops")
            Pulse.success()
        }
    }

    // =========================================================================
    // MARK: - Navigation → Router
    // =========================================================================

    func handleOpenAddFromCatalog() {
        guard let day = mission else { return }
        router.presentBriefing(.addStopFromCatalog(dayId: day.id, zoneId: day.assignedZoneId))
    }

    func handleOpenQuickAdd() {
        guard let day = mission else { return }
        router.presentBriefing(.quickAddStop(dayId: day.id))
    }

    func handleOpenPressureBreakdown() {
        guard let day = mission else { return }
        router.presentBriefing(.dayEditor(dayId: day.id))
    }

    func handleOpenZonePicker() {
        router.presentBriefing(.pickZoneForToday)
    }

    func handleOpenZoneDetail() {
        guard let z = zone else { return }
        router.switchTab(.zones, then: .zoneDetail(zoneId: z.id))
    }

    // =========================================================================
    // MARK: - View Helpers
    // =========================================================================

    /// Whether today has a mission.
    var hasMission: Bool {
        mission != nil
    }

    /// Whether today has an assigned zone.
    var hasZone: Bool {
        zone != nil
    }

    /// Today's date formatted.
    var todayDateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    /// Zone title.
    var zoneTitle: String {
        zone?.title ?? "No Zone"
    }

    /// Zone icon.
    var zoneIcon: String {
        zone?.iconSymbol ?? "mappin.circle.fill"
    }

    /// Progress fraction 0...1.
    var progressFraction: Double {
        mission?.progressFraction ?? 0
    }

    /// Progress label "3/7".
    var progressLabel: String {
        guard let m = mission else { return "0/0" }
        return "\(m.accomplishedCount)/\(m.deploymentQueue.count)"
    }

    /// Remaining count.
    var remainingCount: Int {
        mission?.remainingCount ?? 0
    }

    /// Total planned minutes label.
    var plannedMinLabel: String {
        let total = mission?.totalPlannedMin ?? 0
        let hrs = total / 60
        let mins = total % 60
        if hrs > 0 { return "\(hrs)h \(mins)m planned" }
        return "\(mins)m planned"
    }

    /// Pressure label with delta.
    var pressureLabel: String {
        switch pressure {
        case .steady:   return "Steady pace"
        case .dense:    return "Dense schedule"
        case .critical:
            let delta = interactor.pressureDelta()
            return "Overload +\(delta)m"
        }
    }

    /// Pressure color.
    var pressureColor: Color {
        switch pressure {
        case .steady:   return Palette.steadyPace
        case .dense:    return Palette.urgencyAmber
        case .critical: return Palette.overloadCrimson
        }
    }

    /// Pressure icon.
    var pressureIcon: String {
        pressure.iconGlyph
    }

    /// Mission status label.
    var statusLabel: String {
        guard let m = mission else { return "No mission" }
        switch m.status {
        case .vacant:       return "Empty — add stops to begin"
        case .briefed:      return "Ready — start your mission"
        case .inField:      return "In progress — keep going!"
        case .accomplished: return "Mission accomplished! 🏆"
        case .abandoned:    return "Abandoned"
        }
    }

    /// Is mission complete.
    var isMissionComplete: Bool {
        mission?.status == .accomplished
    }

    /// Rank + XP bar label.
    var rankProgressLabel: String {
        if gamification.missionsToNextRank > 0 {
            return "\(gamification.missionsToNextRank) missions to next rank"
        }
        return "Max rank achieved!"
    }

    /// All available zones for picker.
    var allZones: [OperationsZone] {
        interactor.fetchAllZones()
    }
}
