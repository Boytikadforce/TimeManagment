// BriefingOnboardView.swift
// c11 — Zone-based day planner with gamification
// Functional onboarding — 6 steps, real data creation, animations

import SwiftUI
import Combine
// MARK: - Onboarding Container

struct BriefingOnboardView: View {

    let onFinish: () -> Void

    @StateObject private var conductor = BriefingConductor()

    // Page transition
    @State private var slideDirection: Edge = .trailing

    var body: some View {
        ZStack {
            Palette.deepOpsBase
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Progress bar ─────────────────────────────────
                BriefingProgressBar(
                    current: conductor.stepIndex,
                    total: conductor.totalSteps
                )
                .padding(.horizontal, Grid.large)
                .padding(.top, Grid.base)

                // ── Step content ─────────────────────────────────
                TabView(selection: $conductor.stepIndex) {
                    BriefingStep_Welcome(conductor: conductor, onFinish: onFinish)
                        .tag(0)
                    BriefingStep_Principle(conductor: conductor)
                        .tag(1)
                    BriefingStep_TimeRules(conductor: conductor)
                        .tag(2)
                    BriefingStep_CreateZone(conductor: conductor)
                        .tag(3)
                    BriefingStep_AddPlaces(conductor: conductor)
                        .tag(4)
                    BriefingStep_LaunchDay(conductor: conductor, onFinish: onFinish)
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: conductor.stepIndex)
            }
        }
    }
}

// MARK: - Briefing Conductor (Presenter)

/// Manages onboarding state — step navigation, collected data, validation.
final class BriefingConductor: ObservableObject {

    let totalSteps = 6

    @Published var stepIndex: Int = 0

    // Step 2 — Time rules
    @Published var defaultDuration: Int = 20
    @Published var defaultBuffer: Int = 10
    @Published var overloadThreshold: Int = 240

    // Step 3 — First zone
    @Published var firstZoneName: String = ""
    @Published var firstZoneIcon: String = "mappin.circle.fill"
    @Published var createdZoneId: UUID? = nil

    // Step 4 — Quick places
    @Published var selectedPresets: Set<UUID> = []
    @Published var customPlaces: [String] = []

    // Step 5 — Order
    @Published var orderedStops: [GroundPoint] = []

    // Allow district change
    @Published var allowZoneChange: Bool = true

    func advance() {
        guard stepIndex < totalSteps - 1 else { return }
        Pulse.light()
        withAnimation(.easeInOut(duration: 0.3)) {
            stepIndex += 1
        }
    }

    func retreat() {
        guard stepIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            stepIndex -= 1
        }
    }

    /// Persist all collected data and mark onboarding complete.
    func finalizeBriefing() {
        let vault = DataVault.shared

        // Save config
        vault.mutateConfig { cfg in
            cfg.defaultDurationMin = self.defaultDuration
            cfg.defaultBufferMin = self.defaultBuffer
            cfg.criticalPressureThresholdMin = self.overloadThreshold
            cfg.densePressureThresholdMin = max(self.overloadThreshold - 60, 60)
            cfg.allowZoneChangeDuringDay = self.allowZoneChange
            cfg.hasCompletedBriefing = true
        }

        // Create first zone if named
        if !firstZoneName.trimmingCharacters(in: .whitespaces).isEmpty {
            var zone = OperationsZone(
                title: firstZoneName.trimmingCharacters(in: .whitespaces),
                iconSymbol: firstZoneIcon,
                isPinned: true
            )

            // Add selected preset places
            for preset in QuickDeployPreset.starterKit where selectedPresets.contains(preset.id) {
                let point = GroundPoint(
                    title: preset.title,
                    tag: preset.tag,
                    durationMin: defaultDuration,
                    bufferMin: defaultBuffer,
                    iconSymbol: preset.icon
                )
                zone.groundPoints.append(point)
            }

            // Add custom places
            for name in customPlaces where !name.trimmingCharacters(in: .whitespaces).isEmpty {
                let point = GroundPoint(
                    title: name.trimmingCharacters(in: .whitespaces),
                    durationMin: defaultDuration,
                    bufferMin: defaultBuffer
                )
                zone.groundPoints.append(point)
            }

            vault.deployZone(zone)
            createdZoneId = zone.id

            // Auto-create today's field day
            let today = vault.todayFieldDay(forZoneId: zone.id)
            // Add all zone places as stops
            for (idx, point) in zone.groundPoints.enumerated() {
                let stop = DeploymentStop(
                    groundPointId: point.id,
                    title: point.title,
                    tag: point.tag,
                    durationMin: point.durationMin,
                    bufferMin: point.bufferMin,
                    sortIndex: idx
                )
                vault.deployStop(stop, toDayId: today.id)
            }
        }

        Pulse.success()
    }
}

