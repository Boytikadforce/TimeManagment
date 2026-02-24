// CommandCenterPresenter.swift
// c11 — Zone-based day planner with gamification
// VIPER Presenter — observable state for HQ / Settings tab

import SwiftUI
import Combine

// MARK: - Presenter

final class CommandCenterPresenter: ObservableObject {

    // ── Published UI state ───────────────────────────────────────
    @Published var config: CommandCenterConfig = CommandCenterConfig()
    @Published var rankInfo: RankInfo = RankInfo(
        currentRank: OperatorRank.ladder[0], nextRank: OperatorRank.ladder[1],
        missionsCompleted: 0, missionsToNext: 3,
        progressFraction: 0, lifetimePoints: 0
    )
    @Published var lifetimeStats: LifetimeStats = LifetimeStats(
        totalMissions: 0, totalZones: 0, totalPlaces: 0,
        totalFieldDays: 0, longestStreak: 0, currentStreak: 0,
        medalsUnlocked: 0, medalsTotal: 8, lifetimePoints: 0
    )
    @Published var medals: [FieldMedal] = []
    @Published var report: IntelReport = IntelReport()
    @Published var reportPeriod: Int = 7

    // Editable settings
    @Published var editDefaultDuration: Int = 20
    @Published var editDefaultBuffer: Int = 10
    @Published var editDenseThreshold: Int = 180
    @Published var editCriticalThreshold: Int = 240
    @Published var editRecommendedStops: Int = 8
    @Published var editAllowZoneChange: Bool = true
    @Published var editUndoAlerts: Bool = true
    @Published var editShowBreakdown: Bool = true

    // Profile
    @Published var editAvatar: String = "🎯"
    @Published var editCallSign: String = "Operator"

    // Notifications
    @Published var editEnableMorningReminder: Bool = false
    @Published var editMorningReminderHour: Int = 8
    @Published var editMorningReminderMinute: Int = 0

    // ── Dependencies ─────────────────────────────────────────────
    private let interactor: CommandCenterInteracting
    private let router: MissionRouter
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(interactor: CommandCenterInteracting, router: MissionRouter) {
        self.interactor = interactor
        self.router = router
        bindChanges()
    }

    // MARK: - Bindings

    private func bindChanges() {
        DataVault.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAll() }
            .store(in: &cancellables)

