// ZoneDetailView.swift
// c11 — Zone-based day planner with gamification
// VIPER View — zone's place catalog screen

import SwiftUI

// MARK: - Zone Detail View

struct ZoneDetailView: View {

    @ObservedObject var presenter: ZoneDetailPresenter
    @EnvironmentObject var router: MissionRouter

    @State private var headerVisible = false
    @State private var listAppeared = false

    var body: some View {
        ZStack {
            Palette.deepOpsBase
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Grid.large) {

                    // ── Stats header ─────────────────────────────
                    ZoneStatsHeader(
                        icon: presenter.zoneIcon,
                        stats: presenter.stats,
                        durationLabel: presenter.totalDurationLabel,
                        isToday: presenter.isZoneToday
                    )
                    .padding(.horizontal, Grid.base)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : -10)

                    // ── Action strip ─────────────────────────────
                    ZoneActionStrip(
                        isToday: presenter.isZoneToday,
                        onAddPlace: { presenter.handleOpenAddPlace() },
                        onBuildDay: { presenter.handleBuildDay() },
                        onGoToToday: { presenter.handleJumpToToday() }
                    )
                    .padding(.horizontal, Grid.base)

                    // ── Search + Tag filter ──────────────────────
                    VStack(spacing: Grid.medium) {
                        FieldSearchBar(
                            query: $presenter.searchQuery,
                            placeholder: "Search stops…"
                        )

                        TagFilterStrip(
                            activeTag: presenter.activeTagFilter,
                            onSelect: { presenter.handleSetTagFilter($0) }
                        )
                    }
                    .padding(.horizontal, Grid.base)

                    // ── Places list ──────────────────────────────
                    if presenter.isEmptyState {
                        EmptyPlacesPlaceholder(
                            onAddTapped: { presenter.handleOpenAddPlace() }
                        )
                        .padding(.top, Grid.huge)
                    } else if presenter.isFilteredEmpty {
                        FilteredEmptyState()
                            .padding(.top, Grid.huge)
                    } else {
                        // Favorites section
                        if !presenter.favoritePlaces.isEmpty {
                            PlaceSection(
                                title: "⭐ Favorites",
                                places: presenter.favoritePlaces,
                                presenter: presenter,
                                startDelay: 0
                            )
                            .opacity(listAppeared ? 1 : 0)
                        }

                        // All places section
                        if !presenter.regularPlaces.isEmpty {
                            PlaceSection(
                                title: "All Stops",
                                places: presenter.regularPlaces,
                                presenter: presenter,
                                startDelay: Double(presenter.favoritePlaces.count) * 0.04
                            )
                            .opacity(listAppeared ? 1 : 0)
                        }
                    }

                    // ── Blueprints section ───────────────────────
                    if !presenter.blueprints.isEmpty {
                        BlueprintSection(
                            blueprints: presenter.blueprints,
                            onDelete: { presenter.handleDeleteBlueprint(bpId: $0) }
                        )
                        .padding(.horizontal, Grid.base)
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.top, Grid.small)
            }

            // ── FAB — Add Place ──────────────────────────────────
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { presenter.handleOpenAddPlace() }) {
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
        .navigationTitle(presenter.zoneTitle)
        .navigationBarTitleDisplayMode(.large)
        .modifier(ToolbarColorSchemeModifier())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { presenter.handleOpenAddPlace() }) {
                        Label("New Stop", systemImage: "plus.circle")
                    }
                    Button(action: { presenter.handleBuildDay() }) {
                        Label("Build Day Here", systemImage: "flag.fill")
                    }
                    if !presenter.filteredPlaces.isEmpty {
                        Button(action: { promptCreateBlueprint() }) {
                            Label("Save as Blueprint", systemImage: "doc.on.doc")
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
            headerVisible = true
            listAppeared = true
        }
    }

    private func promptCreateBlueprint() {
        presenter.handleCreateBlueprint(title: "Route \(presenter.blueprints.count + 1)")
    }
}

// MARK: - Zone Stats Header

private let knownZoneIcons: Set<String> = [
    "mappin.circle.fill", "building.2.fill", "house.fill", "building.columns.fill",
    "storefront.fill", "tent.fill", "cart.fill", "briefcase.fill", "graduationcap.fill",
    "cross.case.fill", "dumbbell.fill", "fork.knife", "leaf.fill", "sun.max.fill",
    "tree.fill", "mountain.2.fill", "water.waves", "cloud.fill", "star.fill",
    "bolt.fill", "heart.fill", "flag.fill", "bookmark.fill", "target",
    "shippingbox.fill", "wrench.fill"
]

struct ZoneStatsHeader: View {
    let icon: String
    let stats: ZoneStats
    let durationLabel: String
    let isToday: Bool

    private var safeIcon: String {
        knownZoneIcons.contains(icon) ? icon : "mappin.circle.fill"
    }

