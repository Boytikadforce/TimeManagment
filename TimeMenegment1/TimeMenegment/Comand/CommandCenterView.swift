// CommandCenterView.swift
// c11 — Zone-based day planner with gamification
// VIPER View — HQ / Settings tab

import SwiftUI

// MARK: - Command Center View

struct CommandCenterView: View {

    @ObservedObject var presenter: CommandCenterPresenter
    @EnvironmentObject var router: MissionRouter

    @State private var appeared = false

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack(path: $router.commandPath) {
                    commandContent
                }
            } else {
                NavigationView {
                    commandContent
                }
            }
        }
    }

    private var commandContent: some View {
        ZStack {
                Palette.deepOpsBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Grid.large) {

                        // ── Operator profile card ────────────────
                        OperatorProfileCard(
                            avatar: presenter.editAvatar,
                            callSign: presenter.editCallSign,
                            rankDisplay: presenter.rankDisplay,
                            xpDisplay: presenter.xpDisplay,
                            streakDisplay: presenter.streakDisplay,
                            progress: presenter.rankInfo.progressFraction,
                            missionsToNext: presenter.rankInfo.missionsToNext,
                            onAvatarTap: { presenter.handleOpenAvatarPicker() }
                        )
                        .padding(.horizontal, Grid.base)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -10)

                        // ── Quick stats row ──────────────────────
                        QuickStatsRow(stats: presenter.lifetimeStats)
                            .padding(.horizontal, Grid.base)

                        // ── Intel report card ────────────────────
                        IntelReportCard(
                            report: presenter.report,
                            period: presenter.reportPeriod,
                            completionPercent: presenter.completionRatePercent,
                            onPeriodChange: { presenter.handleSetReportPeriod($0) }
                        )
                        .padding(.horizontal, Grid.base)

                        // ── Medals gallery ───────────────────────
                        MedalsGallery(
                            unlocked: presenter.unlockedMedals,
                            locked: presenter.lockedMedals,
                            progressLabel: presenter.medalProgress
                        )
                        .padding(.horizontal, Grid.base)

                        // ── Time & pressure settings ─────────────
                        TimePressureSettings(presenter: presenter)
                            .padding(.horizontal, Grid.base)

                        // ── Behavior toggles ─────────────────────
                        BehaviorToggles(presenter: presenter)
                            .padding(.horizontal, Grid.base)

                        // ── Notifications ─────────────────────────
                        NotificationsSection(presenter: presenter)
                            .padding(.horizontal, Grid.base)

                        // ── Actions row ──────────────────────────
                        HQActionsSection(
                            onExport: { shareExport() },
                            onResetToday: { presenter.handleResetToday() },
                            onNuclearReset: { presenter.handleNuclearReset() }
                        )
                        .padding(.horizontal, Grid.base)

                        // ── App info ─────────────────────────────
                        AppInfoFooter()
                            .padding(.top, Grid.base)

                        Spacer().frame(height: 100)
                    }
                    .padding(.top, Grid.small)
                }
            }
            .navigationTitle("HQ")
            .navigationBarTitleDisplayMode(.large)
            .modifier(ToolbarColorSchemeModifier())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if presenter.hasUnsavedChanges {
                        Button(action: { presenter.handleSaveSettings() }) {
                            Text("Save")
                                .font(Signal.briefing(17))
                                .foregroundColor(Palette.ambitionGold)
                        }
                    }
                }
            }
            .onAppear {
                presenter.onAppear()
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    appeared = true
                }
            }
    }

    private func shareExport() {
        let text = presenter.handleExport()
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - Operator Profile Card

struct OperatorProfileCard: View {
    let avatar: String
    let callSign: String
    let rankDisplay: String
    let xpDisplay: String
    let streakDisplay: String
    let progress: Double
    let missionsToNext: Int
    let onAvatarTap: () -> Void

    @State private var ringPulse = false

    var body: some View {
        VStack(spacing: Grid.medium) {
            HStack(spacing: Grid.base) {
                // Avatar
                Button(action: onAvatarTap) {
                    ZStack {
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [Palette.ambitionGold, Palette.conquestGreen, Palette.momentumGlow, Palette.ambitionGold],
                                    center: .center
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 72, height: 72)
                            .scaleEffect(ringPulse ? 1.06 : 1.0)

                        Text(avatar)
                            .font(.system(size: 36))
                    }
                }

                VStack(alignment: .leading, spacing: Grid.micro) {
                    Text(callSign)
                        .font(Signal.headline(24))
                        .foregroundColor(Palette.frostCommand)

                    Text(rankDisplay)
                        .font(Signal.briefing(16))
                        .foregroundColor(Palette.ambitionGold)

                    HStack(spacing: Grid.medium) {
                        Text(xpDisplay)
                            .font(Signal.mono(14))
                            .foregroundColor(Palette.momentumGlow)

                        if !streakDisplay.isEmpty {
                            Text(streakDisplay)
                                .font(Signal.intel(14))
                                .foregroundColor(Palette.conquestGreen)
                        }
                    }
                }

                Spacer()
            }

            // Rank progress bar
            VStack(alignment: .leading, spacing: Grid.micro) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.dormantGray)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Palette.ambitionGold, Palette.momentumGlow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(progress))
                            .animation(.easeInOut(duration: 0.6), value: progress)
                    }
                }
                .frame(height: 6)

                Text(missionsToNext > 0
                    ? "\(missionsToNext) missions to next rank"
                    : "Maximum rank achieved!"
                )
                .font(.system(size: 13))
                .foregroundColor(Palette.secondaryLabel)
            }
        }
        .padding(Grid.base)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                ringPulse = true
            }
        }
    }
}