// MARK: - Progress Bar

struct BriefingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: Grid.micro) {
            ForEach(0..<total, id: \.self) { idx in
                Capsule()
                    .fill(idx <= current ? Palette.ambitionGold : Palette.dormantGray)
                    .frame(height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: current)
            }
        }
    }
}

// =========================================================================
// MARK: - STEP 0: Welcome
// =========================================================================

struct BriefingStep_Welcome: View {
    @ObservedObject var conductor: BriefingConductor
    let onFinish: () -> Void

    @State private var cardsVisible = false
    @State private var titleVisible = false

    var body: some View {
        VStack(spacing: Grid.large) {
            Spacer()

            // Animated icon stack
            ZStack {
                RoundedRectangle(cornerRadius: Shield.medium)
                    .fill(Palette.tacticalSurface)
                    .frame(width: 90, height: 70)
                    .rotationEffect(.degrees(-8))
                    .offset(x: -20, y: 10)
                    .opacity(cardsVisible ? 1 : 0)
                    .scaleEffect(cardsVisible ? 1 : 0.5)

                RoundedRectangle(cornerRadius: Shield.medium)
                    .fill(Palette.elevatedBunker)
                    .frame(width: 90, height: 70)
                    .rotationEffect(.degrees(5))
                    .offset(x: 15, y: -5)
                    .opacity(cardsVisible ? 1 : 0)
                    .scaleEffect(cardsVisible ? 1 : 0.5)

                RoundedRectangle(cornerRadius: Shield.medium)
                    .fill(Palette.ambitionGold)
                    .frame(width: 90, height: 70)
                    .overlay(
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Palette.deepOpsBase)
                    )
                    .opacity(cardsVisible ? 1 : 0)
                    .scaleEffect(cardsVisible ? 1 : 0.7)
            }
            .padding(.bottom, Grid.base)

            // Title
            VStack(spacing: Grid.small) {
                Text("c11")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(Palette.ambitionGold)

                Text("Zone Your Day")
                    .font(Signal.headline(26))
                    .foregroundColor(Palette.frostCommand)

                Text("One day — one zone • places list • visit order")
                    .font(Signal.intel(15))
                    .foregroundColor(Palette.silentDuty)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Grid.large)
            }
            .opacity(titleVisible ? 1 : 0)
            .offset(y: titleVisible ? 0 : 20)

            Spacer()

            // Actions
            VStack(spacing: Grid.medium) {
                Button(action: { conductor.advance() }) {
                    HStack {
                        Text("Start Briefing")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(GoldActionButton())

                Button("Skip — I'll explore") {
                    conductor.finalizeBriefing()
                    onFinish()
                }
                .font(Signal.intel(14))
                .foregroundColor(Palette.silentDuty)
            }
            .padding(.bottom, Grid.epic)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                cardsVisible = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                titleVisible = true
            }
        }
    }
}

// =========================================================================
// MARK: - STEP 1: Principle — "Day = 1 Zone"
// =========================================================================

struct BriefingStep_Principle: View {
    @ObservedObject var conductor: BriefingConductor

    @State private var ruleCardVisible = false
    @State private var toggleVisible = false

