// TodaySheets.swift
// c11 — Zone-based day planner with gamification
// Modal sheets for the Today tab

import SwiftUI

// =========================================================================
// MARK: - Zone Picker Sheet
// =========================================================================

struct ZonePickerSheet: View {

    let zones: [OperationsZone]
    let currentZoneId: UUID?
    let onSelect: (UUID) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Palette.deepOpsBase
                    .ignoresSafeArea()

                if zones.isEmpty {
                    VStack(spacing: Grid.medium) {
                        Image(systemName: "map")
                            .font(.system(size: 40))
                            .foregroundColor(Palette.dormantGray)
                        Text("No zones available")
                            .font(Signal.briefing(16))
                            .foregroundColor(Palette.silentDuty)
                        Text("Create a zone first in the Zones tab")
                            .font(Signal.intel(13))
                            .foregroundColor(Palette.dormantGray)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: Grid.medium) {
                            Text("Pick a zone for today's mission")
                                .font(Signal.intel(14))
                                .foregroundColor(Palette.silentDuty)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, Grid.base)

                            ForEach(zones) { zone in
                                ZonePickerRow(
                                    zone: zone,
                                    isCurrent: zone.id == currentZoneId,
                                    onSelect: { onSelect(zone.id) }
                                )
                            }

                            Spacer().frame(height: Grid.huge)
                        }
                        .padding(.horizontal, Grid.base)
                    }
                }
            }
            .navigationTitle("Select Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundColor(Palette.silentDuty)
                }
            }
        }
    }
}

struct ZonePickerRow: View {
    let zone: OperationsZone
    let isCurrent: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            zoneRowContent
        }
        .buttonStyle(.plain)
    }

    private var zoneRowContent: some View {
            HStack(spacing: Grid.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: Shield.small)
                        .fill(isCurrent ? Palette.ambitionGold : Palette.elevatedBunker)
                        .frame(width: 44, height: 44)

                    Image(systemName: zone.iconSymbol)
                        .font(.system(size: 20))
                        .foregroundColor(
                            isCurrent ? Palette.deepOpsBase : Palette.silentDuty
                        )
                }

                VStack(alignment: .leading, spacing: Grid.micro) {
                    Text(zone.title)
                        .font(Signal.briefing(16))
                        .foregroundColor(Palette.frostCommand)

                    Text("\(zone.groundPoints.count) stops in catalog")
                        .font(Signal.whisper())
                        .foregroundColor(Palette.dormantGray)
                }

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Palette.ambitionGold)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(Palette.dormantGray)
                }
            }
            .padding(Grid.medium)
            .background(Palette.tacticalSurface)
            .cornerRadius(Shield.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Shield.medium)
                    .stroke(
                        isCurrent ? Palette.ambitionGold.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
            )
    }
}

// =========================================================================
// MARK: - Add From Catalog Sheet
// =========================================================================

struct AddFromCatalogSheet: View {

    let availablePlaces: [GroundPoint]
    let onDeploy: (GroundPoint) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""

    private var filtered: [GroundPoint] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return availablePlaces
        }
        let q = searchText.lowercased()
        return availablePlaces.filter {
            $0.title.lowercased().contains(q) || $0.tag.callSign.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Palette.deepOpsBase
                    .ignoresSafeArea()

                VStack(spacing: Grid.medium) {
                    // Search
                    FieldSearchBar(query: $searchText, placeholder: "Search catalog…")
                        .padding(.horizontal, Grid.base)
                        .padding(.top, Grid.small)

                    if availablePlaces.isEmpty {
                        Spacer()
                        VStack(spacing: Grid.medium) {
                            Image(systemName: "tray")
                                .font(.system(size: 36))
                                .foregroundColor(Palette.dormantGray)
                            Text("All stops already deployed")
                                .font(Signal.briefing(16))
                                .foregroundColor(Palette.silentDuty)
                            Text("Use Quick Add for new stops")
                                .font(Signal.intel(13))
                                .foregroundColor(Palette.dormantGray)
                        }
                        Spacer()
                    } else if filtered.isEmpty {
                        Spacer()
                        Text("No matches")
                            .font(Signal.intel(14))
                            .foregroundColor(Palette.dormantGray)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Grid.small) {
                                ForEach(filtered) { place in
                                    CatalogDeployRow(
                                        place: place,
                                        onDeploy: { onDeploy(place) }
                                    )
                                }
                            }
                            .padding(.horizontal, Grid.base)
                            .padding(.bottom, Grid.epic)
                        }
                    }
                }
            }
            .navigationTitle("Add from Catalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { onDismiss() }
                        .foregroundColor(Palette.ambitionGold)
                }
            }
        }
    }
}

struct CatalogDeployRow: View {
    let place: GroundPoint
    let onDeploy: () -> Void

