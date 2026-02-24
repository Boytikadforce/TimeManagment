// ZonesHubInteractor.swift
// c11 — Zone-based day planner with gamification
// VIPER Interactor — business logic for Zones tab

import Foundation
import Combine
import SwiftUI

// MARK: - Protocol

protocol ZonesHubInteracting: AnyObject {
    /// Load all active zones sorted (pinned first).
    func fetchActiveZones() -> [OperationsZone]

    /// Get today's active field day if it exists.
    func fetchCurrentFieldDay() -> FieldDay?

    /// Create a new zone with given name and icon.
    func createZone(title: String, icon: String)

    /// Rename a zone.
    func renameZone(id: UUID, newTitle: String)

    /// Toggle zone pin status.
    func togglePin(zoneId: UUID)

    /// Toggle zone archive status.
    func toggleArchive(zoneId: UUID)

    /// Delete zone permanently.
    func deleteZone(id: UUID)

    /// Set a zone as today's active zone (creates FieldDay if needed).
    func assignZoneToToday(zoneId: UUID)

    /// Get the number of places inside a zone.
    func placesCount(forZoneId zoneId: UUID) -> Int

    /// Check if a zone is currently assigned to today.
    func isAssignedToday(zoneId: UUID) -> Bool

    /// Get zone by ID.
    func zone(byId id: UUID) -> OperationsZone?

    /// Compute quick stats for zones list.
    func computeZonesOverview() -> ZonesOverview

    /// Reorder zones in the list.
    func reorderZones(fromOffsets: IndexSet, toOffset: Int)
}

// MARK: - Overview Data

/// Quick stats displayed at the top of Zones Hub.
struct ZonesOverview {
    let totalZones: Int
    let totalPlaces: Int
    let todayZoneTitle: String?
    let todayProgress: Double       // 0...1
    let todayStopsDone: Int
    let todayStopsTotal: Int
    let streakDays: Int
    let operatorRankTitle: String
    let operatorBadge: String
}

// MARK: - Implementation

final class ZonesHubInteractor: ZonesHubInteracting {

    private let vault: DataVault

    init(vault: DataVault = .shared) {
        self.vault = vault
    }

    func fetchActiveZones() -> [OperationsZone] {
        vault.activeZonesSorted()
    }

    func fetchCurrentFieldDay() -> FieldDay? {
        vault.currentFieldDay()
    }

    func createZone(title: String, icon: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let zone = OperationsZone(title: trimmed, iconSymbol: icon)
        vault.deployZone(zone)
    }

    func renameZone(id: UUID, newTitle: String) {
        guard var zone = vault.zone(by: id) else { return }
        zone.title = newTitle.trimmingCharacters(in: .whitespaces)
        vault.updateZone(zone)
    }

    func togglePin(zoneId: UUID) {
        vault.toggleZonePin(id: zoneId)
    }

    func toggleArchive(zoneId: UUID) {
        vault.toggleZoneArchive(id: zoneId)
    }

    func deleteZone(id: UUID) {
        vault.withdrawZone(id: id)
    }

    func assignZoneToToday(zoneId: UUID) {
        // Check if there's already a today plan
        if let existing = vault.currentFieldDay() {
            // Reassign
            vault.reassignTodayZone(dayId: existing.id, newZoneId: zoneId)
        } else {
            // Create new today
            _ = vault.todayFieldDay(forZoneId: zoneId)
        }
        // Mark zone as recently used
        if var zone = vault.zone(by: zoneId) {
            zone.lastDeployedAt = Date()
            vault.updateZone(zone)
        }
    }

    func placesCount(forZoneId zoneId: UUID) -> Int {
        vault.zone(by: zoneId)?.groundPoints.count ?? 0
    }

    func isAssignedToday(zoneId: UUID) -> Bool {
        vault.currentFieldDay()?.assignedZoneId == zoneId
    }

    func zone(byId id: UUID) -> OperationsZone? {
        vault.zone(by: id)
    }

    func reorderZones(fromOffsets: IndexSet, toOffset: Int) {
        vault.reorderZones(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func computeZonesOverview() -> ZonesOverview {
        let activeZones = vault.activeZonesSorted()
        let totalPlaces = activeZones.reduce(0) { $0 + $1.groundPoints.count }
        let today = vault.currentFieldDay()

        let todayTitle = today.flatMap { vault.zone(by: $0.assignedZoneId)?.title }
        let progress = today?.progressFraction ?? 0
        let done = today?.accomplishedCount ?? 0
        let total = today?.deploymentQueue.count ?? 0

        let rank = vault.currentRank

        return ZonesOverview(
            totalZones: activeZones.count,
            totalPlaces: totalPlaces,
            todayZoneTitle: todayTitle,
            todayProgress: progress,
            todayStopsDone: done,
            todayStopsTotal: total,
            streakDays: vault.config.dailyStreakCount,
            operatorRankTitle: rank.title,
            operatorBadge: rank.badge
        )
    }
}
