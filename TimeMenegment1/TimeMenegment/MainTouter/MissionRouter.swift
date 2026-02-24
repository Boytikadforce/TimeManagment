// MissionRouter.swift
// c11 — Zone-based day planner with gamification
// VIPER Router — centralized navigation state

import SwiftUI
import Combine

// MARK: - Route Destinations

/// All possible navigation destinations in c11.
enum Waypoint: Hashable, Identifiable {
    // Tab roots
    case zonesHub
    case todayBriefing
    case commandCenter

    // Zones drill-down
    case zoneDetail(zoneId: UUID)

    // Today drill-down
    case pressureBreakdown(dayId: UUID)

    var id: String {
        switch self {
        case .zonesHub:                     return "zonesHub"
        case .todayBriefing:                return "todayBriefing"
        case .commandCenter:                return "commandCenter"
        case .zoneDetail(let id):           return "zoneDetail_\(id)"
        case .pressureBreakdown(let id):    return "pressureBreakdown_\(id)"
        }
    }
}

/// Sheet-style modal presentations.
enum Briefing: Identifiable, Hashable {
    case addZone
    case editZone(zoneId: UUID)
    case addGroundPoint(zoneId: UUID)
    case editGroundPoint(zoneId: UUID, pointId: UUID)
    case pickZoneForToday
    case dayEditor(dayId: UUID)
    case addStopFromCatalog(dayId: UUID, zoneId: UUID)
    case quickAddStop(dayId: UUID)
    case achievementUnlocked(medalId: String)
    case rankUpCelebration(rankIndex: Int)
    case intelReport
    case avatarPicker
    case dangerZone

    var id: String {
        switch self {
        case .addZone:                                  return "addZone"
        case .editZone(let id):                         return "editZone_\(id)"
        case .addGroundPoint(let id):                   return "addGP_\(id)"
        case .editGroundPoint(let zId, let pId):        return "editGP_\(zId)_\(pId)"
        case .pickZoneForToday:                         return "pickZone"
        case .dayEditor(let id):                        return "dayEditor_\(id)"
        case .addStopFromCatalog(let dId, let zId):     return "addStop_\(dId)_\(zId)"
        case .quickAddStop(let id):                     return "quickAdd_\(id)"
        case .achievementUnlocked(let id):              return "medal_\(id)"
        case .rankUpCelebration(let idx):               return "rankUp_\(idx)"
        case .intelReport:                              return "intel"
        case .avatarPicker:                             return "avatar"
        case .dangerZone:                               return "danger"
        }
    }
}

/// Alert confirmations.
enum FieldAlert: Identifiable {
    case confirmWithdrawZone(zoneId: UUID)
    case confirmClearToday(dayId: UUID)
    case confirmNuclearReset
    case confirmReassignZone(dayId: UUID, newZoneId: UUID)
    case undoAvailable(message: String)

    var id: String {
        switch self {
        case .confirmWithdrawZone(let id):              return "delZone_\(id)"
        case .confirmClearToday(let id):                return "clearDay_\(id)"
        case .confirmNuclearReset:                      return "nuke"
        case .confirmReassignZone(let dId, let zId):    return "reassign_\(dId)_\(zId)"
        case .undoAvailable(let msg):                   return "undo_\(msg)"
        }
    }
}

// MARK: - Tab Identity

/// The three main tabs of c11.
enum OperationsTab: Int, CaseIterable, Hashable {
    case zones   = 0
    case today   = 1
    case command  = 2

    var label: String {
        switch self {
        case .zones:   return "Zones"
        case .today:   return "Today"
        case .command:  return "HQ"
        }
    }

    var iconGlyph: String {
        switch self {
        case .zones:   return "map.fill"
        case .today:   return "flag.fill"
        case .command:  return "gearshape.fill"
        }
    }
}

// MARK: - MissionRouter

/// Central navigation controller for the entire app.
/// Owned by the root view; passed down via @EnvironmentObject.
final class MissionRouter: ObservableObject {

    // ── Tab ──────────────────────────────────────────────────────
    @Published var activeTab: OperationsTab = .zones

    // ── Navigation stacks (per tab) ─────────────────────────────
    @Published var zonesPath: [Waypoint] = []
    @Published var todayPath: [Waypoint] = []
    @Published var commandPath: [Waypoint] = []

    // ── Sheet / Modal ────────────────────────────────────────────
    @Published var activeBriefing: Briefing? = nil

    // ── Alert ────────────────────────────────────────────────────
    @Published var activeAlert: FieldAlert? = nil

    // ── Toast / Snackbar ─────────────────────────────────────────
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var showUndoButton: Bool = false

