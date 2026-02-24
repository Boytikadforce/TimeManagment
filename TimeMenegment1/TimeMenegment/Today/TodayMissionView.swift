// TodayMissionView.swift
// c11 — Zone-based day planner with gamification
// VIPER View — Today tab main screen

import SwiftUI

/// Hides list scroll content background on iOS 16+. No-op on iOS 15.
private struct ListScrollContentBackgroundHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

// MARK: - Today Mission View

struct TodayMissionView: View {

    @ObservedObject var presenter: TodayMissionPresenter
    @EnvironmentObject var router: MissionRouter

    @State private var headerAppeared = false
    @State private var listAppeared = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack(path: $router.todayPath) {
                    todayContent
                }
                .navigationDestination(for: Waypoint.self) { waypoint in
                    switch waypoint {
                    case .pressureBreakdown(let dayId):
                        PressureBreakdownPlaceholder(dayId: dayId)
                    default:
                        EmptyView()
                    }
                }
            } else {
                NavigationView {
                    todayContent
                }
            }
        }
    }

    private var todayContent: some View {
        ZStack {
                Palette.deepOpsBase
                    .ignoresSafeArea()

                if !presenter.hasMission {
                    // ── No mission state ─────────────────────────
                    NoMissionPlaceholder(
                        onPickZone: { presenter.handleOpenZonePicker() }
                    )
                } else {
                    // ── Active mission ───────────────────────────
                    ScrollView {
                        VStack(spacing: Grid.large) {

                            // ── Mission header ───────────────────
                            MissionHeaderCard(
                                dateLabel: presenter.todayDateLabel,
                                zoneTitle: presenter.zoneTitle,
                                zoneIcon: presenter.zoneIcon,
                                progressFraction: presenter.progressFraction,
                                progressLabel: presenter.progressLabel,
                                remainingCount: presenter.remainingCount,
                                plannedMinLabel: presenter.plannedMinLabel,
                                statusLabel: presenter.statusLabel,
                                isMissionComplete: presenter.isMissionComplete,
                                onZoneTap: { presenter.handleOpenZoneDetail() }
                            )
                            .padding(.horizontal, Grid.base)
                            .opacity(headerAppeared ? 1 : 0)
                            .offset(y: headerAppeared ? 0 : -12)

                            // ── Next up highlight ─────────────────
                            if let nextStop = presenter.stops.first(where: { !$0.isAccomplished }),
                               !presenter.isMissionComplete {
                                NextUpCard(
                                    stop: nextStop,
                                    index: (presenter.stops.firstIndex(where: { !$0.isAccomplished }) ?? 0) + 1,
                                    onTap: { presenter.handleToggleAccomplished(stopId: nextStop.id) }
                                )
                                .padding(.horizontal, Grid.base)
                            }

                            // ── Pressure badge ───────────────────
                            if !presenter.stops.isEmpty {
                                PressureBadge(
                                    label: presenter.pressureLabel,
                                    icon: presenter.pressureIcon,
                                    color: presenter.pressureColor,
                                    tooManyStops: presenter.tooManyStops,
                                    stopsCount: presenter.breakdown.stopsCount,
                                    maxRecommended: presenter.breakdown.recommendedMax,
                                    onDetailsTap: { presenter.handleOpenPressureBreakdown() }
                                )
                                .padding(.horizontal, Grid.base)
                            }

                            // ── Time block card ───────────────────
                            if !presenter.stops.isEmpty, let total = presenter.mission?.totalPlannedMin, total > 0 {
                                TimeBlockCard(totalMinutes: total)
                                    .padding(.horizontal, Grid.base)
                            }

                            // ── Gamification bar ─────────────────
                            GamificationBar(
                                badge: presenter.gamification.rankBadge,
                                rankTitle: presenter.gamification.rankTitle,
                                streak: presenter.gamification.streakDays,
                                pointsToday: presenter.gamification.pointsToday,
                                progress: presenter.gamification.progressToNextRank,
                                progressLabel: presenter.rankProgressLabel
                            )
                            .padding(.horizontal, Grid.base)

                            // ── Action strip ─────────────────────
                            TodayActionStrip(
                                onAddFromCatalog: { presenter.handleOpenAddFromCatalog() },
                                onQuickAdd: { presenter.handleOpenQuickAdd() },
                                hasAvailablePlaces: !presenter.availablePlaces.isEmpty
                            )
                            .padding(.horizontal, Grid.base)

                            // ── Stops list ───────────────────────
                            if presenter.stops.isEmpty {
                                EmptyQueuePrompt(
                                    onAdd: { presenter.handleOpenAddFromCatalog() }
                                )
                                .padding(.top, Grid.large)
                            } else {
                                DeploymentQueueList(
                                    stops: presenter.stops,
                                    isMissionComplete: presenter.isMissionComplete,
                                    onToggle: { presenter.handleToggleAccomplished(stopId: $0) },
                                    onDelete: { presenter.handleWithdrawStop(stopId: $0) },
                                    onReorder: { presenter.handleReorder(fromOffsets: $0, toOffset: $1) }
                                )
                                .padding(.horizontal, Grid.base)
                                .opacity(listAppeared ? 1 : 0)
                            }

                            Spacer().frame(height: 100)
                        }
                        .padding(.top, Grid.small)
                    }
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .modifier(ToolbarColorSchemeModifier())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if presenter.hasMission {
                        Menu {
                            Button(action: { presenter.handleOpenAddFromCatalog() }) {
                                Label("Add from Catalog", systemImage: "plus.circle")
                            }
                            Button(action: { presenter.handleOpenQuickAdd() }) {
                                Label("Quick Add Stop", systemImage: "bolt.circle")
                            }

                            Divider()

                            Button(action: { presenter.handleOpenZonePicker() }) {
                                Label("Change Zone", systemImage: "arrow.triangle.2.circlepath")
                            }

                            if !presenter.stops.isEmpty {
                                Divider()

                                if presenter.pressure == .critical {
                                    Button(action: { presenter.handleCompressBuffers() }) {
                                        Label("Compress Buffers", systemImage: "arrow.down.right.and.arrow.up.left")
                                    }
                                    Button(action: { presenter.handleCreateLightVariant() }) {
                                        Label("Create Light Plan", systemImage: "doc.badge.gearshape")
                                    }
                                }

                                Button(role: .destructive, action: { presenter.handleClearAll() }) {
                                    Label("Clear All Stops", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(Palette.ambitionGold)
                        }
                    }
                }
            }
            .onAppear {
                presenter.onAppear()
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    headerAppeared = true
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
                    listAppeared = true
                }
            }
        }
}

// MARK: - Next Up Card

struct NextUpCard: View {
    let stop: DeploymentStop
    let index: Int
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Grid.medium) {
                ZStack {
                    Circle()
                        .stroke(Palette.ambitionGold.opacity(0.5), lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulse ? 1.05 : 1.0)
                    Text("\(index)")
                        .font(Signal.mono(16))
                        .foregroundColor(Palette.ambitionGold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT UP")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(Palette.ambitionGold.opacity(0.9))
                    Text(stop.title)
                        .font(Signal.briefing(16))
                        .foregroundColor(Palette.frostCommand)
                        .lineLimit(1)
                    HStack(spacing: Grid.small) {
                        Image(systemName: stop.tag.iconGlyph)
                            .font(.system(size: 10))
                        Text(stop.tag.callSign)
                            .font(Signal.whisper())
                        Text("•")
                        Text("\(stop.loadMin)m")
                            .font(Signal.whisper())
                    }
                    .foregroundColor(Palette.secondaryLabel)
                }

                Spacer()

                Image(systemName: "checkmark.circle")
                    .font(.system(size: 24))
                    .foregroundColor(Palette.ambitionGold.opacity(0.6))
            }
            .padding(Grid.base)
            .background(
                RoundedRectangle(cornerRadius: Shield.medium)
                    .fill(Palette.tacticalSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Shield.medium)
                            .stroke(Palette.ambitionGold.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Mission Header Card

struct MissionHeaderCard: View {
    let dateLabel: String
    let zoneTitle: String
    let zoneIcon: String
    let progressFraction: Double
    let progressLabel: String
    let remainingCount: Int
    let plannedMinLabel: String
    let statusLabel: String
    let isMissionComplete: Bool
    let onZoneTap: () -> Void

    @State private var ringAnimated = false

    var body: some View {
        VStack(spacing: Grid.medium) {
            // Date + Zone
            HStack {
                VStack(alignment: .leading, spacing: Grid.micro) {
                    Text(dateLabel)
                        .font(Signal.whisper())
                        .foregroundColor(Palette.silentDuty)

                    Button(action: onZoneTap) {
                        HStack(spacing: Grid.small) {
                            Image(systemName: zoneIcon)
                                .font(.system(size: 16))
                                .foregroundColor(Palette.ambitionGold)
                            Text(zoneTitle)
                                .font(Signal.dispatch(18))
                                .foregroundColor(Palette.frostCommand)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(Palette.dormantGray)
                        }
                    }
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Palette.dormantGray, lineWidth: 5)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: ringAnimated ? CGFloat(progressFraction) : 0)
                        .stroke(
                            isMissionComplete
                                ? Palette.conquestGreen
                                : Palette.ambitionGold,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text(progressLabel)
                        .font(Signal.briefing(14))
                        .foregroundColor(Palette.frostCommand)
                }
            }

            // Stats row
            HStack(spacing: Grid.large) {
                MissionMetric(
                    icon: "clock.fill",
                    value: plannedMinLabel,
                    color: Palette.silentDuty
                )
                MissionMetric(
                    icon: "mappin.circle.fill",
                    value: "\(remainingCount) left",
                    color: remainingCount == 0 ? Palette.conquestGreen : Palette.silentDuty
                )
            }

            // Status
            Text(statusLabel)
                .font(Signal.intel(13))
                .foregroundColor(
                    isMissionComplete ? Palette.conquestGreen : Palette.silentDuty
                )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Grid.base)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Shield.medium)
                .stroke(
                    isMissionComplete
                        ? Palette.conquestGreen.opacity(0.4)
                        : Color.clear,
                    lineWidth: 1.5
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                ringAnimated = true
            }
        }
        .onChange(of: progressFraction) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                ringAnimated = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.6)) {
                    ringAnimated = true
                }
            }
        }
    }
}

