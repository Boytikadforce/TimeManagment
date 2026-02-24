// DataVault.swift
// c11 — Zone-based day planner with gamification
// JSON-based local persistence — no Core Data

import Foundation
import Combine
import SwiftUI

// MARK: - Schema Versioning

private let kSchemaVersion = 1

/// Wrapper for versioned JSON files — enables migration when schema changes.
private struct VersionedFile<T: Codable>: Codable {
    var schemaVersion: Int
    var data: T
}

// MARK: - DataVault — The Operational Archive

/// Thread-safe, file-based data store using Codable + JSON.
/// All mutations publish changes via Combine so VIPER presenters react instantly.
final class DataVault: ObservableObject {

    static let shared = DataVault()

    // ── Published state ──────────────────────────────────────────
    @Published private(set) var zones: [OperationsZone] = []
    @Published private(set) var fieldDays: [FieldDay] = []
    @Published private(set) var config: CommandCenterConfig = CommandCenterConfig()
    @Published private(set) var medals: [FieldMedal] = FieldMedal.catalog
    @Published private(set) var lastUndo: UndoSnapshot? = nil

    // ── File URLs ────────────────────────────────────────────────
    private let archiveQueue = DispatchQueue(label: "com.c11.vault", qos: .userInitiated)
    private let zonesFile: URL
    private let daysFile: URL
    private let configFile: URL
    private let medalsFile: URL

    // MARK: - Init

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let vault = docs.appendingPathComponent("c11_vault", isDirectory: true)