    @State private var deployed = false

    var body: some View {
        HStack(spacing: Grid.medium) {
            Image(systemName: place.tag.iconGlyph)
                .font(.system(size: 16))
                .foregroundColor(Palette.ambitionGold)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Grid.micro) {
                Text(place.title)
                    .font(Signal.briefing(15))
                    .foregroundColor(Palette.frostCommand)
                    .lineLimit(1)

                HStack(spacing: Grid.small) {
                    Text(place.tag.callSign)
                        .font(Signal.whisper())
                    Text("•")
                    Text("\(place.totalLoadMin)m")
                        .font(Signal.whisper())
                }
                .foregroundColor(Palette.dormantGray)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    deployed = true
                }
                onDeploy()
            }) {
                if deployed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Palette.conquestGreen)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Palette.ambitionGold)
                }
            }
            .disabled(deployed)
        }
        .padding(Grid.medium)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.small)
    }
}

// =========================================================================
// MARK: - Quick Add Stop Sheet
// =========================================================================

struct QuickAddStopSheet: View {

    let onCommit: (String, ErrandTag, Int, Int, String) -> Void
    let onDismiss: () -> Void

    @State private var stopName = ""
    @State private var memo = ""
    @State private var selectedTag: ErrandTag = .errands
    @State private var durationMin: Int = 20
    @State private var bufferMin: Int = 10
    @State private var showValidation = false

    private let quickDurations = [10, 15, 20, 30, 45, 60, 90, 120]
    private let quickBuffers = [0, 5, 10, 15, 20]

    var body: some View {
        NavigationView {
            ZStack {
                Palette.deepOpsBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Grid.large) {

                        // Header
                        VStack(spacing: Grid.small) {
                            Image(systemName: "bolt.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Palette.conquestGreen)

                            Text("Quick deploy a new stop")
                                .font(Signal.intel(14))
                                .foregroundColor(Palette.silentDuty)
                        }
                        .padding(.top, Grid.base)

                        // Name
                        FormSection(title: "STOP NAME") {
                            TextField("What needs to be done?", text: $stopName)
                                .font(Signal.briefing(16))
                                .foregroundColor(Palette.frostCommand)
                                .accentColor(Palette.ambitionGold)
                                .padding(Grid.medium)
                                .background(Palette.tacticalSurface)
                                .cornerRadius(Shield.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Shield.small)
                                        .stroke(
                                            showValidation && stopName.trimmingCharacters(in: .whitespaces).isEmpty
                                                ? Palette.overloadCrimson
                                                : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )

                            if showValidation && stopName.trimmingCharacters(in: .whitespaces).isEmpty {
                                ValidationHint(message: "Name is required")
                            }
                        }

                        // Tag — compact horizontal
                        FormSection(title: "CATEGORY") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Grid.small) {
                                    ForEach(ErrandTag.allCases) { tag in
                                        Button(action: {
                                            selectedTag = tag
                                            Pulse.light()
                                        }) {
                                            HStack(spacing: Grid.micro) {
                                                Image(systemName: tag.iconGlyph)
                                                    .font(.system(size: 12))
                                                Text(tag.callSign)
                                                    .font(Signal.whisper())
                                            }
                                            .foregroundColor(
                                                selectedTag == tag
                                                    ? Palette.deepOpsBase
                                                    : Palette.silentDuty
                                            )
                                            .padding(.horizontal, Grid.medium)
                                            .padding(.vertical, Grid.small)
                                            .background(
                                                selectedTag == tag
                                                    ? Palette.ambitionGold
                                                    : Palette.elevatedBunker
                                            )
                                            .cornerRadius(Shield.pill)
                                        }
                                    }
                                }
                            }
                        }

                        // Duration
                        FormSection(title: "DURATION") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Grid.small) {
                                    ForEach(quickDurations, id: \.self) { d in
                                        TimeChip(
                                            value: d,
                                            unit: "m",
                                            isSelected: durationMin == d,
                                            onTap: { durationMin = d }
                                        )
                                    }
                                }
                            }
                        }

                        // Buffer
                        FormSection(title: "BUFFER") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Grid.small) {
                                    ForEach(quickBuffers, id: \.self) { b in
                                        TimeChip(
                                            value: b,
                                            unit: b == 0 ? "none" : "m",
                                            isSelected: bufferMin == b,
                                            onTap: { bufferMin = b }
                                        )
                                    }
                                }
                            }
                        }

                        // Memo / Notes
                        FormSection(title: "NOTES (optional)") {
                            ZStack(alignment: .topLeading) {
                                if memo.isEmpty {
                                    Text("Add details, address, reminder…")
                                        .font(Signal.intel(15))
                                        .foregroundColor(Palette.dormantGray)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 8)
                                }
                                TextEditor(text: $memo)
                                    .font(Signal.intel(15))
                                    .foregroundColor(Palette.frostCommand)
                                    .frame(minHeight: 70)
                                    .padding(Grid.micro)
                            }
                            .padding(Grid.small)
                            .background(Palette.tacticalSurface)
                            .cornerRadius(Shield.small)
                        }

                        // Load preview
                        TotalLoadBadge(duration: durationMin, buffer: bufferMin)

                        // Deploy button
                        Button(action: commitQuickDeploy) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Deploy Now")
                            }
                        }
                        .buttonStyle(ConquestButton())
                        .padding(.top, Grid.base)

                        Spacer().frame(height: Grid.epic)
                    }
                    .padding(.horizontal, Grid.large)
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundColor(Palette.silentDuty)
                }
            }
            .onAppear {
                let cfg = DataVault.shared.config
                durationMin = cfg.defaultDurationMin
                bufferMin = cfg.defaultBufferMin
            }
        }
    }

    private func commitQuickDeploy() {
        let trimmed = stopName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showValidation = true
            Pulse.warning()
            return
        }
        onCommit(trimmed, selectedTag, durationMin, bufferMin, memo.trimmingCharacters(in: .whitespaces))
    }
}