    var body: some View {
        VStack(spacing: Grid.large) {
            Spacer()

            // Rule card
            VStack(spacing: Grid.base) {
                Image(systemName: "scope")
                    .font(.system(size: 44))
                    .foregroundColor(Palette.ambitionGold)

                Text("Day = 1 Zone")
                    .font(Signal.headline(28))
                    .foregroundColor(Palette.frostCommand)

                Text("Less running around, more tasks closed.\nFocus on one area each day.")
                    .font(Signal.intel(15))
                    .foregroundColor(Palette.silentDuty)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Grid.large)
            }
            .padding(Grid.large)
            .operationsCard()
            .padding(.horizontal, Grid.large)
            .opacity(ruleCardVisible ? 1 : 0)
            .scaleEffect(ruleCardVisible ? 1 : 0.9)

            // Toggle
            HStack {
                VStack(alignment: .leading, spacing: Grid.micro) {
                    Text("Allow zone change during day")
                        .font(Signal.briefing(14))
                        .foregroundColor(Palette.frostCommand)
                    Text("Life happens — you can switch if needed")
                        .font(Signal.whisper())
                        .foregroundColor(Palette.silentDuty)
                }
                Spacer()
                Toggle("", isOn: $conductor.allowZoneChange)
                    .tint(Palette.ambitionGold)
                    .labelsHidden()
            }
            .padding(Grid.base)
            .operationsCard()
            .padding(.horizontal, Grid.large)
            .opacity(toggleVisible ? 1 : 0)
            .offset(y: toggleVisible ? 0 : 15)

            Spacer()

            // Navigation
            HStack(spacing: Grid.base) {
                Button(action: { conductor.retreat() }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(Palette.silentDuty)
                }

                Spacer()

                Button(action: { conductor.advance() }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(GoldActionButton())
            }
            .padding(.horizontal, Grid.large)
            .padding(.bottom, Grid.epic)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) {
                ruleCardVisible = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                toggleVisible = true
            }
        }
    }
}

// =========================================================================
// MARK: - STEP 2: Time Rules
// =========================================================================

struct BriefingStep_TimeRules: View {
    @ObservedObject var conductor: BriefingConductor

    @State private var visible = false

    private let durationOptions = [10, 15, 20, 30]
    private let bufferOptions = [0, 5, 10, 15]
    private let thresholdOptions = [120, 180, 240, 300, 360]

    var body: some View {
        ScrollView {
            VStack(spacing: Grid.large) {

                Spacer().frame(height: Grid.large)

                // Header
                VStack(spacing: Grid.small) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Palette.ambitionGold)

                    Text("Time & Pressure Rules")
                        .font(Signal.headline(24))
                        .foregroundColor(Palette.frostCommand)

                    Text("Set your defaults — adjust anytime in settings")
                        .font(Signal.intel(14))
                        .foregroundColor(Palette.silentDuty)
                }
                .opacity(visible ? 1 : 0)

                // Duration picker
                TimeRuleCard(
                    title: "Default stop duration",
                    value: conductor.defaultDuration,
                    unit: "min",
                    options: durationOptions,
                    onSelect: { conductor.defaultDuration = $0 }
                )

                // Buffer picker
                TimeRuleCard(
                    title: "Buffer between stops",
                    value: conductor.defaultBuffer,
                    unit: "min",
                    options: bufferOptions,
                    onSelect: { conductor.defaultBuffer = $0 }
                )

                // Threshold picker
                TimeRuleCard(
                    title: "Overload threshold",
                    value: conductor.overloadThreshold,
                    unit: "min",
                    options: thresholdOptions,
                    onSelect: { conductor.overloadThreshold = $0 }
                )

                // Preview
                PressurePreviewCard(
                    duration: conductor.defaultDuration,
                    buffer: conductor.defaultBuffer,
                    threshold: conductor.overloadThreshold
                )

                Spacer().frame(height: Grid.base)

                // Navigation
                HStack(spacing: Grid.base) {
                    Button(action: { conductor.retreat() }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(Palette.silentDuty)
                    }
                    Spacer()
                    Button(action: { conductor.advance() }) {
                        HStack {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(GoldActionButton())
                }
                .padding(.horizontal, Grid.large)
                .padding(.bottom, Grid.epic)
            }
            .padding(.horizontal, Grid.large)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                visible = true
            }
        }
    }
}

