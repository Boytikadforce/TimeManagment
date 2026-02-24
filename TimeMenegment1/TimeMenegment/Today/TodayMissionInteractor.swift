// TodayMissionInteractor.swift
// c11 — Zone-based day planner with gamification
// VIPER Interactor — business logic for Today tab

import Foundation

// MARK: - Protocol

protocol TodayMissionInteracting: AnyObject {
    /// Get today's field day if it exists.
    func fetchTodayMission() -> FieldDay?

    /// Get the zone assigned to today.
    func fetchTodayZone() -> OperationsZone?

    /// Get available places from today's zone catalog (not yet in queue).
    func fetchAvailablePlaces() -> [GroundPoint]

    /// Add a place from catalog to today's queue.
    func deployStopFromCatalog(point: GroundPoint) -> Bool

    /// Quick-add a new stop (creates place in zone + adds to today).
    func quickDeployStop(title: String, tag: ErrandTag, durationMin: Int, bufferMin: Int, memo: String)

    /// Remove a stop from today's queue.
    func withdrawStop(stopId: UUID)

    /// Toggle accomplished state.
    func toggleAccomplished(stopId: UUID)

    /// Reorder stops via drag-and-drop.
    func reorderStops(fromOffsets: IndexSet, toOffset: Int)

    /// Change today's assigned zone.
    func reassignZone(newZoneId: UUID)

    /// Clear all stops from today.
    func clearAllStops()

    /// Evaluate pressure level for today.
    func evaluateTodayPressure() -> PressureLevel

    /// Get pressure delta (minutes over threshold).
    func pressureDelta() -> Int

    /// Check if too many places flag should show.
    func isTooManyStops() -> Bool

    /// Get time breakdown for pressure detail.
    func computeTimeBreakdown() -> TimeBreakdown

    /// Compress buffers on longest stops (quick fix).
    func compressBuffers(count: Int)

    /// Create an alternative ops variant.
    func createLightVariant() -> AlternativeOps?

    /// Get all active zones for zone picker.
    func fetchAllZones() -> [OperationsZone]

    /// Get gamification snapshot for today.
    func fetchTodayGamification() -> TodayGamification
}

// MARK: - Supporting Types

struct TimeBreakdown {
    let totalDurationMin: Int
    let totalBufferMin: Int
    let totalLoadMin: Int
    let thresholdMin: Int
    let deltaMin: Int
    let stopsCount: Int
    let recommendedMax: Int
    let pressure: PressureLevel
}

struct TodayGamification {
    let streakDays: Int
    let rankTitle: String
    let rankBadge: String
    let pointsToday: Int
    let missionsToNextRank: Int
    let progressToNextRank: Double
}

// MARK: - Implementation

final class TodayMissionInteractor: TodayMissionInteracting {

    private let vault: DataVault

    init(vault: DataVault = .shared) {
        self.vault = vault
    }

    func fetchTodayMission() -> FieldDay? {
        vault.currentFieldDay()
    }

    func fetchTodayZone() -> OperationsZone? {
        guard let day = vault.currentFieldDay() else { return nil }
        return vault.zone(by: day.assignedZoneId)
    }

    func fetchAvailablePlaces() -> [GroundPoint] {
        guard let day = vault.currentFieldDay(),
              let zone = vault.zone(by: day.assignedZoneId) else { return [] }

        let deployedIds = Set(day.deploymentQueue.map { $0.groundPointId })
        return zone.groundPoints.filter { !deployedIds.contains($0.id) }
    }

    func deployStopFromCatalog(point: GroundPoint) -> Bool {
        guard let day = vault.currentFieldDay() else { return false }

        let alreadyDeployed = day.deploymentQueue.contains { $0.groundPointId == point.id }
        if alreadyDeployed { return false }

        let stop = DeploymentStop(
            groundPointId: point.id,
            title: point.title,
            tag: point.tag,
            durationMin: point.durationMin,
            bufferMin: point.bufferMin,
            sortIndex: day.deploymentQueue.count
        )
        vault.deployStop(stop, toDayId: day.id)
        return true
    }

    func quickDeployStop(title: String, tag: ErrandTag, durationMin: Int, bufferMin: Int, memo: String = "") {
        guard let day = vault.currentFieldDay() else { return }

        // Also add to zone catalog
        let point = GroundPoint(
            title: title,
            tag: tag,
            durationMin: durationMin,
            bufferMin: bufferMin,
            memo: memo
        )
        vault.deployGroundPoint(point, toZoneId: day.assignedZoneId)

        // Add to today
        let stop = DeploymentStop(
            groundPointId: point.id,
            title: point.title,
            tag: point.tag,
            durationMin: point.durationMin,
            bufferMin: point.bufferMin,
            sortIndex: day.deploymentQueue.count
        )
        vault.deployStop(stop, toDayId: day.id)
    }

    func withdrawStop(stopId: UUID) {
        guard let day = vault.currentFieldDay() else { return }
        vault.withdrawStop(stopId: stopId, fromDayId: day.id)
    }

