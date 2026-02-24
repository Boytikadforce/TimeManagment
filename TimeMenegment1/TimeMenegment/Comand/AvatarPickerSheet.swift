// AvatarPickerSheet.swift
// c11 — Zone-based day planner with gamification
// Modal sheets: emoji avatar picker, callsign editor, achievement unlock, rank-up celebration

import SwiftUI

// MARK: - Avatar Picker Sheet

struct AvatarPickerSheet: View {

    let currentAvatar: String
    let currentCallSign: String
    let onSelectAvatar: (String) -> Void
    let onSaveCallSign: (String) -> Void
    let onDismiss: () -> Void

    @State private var editedCallSign: String = ""
    @State private var selectedEmoji: String = ""
    @State private var appeared = false

    private let emojiSections: [(title: String, emojis: [String])] = [
        ("Faces", ["😎", "🤓", "🧐", "😤", "🥷", "🦊", "🐺", "🦅"]),
        ("Objects", ["🎯", "🏆", "⚡️", "🔥", "💎", "🚀", "🗺", "🧭"]),
        ("Nature", ["🌟", "🌙", "☀️", "🌈", "🍀", "🌊", "⛰", "🌋"]),
        ("Symbols", ["♟", "🎪", "🎭", "🎨", "🔮", "🛡", "⚔️", "👑"]),
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Palette.deepOpsBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Grid.large) {

                        // ── Preview ──────────────────────────────
                        VStack(spacing: Grid.medium) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            colors: [Palette.ambitionGold, Palette.conquestGreen, Palette.momentumGlow, Palette.ambitionGold],
                                            center: .center
                                        ),
                                        lineWidth: 3
                                    )
                                    .frame(width: 100, height: 100)

                                Text(selectedEmoji)
                                    .font(.system(size: 48))
                            }
                            .scaleEffect(appeared ? 1 : 0.7)

                            Text(editedCallSign.isEmpty ? "Operator" : editedCallSign)
                                .font(Signal.headline(20))
                                .foregroundColor(Palette.frostCommand)
                        }
                        .padding(.top, Grid.large)

                        // ── Callsign input ───────────────────────
                        VStack(alignment: .leading, spacing: Grid.small) {
                            Text("CALLSIGN")
                                .font(Signal.whisper())
                                .foregroundColor(Palette.silentDuty)
                                .tracking(1.2)

                            HStack {
                                TextField("Your name or alias", text: $editedCallSign)
                                    .font(Signal.briefing(16))
                                    .foregroundColor(Palette.frostCommand)
                                    .accentColor(Palette.ambitionGold)

                                if !editedCallSign.isEmpty {
                                    Button(action: {
                                        onSaveCallSign(editedCallSign)
                                    }) {
                                        Text("Save")
                                            .font(Signal.briefing(13))
                                            .foregroundColor(Palette.ambitionGold)
                                    }
                                }
                            }
                            .padding(Grid.medium)
                            .background(Palette.tacticalSurface)
                            .cornerRadius(Shield.small)
                        }
                        .padding(.horizontal, Grid.large)

                        // ── Emoji grid ───────────────────────────
                        ForEach(emojiSections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: Grid.small) {
                                Text(section.title.uppercased())
                                    .font(Signal.whisper())
                                    .foregroundColor(Palette.dormantGray)
                                    .tracking(1)
                                    .padding(.horizontal, Grid.large)

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: Grid.medium) {
                                    ForEach(section.emojis, id: \.self) { emoji in
                                        Button(action: {
                                            selectedEmoji = emoji
                                            onSelectAvatar(emoji)
                                        }) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: Shield.medium)
                                                    .fill(
                                                        selectedEmoji == emoji
                                                            ? Palette.ambitionGold.opacity(0.2)
                                                            : Palette.elevatedBunker
                                                    )
                                                    .frame(height: 60)

                                                if selectedEmoji == emoji {
                                                    RoundedRectangle(cornerRadius: Shield.medium)
                                                        .stroke(Palette.ambitionGold, lineWidth: 2)
                                                        .frame(height: 60)
                                                }

                                                Text(emoji)
                                                    .font(.system(size: 28))
                                            }
                                        }
                                        .scaleEffect(selectedEmoji == emoji ? 1.08 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedEmoji)
                                    }
                                }
                                .padding(.horizontal, Grid.large)
                            }
                        }

                        Spacer().frame(height: Grid.epic)
                    }
                }
            }
            .navigationTitle("Operator Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                        .foregroundColor(Palette.ambitionGold)
                }
            }
            .onAppear {
                selectedEmoji = currentAvatar
                editedCallSign = currentCallSign
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - Achievement Unlocked Sheet

struct AchievementUnlockedSheet: View {

    let medal: FieldMedal
    let onDismiss: () -> Void

    @State private var iconScale: CGFloat = 0.3
    @State private var glowRadius: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var raysRotation: Double = 0

    var body: some View {
        ZStack {
            Palette.deepOpsBase
                .ignoresSafeArea()

            // Rays
            ForEach(0..<8, id: \.self) { i in
                Rectangle()
                    .fill(Palette.badgeShimmer.opacity(0.08))
                    .frame(width: 2, height: 200)
                    .rotationEffect(.degrees(Double(i) * 45 + raysRotation))
            }

            VStack(spacing: Grid.large) {
                Spacer()

                // Medal icon
                ZStack {
                    Circle()
                        .fill(Palette.badgeShimmer.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .shadow(color: Palette.badgeShimmer.opacity(0.3), radius: glowRadius)

                    Circle()
                        .stroke(Palette.badgeShimmer, lineWidth: 2)
                        .frame(width: 120, height: 120)

                    Text(medal.iconEmoji)
                        .font(.system(size: 56))
                        .scaleEffect(iconScale)
                }

                // Text
                VStack(spacing: Grid.small) {
                    Text("MEDAL UNLOCKED")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(Palette.badgeShimmer)
                        .tracking(3)

                    Text(medal.title)
                        .font(Signal.headline(26))
                        .foregroundColor(Palette.frostCommand)

                    Text(medal.description)
                        .font(Signal.intel(15))
                        .foregroundColor(Palette.silentDuty)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Grid.large)
                }
                .opacity(textOpacity)

                Spacer()

                Button(action: onDismiss) {
                    Text("Acknowledged")
                }
                .buttonStyle(GoldActionButton())
                .padding(.bottom, Grid.epic)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                glowRadius = 30
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                textOpacity = 1
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                raysRotation = 360
            }
        }
    }
}

// MARK: - Rank Up Celebration Sheet

struct RankUpSheet: View {

    let rank: OperatorRank
    let onDismiss: () -> Void

    @State private var badgeScale: CGFloat = 0.2
    @State private var textOpacity: Double = 0
    @State private var particlePhase = false

    var body: some View {
        ZStack {
            Palette.deepOpsBase
                .ignoresSafeArea()

            // Particles
            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(i % 2 == 0 ? Palette.ambitionGold : Palette.conquestGreen)
                    .frame(width: CGFloat.random(in: 4...8))
                    .offset(
                        x: particlePhase ? CGFloat.random(in: -150...150) : 0,
                        y: particlePhase ? CGFloat.random(in: -200...200) : 0
                    )
                    .opacity(particlePhase ? 0 : 0.8)
            }

            VStack(spacing: Grid.large) {
                Spacer()

                // Rank badge
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Palette.ambitionGold.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 180, height: 180)

                    Text(rank.badge)
                        .font(.system(size: 72))
                        .scaleEffect(badgeScale)
                }

                VStack(spacing: Grid.small) {
                    Text("RANK UP!")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(Palette.ambitionGold)
                        .tracking(4)

                    Text(rank.title)
                        .font(Signal.headline(32))
                        .foregroundColor(Palette.frostCommand)

                    Text("Keep completing missions to climb higher")
                        .font(Signal.intel(14))
                        .foregroundColor(Palette.silentDuty)
                }
                .opacity(textOpacity)

                Spacer()

                Button(action: onDismiss) {
                    HStack {
                        Image(systemName: "arrow.right")
                        Text("Continue")
                    }
                }
                .buttonStyle(ConquestButton())
                .padding(.bottom, Grid.epic)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.4).delay(0.2)) {
                badgeScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
                textOpacity = 1
            }
            withAnimation(.easeOut(duration: 1.5).delay(0.1)) {
                particlePhase = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AvatarPickerSheet_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AvatarPickerSheet(
                currentAvatar: "🎯",
                currentCallSign: "Operator",
                onSelectAvatar: { _ in },
                onSaveCallSign: { _ in },
                onDismiss: {}
            )

            AchievementUnlockedSheet(
                medal: FieldMedal.catalog[0],
                onDismiss: {}
            )

            RankUpSheet(
                rank: OperatorRank.ladder[3],
                onDismiss: {}
            )
        }
        .preferredColorScheme(.dark)
    }
}
#endif