        // Create vault directory if needed
        try? FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)

        zonesFile  = vault.appendingPathComponent("operations_zones.json")
        daysFile   = vault.appendingPathComponent("field_days.json")
        configFile = vault.appendingPathComponent("command_config.json")
        medalsFile = vault.appendingPathComponent("field_medals.json")

        loadAll()
    }

    // MARK: - Load All

    private func loadAll() {
        zones    = loadVersioned(zonesFile, default: []) ?? []
        fieldDays = loadVersioned(daysFile, default: []) ?? []
        config   = loadVersioned(configFile, default: CommandCenterConfig()) ?? CommandCenterConfig()
        let loadedMedals = loadVersioned(medalsFile, default: FieldMedal.catalog) ?? FieldMedal.catalog
        medals = mergeMedalsWithCatalog(loaded: loadedMedals)
    }

    /// Merge saved medals with catalog — add any new catalog entries as locked.
    private func mergeMedalsWithCatalog(loaded: [FieldMedal]) -> [FieldMedal] {
        var result: [FieldMedal] = []
        let loadedById = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        for catalogMedal in FieldMedal.catalog {
            if let saved = loadedById[catalogMedal.id] {
                result.append(saved)
            } else {
                result.append(catalogMedal)
            }
        }
        return result
    }

    // MARK: - Generic Disk I/O with Migration

    /// Load versioned file. If schema mismatch or decode fails, attempts legacy decode or returns default.
    private func loadVersioned<T: Codable>(_ url: URL, default fallback: T) -> T? {
        guard let rawData = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try versioned format first
        if let versioned = try? decoder.decode(VersionedFile<T>.self, from: rawData) {
            if versioned.schemaVersion == kSchemaVersion {
                return versioned.data
            }
            // Version mismatch — preserve backup and attempt migration
            let backupUrl = url.deletingPathExtension().appendingPathExtension("backup.json")
            try? rawData.write(to: backupUrl, options: .atomicWrite)
            // For now, try using data as-is if structure is compatible
            return versioned.data
        }

        // Legacy format (no schemaVersion) — try direct decode and migrate on next persist
        if let legacy = try? decoder.decode(T.self, from: rawData) {
            return legacy
        }

        return nil
    }

    private func saveToDisk<T: Codable>(_ object: T, url: URL) {
        let versioned = VersionedFile(schemaVersion: kSchemaVersion, data: object)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(versioned) else { return }
        archiveQueue.async {
            try? data.write(to: url, options: .atomicWrite)
        }
    }

    private func persistZones() {
        saveToDisk(zones, url: zonesFile)
    }

    private func persistDays() {
        saveToDisk(fieldDays, url: daysFile)
    }

    private func persistConfig() {
        saveToDisk(config, url: configFile)
    }

    private func persistMedals() {
        saveToDisk(medals, url: medalsFile)
    }

    // =========================================================================
    // MARK: - ZONES (Districts)
    // =========================================================================

    /// Add a new operations zone.
    func deployZone(_ zone: OperationsZone) {
        var newZone = zone
        newZone.sortIndex = zones.filter { !$0.isArchived }.count
        zones.append(newZone)
        persistZones()
        checkMedal_zoneCount()
    }

    /// Update an existing zone by ID.
    func updateZone(_ zone: OperationsZone) {
        guard let idx = zones.firstIndex(where: { $0.id == zone.id }) else { return }
        zones[idx] = zone
        zones[idx].updatedAt = Date()
        persistZones()
    }

    /// Remove a zone entirely.
    func withdrawZone(id: UUID) {
        if let zone = zones.first(where: { $0.id == id }) {
            var payload = UndoPayload()
            payload.zone = zone
            snapshotForUndo(action: .withdraw, zoneId: id, payload: payload)
        }
        zones.removeAll { $0.id == id }
        normalizeZoneSortIndices()
        persistZones()
        scheduleUndoExpiry()
    }

    /// Toggle pin status.
    func toggleZonePin(id: UUID) {
        guard let idx = zones.firstIndex(where: { $0.id == id }) else { return }
        zones[idx].isPinned.toggle()
        zones[idx].updatedAt = Date()
        persistZones()
    }

    /// Toggle archive status.
    func toggleZoneArchive(id: UUID) {
        guard let idx = zones.firstIndex(where: { $0.id == id }) else { return }
        zones[idx].isArchived.toggle()
        zones[idx].updatedAt = Date()
        normalizeZoneSortIndices()
        persistZones()
    }

    /// Get active (non-archived) zones sorted by pinned-first then sortIndex.
    func activeZonesSorted() -> [OperationsZone] {
        zones
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.sortIndex < rhs.sortIndex
            }
    }

    /// Find zone by ID.
    func zone(by id: UUID) -> OperationsZone? {
        zones.first { $0.id == id }
    }

    /// Reorder active zones (pinned first, then by new order).
    func reorderZones(fromOffsets: IndexSet, toOffset: Int) {
        let active = activeZonesSorted()
        var reordered = active
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (idx, zone) in reordered.enumerated() {
            if let i = zones.firstIndex(where: { $0.id == zone.id }) {
                zones[i].sortIndex = idx
                zones[i].updatedAt = Date()
            }
        }
        persistZones()
    }

    private func normalizeZoneSortIndices() {
        let active = zones.enumerated()
            .filter { !$0.element.isArchived }
            .sorted { $0.element.sortIndex < $1.element.sortIndex }
        for (newIdx, pair) in active.enumerated() {
            zones[pair.offset].sortIndex = newIdx
        }
    }

    // =========================================================================
    // MARK: - GROUND POINTS (Places inside zones)
    // =========================================================================

    /// Add a place to a zone's catalog.
    func deployGroundPoint(_ point: GroundPoint, toZoneId zoneId: UUID) {
        guard let idx = zones.firstIndex(where: { $0.id == zoneId }) else { return }
        zones[idx].groundPoints.append(point)
        zones[idx].updatedAt = Date()
        persistZones()
        checkMedal_places()
        checkMedal_zoneArchitect()
    }

    /// Update a place inside a zone.
    func updateGroundPoint(_ point: GroundPoint, inZoneId zoneId: UUID) {
        guard let zIdx = zones.firstIndex(where: { $0.id == zoneId }) else { return }
        guard let pIdx = zones[zIdx].groundPoints.firstIndex(where: { $0.id == point.id }) else { return }
        zones[zIdx].groundPoints[pIdx] = point
        zones[zIdx].groundPoints[pIdx].updatedAt = Date()
        zones[zIdx].updatedAt = Date()
        persistZones()
    }

    /// Remove a place from a zone.
    func withdrawGroundPoint(id: UUID, fromZoneId zoneId: UUID) {
        guard let zIdx = zones.firstIndex(where: { $0.id == zoneId }),
              let point = zones[zIdx].groundPoints.first(where: { $0.id == id }) else { return }
        var payload = UndoPayload()
        payload.groundPoint = point
        payload.groundPointZoneId = zoneId
        snapshotForUndo(action: .withdraw, zoneId: zoneId, pointId: id, payload: payload)
        zones[zIdx].groundPoints.removeAll { $0.id == id }
        zones[zIdx].updatedAt = Date()
        persistZones()
        scheduleUndoExpiry()
    }

    /// Toggle favorite status of a place.
    func toggleGroundPointFavorite(pointId: UUID, inZoneId zoneId: UUID) {
        guard let zIdx = zones.firstIndex(where: { $0.id == zoneId }) else { return }
        guard let pIdx = zones[zIdx].groundPoints.firstIndex(where: { $0.id == pointId }) else { return }
        zones[zIdx].groundPoints[pIdx].isFavorite.toggle()
        persistZones()
        checkMedal_favorites()
    }

    /// Retrieve sorted places for a zone (favorites first).
    func groundPointsSorted(forZoneId zoneId: UUID) -> [GroundPoint] {
        guard let zone = zones.first(where: { $0.id == zoneId }) else { return [] }
        return zone.groundPoints.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.createdAt < rhs.createdAt
        }
    }

    // =========================================================================
    // MARK: - FIELD DAYS (Day Plans)
    // =========================================================================

    /// Today's date key in "yyyy-MM-dd" format.
    static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Get or create today's field day for a given zone.
    func todayFieldDay(forZoneId zoneId: UUID) -> FieldDay {
        let key = DataVault.todayKey
        if let existing = fieldDays.first(where: { $0.dateKey == key }) {
            return existing
        }
        let zoneName = zone(by: zoneId)?.title ?? "Zone"
        var newDay = FieldDay(dateKey: key, assignedZoneId: zoneId, assignedZoneTitle: zoneName)
        newDay.status = .briefed
        fieldDays.append(newDay)
        persistDays()
        return newDay
    }

    /// Get today's field day if it exists.
    func currentFieldDay() -> FieldDay? {
        fieldDays.first { $0.dateKey == DataVault.todayKey }
    }

    /// Update a field day.
    func updateFieldDay(_ day: FieldDay) {
        if let idx = fieldDays.firstIndex(where: { $0.id == day.id }) {
            fieldDays[idx] = day
            fieldDays[idx].updatedAt = Date()
        } else {
            fieldDays.append(day)
        }
        persistDays()
    }

    /// Add a deployment stop to today's plan.
    func deployStop(_ stop: DeploymentStop, toDayId dayId: UUID) {
        guard let idx = fieldDays.firstIndex(where: { $0.id == dayId }) else { return }
        var newStop = stop
        newStop.sortIndex = fieldDays[idx].deploymentQueue.count
        fieldDays[idx].deploymentQueue.append(newStop)
        fieldDays[idx].updatedAt = Date()
        if fieldDays[idx].status == .vacant {
            fieldDays[idx].status = .briefed
        }
        persistDays()
        fieldDays = fieldDays
    }

    /// Remove a stop from a day.
    func withdrawStop(stopId: UUID, fromDayId dayId: UUID) {
        guard let dIdx = fieldDays.firstIndex(where: { $0.id == dayId }) else { return }
        var payload = UndoPayload()
        payload.dayId = dayId
        payload.deploymentQueue = fieldDays[dIdx].deploymentQueue
        snapshotForUndo(action: .withdraw, dayId: dayId, payload: payload)
        fieldDays[dIdx].deploymentQueue.removeAll { $0.id == stopId }
        normalizeStopIndices(dayIndex: dIdx)
        persistDays()
        scheduleUndoExpiry()
    }

    /// Toggle accomplished state of a stop.
    func toggleStopAccomplished(stopId: UUID, inDayId dayId: UUID) {
        guard let dIdx = fieldDays.firstIndex(where: { $0.id == dayId }) else { return }
        guard let sIdx = fieldDays[dIdx].deploymentQueue.firstIndex(where: { $0.id == stopId }) else { return }

        fieldDays[dIdx].deploymentQueue[sIdx].isAccomplished.toggle()
        fieldDays[dIdx].deploymentQueue[sIdx].accomplishedAt =
            fieldDays[dIdx].deploymentQueue[sIdx].isAccomplished ? Date() : nil

        // Update day status
        let allDone = fieldDays[dIdx].deploymentQueue.allSatisfy { $0.isAccomplished }
        let anyDone = fieldDays[dIdx].deploymentQueue.contains { $0.isAccomplished }
        if allDone && !fieldDays[dIdx].deploymentQueue.isEmpty {
            fieldDays[dIdx].status = .accomplished
            awardMissionPoints(dayIndex: dIdx)
        } else if anyDone {
            fieldDays[dIdx].status = .inField
        } else {
            fieldDays[dIdx].status = .briefed
        }

        fieldDays[dIdx].updatedAt = Date()
        persistDays()
        checkMedal_stopsCompleted()
        checkMedal_perfectDay(dayIndex: dIdx)
    }

    /// Reorder stops via drag-and-drop result.
    func reorderStops(dayId: UUID, fromOffsets: IndexSet, toOffset: Int) {
        guard let dIdx = fieldDays.firstIndex(where: { $0.id == dayId }) else { return }
        var payload = UndoPayload()
        payload.dayId = dayId
        payload.deploymentQueue = fieldDays[dIdx].deploymentQueue
        snapshotForUndo(action: .reposition, dayId: dayId, payload: payload)
        fieldDays[dIdx].deploymentQueue.move(fromOffsets: fromOffsets, toOffset: toOffset)
        normalizeStopIndices(dayIndex: dIdx)
        persistDays()
        scheduleUndoExpiry()
    }

    /// Change the assigned zone for today. Keeps existing stops (they're self-contained).
    func reassignTodayZone(dayId: UUID, newZoneId: UUID) {
        guard let dIdx = fieldDays.firstIndex(where: { $0.id == dayId }) else { return }
        let zoneName = zone(by: newZoneId)?.title ?? "Zone"
        fieldDays[dIdx].assignedZoneId = newZoneId
        fieldDays[dIdx].assignedZoneTitle = zoneName
        // Keep deploymentQueue — stops are self-contained (title, duration, etc.)
        fieldDays[dIdx].updatedAt = Date()

        // Mark zone as recently used
        if let zIdx = zones.firstIndex(where: { $0.id == newZoneId }) {
            zones[zIdx].lastDeployedAt = Date()
            persistZones()
        }

        persistDays()
        fieldDays = fieldDays
    }

    /// Clear today's plan.
    func clearTodayPlan(dayId: UUID) {
        guard let dIdx = fieldDays.firstIndex(where: { $0.id == dayId }) else { return }
        var payload = UndoPayload()
        payload.dayId = dayId
        payload.deploymentQueue = fieldDays[dIdx].deploymentQueue
        snapshotForUndo(action: .withdraw, dayId: dayId, payload: payload)
        fieldDays[dIdx].deploymentQueue = []
        fieldDays[dIdx].status = .vacant
        fieldDays[dIdx].updatedAt = Date()
        persistDays()
        scheduleUndoExpiry()
    }

    private func normalizeStopIndices(dayIndex: Int) {
        for i in fieldDays[dayIndex].deploymentQueue.indices {
            fieldDays[dayIndex].deploymentQueue[i].sortIndex = i
        }
    }

    // =========================================================================
    // MARK: - PRESSURE (Overload Calculation)
    // =========================================================================

    /// Calculate pressure level for a given day.
    func evaluatePressure(forDay day: FieldDay) -> PressureLevel {
        let total = day.totalPlannedMin
        if total > config.criticalPressureThresholdMin {
            return .critical
        } else if total > config.densePressureThresholdMin {
            return .dense
        }
        return .steady
    }

    /// Pressure delta — how many minutes over the threshold.
    func pressureDelta(forDay day: FieldDay) -> Int {
        let total = day.totalPlannedMin
        let threshold = config.criticalPressureThresholdMin
        return max(0, total - threshold)
    }

    // =========================================================================
    // MARK: - CONFIG (Settings)
    // =========================================================================

    /// Update global configuration.
    func updateConfig(_ newConfig: CommandCenterConfig) {
        config = newConfig
        persistConfig()
    }

    /// Update a single config field via closure.
    func mutateConfig(_ mutation: (inout CommandCenterConfig) -> Void) {
        mutation(&config)
        persistConfig()
    }

    // =========================================================================
    // MARK: - ROUTE BLUEPRINTS (Templates)
    // =========================================================================

    func addBlueprint(_ bp: RouteBlueprint, toZoneId zoneId: UUID) {
        guard let idx = zones.firstIndex(where: { $0.id == zoneId }) else { return }
        zones[idx].routeBlueprints.append(bp)
        persistZones()
        checkMedal_templates()
    }

    func removeBlueprint(bpId: UUID, fromZoneId zoneId: UUID) {
        guard let idx = zones.firstIndex(where: { $0.id == zoneId }) else { return }
        zones[idx].routeBlueprints.removeAll { $0.id == bpId }
        persistZones()
    }

    // =========================================================================
    // MARK: - GAMIFICATION — Points & Medals
    // =========================================================================

    private func awardMissionPoints(dayIndex: Int) {
        let stopsCount = fieldDays[dayIndex].deploymentQueue.count
        let bonus = stopsCount * 10
        config.totalMissionsAccomplished += 1
        config.lifetimePointsEarned += bonus
        updateRank()
        updateStreak()
        persistConfig()
        checkMedal_firstMission()
    }

    private func updateRank() {
        let missions = config.totalMissionsAccomplished
        let newRank = OperatorRank.ladder.last { missions >= $0.requiredMissions }
        config.currentRankIndex = newRank?.id ?? 0
    }

    private func updateStreak() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let yesterdayKey = f.string(from: yesterday)

        let hadYesterday = fieldDays.contains {
            $0.dateKey == yesterdayKey && $0.status == .accomplished
        }
        if hadYesterday {
            config.dailyStreakCount += 1
        } else {
            config.dailyStreakCount = 1
        }
        checkMedal_streak()
    }

    /// Current operator rank.
    var currentRank: OperatorRank {
        OperatorRank.ladder[safe: config.currentRankIndex] ?? OperatorRank.ladder[0]
    }

    /// Points needed for next rank.
    var missionsToNextRank: Int {
        let nextIdx = config.currentRankIndex + 1
        guard let next = OperatorRank.ladder[safe: nextIdx] else { return 0 }
        return max(0, next.requiredMissions - config.totalMissionsAccomplished)
    }

    // ── Medal checks ─────────────────────────────────────────────

    private func checkMedal_zoneCount() {
        if zones.count >= 1  { unlockMedal("first_zone") }
        if zones.count >= 5  { unlockMedal("five_zones") }
        if zones.count >= 10 { unlockMedal("ten_zones") }
    }

    private func checkMedal_firstMission() {
        let m = config.totalMissionsAccomplished
        if m >= 1   { unlockMedal("first_mission") }
        if m >= 30  { unlockMedal("thirty_missions") }
        if m >= 50  { unlockMedal("fifty_missions") }
        if m >= 100 { unlockMedal("hundred_missions") }
    }

    private func checkMedal_streak() {
        let s = config.dailyStreakCount
        if s >= 5  { unlockMedal("five_streak") }
        if s >= 10 { unlockMedal("ten_streak") }
        if s >= 14 { unlockMedal("two_weeks") }
        if s >= 25 { unlockMedal("twenty_five_streak") }
    }

    private func checkMedal_stopsCompleted() {
        let total = fieldDays.reduce(0) { $0 + $1.accomplishedCount }
        if total >= 50  { unlockMedal("fifty_stops") }
        if total >= 100 { unlockMedal("hundred_stops") }
    }

    private func checkMedal_perfectDay(dayIndex: Int) {
        let day = fieldDays[dayIndex]
        if !day.deploymentQueue.isEmpty && day.deploymentQueue.allSatisfy({ $0.isAccomplished }) {
            unlockMedal("perfect_day")
            if day.deploymentQueue.count >= 15 { unlockMedal("speed_demon") }
        }
        let pressure = evaluatePressure(forDay: day)
        if pressure == .critical && day.status == .accomplished {
            unlockMedal("overload_survivor")
        }
        if pressure == .dense && day.status == .accomplished {
            unlockMedal("dense_day")
        }
    }

    private func checkMedal_templates() {
        let total = zones.reduce(0) { $0 + $1.routeBlueprints.count }
        if total >= 1 { unlockMedal("first_blueprint") }
        if total >= 3 { unlockMedal("template_master") }
        if total >= 5 { unlockMedal("five_blueprints") }
    }

    private func checkMedal_places() {
        let total = zones.reduce(0) { $0 + $1.groundPoints.count }
        if total >= 1  { unlockMedal("first_place") }
        if total >= 20 { unlockMedal("twenty_places") }
        if total >= 50 { unlockMedal("catalog_master") }
    }

    private func checkMedal_zoneArchitect() {
        let count = zones.filter { $0.groundPoints.count >= 5 }.count
        if count >= 3 { unlockMedal("zone_architect") }
    }

    private func checkMedal_favorites() {
        let total = zones.reduce(0) { $0 + $1.groundPoints.filter { $0.isFavorite }.count }
        if total >= 10 { unlockMedal("favorite_collector") }
    }

    private func unlockMedal(_ medalId: String) {
        guard let idx = medals.firstIndex(where: { $0.id == medalId && !$0.isUnlocked }) else { return }
        medals[idx].isUnlocked = true
        medals[idx].unlockedAt = Date()
        persistMedals()
    }

    // =========================================================================
    // MARK: - INTEL REPORT (Statistics)
    // =========================================================================

    /// Generate analytics for a given period.
    func generateIntelReport(days periodDays: Int = 7) -> IntelReport {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -periodDays, to: Date())!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let cutoffKey = f.string(from: cutoff)

        let recentDays = fieldDays.filter { $0.dateKey >= cutoffKey }
        let totalStops = recentDays.reduce(0) { $0 + $1.accomplishedCount }
        let totalMinutes = recentDays.reduce(0) { $0 + $1.totalPlannedMin }
        let avgStops = recentDays.isEmpty ? 0 : Double(totalStops) / Double(recentDays.count)

        // Most used tag
        var tagCounts: [ErrandTag: Int] = [:]
        for day in recentDays {
            for stop in day.deploymentQueue where stop.isAccomplished {
                tagCounts[stop.tag, default: 0] += 1
            }
        }
        let topTag = tagCounts.max(by: { $0.value < $1.value })?.key ?? .other

        // Most active zone
        var zoneCounts: [UUID: Int] = [:]
        for day in recentDays {
            zoneCounts[day.assignedZoneId, default: 0] += 1
        }
        let topZoneId = zoneCounts.max(by: { $0.value < $1.value })?.key
        let topZoneName = topZoneId.flatMap { zone(by: $0)?.title } ?? "—"

        // Completion rate
        let completedCount = recentDays.filter { $0.status == .accomplished }.count
        let rate = recentDays.isEmpty ? 0 : Double(completedCount) / Double(recentDays.count)

        return IntelReport(
            periodDays: periodDays,
            totalMissions: recentDays.count,
            totalStopsCompleted: totalStops,
            totalMinutesPlanned: totalMinutes,
            averageStopsPerDay: avgStops,
            mostUsedTag: topTag,
            mostActiveZoneTitle: topZoneName,
            currentStreak: config.dailyStreakCount,
            longestStreak: max(config.dailyStreakCount, config.dailyStreakCount),
            completionRate: rate
        )
    }

    // =========================================================================
    // MARK: - UNDO
    // =========================================================================

    private var undoExpiryWorkItem: DispatchWorkItem?

    private func snapshotForUndo(action: FieldAction, zoneId: UUID? = nil, dayId: UUID? = nil, pointId: UUID? = nil, payload: UndoPayload) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try? encoder.encode(payload)
        lastUndo = UndoSnapshot(
            actionType: action,
            affectedZoneId: zoneId,
            affectedDayId: dayId,
            affectedPointId: pointId,
            payload: payloadData
        )
    }

    private func scheduleUndoExpiry() {
        undoExpiryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.lastUndo = nil
            }
        }
        undoExpiryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }

    /// Restore state from last undo snapshot. Returns true if undo was executed.
    @discardableResult
    func executeUndo() -> Bool {
        guard let snapshot = lastUndo, let payloadData = snapshot.payload else {
            lastUndo = nil
            return false
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(UndoPayload.self, from: payloadData) else {
            lastUndo = nil
            return false
        }
        lastUndo = nil
        undoExpiryWorkItem?.cancel()

        switch snapshot.actionType {
        case .withdraw:
            if let zone = payload.zone {
                zones.append(zone)
                normalizeZoneSortIndices()
                persistZones()
                return true
            }
            if let point = payload.groundPoint, let zoneId = payload.groundPointZoneId {
                deployGroundPoint(point, toZoneId: zoneId)
                return true
            }
            if let day = payload.fieldDay {
                fieldDays.append(day)
                persistDays()
                return true
            }
            if let dayId = payload.dayId, let queue = payload.deploymentQueue {
                if let dIdx = fieldDays.firstIndex(where: { $0.id == dayId }) {
                    fieldDays[dIdx].deploymentQueue = queue
                    fieldDays[dIdx].status = queue.isEmpty ? .vacant : .briefed
                    fieldDays[dIdx].updatedAt = Date()
                    normalizeStopIndices(dayIndex: dIdx)
                    persistDays()
                    return true
                }
            }
        case .reposition:
            if let dayId = payload.dayId, let queue = payload.deploymentQueue {
                if let dIdx = fieldDays.firstIndex(where: { $0.id == dayId }) {
                    fieldDays[dIdx].deploymentQueue = queue
                    normalizeStopIndices(dayIndex: dIdx)
                    persistDays()
                    return true
                }
            }
        default:
            break
        }
        return false
    }

    // =========================================================================
    // MARK: - RESET / NUKE
    // =========================================================================

    /// Clear today's data only (removes the day entirely).
    func resetToday() {
        if let day = fieldDays.first(where: { $0.dateKey == DataVault.todayKey }) {
            var payload = UndoPayload()
            payload.fieldDay = day
            snapshotForUndo(action: .withdraw, dayId: day.id, payload: payload)
            scheduleUndoExpiry()
        }
        fieldDays.removeAll { $0.dateKey == DataVault.todayKey }
        persistDays()
    }

    /// Wipe everything — factory reset.
    func nuclearReset() {
        zones = []
        fieldDays = []
        config = CommandCenterConfig()
        medals = FieldMedal.catalog
        lastUndo = nil
        persistZones()
        persistDays()
        persistConfig()
        persistMedals()
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
