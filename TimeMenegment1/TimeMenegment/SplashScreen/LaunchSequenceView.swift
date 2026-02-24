// LaunchSequenceView.swift
// c11 — Zone-based day planner with gamification
// Animated splash / loading screen

import SwiftUI

// MARK: - Launch Sequence View

struct LaunchSequenceView: View {

    let onComplete: () -> Void

    // ── Animation state ──────────────────────────────────────────
    @State private var currentPhrase: Int = 0
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var progressValue: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var particlesVisible: Bool = false
    @State private var glowPulse: Bool = false
    @State private var phaseComplete: Bool = false

    // ── Abstract loading phrases ─────────────────────────────────
    private let missionPhrases: [String] = [
        "Initializing operations…",
        "Mapping your zones…",
        "Calibrating daily rhythm…",
        "Synchronizing priorities…",
        "Deploying your command center…",
        "Almost there…",
        "Ready for action."
    ]

    // ── Timing ───────────────────────────────────────────────────
    private let totalDuration: Double = 3.2
    private let phraseInterval: Double = 0.45

    var body: some View {
        ZStack {
            // Background
            Palette.deepOpsBase
                .ignoresSafeArea()

            // Particle field
            ParticleFieldView(isActive: particlesVisible)
                .ignoresSafeArea()
                .opacity(particlesVisible ? 0.6 : 0)

            VStack(spacing: Grid.large) {
                Spacer()

                // ── Animated logo / rings ────────────────────────
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Palette.ambitionGold,
                                    Palette.conquestGreen,
                                    Palette.momentumGlow,
                                    Palette.ambitionGold
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(ringRotation))
                        .scaleEffect(ringScale)

                    // Middle ring
                    Circle()
                        .stroke(
                            Palette.ambitionGold.opacity(0.3),
                            lineWidth: 1.5
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(-ringRotation * 0.7))
                        .scaleEffect(ringScale)

                    // Inner ring
                    Circle()
                        .stroke(
                            Palette.conquestGreen.opacity(0.4),
                            lineWidth: 1
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(ringRotation * 1.3))

                    // Logo text
                    Text("c11")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(Palette.ambitionGold)
                        .shadow(color: Palette.ambitionGold.opacity(glowPulse ? 0.8 : 0.2), radius: glowPulse ? 20 : 5)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }

                // ── Subtitle ─────────────────────────────────────
                Text("Zone Your Day")
                    .font(Signal.dispatch(16))
                    .foregroundColor(Palette.silentDuty)
                    .opacity(logoOpacity)

                Spacer()
                    .frame(height: Grid.huge)

                // ── Loading phrase ───────────────────────────────
                Text(missionPhrases[safe: currentPhrase] ?? "")
                    .font(Signal.intel(14))
                    .foregroundColor(Palette.silentDuty.opacity(0.8))
                    .opacity(textOpacity)
                    .animation(.easeInOut(duration: 0.3), value: currentPhrase)
                    .frame(height: 20)

                // ── Progress bar ─────────────────────────────────
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Shield.pill)
                        .fill(Palette.tacticalSurface)
                        .frame(height: 4)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: Shield.pill)
                            .fill(
                                LinearGradient(
                                    colors: [Palette.ambitionGold, Palette.conquestGreen],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progressValue, height: 4)
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, Grid.epic)

                // ── Dots indicator ───────────────────────────────
                HStack(spacing: Grid.small) {
                    ForEach(0..<7, id: \.self) { idx in
                        Circle()
                            .fill(idx <= currentPhrase ? Palette.ambitionGold : Palette.dormantGray)
                            .frame(width: 6, height: 6)
                            .scaleEffect(idx == currentPhrase ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentPhrase)
                    }
                }

                Spacer()
                    .frame(height: Grid.epic)
            }
        }
        .onAppear(perform: startSequence)
    }

    // MARK: - Animation Sequence

    private func startSequence() {
        // Phase 1: Logo appears
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Phase 2: Rings start spinning
        withAnimation(.linear(duration: totalDuration * 3).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 1.0
        }

        // Phase 3: Glow pulse
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            glowPulse = true
        }

        // Phase 4: Particles
        withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
            particlesVisible = true
        }

        // Phase 5: Text and progress
        withAnimation(.easeIn(duration: 0.3).delay(0.4)) {
            textOpacity = 1.0
        }

        // Progress animation
        withAnimation(.easeInOut(duration: totalDuration).delay(0.3)) {
            progressValue = 1.0
        }

        // Cycle through phrases
        for i in 0..<missionPhrases.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + phraseInterval * Double(i)) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentPhrase = i
                }
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                phaseComplete = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onComplete()
            }
        }
    }
}

// MARK: - Particle Field

/// Floating particles that drift upward — adds depth to launch screen.
struct ParticleFieldView: View {
    let isActive: Bool

    // Generate random particles once
    private let particles: [LaunchParticle] = (0..<25).map { _ in
        LaunchParticle(
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: 0...1),
            size: CGFloat.random(in: 2...5),
            speed: Double.random(in: 2...5),
            delay: Double.random(in: 0...2),
            isGold: Bool.random()
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles.indices, id: \.self) { idx in
                    SingleParticle(
                        particle: particles[idx],
                        screenSize: geo.size,
                        isActive: isActive
                    )
                }
            }
        }
    }
}

struct LaunchParticle {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let speed: Double
    let delay: Double
    let isGold: Bool
}

struct SingleParticle: View {
    let particle: LaunchParticle
    let screenSize: CGSize
    let isActive: Bool

    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .fill(particle.isGold ? Palette.ambitionGold : Palette.conquestGreen)
            .frame(width: particle.size, height: particle.size)
            .position(
                x: particle.x * screenSize.width,
                y: particle.y * screenSize.height + offsetY
            )
            .opacity(opacity)
            .onAppear {
                guard isActive else { return }
                withAnimation(
                    .easeInOut(duration: particle.speed)
                    .repeatForever(autoreverses: true)
                    .delay(particle.delay)
                ) {
                    offsetY = -80
                    opacity = Double.random(in: 0.3...0.7)
                }
            }
    }
}

// MARK: - Pulsing Dot (reusable micro-animation)

/// A single dot that pulses — used in various loading states.
struct PulsingDot: View {
    let color: Color
    let delay: Double

    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0.3

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    scale = 1.2
                    opacity = 1.0
                }
            }
    }
}

/// Three-dot loading indicator.
struct TriplePulse: View {
    var body: some View {
        HStack(spacing: Grid.small) {
            PulsingDot(color: Palette.ambitionGold, delay: 0)
            PulsingDot(color: Palette.ambitionGold, delay: 0.2)
            PulsingDot(color: Palette.ambitionGold, delay: 0.4)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LaunchSequenceView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchSequenceView(onComplete: {})
            .preferredColorScheme(.dark)
    }
}
#endif
