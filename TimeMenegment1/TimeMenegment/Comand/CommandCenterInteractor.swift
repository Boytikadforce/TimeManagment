// CommandCenterInteractor.swift
// c11 — Zone-based day planner with gamification
// VIPER Interactor — business logic for HQ / Settings tab

import Foundation

// MARK: - Protocol

protocol CommandCenterInteracting: AnyObject {
    /// Fetch current config.
    func fetchConfig() -> CommandCenterConfig

    /// Update full config.
    func saveConfig(_ config: CommandCenterConfig)

    /// Update avatar emoji.
    func updateAvatar(_ emoji: String)

    /// Update operator callsign.
    func updateCallSign(_ name: String)

    /// Fetch all medals with unlock status.
    func fetchMedals() -> [FieldMedal]

    /// Generate intel report for given period.
    func generateReport(days: Int) -> IntelReport

    /// Fetch current rank info.
    func fetchRankInfo() -> RankInfo

    /// Fetch lifetime stats.
    func fetchLifetimeStats() -> LifetimeStats

    /// Reset today's plan only.
    func resetToday()

    /// Full nuclear reset — wipe everything.
    func nuclearReset()

    /// Export data as shareable summary string.
    func exportSummary() -> String

    /// Total zones count.
    func totalZonesCount() -> Int

    /// Total places count across all zones.
    func totalPlacesCount() -> Int

    /// Request notification permission. Call when user enables reminders.
    func requestNotificationPermission(completion: @escaping (Bool) -> Void)

    /// Apply notification settings — request permission and schedule/cancel morning reminder.
    /// Completion is called with true if enabled and permission granted, false otherwise.
    func applyNotificationSettings(enable: Bool, hour: Int, minute: Int, completion: ((Bool) -> Void)?)
}

// MARK: - Supporting Types

struct RankInfo {
    let currentRank: OperatorRank
    let nextRank: OperatorRank?
    let missionsCompleted: Int
    let missionsToNext: Int
    let progressFraction: Double
    let lifetimePoints: Int
}

struct LifetimeStats {
    let totalMissions: Int
    let totalZones: Int
    let totalPlaces: Int
    let totalFieldDays: Int
    let longestStreak: Int
    let currentStreak: Int
    let medalsUnlocked: Int
    let medalsTotal: Int
    let lifetimePoints: Int
}

// MARK: - Implementation

final class CommandCenterInteractor: CommandCenterInteracting {

    private let vault: DataVault

    init(vault: DataVault = .shared) {
        self.vault = vault
    }

    func fetchConfig() -> CommandCenterConfig {
        vault.config
    }

    func saveConfig(_ config: CommandCenterConfig) {
        vault.updateConfig(config)
    }

    func updateAvatar(_ emoji: String) {
        vault.mutateConfig { $0.operatorAvatar = emoji }
    }

    func updateCallSign(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        vault.mutateConfig { $0.operatorCallSign = trimmed }
    }

    func fetchMedals() -> [FieldMedal] {
        vault.medals
    }

    func generateReport(days: Int) -> IntelReport {
        vault.generateIntelReport(days: days)
    }

    func fetchRankInfo() -> RankInfo {
        let config = vault.config
        let current = vault.currentRank
        let nextIdx = config.currentRankIndex + 1
        let next = OperatorRank.ladder[safe: nextIdx]

        let progress: Double
        if let n = next {
            let range = n.requiredMissions - current.requiredMissions
            let done = config.totalMissionsAccomplished - current.requiredMissions
            progress = range > 0 ? min(1.0, Double(done) / Double(range)) : 1.0
        } else {
            progress = 1.0
        }

        return RankInfo(
            currentRank: current,
            nextRank: next,
            missionsCompleted: config.totalMissionsAccomplished,
            missionsToNext: vault.missionsToNextRank,
            progressFraction: progress,
            lifetimePoints: config.lifetimePointsEarned
        )
    }

    func fetchLifetimeStats() -> LifetimeStats {
        let config = vault.config
        let unlocked = vault.medals.filter { $0.isUnlocked }.count

        return LifetimeStats(
            totalMissions: config.totalMissionsAccomplished,
            totalZones: vault.zones.filter { !$0.isArchived }.count,
            totalPlaces: vault.zones.reduce(0) { $0 + $1.groundPoints.count },
            totalFieldDays: vault.fieldDays.count,
            longestStreak: config.dailyStreakCount, // simplified
            currentStreak: config.dailyStreakCount,
            medalsUnlocked: unlocked,
            medalsTotal: vault.medals.count,
            lifetimePoints: config.lifetimePointsEarned
        )
    }

    func resetToday() {
        vault.resetToday()
    }

    func nuclearReset() {
        vault.nuclearReset()
        NotificationService.shared.removeMorningReminder()
    }

    func exportSummary() -> String {
        let stats = fetchLifetimeStats()
        let rank = fetchRankInfo()

        return """
        📊 Sequence — Zone Your Day

        🎖 Rank: \(rank.currentRank.badge) \(rank.currentRank.title)
        ⭐ Lifetime XP: \(stats.lifetimePoints)
        🔥 Current Streak: \(stats.currentStreak) days
        ✅ Missions Completed: \(stats.totalMissions)
        🗺 Zones: \(stats.totalZones)
        📍 Total Stops: \(stats.totalPlaces)
        🏅 Medals: \(stats.medalsUnlocked)/\(stats.medalsTotal)

        Zone your day. One zone at a time.
        """
    }

    func totalZonesCount() -> Int {
        vault.zones.filter { !$0.isArchived }.count
    }

    func totalPlacesCount() -> Int {
        vault.zones.reduce(0) { $0 + $1.groundPoints.count }
    }

    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        NotificationService.shared.requestPermission(completion: completion)
    }

    func applyNotificationSettings(enable: Bool, hour: Int, minute: Int, completion: ((Bool) -> Void)? = nil) {
        if enable {
            NotificationService.shared.requestPermission { granted in
                if granted {
                    NotificationService.shared.scheduleMorningReminder(hour: hour, minute: minute)
                }
                completion?(granted)
            }
        } else {
            NotificationService.shared.removeMorningReminder()
            completion?(true)
        }
    }
}
