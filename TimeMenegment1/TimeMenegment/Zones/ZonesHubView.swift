// ZonesHubView.swift
// c11 — Zone-based day planner with gamification
// VIPER View — Zones tab main screen

import SwiftUI

// MARK: - Zones Hub View

struct ZonesHubView: View {

    @ObservedObject var presenter: ZonesHubPresenter
    @EnvironmentObject var router: MissionRouter

    @State private var headerVisible = false
    @State private var cardsAppeared = false
    @State private var isReorderMode = false

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack(path: $router.zonesPath) {
                    zonesContent
                }
                .navigationDestination(for: Waypoint.self) { waypoint in
                    switch waypoint {
                    case .zoneDetail(let zoneId):
                        ZoneDetailPlaceholder.makeReal(zoneId: zoneId, router: router)
                    default:
                        EmptyView()
                    }
                }
            } else {
                NavigationView {
                    zonesContent
                }
            }
        }
    }

    private var zonesContent: some View {
        ZStack {
                Palette.deepOpsBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Grid.large) {

                        // ── Rank & Streak banner ─────────────────
                        OperatorBadgeBanner(
                            rankLabel: presenter.rankLabel,
                            streakLabel: presenter.streakLabel
                        )
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : -10)

                        // ── Today quick-card ─────────────────────
                        if presenter.hasTodayZone {
                            TodayQuickCard(
                                subtitle: presenter.todaySubtitle,
                                progress: presenter.overview.todayProgress,
                                onTap: { presenter.handleJumpToToday() }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }

                        // ── Search bar ───────────────────────────
                        FieldSearchBar(
                            query: $presenter.searchQuery,
                            placeholder: "Search zones…"
                        )
                        .padding(.horizontal, Grid.base)

                        // ── Stats summary card ───────────────────
                        ZonesStatsCard(
                            totalZones: presenter.overview.totalZones,
                            totalPlaces: presenter.overview.totalPlaces,
                            todayProgress: presenter.overview.todayProgress,
                            todayStopsDone: presenter.overview.todayStopsDone,
                            todayStopsTotal: presenter.overview.todayStopsTotal
                        )
                        .padding(.horizontal, Grid.base)

                        // ── Zone cards list ──────────────────────
                        if presenter.activeZones.isEmpty {
                            EmptyZonesPlaceholder(
                                onCreateTapped: { presenter.handleOpenAddZone() }
                            )
                            .padding(.top, Grid.epic)
                        } else {
                            VStack(alignment: .leading, spacing: Grid.small) {
                                HStack {
                                    Text("Your zones")
                                        .font(Signal.briefing(15))
                                        .foregroundColor(Palette.silentDuty)
                                    Spacer()
                                    Button(action: { isReorderMode.toggle() }) {
                                        Text(isReorderMode ? "Done" : "Reorder")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Palette.ambitionGold)
                                    }
                                }
                                .padding(.horizontal, Grid.base)

                                List {
                                    ForEach(Array(presenter.activeZones.enumerated()), id: \.element.id) { index, zone in
                                        zoneCard(for: zone, at: index)
                                            .listRowBackground(Color.clear)
                                            .listRowInsets(EdgeInsets(top: 4, leading: Grid.base, bottom: 4, trailing: Grid.base))
                                            .listRowSeparator(.hidden)
                                    }
                                    .onMove { from, to in
                                        presenter.handleReorderZones(fromOffsets: from, toOffset: to)
                                    }
                                }
                                .listStyle(.plain)
                                .modifier(ScrollContentBackgroundHiddenModifier())
                                .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
                                .frame(minHeight: CGFloat(presenter.activeZones.count) * 88)
                            }
                            .padding(.horizontal, 0)
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.top, Grid.base)
                }

                // ── FAB — Add Zone ───────────────────────────────
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { presenter.handleOpenAddZone() }) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Palette.deepOpsBase)
                                .frame(width: 56, height: 56)
                                .background(Palette.ambitionGold)
                                .clipShape(Circle())
                                .shadow(color: Palette.ambitionGold.opacity(0.4), radius: 10, y: 4)
                        }
                        .padding(.trailing, Grid.large)
                        .padding(.bottom, Grid.large)
                    }
                }
            }
            .navigationTitle("Zones")
            .navigationBarTitleDisplayMode(.large)
            .modifier(ToolbarColorSchemeModifier())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { presenter.handleOpenAddZone() }) {
                            Label("New Zone", systemImage: "plus.circle")
                        }
                        if presenter.hasTodayZone {
                            Button(action: { presenter.handleJumpToToday() }) {
                                Label("Go to Today", systemImage: "flag.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Palette.ambitionGold)
                    }
                }
            }
            .onAppear {
                presenter.onAppear()
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    headerVisible = true
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.25)) {
                    cardsAppeared = true
                }
            }
    }

    @ViewBuilder
    private func zoneCard(for zone: OperationsZone, at index: Int) -> some View {
        let card = ZoneCard(
            zone: zone,
            placesCount: presenter.placesCount(for: zone),
            isTodayZone: presenter.isTodayZone(zone),
            lastDeployed: presenter.lastDeployedLabel(for: zone),
            onTap: { presenter.handleOpenZone(zoneId: zone.id) },
            onAssignToday: { presenter.handleAssignToday(zoneId: zone.id) },
            onPin: { presenter.handleTogglePin(zoneId: zone.id) },
            onArchive: { presenter.handleToggleArchive(zoneId: zone.id) },
            onDelete: { presenter.handleRequestDelete(zoneId: zone.id) },
            isNavigationTarget: true
        )
        .opacity(cardsAppeared ? 1 : 0)
        .offset(y: cardsAppeared ? 0 : 20)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.75)
                .delay(Double(index) * 0.06),
            value: cardsAppeared
        )

        if #available(iOS 16.0, *) {
            NavigationLink(value: Waypoint.zoneDetail(zoneId: zone.id)) {
                card
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(destination: ZoneDetailPlaceholder.makeReal(zoneId: zone.id, router: router)) {
                card
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Zones Stats Card

struct ZonesStatsCard: View {
    let totalZones: Int
    let totalPlaces: Int
    let todayProgress: Double
    let todayStopsDone: Int
    let todayStopsTotal: Int

    var body: some View {
        HStack(spacing: Grid.large) {
            // Zones & Places
            VStack(spacing: Grid.micro) {
                HStack(spacing: Grid.micro) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Palette.ambitionGold)
                    Text("\(totalZones)")
                        .font(Signal.dispatch(18))
                        .foregroundColor(Palette.frostCommand)
                }
                Text("zones")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.secondaryLabel)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Palette.gridLine)
                .frame(width: 1, height: 36)

            VStack(spacing: Grid.micro) {
                HStack(spacing: Grid.micro) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Palette.conquestGreen)
                    Text("\(totalPlaces)")
                        .font(Signal.dispatch(18))
                        .foregroundColor(Palette.frostCommand)
                }
                Text("stops")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.secondaryLabel)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Palette.gridLine)
                .frame(width: 1, height: 36)

            // Today progress
            VStack(spacing: Grid.micro) {
                ZStack {
                    Circle()
                        .stroke(Palette.dormantGray, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: CGFloat(todayProgress))
                        .stroke(Palette.conquestGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    Text("\(todayStopsDone)/\(todayStopsTotal)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.frostCommand)
                }
                Text("today")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.secondaryLabel)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Grid.medium)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

// MARK: - Operator Badge Banner

struct OperatorBadgeBanner: View {
    let rankLabel: String
    let streakLabel: String

    var body: some View {
        HStack(spacing: Grid.medium) {
            Text(rankLabel)
                .font(Signal.briefing(14))
                .foregroundColor(Palette.ambitionGold)

            if !streakLabel.isEmpty {
                Text("•")
                    .foregroundColor(Palette.secondaryLabel)
                Text(streakLabel)
                    .font(Signal.briefing(14))
                    .foregroundColor(Palette.conquestGreen)
            }

            Spacer()
        }
        .padding(.horizontal, Grid.large)
    }
}

// MARK: - Today Quick Card

struct TodayQuickCard: View {
    let subtitle: String
    let progress: Double
    let onTap: () -> Void

    @State private var shimmer = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Grid.medium) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Palette.ambitionGold.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: "flag.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Palette.ambitionGold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Mission")
                            .font(Signal.dispatch(18))
                            .foregroundColor(Palette.frostCommand)
                        Text(subtitle)
                            .font(Signal.intel(14))
                            .foregroundColor(Palette.silentDuty)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Palette.secondaryLabel)
                }

                // Progress bar with label
                VStack(alignment: .leading, spacing: Grid.micro) {
                    HStack {
                        Text(progress >= 1 ? "Complete!" : "\(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(progress >= 1 ? Palette.conquestGreen : Palette.ambitionGold)
                        Spacer()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Palette.dormantGray)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Palette.ambitionGold, Palette.conquestGreen],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(progress))
                                .animation(.easeInOut(duration: 0.6), value: progress)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(Grid.base)
            .background(
                RoundedRectangle(cornerRadius: Shield.medium)
                    .fill(Palette.tacticalSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Shield.medium)
                            .stroke(Palette.ambitionGold.opacity(0.4), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, Grid.base)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Zone Card

struct ZoneCard: View {
    let zone: OperationsZone
    let placesCount: Int
    let isTodayZone: Bool
    let lastDeployed: String?
    let onTap: () -> Void
    let onAssignToday: () -> Void
    let onPin: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    var isNavigationTarget: Bool = false

    private var cardContent: some View {
        HStack(spacing: Grid.medium) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: Shield.small)
                        .fill(isTodayZone ? Palette.ambitionGold : Palette.elevatedBunker)
                        .frame(width: 44, height: 44)

                    Image(systemName: zone.iconSymbol)
                        .font(.system(size: 20))
                        .foregroundColor(
                            isTodayZone ? Palette.deepOpsBase : Palette.silentDuty
                        )
                }

                // Info
                VStack(alignment: .leading, spacing: Grid.micro) {
                    HStack(spacing: Grid.small) {
                        Text(zone.title)
                            .font(Signal.briefing(16))
                            .foregroundColor(Palette.frostCommand)
                            .lineLimit(1)

                        if zone.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Palette.ambitionGold)
                        }

                        if isTodayZone {
                            Text("TODAY")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundColor(Palette.deepOpsBase)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Palette.ambitionGold)
                                .cornerRadius(Shield.pill)
                        }
                    }

                    HStack(spacing: Grid.medium) {
                        Label("\(placesCount)", systemImage: "mappin")
                            .font(Signal.whisper())
                            .foregroundColor(Palette.silentDuty)

                        if let last = lastDeployed {
                            Label(last, systemImage: "clock")
                                .font(Signal.whisper())
                                .foregroundColor(Palette.silentDuty)
                        }
                    }
                }

                Spacer()

                if !isTodayZone {
                    Button(action: onAssignToday) {
                        Text("Today")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Palette.ambitionGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Palette.ambitionGold.opacity(0.2))
                            .cornerRadius(Shield.pill)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Grid.medium)
            .background(Palette.tacticalSurface)
            .cornerRadius(Shield.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Shield.medium)
                    .stroke(
                        isTodayZone
                            ? Palette.ambitionGold.opacity(0.4)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
    }

    var body: some View {
        Group {
            if isNavigationTarget {
                cardContent
            } else {
                Button(action: onTap) {
                    cardContent
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            Button(action: onAssignToday) {
                Label(
                    isTodayZone ? "Already Today's Zone" : "Set as Today's Zone",
                    systemImage: "flag.fill"
                )
            }
            .buttonStyle(.borderless)
            .disabled(isTodayZone)

            Button(action: onPin) {
                Label(
                    zone.isPinned ? "Unpin" : "Pin to Top",
                    systemImage: zone.isPinned ? "pin.slash" : "pin.fill"
                )
            }

            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete Zone", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(Palette.dormantGray)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onAssignToday) {
                Label("Today", systemImage: "flag.fill")
            }
            .tint(Palette.ambitionGold)
        }
    }
}

