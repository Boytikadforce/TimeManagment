// ZoneDetailPresenter.swift
// c11 — Zone-based day planner with gamification
// VIPER Presenter — observable state for zone's place catalog

import SwiftUI
import Combine

// MARK: - Presenter

final class ZoneDetailPresenter: ObservableObject {

    // ── Identity ─────────────────────────────────────────────────
    let zoneId: UUID

    // ── Published UI state ───────────────────────────────────────
    @Published var zone: OperationsZone?
    @Published var filteredPlaces: [GroundPoint] = []
    @Published var stats: ZoneStats = ZoneStats(
        totalPlaces: 0, favoritePlaces: 0, totalDurationMin: 0,
        averageDurationMin: 0, blueprintCount: 0, timesDeployed: 0,
        mostCommonTag: .other
    )
    @Published var blueprints: [RouteBlueprint] = []
    @Published var searchQuery: String = ""
    @Published var activeTagFilter: ErrandTag? = nil
    @Published var isZoneToday: Bool = false

    // ── Dependencies ─────────────────────────────────────────────
    private let interactor: ZoneDetailInteracting
    private let router: MissionRouter
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(zoneId: UUID, interactor: ZoneDetailInteracting, router: MissionRouter) {
        self.zoneId = zoneId
        self.interactor = interactor
        self.router = router
        bindChanges()
    }

    // MARK: - Bindings

    private func bindChanges() {
        // React to zone/place mutations
        DataVault.shared.$zones
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        DataVault.shared.$fieldDays
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshTodayStatus() }
            .store(in: &cancellables)

        // Search debounce
        $searchQuery
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.refreshPlaces() }
            .store(in: &cancellables)

        // Tag filter changes
        $activeTagFilter
            .sink { [weak self] _ in self?.refreshPlaces() }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func onAppear() {
        refreshAll()
    }

    private func refreshAll() {
        zone = interactor.fetchZone(id: zoneId)
        stats = interactor.computeZoneStats(zoneId: zoneId)
        blueprints = interactor.fetchBlueprints(zoneId: zoneId)
        refreshPlaces()
        refreshTodayStatus()
    }

    private func refreshPlaces() {
        filteredPlaces = interactor.filterPlaces(
            zoneId: zoneId,
            query: searchQuery,
            tag: activeTagFilter
        )
    }

    private func refreshTodayStatus() {
        isZoneToday = interactor.isZoneActiveToday(zoneId: zoneId)
    }

    // =========================================================================
    // MARK: - User Actions → Interactor
    // =========================================================================

    /// Create a new place in this zone.
    func handleCreatePlace(title: String, tag: ErrandTag, durationMin: Int, bufferMin: Int, memo: String, icon: String) {
        interactor.createPlace(
            inZoneId: zoneId,
            title: title,
            tag: tag,
            durationMin: durationMin,
            bufferMin: bufferMin,
            memo: memo,
            icon: icon
        )
        router.dismissBriefing()
        router.flashToast("Stop deployed ✓")
        Pulse.success()
    }

    /// Update an existing place.
    func handleUpdatePlace(_ place: GroundPoint) {
        interactor.updatePlace(place, inZoneId: zoneId)
        router.dismissBriefing()
        router.flashToast("Stop updated ✓")
    }

    /// Delete a place.
    func handleDeletePlace(pointId: UUID) {
        interactor.deletePlace(pointId: pointId, fromZoneId: zoneId)
        router.flashToast("Stop withdrawn", showUndo: true)
        Pulse.light()
    }

    /// Toggle favorite on a place.
    func handleToggleFavorite(pointId: UUID) {
        interactor.toggleFavorite(pointId: pointId, inZoneId: zoneId)
        Pulse.light()
    }

    /// Deploy a place to today's plan.
    func handleDeployToToday(point: GroundPoint) {
        if interactor.deployPlaceToToday(point: point, zoneId: zoneId) {
            router.flashToast("Added to today ✓")
            Pulse.success()
        } else if !isZoneToday {
            router.flashToast("Assign this zone to today first")
            Pulse.warning()
        } else {
            router.flashToast("Already in today's plan")
            Pulse.warning()
        }
    }

    /// Set tag filter.
    func handleSetTagFilter(_ tag: ErrandTag?) {
        activeTagFilter = (activeTagFilter == tag) ? nil : tag
    }

    /// Create a route blueprint from current filtered places.
    func handleCreateBlueprint(title: String) {
        let ids = filteredPlaces.map { $0.id }
        guard !ids.isEmpty else { return }
        interactor.createBlueprint(zoneId: zoneId, title: title, pointIds: ids)
        router.flashToast("Blueprint saved ✓")
        Pulse.success()
    }

    /// Delete a blueprint.
    func handleDeleteBlueprint(bpId: UUID) {
        interactor.deleteBlueprint(bpId: bpId, fromZoneId: zoneId)
        router.flashToast("Blueprint removed")
    }

    // =========================================================================
    // MARK: - Navigation → Router
    // =========================================================================

    /// Open add place sheet.
    func handleOpenAddPlace() {
        router.presentBriefing(.addGroundPoint(zoneId: zoneId))
    }

    /// Open edit place sheet.
    func handleOpenEditPlace(pointId: UUID) {
        router.presentBriefing(.editGroundPoint(zoneId: zoneId, pointId: pointId))
    }

    /// Jump to today.
    func handleJumpToToday() {
        router.jumpToToday()
    }

    /// Navigate to build day from this zone.
    func handleBuildDay() {
        if !isZoneToday {
            let vault = DataVault.shared
            if let existing = vault.currentFieldDay() {
                vault.reassignTodayZone(dayId: existing.id, newZoneId: zoneId)
            } else {
                _ = vault.todayFieldDay(forZoneId: zoneId)
            }
            router.jumpToToday()
        } else {
            router.jumpToToday()
        }
    }

    // =========================================================================
    // MARK: - View Helpers
    // =========================================================================

    /// Zone title for navigation bar.
    var zoneTitle: String {
        zone?.title ?? "Zone"
    }

    /// Zone icon.
    var zoneIcon: String {
        zone?.iconSymbol ?? "mappin.circle.fill"
    }

    /// Formatted total duration.
    var totalDurationLabel: String {
        let hrs = stats.totalDurationMin / 60
        let mins = stats.totalDurationMin % 60
        if hrs > 0 {
            return "\(hrs)h \(mins)m total"
        }
        return "\(mins)m total"
    }

    /// Whether places list is empty (considering filters).
    var isEmptyState: Bool {
        filteredPlaces.isEmpty && searchQuery.isEmpty && activeTagFilter == nil
    }

    /// Whether filtered results are empty but zone has places.
    var isFilteredEmpty: Bool {
        filteredPlaces.isEmpty && (!searchQuery.isEmpty || activeTagFilter != nil)
    }

    /// Favorites section places.
    var favoritePlaces: [GroundPoint] {
        filteredPlaces.filter { $0.isFavorite }
    }

    /// Non-favorite places.
    var regularPlaces: [GroundPoint] {
        filteredPlaces.filter { !$0.isFavorite }
    }

    /// Check if a place is already in today's queue.
    func isDeployedToday(pointId: UUID) -> Bool {
        guard let today = DataVault.shared.currentFieldDay() else { return false }
        return today.deploymentQueue.contains { $0.groundPointId == pointId }
    }
}