    func toggleAccomplished(stopId: UUID) {
        guard let day = vault.currentFieldDay() else { return }
        vault.toggleStopAccomplished(stopId: stopId, inDayId: day.id)
    }

    func reorderStops(fromOffsets: IndexSet, toOffset: Int) {
        guard let day = vault.currentFieldDay() else { return }
        vault.reorderStops(dayId: day.id, fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func reassignZone(newZoneId: UUID) {
        if let day = vault.currentFieldDay() {
            vault.reassignTodayZone(dayId: day.id, newZoneId: newZoneId)
        } else {
            _ = vault.todayFieldDay(forZoneId: newZoneId)
        }
    }

    func clearAllStops() {
        guard let day = vault.currentFieldDay() else { return }
        vault.clearTodayPlan(dayId: day.id)
    }

    func evaluateTodayPressure() -> PressureLevel {
        guard let day = vault.currentFieldDay() else { return .steady }
        return vault.evaluatePressure(forDay: day)
    }

    func pressureDelta() -> Int {
        guard let day = vault.currentFieldDay() else { return 0 }
        return vault.pressureDelta(forDay: day)
    }

    func isTooManyStops() -> Bool {
        guard let day = vault.currentFieldDay() else { return false }
        return day.deploymentQueue.count > vault.config.recommendedStopsCount
    }

    func computeTimeBreakdown() -> TimeBreakdown {
        guard let day = vault.currentFieldDay() else {
            return TimeBreakdown(
                totalDurationMin: 0, totalBufferMin: 0, totalLoadMin: 0,
                thresholdMin: 0, deltaMin: 0, stopsCount: 0,
                recommendedMax: 0, pressure: .steady
            )
        }

        let totalDur = day.deploymentQueue.reduce(0) { $0 + $1.durationMin }
        let totalBuf = day.deploymentQueue.reduce(0) { $0 + $1.bufferMin }
        let totalLoad = totalDur + totalBuf
        let threshold = vault.config.criticalPressureThresholdMin
        let delta = max(0, totalLoad - threshold)

        return TimeBreakdown(
            totalDurationMin: totalDur,
            totalBufferMin: totalBuf,
            totalLoadMin: totalLoad,
            thresholdMin: threshold,
            deltaMin: delta,
            stopsCount: day.deploymentQueue.count,
            recommendedMax: vault.config.recommendedStopsCount,
            pressure: vault.evaluatePressure(forDay: day)
        )
    }

    func compressBuffers(count: Int) {
        guard var day = vault.currentFieldDay() else { return }

        // Sort by buffer descending, compress top N
        let sorted = day.deploymentQueue.enumerated()
            .sorted { $0.element.bufferMin > $1.element.bufferMin }

        for i in 0..<min(count, sorted.count) {
            let idx = sorted[i].offset
            let newBuffer = max(0, day.deploymentQueue[idx].bufferMin - 5)
            day.deploymentQueue[idx].bufferMin = newBuffer
        }
        vault.updateFieldDay(day)
    }

    func createLightVariant() -> AlternativeOps? {
        guard let day = vault.currentFieldDay() else { return nil }

        // Light variant: keep first 2/3 of stops, compress buffers
        let keepCount = max(1, (day.deploymentQueue.count * 2) / 3)
        var lightStops = Array(day.deploymentQueue.prefix(keepCount))
        for i in lightStops.indices {
            lightStops[i].bufferMin = max(0, lightStops[i].bufferMin - 5)
            lightStops[i].sortIndex = i
        }

        let variant = AlternativeOps(
            label: "Light Plan",
            stops: lightStops
        )

        var updatedDay = day
        updatedDay.alternativeOps.append(variant)
        vault.updateFieldDay(updatedDay)

        return variant
    }

    func fetchAllZones() -> [OperationsZone] {
        vault.activeZonesSorted()
    }

    func fetchTodayGamification() -> TodayGamification {
        let config = vault.config
        let rank = vault.currentRank
        let toNext = vault.missionsToNextRank

        let nextRank = OperatorRank.ladder[safe: config.currentRankIndex + 1]
        let progress: Double
        if let next = nextRank {
            let rangeNeeded = next.requiredMissions - rank.requiredMissions
            let rangeDone = config.totalMissionsAccomplished - rank.requiredMissions
            progress = rangeNeeded > 0 ? Double(rangeDone) / Double(rangeNeeded) : 1.0
        } else {
            progress = 1.0
        }

        // Points earned today
        let todayDay = vault.currentFieldDay()
        let todayPoints = (todayDay?.accomplishedCount ?? 0) * 10

        return TodayGamification(
            streakDays: config.dailyStreakCount,
            rankTitle: rank.title,
            rankBadge: rank.badge,
            pointsToday: todayPoints,
            missionsToNextRank: toNext,
            progressToNextRank: min(1.0, max(0, progress))
        )
    }
}
