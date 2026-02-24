// AddZoneSheet.swift
// c11 — Zone-based day planner with gamification
// Modal sheet for creating and editing zones

import SwiftUI

// MARK: - Mode

enum ZoneFormMode {
    case create
    case edit(zoneId: UUID)

    var navigationTitle: String {
        switch self {
        case .create: return "Deploy New Zone"
        case .edit:   return "Edit Zone"
        }
    }

    var commitLabel: String {
        switch self {
        case .create: return "Deploy Zone"
        case .edit:   return "Save Changes"
        }
    }
}

// MARK: - Add / Edit Zone Sheet

struct AddZoneSheet: View {

    let mode: ZoneFormMode
    let onCommit: (String, String) -> Void
    let onDismiss: () -> Void

    @State private var zoneName: String = ""
    @State private var selectedIcon: String = "mappin.circle.fill"
    @State private var showValidation: Bool = false
    @State private var appearAnimated: Bool = false
    @State private var iconBounce: Bool = false

    // Icon catalog
    private let iconCatalog: [(section: String, icons: [String])] = [
        ("Places", [
            "mappin.circle.fill", "building.2.fill", "house.fill",
            "building.columns.fill", "storefront.fill", "tent.fill"
        ]),
        ("Activity", [
            "cart.fill", "briefcase.fill", "graduationcap.fill",
            "cross.case.fill", "dumbbell.fill", "fork.knife"
        ]),
        ("Nature", [
            "leaf.fill", "sun.max.fill", "tree.fill",
            "mountain.2.fill", "water.waves", "cloud.fill"
        ]),
        ("Symbols", [
            "star.fill", "bolt.fill", "heart.fill",
            "flag.fill", "bookmark.fill", "target"
        ])
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Palette.deepOpsBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Grid.large) {

                        // ── Preview badge ────────────────────────
                        ZonePreviewBadge(
                            name: zoneName.isEmpty ? "Zone Name" : zoneName,
                            icon: selectedIcon,
                            isPlaceholder: zoneName.isEmpty
                        )
                        .padding(.top, Grid.large)
                        .opacity(appearAnimated ? 1 : 0)
                        .scaleEffect(appearAnimated ? 1 : 0.85)

                        // ── Name input ───────────────────────────
                        VStack(alignment: .leading, spacing: Grid.small) {
                            Text("ZONE NAME")
                                .font(Signal.whisper())
                                .foregroundColor(Palette.silentDuty)
                                .tracking(1.2)

                            TextField("e.g. Downtown, Campus, Home Area", text: $zoneName)
                                .font(Signal.briefing(17))
                                .foregroundColor(Palette.frostCommand)
                                .accentColor(Palette.ambitionGold)
                                .padding(Grid.medium)
                                .background(Palette.tacticalSurface)
                                .cornerRadius(Shield.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Shield.small)
                                        .stroke(
                                            showValidation && zoneName.trimmingCharacters(in: .whitespaces).isEmpty
                                                ? Palette.overloadCrimson
                                                : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )

                            if showValidation && zoneName.trimmingCharacters(in: .whitespaces).isEmpty {
                                HStack(spacing: Grid.micro) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 11))
                                    Text("Zone name is required")
                                        .font(Signal.whisper())
                                }
                                .foregroundColor(Palette.overloadCrimson)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, Grid.large)
                        .animation(.easeInOut(duration: 0.2), value: showValidation)

                        // ── Character count ──────────────────────
                        HStack {
                            Spacer()
                            Text("\(zoneName.count)/30")
                                .font(Signal.whisper())
                                .foregroundColor(
                                    zoneName.count > 30
                                        ? Palette.overloadCrimson
                                        : Palette.silentDuty
                                )
                        }
                        .padding(.horizontal, Grid.large)

                        // ── Icon picker ──────────────────────────
                        VStack(alignment: .leading, spacing: Grid.medium) {
                            Text("ZONE ICON")
                                .font(Signal.whisper())
                                .foregroundColor(Palette.silentDuty)
                                .tracking(1.2)
                                .padding(.horizontal, Grid.large)

                            ForEach(iconCatalog, id: \.section) { group in
                                VStack(alignment: .leading, spacing: Grid.small) {
                                    Text(group.section)
                                        .font(Signal.intel(12))
                                        .foregroundColor(Palette.dormantGray)
                                        .padding(.horizontal, Grid.large)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: Grid.medium) {
                                            ForEach(group.icons, id: \.self) { icon in
                                                IconChip(
                                                    icon: icon,
                                                    isSelected: selectedIcon == icon,
                                                    onTap: {
                                                        selectedIcon = icon
                                                        iconBounce = true
                                                        Pulse.light()
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                            iconBounce = false
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.horizontal, Grid.large)
                                    }
                                }
                            }
                        }

                        // ── Quick suggestions ────────────────────
                        VStack(alignment: .leading, spacing: Grid.small) {
                            Text("QUICK IDEAS")
                                .font(Signal.whisper())
                                .foregroundColor(Palette.silentDuty)
                                .tracking(1.2)

                            FlowLayoutCompat(spacing: Grid.small) {
                                ForEach(quickSuggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        zoneName = suggestion
                                        Pulse.light()
                                    }) {
                                        Text(suggestion)
                                            .font(Signal.intel(13))
                                            .foregroundColor(
                                                zoneName == suggestion
                                                    ? Palette.deepOpsBase
                                                    : Palette.silentDuty
                                            )
                                            .padding(.horizontal, Grid.medium)
                                            .padding(.vertical, Grid.small)
                                            .background(
                                                zoneName == suggestion
                                                    ? Palette.ambitionGold
                                                    : Palette.elevatedBunker
                                            )
                                            .cornerRadius(Shield.pill)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Grid.large)

                        Spacer().frame(height: Grid.epic)
                    }
                }
            }
            .navigationTitle(mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundColor(Palette.silentDuty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: commitForm) {
                        Text(mode.commitLabel)
                            .font(Signal.briefing(15))
                            .foregroundColor(
                                isFormValid ? Palette.ambitionGold : Palette.dormantGray
                            )
                    }
                }
            }
            .onAppear {
                loadExistingData()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                    appearAnimated = true
                }
            }
        }
    }

    // MARK: - Logic

    private var isFormValid: Bool {
        let trimmed = zoneName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count <= 30
    }

    private func commitForm() {
        guard isFormValid else {
            showValidation = true
            Pulse.warning()
            return
        }
        onCommit(zoneName.trimmingCharacters(in: .whitespaces), selectedIcon)
    }

    private func loadExistingData() {
        if case .edit(let zoneId) = mode,
           let zone = DataVault.shared.zone(by: zoneId) {
            zoneName = zone.title
            selectedIcon = zone.iconSymbol
        }
    }

    private var quickSuggestions: [String] {
        [
            "Downtown", "North Side", "South End",
            "Home Area", "Campus", "Business District",
            "Old Town", "Waterfront", "Midtown",
            "Suburbs", "Industrial", "Park Area"
        ]
    }
}