        DataVault.shared.$medals
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshMedals() }
            .store(in: &cancellables)

        DataVault.shared.$zones
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStats() }
            .store(in: &cancellables)

        DataVault.shared.$fieldDays
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStats() }
            .store(in: &cancellables)

        $reportPeriod
            .sink { [weak self] period in
                self?.report = self?.interactor.generateReport(days: period) ?? IntelReport()
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func onAppear() {
        refreshAll()
    }

    private func refreshAll() {
        config = interactor.fetchConfig()
        loadEditableFields()
        refreshStats()
        refreshMedals()
    }

    private func refreshStats() {
        rankInfo = interactor.fetchRankInfo()
        lifetimeStats = interactor.fetchLifetimeStats()
        report = interactor.generateReport(days: reportPeriod)
    }

    private func refreshMedals() {
        medals = interactor.fetchMedals()
    }

    private func loadEditableFields() {
        editDefaultDuration = config.defaultDurationMin
        editDefaultBuffer = config.defaultBufferMin
        editDenseThreshold = config.densePressureThresholdMin
        editCriticalThreshold = config.criticalPressureThresholdMin
        editRecommendedStops = config.recommendedStopsCount
        editAllowZoneChange = config.allowZoneChangeDuringDay
        editUndoAlerts = config.enableUndoAlerts
        editShowBreakdown = config.showTimeBreakdown
        editAvatar = config.operatorAvatar
        editCallSign = config.operatorCallSign
        editEnableMorningReminder = config.enableMorningReminder
        editMorningReminderHour = config.morningReminderHour
        editMorningReminderMinute = config.morningReminderMinute
    }

    /// True when any editable field differs from saved config.
    var hasUnsavedChanges: Bool {
        editDefaultDuration != config.defaultDurationMin
        || editDefaultBuffer != config.defaultBufferMin
        || editDenseThreshold != config.densePressureThresholdMin
        || editCriticalThreshold != config.criticalPressureThresholdMin
        || editRecommendedStops != config.recommendedStopsCount
        || editAllowZoneChange != config.allowZoneChangeDuringDay
        || editUndoAlerts != config.enableUndoAlerts
        || editShowBreakdown != config.showTimeBreakdown
        || editAvatar != config.operatorAvatar
        || editCallSign != config.operatorCallSign
        || editEnableMorningReminder != config.enableMorningReminder
        || editMorningReminderHour != config.morningReminderHour
        || editMorningReminderMinute != config.morningReminderMinute
    }

    // =========================================================================
    // MARK: - User Actions → Interactor
    // =========================================================================

    /// Save all settings edits.
    func handleSaveSettings() {
        var updated = config
        updated.defaultDurationMin = editDefaultDuration
        updated.defaultBufferMin = editDefaultBuffer
        updated.densePressureThresholdMin = editDenseThreshold
        updated.criticalPressureThresholdMin = max(editDenseThreshold, editCriticalThreshold)
        updated.recommendedStopsCount = editRecommendedStops
        updated.allowZoneChangeDuringDay = editAllowZoneChange
        updated.enableUndoAlerts = editUndoAlerts
        updated.showTimeBreakdown = editShowBreakdown
        updated.enableMorningReminder = editEnableMorningReminder
        updated.morningReminderHour = editMorningReminderHour
        updated.morningReminderMinute = editMorningReminderMinute
        interactor.saveConfig(updated)
        let enableReminder = editEnableMorningReminder
        let r = router
        interactor.applyNotificationSettings(enable: enableReminder, hour: editMorningReminderHour, minute: editMorningReminderMinute) { granted in
            if enableReminder && !granted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    r.flashToast("Enable notifications in Settings")
                }
            }
        }
        router.flashToast("Settings saved ✓")
        Pulse.success()
    }

    /// Request notification permission. Call when user enables morning reminder.
    func handleRequestNotificationPermission() {
        interactor.requestNotificationPermission { _ in }
    }

    /// Update avatar emoji.
    func handleUpdateAvatar(_ emoji: String) {
        editAvatar = emoji
        interactor.updateAvatar(emoji)
        Pulse.light()
    }

    /// Update callsign.
    func handleUpdateCallSign(_ callSign: String) {
        editCallSign = callSign
        interactor.updateCallSign(callSign)
        router.flashToast("Callsign updated ✓")
    }

    /// Change report period.
    func handleSetReportPeriod(_ days: Int) {
        reportPeriod = days
    }

    /// Reset today only.
    func handleResetToday() {
        router.raiseAlert(.confirmClearToday(dayId: UUID()))
    }

    /// Confirm reset today.
    func handleConfirmResetToday() {
        interactor.resetToday()
        router.dismissAlert()
        router.flashToast("Today reset ✓", showUndo: true)
        Pulse.warning()
    }

    /// Nuclear reset.
    func handleNuclearReset() {
        router.raiseAlert(.confirmNuclearReset)
    }

    /// Confirm nuclear reset.
    func handleConfirmNuclearReset() {
        interactor.nuclearReset()
        router.dismissAlert()
        router.flashToast("All data erased")
        Pulse.warning()
    }

    /// Share / export summary.
    func handleExport() -> String {
        interactor.exportSummary()
    }

    // =========================================================================
    // MARK: - Navigation → Router
    // =========================================================================

    func handleOpenIntelReport() {
        router.presentBriefing(.intelReport)
    }

    func handleOpenAvatarPicker() {
        router.presentBriefing(.avatarPicker)
    }

    func handleOpenDangerZone() {
        router.presentBriefing(.dangerZone)
    }

    // =========================================================================
    // MARK: - View Helpers
    // =========================================================================

    /// Formatted rank display.
    var rankDisplay: String {
        "\(rankInfo.currentRank.badge) \(rankInfo.currentRank.title)"
    }

    /// XP display.
    var xpDisplay: String {
        "\(rankInfo.lifetimePoints) XP"
    }

    /// Streak display.
    var streakDisplay: String {
        lifetimeStats.currentStreak > 0 ? "🔥 \(lifetimeStats.currentStreak)-day streak" : "No streak yet"
    }

    /// Medal progress.
    var medalProgress: String {
        "\(lifetimeStats.medalsUnlocked)/\(lifetimeStats.medalsTotal) unlocked"
    }

    /// Unlocked medals only.
    var unlockedMedals: [FieldMedal] {
        medals.filter { $0.isUnlocked }
    }

    /// Locked medals only.
    var lockedMedals: [FieldMedal] {
        medals.filter { !$0.isUnlocked }
    }

    /// Report completion rate as percentage.
    var completionRatePercent: String {
        "\(Int(report.completionRate * 100))%"
    }
}
