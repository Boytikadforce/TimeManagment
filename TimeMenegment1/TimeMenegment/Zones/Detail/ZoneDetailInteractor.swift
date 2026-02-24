// ZoneDetailInteractor.swift
// c11 — Zone-based day planner with gamification
// VIPER Interactor — business logic for zone's place catalog

import Foundation

// MARK: - Protocol

protocol ZoneDetailInteracting: AnyObject {
    /// Fetch zone by ID.
    func fetchZone(id: UUID) -> OperationsZone?

    /// Get sorted places for the zone (favorites first).
    func fetchSortedPlaces(zoneId: UUID) -> [GroundPoint]

    /// Filter places by search query and/or tag.
    func filterPlaces(zoneId: UUID, query: String, tag: ErrandTag?) -> [GroundPoint]

    /// Add a new place to the zone catalog.
    func createPlace(inZoneId zoneId: UUID, title: String, tag: ErrandTag, durationMin: Int, bufferMin: Int, memo: String, icon: String)

    /// Update an existing place.
    func updatePlace(_ place: GroundPoint, inZoneId zoneId: UUID)

    /// Remove a place from zone catalog.
    func deletePlace(pointId: UUID, fromZoneId zoneId: UUID)

    /// Toggle favorite status.
    func toggleFavorite(pointId: UUID, inZoneId zoneId: UUID)

    /// Add a place from catalog to today's deployment queue.
    func deployPlaceToToday(point: GroundPoint, zoneId: UUID) -> Bool

    /// Get the number of favorites in a zone.
    func favoritesCount(zoneId: UUID) -> Int

    /// Check if zone is assigned to today.
    func isZoneActiveToday(zoneId: UUID) -> Bool

    /// Create a route blueprint (template) from given point IDs.
    func createBlueprint(zoneId: UUID, title: String, pointIds: [UUID])

    /// Fetch blueprints for a zone.
    func fetchBlueprints(zoneId: UUID) -> [RouteBlueprint]

    /// Delete a blueprint.
    func deleteBlueprint(bpId: UUID, fromZoneId zoneId: UUID)

    /// Compute zone stats for header.
    func computeZoneStats(zoneId: UUID) -> ZoneStats
}

// MARK: - Zone Stats

struct ZoneStats {
    let totalPlaces: Int
    let favoritePlaces: Int
    let totalDurationMin: Int
    let averageDurationMin: Int
    let blueprintCount: Int
    let timesDeployed: Int
    let mostCommonTag: ErrandTag
}

// MARK: - Implementation

final class ZoneDetailInteractor: ZoneDetailInteracting {

    private let vault: DataVault

    init(vault: DataVault = .shared) {
        self.vault = vault
    }

    func fetchZone(id: UUID) -> OperationsZone? {
        vault.zone(by: id)
    }

    func fetchSortedPlaces(zoneId: UUID) -> [GroundPoint] {
        vault.groundPointsSorted(forZoneId: zoneId)
    }

    func filterPlaces(zoneId: UUID, query: String, tag: ErrandTag?) -> [GroundPoint] {
        var places = vault.groundPointsSorted(forZoneId: zoneId)

        // Filter by tag
        if let selectedTag = tag {
            places = places.filter { $0.tag == selectedTag }
        }

        // Filter by search query
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty {
            places = places.filter {
                $0.title.lowercased().contains(trimmed) ||
                $0.memo.lowercased().contains(trimmed)
            }
        }

        return places
    }

    func createPlace(inZoneId zoneId: UUID, title: String, tag: ErrandTag, durationMin: Int, bufferMin: Int, memo: String, icon: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let point = GroundPoint(
            title: trimmed,
            tag: tag,
            durationMin: durationMin,
            bufferMin: bufferMin,
            memo: memo,
            iconSymbol: icon
        )
        vault.deployGroundPoint(point, toZoneId: zoneId)
    }

    func updatePlace(_ place: GroundPoint, inZoneId zoneId: UUID) {
        vault.updateGroundPoint(place, inZoneId: zoneId)
    }

    func deletePlace(pointId: UUID, fromZoneId zoneId: UUID) {
        vault.withdrawGroundPoint(id: pointId, fromZoneId: zoneId)
    }

    func toggleFavorite(pointId: UUID, inZoneId zoneId: UUID) {
        vault.toggleGroundPointFavorite(pointId: pointId, inZoneId: zoneId)
    }

    func deployPlaceToToday(point: GroundPoint, zoneId: UUID) -> Bool {
        // Ensure today's field day exists for this zone
        guard let today = vault.currentFieldDay(), today.assignedZoneId == zoneId else {
            return false
        }

        // Check if already in queue
        let alreadyAdded = today.deploymentQueue.contains { $0.groundPointId == point.id }
        if alreadyAdded { return false }

        let stop = DeploymentStop(
            groundPointId: point.id,
            title: point.title,
            tag: point.tag,
            durationMin: point.durationMin,
            bufferMin: point.bufferMin,
            sortIndex: today.deploymentQueue.count
        )
        vault.deployStop(stop, toDayId: today.id)
        return true
    }

    func favoritesCount(zoneId: UUID) -> Int {
        vault.zone(by: zoneId)?.groundPoints.filter { $0.isFavorite }.count ?? 0
    }

    func isZoneActiveToday(zoneId: UUID) -> Bool {
        vault.currentFieldDay()?.assignedZoneId == zoneId
    }

    func createBlueprint(zoneId: UUID, title: String, pointIds: [UUID]) {
        let bp = RouteBlueprint(title: title, orderedPointIds: pointIds)
        vault.addBlueprint(bp, toZoneId: zoneId)
    }

    func fetchBlueprints(zoneId: UUID) -> [RouteBlueprint] {
        vault.zone(by: zoneId)?.routeBlueprints ?? []
    }

    func deleteBlueprint(bpId: UUID, fromZoneId zoneId: UUID) {
        vault.removeBlueprint(bpId: bpId, fromZoneId: zoneId)
    }

    func computeZoneStats(zoneId: UUID) -> ZoneStats {
        guard let zone = vault.zone(by: zoneId) else {
            return ZoneStats(totalPlaces: 0, favoritePlaces: 0, totalDurationMin: 0,
                           averageDurationMin: 0, blueprintCount: 0, timesDeployed: 0,
                           mostCommonTag: .other)
        }

        let places = zone.groundPoints
        let totalDur = places.reduce(0) { $0 + $1.durationMin }
        let avgDur = places.isEmpty ? 0 : totalDur / places.count

        // Most common tag
        var tagCounts: [ErrandTag: Int] = [:]
        for p in places { tagCounts[p.tag, default: 0] += 1 }
        let topTag = tagCounts.max(by: { $0.value < $1.value })?.key ?? .other

        // Times deployed as today zone
        let deployCount = vault.fieldDays.filter { $0.assignedZoneId == zoneId }.count

        return ZoneStats(
            totalPlaces: places.count,
            favoritePlaces: places.filter { $0.isFavorite }.count,
            totalDurationMin: totalDur,
            averageDurationMin: avgDur,
            blueprintCount: zone.routeBlueprints.count,
            timesDeployed: deployCount,
            mostCommonTag: topTag
        )
    }
}