/// Single time-rule card with selectable chips.
struct TimeRuleCard: View {
    let title: String
    let value: Int
    let unit: String
    let options: [Int]
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.medium) {
            Text(title)
                .font(Signal.briefing(14))
                .foregroundColor(Palette.frostCommand)

            HStack(spacing: Grid.small) {
                ForEach(options, id: \.self) { opt in
                    Button(action: { onSelect(opt) }) {
                        Text("\(opt) \(unit)")
                            .font(Signal.intel(13))
                            .foregroundColor(opt == value ? Palette.deepOpsBase : Palette.silentDuty)
                            .padding(.horizontal, Grid.medium)
                            .padding(.vertical, Grid.small)
                            .background(opt == value ? Palette.ambitionGold : Palette.elevatedBunker)
                            .cornerRadius(Shield.pill)
                    }
                }
            }
        }
        .padding(Grid.base)
        .operationsCard()
    }
}

/// Live preview of how many stops fit before overload.
struct PressurePreviewCard: View {
    let duration: Int
    let buffer: Int
    let threshold: Int

    private var maxStops: Int {
        let load = duration + buffer
        guard load > 0 else { return 0 }
        return threshold / load
    }

    var body: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Palette.conquestGreen)
            Text("With these rules, up to **\(maxStops) stops** fit comfortably in a day")
                .font(Signal.intel(13))
                .foregroundColor(Palette.silentDuty)
        }
        .padding(Grid.base)
        .operationsCard()
    }
}

// =========================================================================
// MARK: - STEP 3: Create First Zone
// =========================================================================

struct BriefingStep_CreateZone: View {
    @ObservedObject var conductor: BriefingConductor

    @State private var visible = false

    private let iconOptions = [
        "mappin.circle.fill", "building.2.fill", "house.fill",
        "cart.fill", "briefcase.fill", "leaf.fill",
        "star.fill", "bolt.fill"
    ]

    var body: some View {
        VStack(spacing: Grid.large) {
            Spacer()

            VStack(spacing: Grid.small) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Palette.ambitionGold)

                Text("Create Your First Zone")
                    .font(Signal.headline(24))
                    .foregroundColor(Palette.frostCommand)

                Text("A zone is a neighborhood or area you visit")
                    .font(Signal.intel(14))
                    .foregroundColor(Palette.silentDuty)
            }
            .opacity(visible ? 1 : 0)

            // Name input
            VStack(alignment: .leading, spacing: Grid.small) {
                Text("Zone name")
                    .font(Signal.whisper())
                    .foregroundColor(Palette.silentDuty)

                TextField("e.g. Downtown, North Side, Home Area", text: $conductor.firstZoneName)
                    .font(Signal.briefing())
                    .foregroundColor(Palette.frostCommand)
                    .padding(Grid.medium)
                    .background(Palette.elevatedBunker)
                    .cornerRadius(Shield.small)
                    .accentColor(Palette.ambitionGold)
            }
            .padding(.horizontal, Grid.large)

            // Icon picker
            VStack(alignment: .leading, spacing: Grid.small) {
                Text("Pick an icon")
                    .font(Signal.whisper())
                    .foregroundColor(Palette.silentDuty)
                    .padding(.horizontal, Grid.large)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Grid.medium) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button(action: {
                                conductor.firstZoneIcon = icon
                                Pulse.light()
                            }) {
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(
                                        conductor.firstZoneIcon == icon
                                            ? Palette.deepOpsBase
                                            : Palette.silentDuty
                                    )
                                    .frame(width: 48, height: 48)
                                    .background(
                                        conductor.firstZoneIcon == icon
                                            ? Palette.ambitionGold
                                            : Palette.elevatedBunker
                                    )
                                    .cornerRadius(Shield.medium)
                            }
                        }
                    }
                    .padding(.horizontal, Grid.large)
                }
            }

            Spacer()

            // Navigation
            HStack(spacing: Grid.base) {
                Button(action: { conductor.retreat() }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(Palette.silentDuty)
                }
                Spacer()

                Button(action: { conductor.advance() }) {
                    HStack {
                        Text(conductor.firstZoneName.isEmpty ? "Skip" : "Next")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(GoldActionButton())
            }
            .padding(.horizontal, Grid.large)
            .padding(.bottom, Grid.epic)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                visible = true
            }
        }
    }
}