// MARK: - Zone Preview Badge

struct ZonePreviewBadge: View {
    let name: String
    let icon: String
    let isPlaceholder: Bool

    @State private var glowPhase: Bool = false

    var body: some View {
        VStack(spacing: Grid.medium) {
            ZStack {
                // Glow ring
                Circle()
                    .stroke(
                        Palette.ambitionGold.opacity(glowPhase ? 0.4 : 0.1),
                        lineWidth: 2
                    )
                    .frame(width: 90, height: 90)
                    .scaleEffect(glowPhase ? 1.1 : 1.0)

                Circle()
                    .fill(Palette.tacticalSurface)
                    .frame(width: 76, height: 76)

                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(Palette.ambitionGold)
            }

            Text(name)
                .font(Signal.dispatch(18))
                .foregroundColor(
                    isPlaceholder ? Palette.dormantGray : Palette.frostCommand
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
        }
    }
}

// MARK: - Icon Chip

struct IconChip: View {
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(
                    isSelected ? Palette.deepOpsBase : Palette.silentDuty
                )
                .frame(width: 48, height: 48)
                .background(
                    isSelected ? Palette.ambitionGold : Palette.elevatedBunker
                )
                .cornerRadius(Shield.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Shield.medium)
                        .stroke(
                            isSelected ? Palette.ambitionGold : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Flow Layout (for quick suggestions)

/// Wrapping layout compatible with iOS 15+. Uses Layout on iOS 16+, LazyVGrid fallback on iOS 15.
struct FlowLayoutCompat<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            FlowLayout(spacing: spacing) { content() }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 200), spacing: spacing)], spacing: spacing) {
                content()
            }
        }
    }
}

@available(iOS 16.0, *)
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return ArrangementResult(
            positions: positions,
            size: CGSize(width: maxWidth, height: totalHeight)
        )
    }

    private struct ArrangementResult {
        let positions: [CGPoint]
        let size: CGSize
    }
}

// MARK: - Preview

#if DEBUG
struct AddZoneSheet_Previews: PreviewProvider {
    static var previews: some View {
        AddZoneSheet(
            mode: .create,
            onCommit: { _, _ in },
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