struct MissionMetric: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: Grid.micro) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(value)
                .font(Signal.intel(13))
        }
        .foregroundColor(color)
    }
}

// MARK: - Pressure Badge

struct PressureBadge: View {
    let label: String
    let icon: String
    let color: Color
    let tooManyStops: Bool
    let stopsCount: Int
    let maxRecommended: Int
    let onDetailsTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onDetailsTap) {
            VStack(spacing: Grid.small) {
                HStack(spacing: Grid.small) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(color)
                        .scaleEffect(pulse ? 1.15 : 1.0)

                    Text(label)
                        .font(Signal.briefing(14))
                        .foregroundColor(color)

                    Spacer()

                    Text("Details")
                        .font(Signal.whisper())
                        .foregroundColor(Palette.secondaryLabel)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(Palette.secondaryLabel)
                }

                if tooManyStops {
                    HStack(spacing: Grid.micro) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 11))
                        Text("\(stopsCount) stops — recommended max \(maxRecommended)")
                            .font(Signal.whisper())
                    }
                    .foregroundColor(Palette.urgencyAmber)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Grid.medium)
            .background(color.opacity(0.1))
            .cornerRadius(Shield.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Shield.medium)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            if color == Palette.overloadCrimson {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

// MARK: - Time Block Card

struct TimeBlockCard: View {
    let totalMinutes: Int

    var body: some View {
        HStack(spacing: Grid.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: Shield.small)
                    .fill(Palette.momentumGlow.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Palette.momentumGlow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Planned time")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.secondaryLabel)
                Text(totalMinutes >= 60
                     ? "\(totalMinutes / 60)h \(totalMinutes % 60)m"
                     : "\(totalMinutes)m")
                    .font(Signal.dispatch(18))
                    .foregroundColor(Palette.frostCommand)
            }

            Spacer()
        }
        .padding(Grid.medium)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

// MARK: - Gamification Bar

struct GamificationBar: View {
    let badge: String
    let rankTitle: String
    let streak: Int
    let pointsToday: Int
    let progress: Double
    let progressLabel: String

    var body: some View {
        HStack(spacing: Grid.medium) {
            // Rank badge
            Text(badge)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: Grid.micro) {
                HStack(spacing: Grid.small) {
                    Text(rankTitle)
                        .font(Signal.briefing(14))
                        .foregroundColor(Palette.ambitionGold)

                    if streak > 0 {
                        Text("🔥 \(streak)")
                            .font(Signal.whisper())
                            .foregroundColor(Palette.conquestGreen)
                    }

                    Spacer()

                    if pointsToday > 0 {
                        Text("+\(pointsToday) XP")
                            .font(Signal.mono(12))
                            .foregroundColor(Palette.momentumGlow)
                    }
                }

                // XP progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Palette.dormantGray)
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
                .frame(height: 4)

                Text(progressLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.secondaryLabel)
            }
        }
        .padding(Grid.medium)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

// MARK: - Today Action Strip

struct TodayActionStrip: View {
    let onAddFromCatalog: () -> Void
    let onQuickAdd: () -> Void
    let hasAvailablePlaces: Bool

    var body: some View {
        HStack(spacing: Grid.medium) {
            if hasAvailablePlaces {
                ActionPill(
                    icon: "tray.and.arrow.down.fill",
                    label: "From Catalog",
                    color: Palette.ambitionGold,
                    action: onAddFromCatalog
                )
            }

            ActionPill(
                icon: "bolt.circle.fill",
                label: "Quick Add",
                color: Palette.conquestGreen,
                action: onQuickAdd
            )
        }
    }
}

// MARK: - Deployment Queue List

struct DeploymentQueueList: View {
    let stops: [DeploymentStop]
    let isMissionComplete: Bool
    let onToggle: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onReorder: (IndexSet, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.small) {
            HStack {
                Text("VISIT ORDER")
                    .font(Signal.whisper())
                    .foregroundColor(Palette.silentDuty)
                    .tracking(1.2)
                Spacer()
                Text("Hold & drag to reorder")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.secondaryLabel)
            }

            List {
                ForEach(stops) { stop in
                    DeploymentStopRow(
                        stop: stop,
                        index: (stops.firstIndex(where: { $0.id == stop.id }) ?? 0) + 1,
                        isMissionComplete: isMissionComplete,
                        onToggle: { onToggle(stop.id) }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive, action: { onDelete(stop.id) }) {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .onMove { from, to in
                    onReorder(from, to)
                }
            }
            .listStyle(.plain)
            .modifier(ListScrollContentBackgroundHiddenModifier())
            .environment(\.editMode, .constant(.active))
            .frame(minHeight: CGFloat(stops.count) * 72)
        }
    }
}

// MARK: - Deployment Stop Row

struct DeploymentStopRow: View {
    let stop: DeploymentStop
    let index: Int
    let isMissionComplete: Bool
    let onToggle: () -> Void

    @State private var checkScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: Grid.medium) {
            // Order number
            Text("\(index)")
                .font(Signal.mono(12))
                .foregroundColor(Palette.dormantGray)
                .frame(width: 20)

            // Checkbox
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    checkScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        checkScale = 1.0
                    }
                }
                onToggle()
            }) {
                ZStack {
                    Circle()
                        .stroke(
                            stop.isAccomplished
                                ? Palette.conquestGreen
                                : Palette.dormantGray,
                            lineWidth: 2
                        )
                        .frame(width: 26, height: 26)

                    if stop.isAccomplished {
                        Circle()
                            .fill(Palette.conquestGreen)
                            .frame(width: 26, height: 26)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Palette.deepOpsBase)
                    }
                }
                .scaleEffect(checkScale)
            }

            // Stop info
            VStack(alignment: .leading, spacing: Grid.micro) {
                Text(stop.title)
                    .font(Signal.briefing(15))
                    .foregroundColor(
                        stop.isAccomplished
                            ? Palette.dormantGray
                            : Palette.frostCommand
                    )
                    .strikethrough(stop.isAccomplished, color: Palette.dormantGray)
                    .lineLimit(1)

                HStack(spacing: Grid.small) {
                    Image(systemName: stop.tag.iconGlyph)
                        .font(.system(size: 10))
                    Text(stop.tag.callSign)
                        .font(Signal.whisper())
                    Text("•")
                    Text("\(stop.loadMin)m")
                        .font(Signal.whisper())
                }
                .foregroundColor(Palette.dormantGray)
            }

            Spacer()

            // XP indicator on accomplished
            if stop.isAccomplished {
                Text("+10 XP")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.momentumGlow)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, Grid.small)
        .padding(.horizontal, Grid.medium)
        .background(
            RoundedRectangle(cornerRadius: Shield.small)
                .fill(
                    stop.isAccomplished
                        ? Palette.tacticalSurface.opacity(0.5)
                        : Palette.tacticalSurface
                )
        )
        .opacity(stop.isAccomplished ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: stop.isAccomplished)
    }
}