// =========================================================================
// MARK: - STEP 4: Add Places
// =========================================================================

struct BriefingStep_AddPlaces: View {
    @ObservedObject var conductor: BriefingConductor

    @State private var customInput: String = ""
    @State private var visible = false

    var body: some View {
        VStack(spacing: Grid.large) {

            Spacer().frame(height: Grid.large)

            VStack(spacing: Grid.small) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Palette.ambitionGold)

                Text("Add Stops to Your Zone")
                    .font(Signal.headline(22))
                    .foregroundColor(Palette.frostCommand)

                Text("Tap to select, or add your own below")
                    .font(Signal.intel(14))
                    .foregroundColor(Palette.silentDuty)
            }
            .opacity(visible ? 1 : 0)

            // Preset grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: Grid.medium),
                    GridItem(.flexible(), spacing: Grid.medium)
                ], spacing: Grid.medium) {
                    ForEach(QuickDeployPreset.starterKit) { preset in
                        PresetChip(
                            preset: preset,
                            isSelected: conductor.selectedPresets.contains(preset.id),
                            onTap: {
                                if conductor.selectedPresets.contains(preset.id) {
                                    conductor.selectedPresets.remove(preset.id)
                                } else {
                                    conductor.selectedPresets.insert(preset.id)
                                }
                                Pulse.light()
                            }
                        )
                    }
                }
                .padding(.horizontal, Grid.large)

                // Custom place input
                VStack(alignment: .leading, spacing: Grid.small) {
                    Text("Add custom stop")
                        .font(Signal.whisper())
                        .foregroundColor(Palette.silentDuty)

                    HStack {
                        TextField("Stop name…", text: $customInput)
                            .font(Signal.briefing(14))
                            .foregroundColor(Palette.frostCommand)
                            .accentColor(Palette.ambitionGold)

                        Button(action: addCustomPlace) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(
                                    customInput.isEmpty
                                        ? Palette.dormantGray
                                        : Palette.ambitionGold
                                )
                        }
                        .disabled(customInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(Grid.medium)
                    .background(Palette.elevatedBunker)
                    .cornerRadius(Shield.small)

                    // Custom places list
                    ForEach(conductor.customPlaces, id: \.self) { name in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Palette.conquestGreen)
                                .font(.system(size: 14))
                            Text(name)
                                .font(Signal.intel(14))
                                .foregroundColor(Palette.frostCommand)
                            Spacer()
                            Button(action: {
                                conductor.customPlaces.removeAll { $0 == name }
                            }) {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(Palette.silentDuty)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.vertical, Grid.micro)
                    }
                }
                .padding(.horizontal, Grid.large)
                .padding(.top, Grid.base)
            }

            // Count badge
            let totalCount = conductor.selectedPresets.count + conductor.customPlaces.count
            if totalCount > 0 {
                Text("\(totalCount) stop\(totalCount == 1 ? "" : "s") selected")
                    .font(Signal.whisper())
                    .foregroundColor(Palette.conquestGreen)
                    .transition(.opacity)
            }

            // Navigation
            HStack(spacing: Grid.base) {
                Button(action: { conductor.retreat() }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(Palette.silentDuty)
                }
                Spacer()
                Button(action: { conductor.advance() }) {
                    HStack {
                        Text(totalCount >= 3 ? "Next" : "Skip")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(GoldActionButton())
            }
            .padding(.horizontal, Grid.large)
            .padding(.bottom, Grid.epic)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                visible = true
            }
        }
    }

    private func addCustomPlace() {
        let trimmed = customInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        conductor.customPlaces.append(trimmed)
        customInput = ""
        Pulse.light()
    }
}

