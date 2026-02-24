// ZonesHubPresenter.swift
// c11 — Zone-based day planner with gamification
// VIPER Presenter — observable bridge between Interactor and View

import SwiftUI
import Combine

// MARK: - Presenter

final class ZonesHubPresenter: ObservableObject {

    // ── Published UI state ───────────────────────────────────────
    @Published var activeZones: [OperationsZone] = []
    @Published var overview: ZonesOverview = ZonesOverview(
        totalZones: 0, totalPlaces: 0,
        todayZoneTitle: nil, todayProgress: 0,
        todayStopsDone: 0, todayStopsTotal: 0,
        streakDays: 0, operatorRankTitle: "Recruit", operatorBadge: "🔰"
    )
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false

    // ── Dependencies ─────────────────────────────────────────────
    private let interactor: ZonesHubInteracting
    private let router: MissionRouter
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(interactor: ZonesHubInteracting, router: MissionRouter) {
        self.interactor = interactor
        self.router = router
        bindVaultChanges()
    }

    // MARK: - Vault Binding

    /// React to DataVault changes automatically.
    private func bindVaultChanges() {
        // Observe zone changes
        DataVault.shared.$zones
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)

        // Observe day changes (today card updates)
        DataVault.shared.$fieldDays
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshOverview()
            }
            .store(in: &cancellables)

        // Observe config changes (rank / streak)
        DataVault.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshOverview()
            }
            .store(in: &cancellables)

        // Search debounce
        $searchQuery
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    /// Full refresh — zones list + overview.
    func refreshData() {
        let allZones = interactor.fetchActiveZones()

        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            activeZones = allZones
        } else {
            let query = searchQuery.lowercased()
            activeZones = allZones.filter {
                $0.title.lowercased().contains(query)
            }
        }

        refreshOverview()
    }

    /// Refresh only the overview stats.
    private func refreshOverview() {
        overview = interactor.computeZonesOverview()
    }

    /// Initial load on appear.
    func onAppear() {
        refreshData()
    }

    // =========================================================================
    // MARK: - User Actions → Interactor
    // =========================================================================

    /// Create a new zone.
    func handleCreateZone(title: String, icon: String) {
        interactor.createZone(title: title, icon: icon)
        router.dismissBriefing()
        router.flashToast("Zone deployed ✓")
        Pulse.success()
    }

    /// Rename a zone.
    func handleRenameZone(id: UUID, newTitle: String) {
        interactor.renameZone(id: id, newTitle: newTitle)
        router.flashToast("Zone renamed ✓")
    }

    /// Pin / unpin a zone.
    func handleTogglePin(zoneId: UUID) {
        interactor.togglePin(zoneId: zoneId)
        let isPinned = interactor.zone(byId: zoneId)?.isPinned ?? false
        router.flashToast(isPinned ? "Pinned ✓" : "Unpinned")
        Pulse.light()
    }

    /// Archive a zone.
    func handleToggleArchive(zoneId: UUID) {
        interactor.toggleArchive(zoneId: zoneId)
        router.flashToast("Zone archived")
        Pulse.light()
    }

    /// Request zone deletion — raises confirmation alert.
    func handleRequestDelete(zoneId: UUID) {
        router.raiseAlert(.confirmWithdrawZone(zoneId: zoneId))
    }

    /// Confirm zone deletion after alert.
    func handleConfirmDelete(zoneId: UUID) {
        interactor.deleteZone(id: zoneId)
        router.dismissAlert()
        router.flashToast("Zone withdrawn", showUndo: true)
        Pulse.warning()
    }

    /// Assign a zone to today. Stops are preserved when changing zone.
    func handleAssignToday(zoneId: UUID) {
        interactor.assignZoneToToday(zoneId: zoneId)
        router.flashToast("Zone assigned to today ✓")
        Pulse.success()
    }

    /// Called from alert confirmation (kept for compatibility).
    func handleConfirmReassign(dayId: UUID, newZoneId: UUID) {
        interactor.assignZoneToToday(zoneId: newZoneId)
        router.dismissAlert()
        router.flashToast("Zone assigned to today ✓")
        Pulse.success()
    }

    // =========================================================================
    // MARK: - Navigation → Router
    // =========================================================================

    /// Navigate to zone detail.
    func handleOpenZone(zoneId: UUID) {
        router.advance(to: .zoneDetail(zoneId: zoneId))
    }

    /// Open "Add Zone" sheet.
    func handleOpenAddZone() {
        router.presentBriefing(.addZone)
    }

    /// Open "Edit Zone" sheet.
    func handleOpenEditZone(zoneId: UUID) {
        router.presentBriefing(.editZone(zoneId: zoneId))
    }

    /// Jump to Today tab.
    func handleJumpToToday() {
        router.jumpToToday()
    }

    /// Reorder zones via drag-and-drop.
    func handleReorderZones(fromOffsets: IndexSet, toOffset: Int) {
        interactor.reorderZones(fromOffsets: fromOffsets, toOffset: toOffset)
        router.flashToast("Zones reordered ✓")
        Pulse.light()
    }

    // =========================================================================
    // MARK: - View Model Helpers
    // =========================================================================

    /// Number of places for display on zone card.
    func placesCount(for zone: OperationsZone) -> Int {
        zone.groundPoints.count
    }

    /// Whether this zone is the current today zone.
    func isTodayZone(_ zone: OperationsZone) -> Bool {
        interactor.isAssignedToday(zoneId: zone.id)
    }

    /// Last used date formatted for display.
    func lastDeployedLabel(for zone: OperationsZone) -> String? {
        guard let date = zone.lastDeployedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Today card subtitle.
    var todaySubtitle: String {
        if let title = overview.todayZoneTitle {
            return "Today: \(title) • \(overview.todayStopsDone)/\(overview.todayStopsTotal) done"
        }
        return "No zone assigned for today"
    }

    /// Whether we have a today zone.
    var hasTodayZone: Bool {
        overview.todayZoneTitle != nil
    }

    /// Gamification label for zone list header.
    var rankLabel: String {
        "\(overview.operatorBadge) \(overview.operatorRankTitle)"
    }

    /// Streak label.
    var streakLabel: String {
        overview.streakDays > 0 ? "🔥 \(overview.streakDays)-day streak" : ""
    }
}