// MARK: - Empty State Placeholder

struct EmptyZonesPlaceholder: View {
    let onCreateTapped: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(spacing: Grid.large) {
            ZStack {
                Circle()
                    .fill(Palette.ambitionGold.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulse ? 1.15 : 1.0)

                Image(systemName: "map.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Palette.ambitionGold.opacity(0.6))
            }

            VStack(spacing: Grid.small) {
                Text("No Zones Yet")
                    .font(Signal.dispatch(20))
                    .foregroundColor(Palette.frostCommand)

                Text("Create your first zone to start\nplanning your day by area")
                    .font(Signal.intel(14))
                    .foregroundColor(Palette.silentDuty)
                    .multilineTextAlignment(.center)
            }

            Button(action: onCreateTapped) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Deploy First Zone")
                }
            }
            .buttonStyle(GoldActionButton())
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Search Bar

struct FieldSearchBar: View {
    @Binding var query: String
    var placeholder: String = "Search…"

    var body: some View {
        HStack(spacing: Grid.small) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(Palette.silentDuty)

            TextField(placeholder, text: $query)
                .font(Signal.intel(15))
                .foregroundColor(Palette.frostCommand)
                .accentColor(Palette.ambitionGold)

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Palette.silentDuty)
                }
            }
        }
        .padding(.horizontal, Grid.medium)
        .padding(.vertical, Grid.small + 2)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

// MARK: - Zone Detail Placeholder (will be replaced by full ZoneDetailView)

struct ZoneDetailPlaceholder: View {
    let zoneId: UUID

    var body: some View {
        ZStack {
            Palette.deepOpsBase.ignoresSafeArea()
            Text("Zone Detail — coming next")
                .foregroundColor(Palette.silentDuty)
        }
        .navigationTitle("Zone")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#if DEBUG
struct ZonesHubView_Previews: PreviewProvider {
    static var previews: some View {
        let router = MissionRouter()
        let interactor = ZonesHubInteractor()
        let presenter = ZonesHubPresenter(interactor: interactor, router: router)
        ZonesHubView(presenter: presenter)
            .environmentObject(router)
            .preferredColorScheme(.dark)
    }
}
#endif