/// Single preset chip.
struct PresetChip: View {
    let preset: QuickDeployPreset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Grid.small) {
                Image(systemName: preset.icon)
                    .font(.system(size: 16))
                Text(preset.title)
                    .font(Signal.intel(14))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? Palette.deepOpsBase : Palette.silentDuty)
            .padding(.horizontal, Grid.medium)
            .padding(.vertical, Grid.small)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Palette.ambitionGold : Palette.elevatedBunker)
            .cornerRadius(Shield.small)
            .overlay(
                RoundedRectangle(cornerRadius: Shield.small)
                    .stroke(isSelected ? Color.clear : Palette.dormantGray, lineWidth: 1)
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// =========================================================================
// MARK: - STEP 5: Launch Day
// =========================================================================

struct BriefingStep_LaunchDay: View {
    @ObservedObject var conductor: BriefingConductor
    let onFinish: () -> Void

    @State private var visible = false
    @State private var rocketLaunched = false

    private var summary: String {
        let stops = conductor.selectedPresets.count + conductor.customPlaces.count
        if conductor.firstZoneName.isEmpty {
            return "You can create zones and stops anytime."
        }
        return "Zone \"\(conductor.firstZoneName)\" with \(stops) stop\(stops == 1 ? "" : "s") is ready."
    }

    var body: some View {
        VStack(spacing: Grid.large) {
            Spacer()

            // Rocket animation
            ZStack {
                Circle()
                    .fill(Palette.ambitionGold.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .scaleEffect(rocketLaunched ? 1.5 : 1.0)
                    .opacity(rocketLaunched ? 0 : 1)

                Text("🚀")
                    .font(.system(size: 64))
                    .offset(y: rocketLaunched ? -120 : 0)
                    .scaleEffect(rocketLaunched ? 0.5 : 1.0)
            }
            .opacity(visible ? 1 : 0)

            VStack(spacing: Grid.small) {
                Text("Ready to Deploy!")
                    .font(Signal.headline(28))
                    .foregroundColor(Palette.frostCommand)

                Text(summary)
                    .font(Signal.intel(15))
                    .foregroundColor(Palette.silentDuty)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Grid.large)
            }
            .opacity(visible ? 1 : 0)

            // Stats preview
            VStack(spacing: Grid.medium) {
                SummaryRow(icon: "map.fill", label: "Zone", value: conductor.firstZoneName.isEmpty ? "—" : conductor.firstZoneName)
                SummaryRow(icon: "mappin.circle.fill", label: "Stops", value: "\(conductor.selectedPresets.count + conductor.customPlaces.count)")
                SummaryRow(icon: "clock.fill", label: "Default duration", value: "\(conductor.defaultDuration) min")
                SummaryRow(icon: "flame.fill", label: "Overload at", value: "\(conductor.overloadThreshold) min")
            }
            .padding(Grid.base)
            .operationsCard()
            .padding(.horizontal, Grid.large)
            .opacity(visible ? 1 : 0)

            Spacer()

            // Launch button
            VStack(spacing: Grid.medium) {
                Button(action: launchMission) {
                    HStack {
                        Image(systemName: "flag.checkered")
                        Text("Launch Day")
                    }
                }
                .buttonStyle(ConquestButton())

                Button(action: { conductor.retreat() }) {
                    Text("Go back")
                        .font(Signal.intel(14))
                        .foregroundColor(Palette.silentDuty)
                }
            }
            .padding(.bottom, Grid.epic)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                visible = true
            }
        }
    }

    private func launchMission() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            rocketLaunched = true
        }
        conductor.finalizeBriefing()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onFinish()
        }
    }
}

struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Palette.ambitionGold)
                .frame(width: 24)
            Text(label)
                .font(Signal.intel(14))
                .foregroundColor(Palette.silentDuty)
            Spacer()
            Text(value)
                .font(Signal.briefing(14))
                .foregroundColor(Palette.frostCommand)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BriefingOnboardView_Previews: PreviewProvider {
    static var previews: some View {
        BriefingOnboardView(onFinish: {})
            .preferredColorScheme(.dark)
    }
}
#endif