// =========================================================================
// MARK: - Day Editor Sheet (with Pressure Breakdown)
// =========================================================================

struct DayEditorSheet: View {

    let breakdown: TimeBreakdown
    let onCompressBuffers: () -> Void
    let onCreateLightVariant: () -> Void
    let onClearAll: () -> Void
    let onChangeZone: () -> Void
    let onDismiss: () -> Void

    @State private var barAnimated = false

    var body: some View {
        NavigationView {
            ZStack {
                Palette.deepOpsBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Grid.large) {

                        // ── Pressure gauge ───────────────────────
                        PressureGauge(
                            pressure: breakdown.pressure,
                            totalMin: breakdown.totalLoadMin,
                            thresholdMin: breakdown.thresholdMin,
                            animated: barAnimated
                        )
                        .padding(.top, Grid.base)

                        // ── Time breakdown ───────────────────────
                        VStack(spacing: Grid.medium) {
                            Text("TIME BREAKDOWN")
                                .font(Signal.whisper())
                                .foregroundColor(Palette.silentDuty)
                                .tracking(1.2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            BreakdownRow(
                                icon: "clock.fill",
                                label: "Task durations",
                                value: "\(breakdown.totalDurationMin) min",
                                color: Palette.ambitionGold
                            )
                            BreakdownRow(
                                icon: "pause.circle.fill",
                                label: "Buffers",
                                value: "\(breakdown.totalBufferMin) min",
                                color: Palette.silentDuty
                            )

                            Divider()
                                .background(Palette.gridLine)

                            BreakdownRow(
                                icon: "sum",
                                label: "Total planned",
                                value: "\(breakdown.totalLoadMin) min",
                                color: Palette.frostCommand,
                                isBold: true
                            )
                            BreakdownRow(
                                icon: "gauge.high",
                                label: "Overload threshold",
                                value: "\(breakdown.thresholdMin) min",
                                color: Palette.dormantGray
                            )

                            if breakdown.deltaMin > 0 {
                                BreakdownRow(
                                    icon: "exclamationmark.triangle.fill",
                                    label: "Over by",
                                    value: "+\(breakdown.deltaMin) min",
                                    color: Palette.overloadCrimson,
                                    isBold: true
                                )
                            }

                            BreakdownRow(
                                icon: "mappin.circle",
                                label: "Stops count",
                                value: "\(breakdown.stopsCount) / \(breakdown.recommendedMax) recommended",
                                color: breakdown.stopsCount > breakdown.recommendedMax
                                    ? Palette.urgencyAmber
                                    : Palette.silentDuty
                            )
                        }
                        .padding(Grid.base)
                        .background(Palette.tacticalSurface)
                        .cornerRadius(Shield.medium)

                        // ── Quick fixes ──────────────────────────
                        if breakdown.pressure != .steady {
                            VStack(alignment: .leading, spacing: Grid.medium) {
                                Text("QUICK FIXES")
                                    .font(Signal.whisper())
                                    .foregroundColor(Palette.silentDuty)
                                    .tracking(1.2)

                                QuickFixButton(
                                    icon: "arrow.down.right.and.arrow.up.left",
                                    title: "Compress Buffers",
                                    subtitle: "Reduce buffer on 2 longest stops by 5 min each",
                                    color: Palette.ambitionGold,
                                    action: onCompressBuffers
                                )

                                QuickFixButton(
                                    icon: "doc.badge.gearshape",
                                    title: "Create Light Plan",
                                    subtitle: "Keep ~2/3 of stops with compressed buffers",
                                    color: Palette.conquestGreen,
                                    action: onCreateLightVariant
                                )
                            }
                        }

                        // ── Day actions ──────────────────────────
                        VStack(alignment: .leading, spacing: Grid.medium) {
                            Text("DAY ACTIONS")
                                .font(Signal.whisper())
                                .foregroundColor(Palette.silentDuty)
                                .tracking(1.2)

                            DayActionRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Change Zone",
                                subtitle: "Switch to a different zone for today",
                                color: Palette.ambitionGold,
                                action: onChangeZone
                            )

                            DayActionRow(
                                icon: "trash",
                                title: "Clear All Stops",
                                subtitle: "Remove all stops and start fresh",
                                color: Palette.overloadCrimson,
                                action: onClearAll
                            )
                        }

                        Spacer().frame(height: Grid.epic)
                    }
                    .padding(.horizontal, Grid.large)
                }
            }
            .navigationTitle("Day Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                        .foregroundColor(Palette.ambitionGold)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.7).delay(0.2)) {
                    barAnimated = true
                }
            }
        }
    }
}

