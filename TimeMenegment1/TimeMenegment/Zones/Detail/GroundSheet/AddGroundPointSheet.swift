// AddGroundPointSheet.swift
// c11 — Zone-based day planner with gamification
// Modal sheet for creating and editing places (ground points)

import SwiftUI

// MARK: - Mode

enum GroundPointFormMode {
    case create(zoneId: UUID)
    case edit(zoneId: UUID, pointId: UUID)

    var zoneId: UUID {
        switch self {
        case .create(let id):       return id
        case .edit(let id, _):      return id
        }
    }

    var navigationTitle: String {
        switch self {
        case .create: return "Deploy New Stop"
        case .edit:   return "Edit Stop"
        }
    }

    var commitLabel: String {
        switch self {
        case .create: return "Deploy"
        case .edit:   return "Save"
        }
    }
}

// MARK: - Sheet

struct AddGroundPointSheet: View {

    let mode: GroundPointFormMode
    let onCommit: (String, ErrandTag, Int, Int, String, String) -> Void
    let onDismiss: () -> Void

    // ── Form state ───────────────────────────────────────────────
    @State private var pointName: String = ""
    @State private var selectedTag: ErrandTag = .other
    @State private var durationMin: Int = 20
    @State private var bufferMin: Int = 10
    @State private var memo: String = ""
    @State private var selectedIcon: String = "mappin"
    @State private var showValidation: Bool = false
    @State private var appeared: Bool = false

    // ── Duration / Buffer options ────────────────────────────────
    private let durationSteps = [5, 10, 15, 20, 30, 45, 60, 90, 120]
    private let bufferSteps = [0, 5, 10, 15, 20, 30]