// MARK: - No Mission Placeholder

struct NoMissionPlaceholder: View {
    let onPickZone: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(spacing: Grid.large) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Palette.ambitionGold.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulse ? 1.15 : 1.0)

                Image(systemName: "flag.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Palette.ambitionGold.opacity(0.5))
            }

            VStack(spacing: Grid.medium) {
                Text("No Mission Today")
                    .font(Signal.headline(26))
                    .foregroundColor(Palette.frostCommand)

                Text("Pick a zone to start planning\nyour day by area")
                    .font(Signal.intel(16))
                    .foregroundColor(Palette.silentDuty)
                    .multilineTextAlignment(.center)

                Text("One zone per day — focus wins")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Palette.secondaryLabel)
            }

            Button(action: onPickZone) {
                HStack {
                    Image(systemName: "scope")
                    Text("Pick a Zone")
                }
            }
            .buttonStyle(GoldActionButton())

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Empty Queue Prompt

struct EmptyQueuePrompt: View {
    let onAdd: () -> Void

    @State private var bounce = false

    var body: some View {
        VStack(spacing: Grid.large) {
            ZStack {
                Circle()
                    .fill(Palette.ambitionGold.opacity(0.08))
                    .frame(width: 80, height: 80)
                    .scaleEffect(bounce ? 1.1 : 1.0)
                Image(systemName: "tray.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Palette.ambitionGold.opacity(0.6))
            }

            VStack(spacing: Grid.small) {
                Text("Queue is empty")
                    .font(Signal.dispatch(18))
                    .foregroundColor(Palette.frostCommand)

                Text("Add stops from the zone catalog\nor create them on the fly")
                    .font(Signal.intel(14))
                    .foregroundColor(Palette.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Stops")
                }
            }
            .buttonStyle(GoldActionButton())
        }
        .padding(Grid.large)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
}

// MARK: - Pressure Breakdown Placeholder

struct PressureBreakdownPlaceholder: View {
    let dayId: UUID

    var body: some View {
        ZStack {
            Palette.deepOpsBase.ignoresSafeArea()
            Text("Pressure details — integrated in day editor sheet")
                .foregroundColor(Palette.silentDuty)
        }
        .navigationTitle("Pressure")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#if DEBUG
struct TodayMissionView_Previews: PreviewProvider {
    static var previews: some View {
        let router = MissionRouter()
        let interactor = TodayMissionInteractor()
        let presenter = TodayMissionPresenter(interactor: interactor, router: router)
        TodayMissionView(presenter: presenter)
            .environmentObject(router)
            .preferredColorScheme(.dark)
    }
}
#endif
