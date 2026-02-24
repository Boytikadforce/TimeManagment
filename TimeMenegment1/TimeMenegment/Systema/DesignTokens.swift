// DesignTokens.swift
// c11 — Zone-based day planner with gamification
// Design system: colors, typography, spacing, haptics

import SwiftUI

// MARK: - iOS 15 Compatibility

/// Applies toolbarColorScheme only on iOS 16+. No-op on iOS 15.
struct ToolbarColorSchemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            content
        }
    }
}

/// Hides scroll/list content background on iOS 16+. No-op on iOS 15.
struct ScrollContentBackgroundHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

// MARK: - Palette — "Operations Room"

/// Core color palette for c11.
/// Every name reflects the time-management & mission metaphor.
struct Palette {

    // ── Backgrounds ──────────────────────────────────────────────
    /// Primary background — deep dark steel  RGB(26, 44, 56)
    static let deepOpsBase       = Color(red: 26/255, green: 44/255, blue: 56/255)
    /// Slightly lifted surface for cards
    static let tacticalSurface   = Color(red: 35/255, green: 58/255, blue: 74/255)
    /// Elevated layer (sheets, modals)
    static let elevatedBunker    = Color(red: 44/255, green: 72/255, blue: 90/255)

    // ── Accent — Gold / Victory / Command ────────────────────────
    /// Primary accent — ambition gold
    static let ambitionGold      = Color(red: 255/255, green: 200/255, blue: 55/255)
    /// Bright victory green — completed, success
    static let conquestGreen     = Color(red: 72/255, green: 220/255, blue: 140/255)
    /// Frost white — text and icons on dark
    static let frostCommand      = Color.white
    /// Dimmed white for secondary text
    static let silentDuty        = Color(red: 180/255, green: 195/255, blue: 210/255)

    // ── Status ───────────────────────────────────────────────────
    /// Comfortable — everything under control
    static let steadyPace        = Color(red: 72/255, green: 220/255, blue: 140/255)
    /// Tight schedule — amber warning
    static let urgencyAmber      = Color(red: 255/255, green: 170/255, blue: 50/255)
    /// Overloaded — crimson alert
    static let overloadCrimson   = Color(red: 255/255, green: 82/255, blue: 82/255)

    // ── Gamification ─────────────────────────────────────────────
    /// XP / streak glow
    static let momentumGlow      = Color(red: 170/255, green: 130/255, blue: 255/255)
    /// Badge shimmer
    static let badgeShimmer      = Color(red: 255/255, green: 215/255, blue: 0/255)
    /// Level-up flash
    static let levelUpFlash      = Color(red: 100/255, green: 255/255, blue: 218/255)

    // ── Utility ──────────────────────────────────────────────────
    /// Transparent overlay for dimming
    static let blackoutVeil      = Color.black.opacity(0.55)
    /// Divider / separator
    static let gridLine          = Color.white.opacity(0.08)
    /// Disabled state
    static let dormantGray       = Color(red: 70/255, green: 85/255, blue: 100/255)
    /// Secondary label — readable on dark (HQ, cards)
    static let secondaryLabel    = Color(red: 155/255, green: 175/255, blue: 195/255)
}

// MARK: - Typography — "Signal"

/// Typographic scale named after communication clarity levels.
struct Signal {

    static func headline(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func dispatch(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func briefing(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func intel(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func whisper(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func mono(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

// MARK: - Spacing — "Grid"

/// Consistent spacing tokens.
struct Grid {
    static let micro:   CGFloat = 4
    static let small:   CGFloat = 8
    static let medium:  CGFloat = 12
    static let base:    CGFloat = 16
    static let large:   CGFloat = 24
    static let huge:    CGFloat = 32
    static let epic:    CGFloat = 48
}

// MARK: - Corner Radius — "Shield"

struct Shield {
    static let small:   CGFloat = 8
    static let medium:  CGFloat = 12
    static let large:   CGFloat = 16
    static let pill:    CGFloat = 50
}

// MARK: - Shadows — "Depth"

struct Depth {
    static let cardShadow   = Color.black.opacity(0.25)
    static let cardRadius:  CGFloat = 4
    static let cardX:       CGFloat = 0
    static let cardY:       CGFloat = 2
}

// MARK: - Haptic — "Pulse"

struct Pulse {
    static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }
    static func medium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.impactOccurred()
    }
    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }
    static func warning() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.warning)
    }
}

// MARK: - View Modifiers — Reusable card style

struct OperationsCard: ViewModifier {
    var cornerRadius: CGFloat = Shield.medium

    func body(content: Content) -> some View {
        content
            .padding(Grid.base)
            .background(Palette.tacticalSurface)
            .cornerRadius(cornerRadius)
            .shadow(
                color: Depth.cardShadow,
                radius: Depth.cardRadius,
                x: Depth.cardX,
                y: Depth.cardY
            )
    }
}

extension View {
    func operationsCard(cornerRadius: CGFloat = Shield.medium) -> some View {
        modifier(OperationsCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Button Styles

struct GoldActionButton: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Signal.briefing())
            .foregroundColor(Palette.deepOpsBase)
            .padding(.horizontal, Grid.large)
            .padding(.vertical, Grid.medium)
            .background(
                isEnabled
                    ? Palette.ambitionGold
                    : Palette.dormantGray
            )
            .cornerRadius(Shield.pill)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostActionButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Signal.briefing())
            .foregroundColor(Palette.ambitionGold)
            .padding(.horizontal, Grid.large)
            .padding(.vertical, Grid.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Shield.pill)
                    .stroke(Palette.ambitionGold, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ConquestButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Signal.briefing())
            .foregroundColor(Palette.deepOpsBase)
            .padding(.horizontal, Grid.large)
            .padding(.vertical, Grid.medium)
            .background(Palette.conquestGreen)
            .cornerRadius(Shield.pill)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Animated Gradient (for gamification moments)

struct MomentumGradient: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            colors: [
                Palette.ambitionGold,
                Palette.conquestGreen,
                Palette.momentumGlow,
                Palette.ambitionGold
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .hueRotation(.degrees(phase * 30))
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}