    // ── Icon options per tag ─────────────────────────────────────
    private var iconOptions: [String] {
        switch selectedTag {
        case .food:     return ["cup.and.saucer.fill", "fork.knife", "takeoutbag.and.cup.and.straw.fill", "mug.fill"]
        case .services: return ["wrench.and.screwdriver.fill", "cross.case.fill", "scissors", "building.columns.fill"]
        case .shopping: return ["bag.fill", "cart.fill", "storefront.fill", "creditcard.fill"]
        case .errands:  return ["tray.full.fill", "shippingbox.fill", "envelope.fill", "doc.text.fill"]
        case .meeting:  return ["person.2.fill", "bubble.left.and.bubble.right.fill", "phone.fill", "video.fill"]
        case .other:    return ["mappin", "ellipsis.circle.fill", "star.fill", "bookmark.fill"]
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Palette.deepOpsBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Grid.large) {

                        // ── Live preview ─────────────────────────
                        StopPreviewPill(
                            name: pointName.isEmpty ? "Stop Name" : pointName,
                            tag: selectedTag,
                            icon: selectedIcon,
                            duration: durationMin,
                            buffer: bufferMin,
                            isPlaceholder: pointName.isEmpty
                        )
                        .padding(.top, Grid.large)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.9)

                        // ── Name input ───────────────────────────
                        FormSection(title: "STOP NAME") {
                            TextField("e.g. Pharmacy, Coffee Shop, Post Office", text: $pointName)
                                .font(Signal.briefing(16))
                                .foregroundColor(Palette.frostCommand)
                                .accentColor(Palette.ambitionGold)
                                .padding(Grid.medium)
                                .background(Palette.tacticalSurface)
                                .cornerRadius(Shield.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Shield.small)
                                        .stroke(
                                            showValidation && pointName.trimmingCharacters(in: .whitespaces).isEmpty
                                                ? Palette.overloadCrimson
                                                : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )

                            if showValidation && pointName.trimmingCharacters(in: .whitespaces).isEmpty {
                                ValidationHint(message: "Stop name is required")
                            }
                        }

                        // ── Tag picker ───────────────────────────
                        FormSection(title: "CATEGORY") {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: Grid.small) {
                                ForEach(ErrandTag.allCases) { tag in
                                    TagPickerChip(
                                        tag: tag,
                                        isSelected: selectedTag == tag,
                                        onTap: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedTag = tag
                                                selectedIcon = iconOptions.first ?? "mappin"
                                            }
                                            Pulse.light()
                                        }
                                    )
                                }
                            }
                        }

                        // ── Icon picker ──────────────────────────
                        FormSection(title: "ICON") {
                            HStack(spacing: Grid.medium) {
                                ForEach(iconOptions, id: \.self) { icon in
                                    Button(action: {
                                        selectedIcon = icon
                                        Pulse.light()
                                    }) {
                                        Image(systemName: icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(
                                                selectedIcon == icon
                                                    ? Palette.deepOpsBase
                                                    : Palette.silentDuty
                                            )
                                            .frame(width: 44, height: 44)
                                            .background(
                                                selectedIcon == icon
                                                    ? Palette.ambitionGold
                                                    : Palette.elevatedBunker
                                            )
                                            .cornerRadius(Shield.medium)
                                    }
                                    .scaleEffect(selectedIcon == icon ? 1.08 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedIcon)
                                }
                                Spacer()
                            }
                        }

                        // ── Duration ─────────────────────────────
                        FormSection(title: "DURATION") {
                            VStack(spacing: Grid.small) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Grid.small) {
                                        ForEach(durationSteps, id: \.self) { step in
                                            TimeChip(
                                                value: step,
                                                unit: "min",
                                                isSelected: durationMin == step,
                                                onTap: {
                                                    durationMin = step
                                                    Pulse.light()
                                                }
                                            )
                                        }
                                    }
                                }

                                // Custom stepper
                                HStack {
                                    Text("Custom:")
                                        .font(Signal.whisper())
                                        .foregroundColor(Palette.silentDuty)

                                    StepperButton(icon: "minus", action: {
                                        durationMin = max(5, durationMin - 5)
                                    })

                                    Text("\(durationMin) min")
                                        .font(Signal.mono(14))
                                        .foregroundColor(Palette.frostCommand)
                                        .frame(width: 60)

                                    StepperButton(icon: "plus", action: {
                                        durationMin = min(240, durationMin + 5)
                                    })

                                    Spacer()
                                }
                            }
                        }

                        // ── Buffer ───────────────────────────────
                        FormSection(title: "BUFFER AFTER STOP") {
                            HStack(spacing: Grid.small) {
                                ForEach(bufferSteps, id: \.self) { step in
                                    TimeChip(
                                        value: step,
                                        unit: step == 0 ? "none" : "min",
                                        isSelected: bufferMin == step,
                                        onTap: {
                                            bufferMin = step
                                            Pulse.light()
                                        }
                                    )
                                }
                            }
                        }

                        // ── Total load preview ───────────────────
                        TotalLoadBadge(duration: durationMin, buffer: bufferMin)

                        // ── Memo ─────────────────────────────────
                        FormSection(title: "MEMO (OPTIONAL)") {
                            memoField
                        }

                        Spacer().frame(height: Grid.epic)
                    }
                    .padding(.horizontal, Grid.large)
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
                loadDefaults()
                loadExistingData()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Logic

    @ViewBuilder
    private var memoField: some View {
        if #available(iOS 16.0, *) {
            TextField("What to do here…", text: $memo, axis: .vertical)
                .font(Signal.intel(14))
                .foregroundColor(Palette.frostCommand)
                .accentColor(Palette.ambitionGold)
                .lineLimit(3...6)
                .padding(Grid.medium)
                .background(Palette.tacticalSurface)
                .cornerRadius(Shield.small)
        } else {
            TextEditor(text: $memo)
                .font(Signal.intel(14))
                .foregroundColor(Palette.frostCommand)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(Grid.medium)
                .background(Palette.tacticalSurface)
                .cornerRadius(Shield.small)
                .overlay(
                    Group {
                        if memo.isEmpty {
                            Text("What to do here…")
                                .font(Signal.intel(14))
                                .foregroundColor(Palette.dormantGray)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )
        }
    }

    private var isFormValid: Bool {
        !pointName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func commitForm() {
        guard isFormValid else {
            showValidation = true
            Pulse.warning()
            return
        }
        onCommit(
            pointName.trimmingCharacters(in: .whitespaces),
            selectedTag,
            durationMin,
            bufferMin,
            memo.trimmingCharacters(in: .whitespaces),
            selectedIcon
        )
    }

    private func loadDefaults() {
        let cfg = DataVault.shared.config
        durationMin = cfg.defaultDurationMin
        bufferMin = cfg.defaultBufferMin
    }

    private func loadExistingData() {
        if case .edit(let zoneId, let pointId) = mode,
           let zone = DataVault.shared.zone(by: zoneId),
           let point = zone.groundPoints.first(where: { $0.id == pointId }) {
            pointName = point.title
            selectedTag = point.tag
            durationMin = point.durationMin
            bufferMin = point.bufferMin
            memo = point.memo
            selectedIcon = point.iconSymbol
        }
    }
}

// MARK: - Form Section Wrapper

struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.small) {
            Text(title)
                .font(Signal.whisper())
                .foregroundColor(Palette.silentDuty)
                .tracking(1.2)

            content
        }
    }
}