// MARK: - Pressure Gauge

struct PressureGauge: View {
    let pressure: PressureLevel
    let totalMin: Int
    let thresholdMin: Int
    let animated: Bool

    private var fillFraction: CGFloat {
        guard thresholdMin > 0 else { return 0 }
        return min(1.3, CGFloat(totalMin) / CGFloat(thresholdMin))
    }

    private var gaugeColor: Color {
        switch pressure {
        case .steady:   return Palette.steadyPace
        case .dense:    return Palette.urgencyAmber
        case .critical: return Palette.overloadCrimson
        }
    }

    var body: some View {
        VStack(spacing: Grid.medium) {
            // Pressure icon + label
            HStack {
                Image(systemName: pressure.iconGlyph)
                    .font(.system(size: 24))
                    .foregroundColor(gaugeColor)

                Text(pressure.label)
                    .font(Signal.headline(22))
                    .foregroundColor(gaugeColor)

                Spacer()

                Text("\(totalMin)/\(thresholdMin) min")
                    .font(Signal.mono(14))
                    .foregroundColor(Palette.silentDuty)
            }

            // Horizontal gauge bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Palette.dormantGray)

                    // Threshold marker
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Palette.elevatedBunker)
                        .frame(width: geo.size.width * min(1.0, CGFloat(thresholdMin) / CGFloat(max(totalMin, thresholdMin) + 30)))

                    // Fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [gaugeColor.opacity(0.7), gaugeColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animated
                            ? geo.size.width * min(1.0, fillFraction)
                            : 0
                        )
                }
            }
            .frame(height: 14)
        }
        .padding(Grid.base)
        .background(gaugeColor.opacity(0.08))
        .cornerRadius(Shield.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Shield.medium)
                .stroke(gaugeColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Breakdown Row

struct BreakdownRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var isBold: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 22)

            Text(label)
                .font(isBold ? Signal.briefing(14) : Signal.intel(14))
                .foregroundColor(Palette.silentDuty)

            Spacer()

            Text(value)
                .font(isBold ? Signal.briefing(14) : Signal.intel(14))
                .foregroundColor(color)
        }
    }
}

// MARK: - Quick Fix Button

struct QuickFixButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Grid.medium) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.15))
                    .cornerRadius(Shield.small)

                VStack(alignment: .leading, spacing: Grid.micro) {
                    Text(title)
                        .font(Signal.briefing(14))
                        .foregroundColor(Palette.frostCommand)
                    Text(subtitle)
                        .font(Signal.whisper())
                        .foregroundColor(Palette.dormantGray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.dormantGray)
            }
            .padding(Grid.medium)
            .background(Palette.tacticalSurface)
            .cornerRadius(Shield.medium)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day Action Row

struct DayActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Grid.medium) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: Grid.micro) {
                    Text(title)
                        .font(Signal.briefing(14))
                        .foregroundColor(color)
                    Text(subtitle)
                        .font(Signal.whisper())
                        .foregroundColor(Palette.dormantGray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.dormantGray)
            }
            .padding(Grid.medium)
            .background(Palette.tacticalSurface)
            .cornerRadius(Shield.medium)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct TodaySheets_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QuickAddStopSheet(
                onCommit: { _, _, _, _, _ in },
                onDismiss: {}
            )

            DayEditorSheet(
                breakdown: TimeBreakdown(
                    totalDurationMin: 180, totalBufferMin: 60, totalLoadMin: 240,
                    thresholdMin: 200, deltaMin: 40, stopsCount: 9,
                    recommendedMax: 8, pressure: .critical
                ),
                onCompressBuffers: {},
                onCreateLightVariant: {},
                onClearAll: {},
                onChangeZone: {},
                onDismiss: {}
            )
        }
        .preferredColorScheme(.dark)
    }
}
#endif