// MARK: - Quick Stats Row

struct QuickStatsRow: View {
    let stats: LifetimeStats

    var body: some View {
        HStack(spacing: Grid.small) {
            QuickStatPill(value: "\(stats.totalMissions)", label: "Missions", icon: "flag.fill", color: Palette.ambitionGold)
            QuickStatPill(value: "\(stats.totalZones)", label: "Zones", icon: "map.fill", color: Palette.conquestGreen)
            QuickStatPill(value: "\(stats.totalPlaces)", label: "Stops", icon: "mappin", color: Palette.momentumGlow)
            QuickStatPill(value: "\(stats.lifetimePoints)", label: "XP", icon: "star.fill", color: Palette.badgeShimmer)
        }
    }
}

struct QuickStatPill: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Grid.micro) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(Signal.briefing(18))
                .foregroundColor(Palette.frostCommand)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Palette.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Grid.medium)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.small)
    }
}

// MARK: - Intel Report Card

struct IntelReportCard: View {
    let report: IntelReport
    let period: Int
    let completionPercent: String
    let onPeriodChange: (Int) -> Void

    private let periods = [7, 30, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.medium) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(Palette.ambitionGold)
                Text("Intel Report")
                    .font(Signal.dispatch(16))
                    .foregroundColor(Palette.frostCommand)
                Spacer()
            }

            // Period selector
            HStack(spacing: Grid.small) {
                ForEach(periods, id: \.self) { p in
                    Button(action: { onPeriodChange(p) }) {
                        Text("\(p)d")
                            .font(Signal.intel(15))
                            .foregroundColor(period == p ? Palette.deepOpsBase : Palette.silentDuty)
                            .padding(.horizontal, Grid.medium)
                            .padding(.vertical, Grid.small)
                            .background(period == p ? Palette.ambitionGold : Palette.elevatedBunker)
                            .cornerRadius(Shield.pill)
                    }
                }
                Spacer()
            }

            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Grid.medium) {
                IntelCell(label: "Missions", value: "\(report.totalMissions)", icon: "flag.fill")
                IntelCell(label: "Completion", value: completionPercent, icon: "checkmark.circle.fill")
                IntelCell(label: "Stops done", value: "\(report.totalStopsCompleted)", icon: "mappin.circle.fill")
                IntelCell(label: "Avg stops/day", value: String(format: "%.1f", report.averageStopsPerDay), icon: "chart.line.uptrend.xyaxis")
                IntelCell(label: "Top zone", value: report.mostActiveZoneTitle, icon: "map.fill")
                IntelCell(label: "Top category", value: report.mostUsedTag.callSign, icon: report.mostUsedTag.iconGlyph)
            }
        }
        .padding(Grid.base)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

struct IntelCell: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: Grid.small) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Palette.ambitionGold)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(Signal.briefing(15))
                    .foregroundColor(Palette.frostCommand)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.secondaryLabel)
            }
            Spacer()
        }
        .padding(Grid.small)
        .background(Palette.elevatedBunker)
        .cornerRadius(Shield.small)
    }
}

// MARK: - Medals Gallery

private let kMedalsPreviewCount = 8

struct MedalsGallery: View {
    let unlocked: [FieldMedal]
    let locked: [FieldMedal]
    let progressLabel: String

    @State private var isExpanded = false