// MARK: - Validation Hint

struct ValidationHint: View {
    let message: String

    var body: some View {
        HStack(spacing: Grid.micro) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
            Text(message)
                .font(Signal.whisper())
        }
        .foregroundColor(Palette.overloadCrimson)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Tag Picker Chip

struct TagPickerChip: View {
    let tag: ErrandTag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Grid.micro) {
                Image(systemName: tag.iconGlyph)
                    .font(.system(size: 18))
                Text(tag.callSign)
                    .font(Signal.whisper())
            }
            .foregroundColor(isSelected ? Palette.deepOpsBase : Palette.silentDuty)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Grid.small + 2)
            .background(isSelected ? Palette.ambitionGold : Palette.elevatedBunker)
            .cornerRadius(Shield.small)
            .overlay(
                RoundedRectangle(cornerRadius: Shield.small)
                    .stroke(isSelected ? Palette.ambitionGold : Palette.dormantGray.opacity(0.3), lineWidth: 1)
            )
        }
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Time Chip

struct TimeChip: View {
    let value: Int
    let unit: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(value == 0 ? unit : "\(value)")
                .font(Signal.intel(13))
                .foregroundColor(isSelected ? Palette.deepOpsBase : Palette.silentDuty)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, Grid.medium)
                .padding(.vertical, Grid.small)
                .background(isSelected ? Palette.ambitionGold : Palette.elevatedBunker)
                .cornerRadius(Shield.pill)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stepper Button

struct StepperButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Palette.ambitionGold)
                .frame(width: 32, height: 32)
                .background(Palette.elevatedBunker)
                .cornerRadius(Shield.small)
        }
    }
}

// MARK: - Stop Preview Pill

struct StopPreviewPill: View {
    let name: String
    let tag: ErrandTag
    let icon: String
    let duration: Int
    let buffer: Int
    let isPlaceholder: Bool

    var body: some View {
        HStack(spacing: Grid.medium) {
            ZStack {
                Circle()
                    .fill(Palette.elevatedBunker)
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Palette.ambitionGold)
            }

            VStack(alignment: .leading, spacing: Grid.micro) {
                Text(name)
                    .font(Signal.briefing(16))
                    .foregroundColor(isPlaceholder ? Palette.dormantGray : Palette.frostCommand)
                    .lineLimit(1)

                HStack(spacing: Grid.small) {
                    Text(tag.callSign)
                        .font(Signal.whisper())
                        .foregroundColor(Palette.silentDuty)

                    Text("•")
                        .foregroundColor(Palette.dormantGray)

                    Text("\(duration + buffer) min total")
                        .font(Signal.whisper())
                        .foregroundColor(Palette.silentDuty)
                }
            }

            Spacer()
        }
        .padding(Grid.base)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Shield.medium)
                .stroke(Palette.ambitionGold.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Total Load Badge

struct TotalLoadBadge: View {
    let duration: Int
    let buffer: Int

    private var total: Int { duration + buffer }

    var body: some View {
        HStack(spacing: Grid.medium) {
            Image(systemName: "timer")
                .font(.system(size: 14))
                .foregroundColor(Palette.conquestGreen)

            VStack(alignment: .leading, spacing: 2) {
                Text("Total load per stop")
                    .font(Signal.whisper())
                    .foregroundColor(Palette.silentDuty)

                HStack(spacing: Grid.small) {
                    Text("\(duration) min task")
                        .font(Signal.intel(13))
                        .foregroundColor(Palette.frostCommand)

                    if buffer > 0 {
                        Text("+ \(buffer) min buffer")
                            .font(Signal.intel(13))
                            .foregroundColor(Palette.dormantGray)
                    }

                    Text("= \(total) min")
                        .font(Signal.briefing(13))
                        .foregroundColor(Palette.ambitionGold)
                }
            }

            Spacer()
        }
        .padding(Grid.medium)
        .background(Palette.tacticalSurface)
        .cornerRadius(Shield.small)
    }
}

// MARK: - Preview

#if DEBUG
struct AddGroundPointSheet_Previews: PreviewProvider {
    static var previews: some View {
        AddGroundPointSheet(
            mode: .create(zoneId: UUID()),
            onCommit: { _, _, _, _, _, _ in },
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