    // ── Celebration overlay ──────────────────────────────────────
    @Published var showCelebration: Bool = false
    @Published var celebrationEmoji: String = "🎉"

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Auto-dismiss toast after 2.5s
        $showToast
            .filter { $0 }
            .delay(for: .seconds(2.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.showToast = false
                }
            }
            .store(in: &cancellables)
    }

    // =========================================================================
    // MARK: - Navigation Actions
    // =========================================================================

    /// Push a waypoint onto the current tab's stack.
    func advance(to waypoint: Waypoint) {
        switch activeTab {
        case .zones:    zonesPath.append(waypoint)
        case .today:    todayPath.append(waypoint)
        case .command:  commandPath.append(waypoint)
        }
    }

    /// Pop to root of current tab.
    func retreatToBase() {
        switch activeTab {
        case .zones:    zonesPath = []
        case .today:    todayPath = []
        case .command:  commandPath = []
        }
    }

    /// Switch tab and optionally push a waypoint.
    func switchTab(_ tab: OperationsTab, then waypoint: Waypoint? = nil) {
        activeTab = tab
        if let wp = waypoint {
            // Small delay so tab switch animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.advance(to: wp)
            }
        }
    }

    /// Navigate to Today tab — most common cross-tab jump.
    func jumpToToday() {
        switchTab(.today)
    }

    /// Open zone detail from anywhere.
    func openZoneDetail(zoneId: UUID) {
        switchTab(.zones, then: .zoneDetail(zoneId: zoneId))
    }

    // =========================================================================
    // MARK: - Sheet / Modal Actions
    // =========================================================================

    /// Present a modal briefing sheet.
    func presentBriefing(_ briefing: Briefing) {
        activeBriefing = briefing
    }

    /// Dismiss current sheet.
    func dismissBriefing() {
        activeBriefing = nil
    }

    // =========================================================================
    // MARK: - Alert Actions
    // =========================================================================

    /// Show a confirmation alert.
    func raiseAlert(_ alert: FieldAlert) {
        activeAlert = alert
    }

    /// Clear the alert.
    func dismissAlert() {
        activeAlert = nil
    }

    // =========================================================================
    // MARK: - Toast / Snackbar
    // =========================================================================

    /// Show a brief toast message.
    /// Show a brief toast message. Set showUndo: true when the action can be undone.
    func flashToast(_ message: String, showUndo: Bool = false) {
        toastMessage = message
        showUndoButton = showUndo
        withAnimation(.easeIn(duration: 0.2)) {
            showToast = true
        }
    }

    /// Dismiss toast and clear undo state.
    func dismissToast() {
        withAnimation(.easeOut(duration: 0.3)) {
            showToast = false
        }
        showUndoButton = false
    }

    // =========================================================================
    // MARK: - Celebrations (Gamification)
    // =========================================================================

    /// Trigger a full-screen celebration overlay.
    func celebrate(emoji: String = "🎉") {
        celebrationEmoji = emoji
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showCelebration = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            withAnimation(.easeOut(duration: 0.4)) {
                self?.showCelebration = false
            }
        }
    }

    /// Show achievement unlock modal.
    func announceAchievement(medalId: String) {
        Pulse.success()
        presentBriefing(.achievementUnlocked(medalId: medalId))
    }

    /// Show rank-up celebration.
    func announceRankUp(rankIndex: Int) {
        Pulse.success()
        celebrate(emoji: OperatorRank.ladder[safe: rankIndex]?.badge ?? "🏅")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.presentBriefing(.rankUpCelebration(rankIndex: rankIndex))
        }
    }
}

// MARK: - Toast Overlay View

/// Reusable toast banner — displayed at the top of the screen. Supports optional Undo button.
struct FieldToast: View {
    let message: String
    let isVisible: Bool
    let showUndo: Bool
    let onUndo: () -> Void

    init(message: String, isVisible: Bool, showUndo: Bool = false, onUndo: @escaping () -> Void = {}) {
        self.message = message
        self.isVisible = isVisible
        self.showUndo = showUndo
        self.onUndo = onUndo
    }

    var body: some View {
        if isVisible {
            VStack {
                HStack(spacing: Grid.medium) {
                    Text(message)
                        .font(Signal.briefing(14))
                        .foregroundColor(Palette.deepOpsBase)

                    if showUndo {
                        Button(action: onUndo) {
                            Text("Undo")
                                .font(Signal.briefing(14).weight(.semibold))
                                .foregroundColor(Palette.deepOpsBase)
                                .underline()
                        }
                    }
                }
                .padding(.horizontal, Grid.large)
                .padding(.vertical, Grid.medium)
                .background(Palette.ambitionGold)
                .cornerRadius(Shield.pill)
                .shadow(color: Depth.cardShadow, radius: 8, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))

                Spacer()
            }
            .padding(.top, Grid.large)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isVisible)
        }
    }
}

// MARK: - Celebration Overlay View

/// Full-screen celebration burst for gamification moments.
struct CelebrationOverlay: View {
    let emoji: String
    let isVisible: Bool

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        if isVisible {
            ZStack {
                Palette.blackoutVeil
                    .ignoresSafeArea()

                VStack(spacing: Grid.base) {
                    Text(emoji)
                        .font(.system(size: 80))
                        .scaleEffect(scale)

                    Text("WELL DONE!")
                        .font(Signal.headline(24))
                        .foregroundColor(Palette.ambitionGold)
                }
                .opacity(opacity)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    scale = 1.2
                    opacity = 1
                }
                withAnimation(.easeInOut(duration: 0.3).delay(0.5)) {
                    scale = 1.0
                }
            }
            .allowsHitTesting(false)
        }
    }
}