    private var allMedals: [FieldMedal] {
        unlocked + locked
    }

    private var displayedMedals: [FieldMedal] {
        if isExpanded || allMedals.count <= kMedalsPreviewCount {
            return allMedals
        }
        return Array(allMedals.prefix(kMedalsPreviewCount))
    }

    private var hasMoreToShow: Bool {
        allMedals.count > kMedalsPreviewCount && !isExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.medium) {
            HStack {
                Image(systemName: "medal.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Palette.badgeShimmer)
                Text("Field Medals")
                    .font(Signal.dispatch(18))
                    .foregroundColor(Palette.frostCommand)
                Spacer()
                Text(progressLabel)
                    .font(Signal.intel(14))
                    .foregroundColor(Palette.secondaryLabel)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Grid.medium) {
                ForEach(displayedMedals) { medal in
                    MedalBadge(medal: medal, isUnlocked: medal.isUnlocked)
                }
            }

            if hasMoreToShow {
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isExpanded = true } }) {
                    HStack(spacing: Grid.small) {
                        Text("Show all \(allMedals.count) medals")
                            .font(Signal.intel(14))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Palette.ambitionGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Grid.small)
                }
                .buttonStyle(.plain)
            } else if isExpanded && allMedals.count > kMedalsPreviewCount {
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isExpanded = false } }) {
                    HStack(spacing: Grid.small) {
                        Text("Collapse")
                            .font(Signal.intel(14))
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Palette.secondaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Grid.small)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Grid.base)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

struct MedalBadge: View {
    let medal: FieldMedal
    let isUnlocked: Bool

    @State private var shimmer = false

    var body: some View {
        VStack(spacing: Grid.micro) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Palette.elevatedBunker : Palette.dormantGray.opacity(0.3))
                    .frame(width: 52, height: 52)

                if isUnlocked {
                    Circle()
                        .stroke(Palette.badgeShimmer.opacity(shimmer ? 0.6 : 0.1), lineWidth: 2)
                        .frame(width: 52, height: 52)
                }

                Text(isUnlocked ? medal.iconEmoji : "🔒")
                    .font(.system(size: 22))
                    .opacity(isUnlocked ? 1 : 0.4)
            }

            Text(medal.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isUnlocked ? Palette.frostCommand : Palette.secondaryLabel)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            if isUnlocked {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    shimmer = true
                }
            }
        }
    }
}

// MARK: - Time & Pressure Settings

struct TimePressureSettings: View {
    @ObservedObject var presenter: CommandCenterPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.medium) {
            HStack {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Palette.ambitionGold)
                Text("Time & Pressure")
                    .font(Signal.dispatch(18))
                    .foregroundColor(Palette.frostCommand)
            }

            SettingsStepperRow(
                label: "Default duration",
                value: $presenter.editDefaultDuration,
                range: 5...120,
                step: 5,
                unit: "min"
            )

            SettingsStepperRow(
                label: "Default buffer",
                value: $presenter.editDefaultBuffer,
                range: 0...60,
                step: 5,
                unit: "min"
            )

            SettingsStepperRow(
                label: "Dense threshold",
                value: $presenter.editDenseThreshold,
                range: 60...480,
                step: 30,
                unit: "min"
            )

            SettingsStepperRow(
                label: "Overload threshold",
                value: $presenter.editCriticalThreshold,
                range: 60...600,
                step: 30,
                unit: "min"
            )

            SettingsStepperRow(
                label: "Recommended stops",
                value: $presenter.editRecommendedStops,
                range: 3...20,
                step: 1,
                unit: ""
            )
        }
        .padding(Grid.base)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

struct SettingsStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .font(Signal.intel(16))
                .foregroundColor(Palette.silentDuty)

            Spacer()

            HStack(spacing: Grid.small) {
                Button(action: {
                    value = max(range.lowerBound, value - step)
                    Pulse.light()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Palette.ambitionGold)
                }

                Text(unit.isEmpty ? "\(value)" : "\(value) \(unit)")
                    .font(Signal.mono(16))
                    .foregroundColor(Palette.frostCommand)
                    .frame(minWidth: 55)

                Button(action: {
                    value = min(range.upperBound, value + step)
                    Pulse.light()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Palette.ambitionGold)
                }
            }
        }
        .padding(.vertical, Grid.micro)
    }
}

// MARK: - Behavior Toggles