    var body: some View {
        VStack(spacing: Grid.medium) {
            // Icon + today badge
            HStack(spacing: Grid.medium) {
                ZStack {
                    Circle()
                        .fill(isToday ? Palette.ambitionGold : Palette.elevatedBunker)
                        .frame(width: 52, height: 52)

                    Image(systemName: safeIcon)
                        .font(.system(size: 24))
                        .foregroundColor(isToday ? Palette.deepOpsBase : Palette.ambitionGold)
                }

                VStack(alignment: .leading, spacing: Grid.micro) {
                    if isToday {
                        Text("TODAY'S ZONE")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(Palette.ambitionGold)
                            .tracking(1)
                    }
                    Text(durationLabel)
                        .font(Signal.intel(13))
                        .foregroundColor(Palette.silentDuty)
                }

                Spacer()
            }

            // Stats chips row
            HStack(spacing: Grid.small) {
                StatMiniChip(value: "\(stats.totalPlaces)", label: "stops", icon: "mappin")
                StatMiniChip(value: "\(stats.favoritePlaces)", label: "favs", icon: "star.fill")
                StatMiniChip(value: "\(stats.blueprintCount)", label: "routes", icon: "doc.on.doc")
                StatMiniChip(value: "\(stats.timesDeployed)", label: "deployed", icon: "flag.fill")
            }
        }
        .padding(Grid.base)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
    }
}

struct StatMiniChip: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: Grid.micro) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(Palette.ambitionGold)
            Text(value)
                .font(Signal.briefing(14))
                .foregroundColor(Palette.frostCommand)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Palette.silentDuty)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Grid.small)
        .background(Palette.elevatedBunker)
        .cornerRadius(Shield.small)
    }
}

// MARK: - Zone Action Strip

struct ZoneActionStrip: View {
    let isToday: Bool
    let onAddPlace: () -> Void
    let onBuildDay: () -> Void
    let onGoToToday: () -> Void

    var body: some View {
        HStack(spacing: Grid.medium) {
            ActionPill(
                icon: "plus.circle.fill",
                label: "Add Stop",
                color: Palette.ambitionGold,
                action: onAddPlace
            )

            if isToday {
                ActionPill(
                    icon: "flag.fill",
                    label: "Go to Today",
                    color: Palette.conquestGreen,
                    action: onGoToToday
                )
            } else {
                ActionPill(
                    icon: "calendar.badge.plus",
                    label: "Build Day",
                    color: Palette.conquestGreen,
                    action: onBuildDay
                )
            }
        }
    }
}

struct ActionPill: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Grid.small) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(Signal.briefing(13))
            }
            .foregroundColor(Palette.deepOpsBase)
            .padding(.horizontal, Grid.medium)
            .padding(.vertical, Grid.small + 2)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(Shield.pill)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Filter Strip

struct TagFilterStrip: View {
    let activeTag: ErrandTag?
    let onSelect: (ErrandTag) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Grid.small) {
                ForEach(ErrandTag.allCases) { tag in
                    Button(action: { onSelect(tag) }) {
                        HStack(spacing: Grid.micro) {
                            Image(systemName: tag.iconGlyph)
                                .font(.system(size: 11))
                            Text(tag.callSign)
                                .font(Signal.whisper())
                        }
                        .foregroundColor(
                            activeTag == tag ? Palette.deepOpsBase : Palette.silentDuty
                        )
                        .padding(.horizontal, Grid.medium)
                        .padding(.vertical, Grid.small)
                        .background(
                            activeTag == tag ? Palette.ambitionGold : Palette.elevatedBunker
                        )
                        .cornerRadius(Shield.pill)
                    }
                }
            }
        }
    }
}

// MARK: - Place Section

struct PlaceSection: View {
    let title: String
    let places: [GroundPoint]
    let presenter: ZoneDetailPresenter
    let startDelay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.medium) {
            Text(title)
                .font(Signal.briefing(14))
                .foregroundColor(Palette.silentDuty)
                .padding(.horizontal, Grid.large)

            LazyVStack(spacing: Grid.small) {
                ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                    GroundPointCard(
                        point: place,
                        isDeployedToday: presenter.isDeployedToday(pointId: place.id),
                        isZoneToday: presenter.isZoneToday,
                        onTap: { presenter.handleOpenEditPlace(pointId: place.id) },
                        onFavorite: { presenter.handleToggleFavorite(pointId: place.id) },
                        onDeployToday: { presenter.handleDeployToToday(point: place) },
                        onDelete: { presenter.handleDeletePlace(pointId: place.id) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, Grid.base)
        }
    }
}

// MARK: - Ground Point Card