struct BehaviorToggles: View {
    @ObservedObject var presenter: CommandCenterPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.medium) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundColor(Palette.ambitionGold)
                Text("Behavior")
                    .font(Signal.dispatch(18))
                    .foregroundColor(Palette.frostCommand)
            }

            SettingsToggleRow(
                label: "Allow zone change during day",
                isOn: $presenter.editAllowZoneChange
            )
            SettingsToggleRow(
                label: "Show undo alerts",
                isOn: $presenter.editUndoAlerts
            )
            SettingsToggleRow(
                label: "Show time breakdown",
                isOn: $presenter.editShowBreakdown
            )
        }
        .padding(Grid.base)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

struct SettingsToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(Signal.intel(14))
                .foregroundColor(Palette.silentDuty)
        }
        .tint(Palette.ambitionGold)
        .onChange(of: isOn) { _ in Pulse.light() }
    }
}

// MARK: - Notifications Section

struct NotificationsSection: View {
    @ObservedObject var presenter: CommandCenterPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.medium) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Palette.ambitionGold)
                Text("Notifications")
                    .font(Signal.dispatch(18))
                    .foregroundColor(Palette.frostCommand)
            }

            SettingsToggleRow(
                label: "Morning reminder",
                isOn: $presenter.editEnableMorningReminder
            )
            .onChange(of: presenter.editEnableMorningReminder) { isOn in
                if isOn {
                    presenter.handleRequestNotificationPermission()
                }
            }

            if presenter.editEnableMorningReminder {
                HStack(spacing: Grid.medium) {
                    Text("Time")
                        .font(Signal.intel(14))
                        .foregroundColor(Palette.silentDuty)

                    Picker("Hour", selection: $presenter.editMorningReminderHour) {
                        ForEach(6..<15, id: \.self) { h in
                            Text("\(h):00").tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: presenter.editMorningReminderHour) { _ in Pulse.light() }

                    Picker("Minute", selection: $presenter.editMorningReminderMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { m in
                            Text(String(format: ":%02d", m)).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: presenter.editMorningReminderMinute) { _ in Pulse.light() }
                }
            }
        }
        .padding(Grid.base)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

// MARK: - HQ Actions Section

struct HQActionsSection: View {
    let onExport: () -> Void
    let onResetToday: () -> Void
    let onNuclearReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.medium) {
            HStack {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Palette.ambitionGold)
                Text("Data & Actions")
                    .font(Signal.dispatch(18))
                    .foregroundColor(Palette.frostCommand)
            }

            // Share
            Button(action: onExport) {
                HQActionRow(
                    icon: "square.and.arrow.up",
                    title: "Share Stats",
                    subtitle: "Export your progress as text",
                    color: Palette.ambitionGold
                )
            }
            .buttonStyle(.plain)

            // Reset today
            Button(action: onResetToday) {
                HQActionRow(
                    icon: "arrow.counterclockwise",
                    title: "Reset Today",
                    subtitle: "Clear today's plan, keep everything else",
                    color: Palette.urgencyAmber
                )
            }
            .buttonStyle(.plain)

            // Nuclear
            Button(action: onNuclearReset) {
                HQActionRow(
                    icon: "exclamationmark.octagon.fill",
                    title: "Erase All Data",
                    subtitle: "Permanently delete everything",
                    color: Palette.overloadCrimson
                )
            }
            .buttonStyle(.plain)
        }
        .padding(Grid.base)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

struct HQActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: Grid.medium) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .cornerRadius(Shield.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Signal.briefing(16))
                    .foregroundColor(color)
                Text(subtitle)
                    .font(Signal.intel(14))
                    .foregroundColor(Palette.secondaryLabel)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(Palette.secondaryLabel)
        }
    }
}

// MARK: - App Info Footer

struct AppInfoFooter: View {
    var body: some View {
        VStack(spacing: Grid.small) {
            Text("c11")
                .font(Signal.briefing(16))
                .foregroundColor(Palette.secondaryLabel)
            Text("Zone Your Day • v1.0")
                .font(Signal.intel(14))
                .foregroundColor(Palette.secondaryLabel)
            Text("One day — one zone")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Palette.secondaryLabel.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Grid.base)
    }
}

// MARK: - Preview

#if DEBUG
struct CommandCenterView_Previews: PreviewProvider {
    static var previews: some View {
        let router = MissionRouter()
        let interactor = CommandCenterInteractor()
        let presenter = CommandCenterPresenter(interactor: interactor, router: router)
        CommandCenterView(presenter: presenter)
            .environmentObject(router)
            .preferredColorScheme(.dark)
    }
}
#endif