struct GroundPointCard: View {
    let point: GroundPoint
    let isDeployedToday: Bool
    let isZoneToday: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onDeployToday: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Grid.medium) {
                // Tag icon
                ZStack {
                    RoundedRectangle(cornerRadius: Shield.small)
                        .fill(Palette.elevatedBunker)
                        .frame(width: 40, height: 40)

                    Image(systemName: point.tag.iconGlyph)
                        .font(.system(size: 17))
                        .foregroundColor(tagColor(point.tag))
                }

                // Info
                VStack(alignment: .leading, spacing: Grid.micro) {
                    HStack(spacing: Grid.small) {
                        Text(point.title)
                            .font(Signal.briefing(15))
                            .foregroundColor(Palette.frostCommand)
                            .lineLimit(1)

                        if point.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Palette.badgeShimmer)
                        }

                        if isDeployedToday {
                            Text("TODAY")
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .foregroundColor(Palette.deepOpsBase)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Palette.conquestGreen)
                                .cornerRadius(Shield.pill)
                        }
                    }

                    HStack(spacing: Grid.medium) {
                        Label("\(point.durationMin)m", systemImage: "clock")
                            .font(Signal.whisper())
                            .foregroundColor(Palette.silentDuty)

                        if point.bufferMin > 0 {
                            Label("+\(point.bufferMin)m", systemImage: "pause.circle")
                                .font(Signal.whisper())
                                .foregroundColor(Palette.dormantGray)
                        }

                        Text(point.tag.callSign)
                            .font(Signal.whisper())
                            .foregroundColor(Palette.dormantGray)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Palette.dormantGray)
            }
            .padding(Grid.medium)
            .background(Palette.tacticalSurface)
            .cornerRadius(Shield.medium)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onDeployToday) {
                Label(
                    isDeployedToday ? "Already in Today" : "Add to Today",
                    systemImage: "flag.badge.ellipsis"
                )
            }
            .disabled(isDeployedToday || !isZoneToday)

            Button(action: onFavorite) {
                Label(
                    point.isFavorite ? "Remove Favorite" : "Add to Favorites",
                    systemImage: point.isFavorite ? "star.slash" : "star.fill"
                )
            }

            Button(action: onTap) {
                Label("Edit Stop", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete Stop", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onFavorite) {
                Label(
                    point.isFavorite ? "Unfav" : "Fav",
                    systemImage: point.isFavorite ? "star.slash" : "star.fill"
                )
            }
            .tint(Palette.badgeShimmer)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if isZoneToday && !isDeployedToday {
                Button(action: onDeployToday) {
                    Label("Today", systemImage: "flag.fill")
                }
                .tint(Palette.conquestGreen)
            }
        }
    }

    private func tagColor(_ tag: ErrandTag) -> Color {
        switch tag {
        case .food:     return Palette.ambitionGold
        case .services: return Palette.conquestGreen
        case .shopping: return Palette.momentumGlow
        case .errands:  return Palette.urgencyAmber
        case .meeting:  return Palette.levelUpFlash
        case .other:    return Palette.silentDuty
        }
    }
}

// MARK: - Blueprint Section

struct BlueprintSection: View {
    let blueprints: [RouteBlueprint]
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.medium) {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.ambitionGold)
                Text("Route Blueprints")
                    .font(Signal.briefing(14))
                    .foregroundColor(Palette.silentDuty)
            }

            ForEach(blueprints) { bp in
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.momentumGlow)

                    Text(bp.title)
                        .font(Signal.intel(14))
                        .foregroundColor(Palette.frostCommand)

                    Spacer()

                    Text("\(bp.orderedPointIds.count) stops")
                        .font(Signal.whisper())
                        .foregroundColor(Palette.dormantGray)

                    Button(action: { onDelete(bp.id) }) {
                        Image(systemName: "trash.circle")
                            .font(.system(size: 16))
                            .foregroundColor(Palette.dormantGray)
                    }
                }
                .padding(Grid.medium)
                .background(Palette.tacticalSurface)
                .cornerRadius(Shield.small)
            }
        }
    }
}

// MARK: - Empty States

struct EmptyPlacesPlaceholder: View {
    let onAddTapped: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(spacing: Grid.large) {
            ZStack {
                Circle()
                    .fill(Palette.ambitionGold.opacity(0.08))
                    .frame(width: 110, height: 110)
                    .scaleEffect(pulse ? 1.12 : 1.0)

                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 40))
                    .foregroundColor(Palette.ambitionGold.opacity(0.5))
            }

            VStack(spacing: Grid.small) {
                Text("No Stops Yet")
                    .font(Signal.dispatch(18))
                    .foregroundColor(Palette.frostCommand)

                Text("Add places you visit in this zone —\ncoffee shops, errands, meetings…")
                    .font(Signal.intel(14))
                    .foregroundColor(Palette.silentDuty)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAddTapped) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Deploy First Stop")
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

struct FilteredEmptyState: View {
    var body: some View {
        VStack(spacing: Grid.medium) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(Palette.dormantGray)

            Text("No matches found")
                .font(Signal.briefing(16))
                .foregroundColor(Palette.silentDuty)

            Text("Try a different search or clear filters")
                .font(Signal.intel(13))
                .foregroundColor(Palette.dormantGray)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ZoneDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let router = MissionRouter()
        let interactor = ZoneDetailInteractor()
        let presenter = ZoneDetailPresenter(
            zoneId: UUID(),
            interactor: interactor,
            router: router
        )
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    ZoneDetailView(presenter: presenter)
                        .environmentObject(router)
                }
            } else {
                NavigationView {
                    ZoneDetailView(presenter: presenter)
                        .environmentObject(router)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
