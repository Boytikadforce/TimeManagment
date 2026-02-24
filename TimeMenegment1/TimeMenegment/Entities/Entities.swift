// Entities.swift
// c11 — Zone-based day planner with gamification
// Pure data models — Codable, no Core Data

import Foundation

// MARK: - Enums — "Field Codes"

/// Tag for categorizing places inside a district.
enum ErrandTag: Int, Codable, CaseIterable, Identifiable {
    case food       = 0
    case services   = 1
    case shopping   = 2
    case errands    = 3
    case meeting    = 4
    case other      = 5

    var id: Int { rawValue }

    var callSign: String {
        switch self {
        case .food:     return "Food"
        case .services: return "Services"
        case .shopping: return "Shopping"
        case .errands:  return "Errands"
        case .meeting:  return "Meeting"
        case .other:    return "Other"
        }
    }

    var iconGlyph: String {
        switch self {
        case .food:     return "cup.and.saucer.fill"
        case .services: return "wrench.and.screwdriver.fill"
        case .shopping: return "bag.fill"
        case .errands:  return "tray.full.fill"
        case .meeting:  return "person.2.fill"
        case .other:    return "ellipsis.circle.fill"
        }
    }
}

/// Current status of a day plan.
enum MissionStatus: Int, Codable, CaseIterable {
    case vacant      = 0   // no plan yet
    case briefed     = 1   // planned
    case inField     = 2   // in progress
    case accomplished = 3  // all done
    case abandoned   = 4   // user gave up
}

/// Overload / schedule pressure level.
enum PressureLevel: Int, Codable, CaseIterable {
    case steady   = 0   // comfortable
    case dense    = 1   // tight
    case critical = 2   // overloaded

    var label: String {
        switch self {
        case .steady:   return "Steady"
        case .dense:    return "Dense"
        case .critical: return "Overload"
        }
    }

    var iconGlyph: String {
        switch self {
        case .steady:   return "checkmark.shield.fill"
        case .dense:    return "exclamationmark.triangle.fill"
        case .critical: return "flame.fill"
        }
    }
}

/// Type of last action for undo support.
enum FieldAction: Int, Codable {
    case deploy     = 0   // add
    case withdraw   = 1   // delete
    case reposition = 2   // reorder
    case revise     = 3   // edit
    case markDone   = 4   // toggle done
    case blueprint  = 5   // apply template
    case reassign   = 6   // change district
}

// MARK: - District (Zone)

/// A geographic zone / district — the core organizational unit.
struct OperationsZone: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var iconSymbol: String = "mappin.circle.fill"
    var isPinned: Bool = false
    var isArchived: Bool = false
    var sortIndex: Int = 0
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastDeployedAt: Date? = nil

    // Inline catalog of places
    var groundPoints: [GroundPoint] = []

    // Route templates
    var routeBlueprints: [RouteBlueprint] = []
}

// MARK: - Place (Ground Point)

/// A single place / errand inside a district.
struct GroundPoint: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var tag: ErrandTag = .other
    var durationMin: Int = 20
    var bufferMin: Int = 10
    var memo: String = ""
    var isFavorite: Bool = false
    var iconSymbol: String = "mappin"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Total load in minutes
    var totalLoadMin: Int {
        durationMin + bufferMin
    }
}

// MARK: - Day Plan (Field Day)

/// Represents a single day's plan — tied to one district.
struct FieldDay: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var dateKey: String                       // "yyyy-MM-dd"
    var assignedZoneId: UUID                  // which district
    var assignedZoneTitle: String = ""        // snapshot of title
    var status: MissionStatus = .vacant
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Ordered list of planned stops
    var deploymentQueue: [DeploymentStop] = []

    // Variants (alternative plans)
    var alternativeOps: [AlternativeOps] = []

    // Computed
    var totalPlannedMin: Int {
        deploymentQueue.reduce(0) { $0 + $1.loadMin }
    }
    var accomplishedCount: Int {
        deploymentQueue.filter { $0.isAccomplished }.count
    }
    var remainingCount: Int {
        deploymentQueue.count - accomplishedCount
    }
    var progressFraction: Double {
        guard !deploymentQueue.isEmpty else { return 0 }
        return Double(accomplishedCount) / Double(deploymentQueue.count)
    }
}

// MARK: - Deployment Stop (Plan Item)

/// A snapshot of a place inside a day plan, with order and done-state.
struct DeploymentStop: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var groundPointId: UUID                   // reference to catalog place
    var title: String                         // snapshot
    var tag: ErrandTag = .other               // snapshot
    var durationMin: Int = 20                 // snapshot
    var bufferMin: Int = 10                   // snapshot
    var sortIndex: Int = 0
    var isAccomplished: Bool = false
    var accomplishedAt: Date? = nil

    var loadMin: Int {
        durationMin + bufferMin
    }
}

// MARK: - Alternative Ops (Day Variant)

/// An alternative version of a day plan for safe experimentation.
struct AlternativeOps: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String = "Light Plan"
    var stops: [DeploymentStop] = []
    var createdAt: Date = Date()

    var totalPlannedMin: Int {
        stops.reduce(0) { $0 + $1.loadMin }
    }
}

// MARK: - Route Blueprint (Template)

/// A reusable order-template for places in a district.
struct RouteBlueprint: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String = "Quick Route"
    var orderedPointIds: [UUID] = []
    var createdAt: Date = Date()
}

// MARK: - Settings (Command Center Config)

/// Global app settings — singleton.
struct CommandCenterConfig: Codable, Equatable {
    var defaultDurationMin: Int = 20
    var defaultBufferMin: Int = 10
    var densePressureThresholdMin: Int = 180
    var criticalPressureThresholdMin: Int = 240
    var recommendedStopsCount: Int = 8
    var allowZoneChangeDuringDay: Bool = true
    var enableUndoAlerts: Bool = true
    var showTimeBreakdown: Bool = true

    // Gamification settings
    var dailyStreakCount: Int = 0
    var totalMissionsAccomplished: Int = 0
    var lifetimePointsEarned: Int = 0
    var currentRankIndex: Int = 0

    // User profile
    var operatorAvatar: String = "🎯"        // emoji avatar
    var operatorCallSign: String = "Operator" // nickname

    // Onboarding
    var hasCompletedBriefing: Bool = false

    // Notifications
    var enableMorningReminder: Bool = false
    var morningReminderHour: Int = 8
    var morningReminderMinute: Int = 0
}

// MARK: - Undo Snapshot

/// Payload for undo — encodes the state to restore.
struct UndoPayload: Codable {
    var zone: OperationsZone?
    var groundPoint: GroundPoint?
    var groundPointZoneId: UUID?
    var dayId: UUID?
    var deploymentQueue: [DeploymentStop]?
    var fieldDay: FieldDay?  // Full day when day was removed (resetToday)
}

/// Stores the last action for single-step undo.
struct UndoSnapshot: Codable {
    var actionType: FieldAction
    var timestamp: Date = Date()
    var affectedZoneId: UUID?
    var affectedDayId: UUID?
    var affectedPointId: UUID?
    var payload: Data?  // JSON-encoded UndoPayload
}

// MARK: - Gamification — Rank & Achievement

/// Operator rank based on completed missions.
struct OperatorRank: Identifiable {
    let id: Int
    let title: String
    let requiredMissions: Int
    let badge: String

    static let ladder: [OperatorRank] = [
        OperatorRank(id: 0, title: "Recruit",       requiredMissions: 0,   badge: "🔰"),
        OperatorRank(id: 1, title: "Scout",          requiredMissions: 3,   badge: "🏃"),
        OperatorRank(id: 2, title: "Pathfinder",     requiredMissions: 7,   badge: "🧭"),
        OperatorRank(id: 3, title: "Navigator",      requiredMissions: 15,  badge: "🗺"),
        OperatorRank(id: 4, title: "Tactician",      requiredMissions: 30,  badge: "⚔️"),
        OperatorRank(id: 5, title: "Strategist",     requiredMissions: 50,  badge: "🎖"),
        OperatorRank(id: 6, title: "Commander",      requiredMissions: 75,  badge: "🏅"),
        OperatorRank(id: 7, title: "Zone Master",    requiredMissions: 100, badge: "👑"),
    ]
}

/// An achievement / badge the user can earn.
struct FieldMedal: Codable, Identifiable, Equatable {
    var id: String                   // unique key e.g. "first_zone"
    var title: String
    var description: String
    var iconEmoji: String
    var isUnlocked: Bool = false
    var unlockedAt: Date? = nil

    static let catalog: [FieldMedal] = [
        FieldMedal(id: "first_zone",         title: "Zone Pioneer",        description: "Create your first zone",           iconEmoji: "📍"),
        FieldMedal(id: "first_mission",      title: "Mission Start",       description: "Complete your first day",          iconEmoji: "🚀"),
        FieldMedal(id: "five_streak",        title: "Momentum",            description: "5-day streak",                     iconEmoji: "🔥"),
        FieldMedal(id: "ten_zones",          title: "Cartographer",        description: "Create 10 zones",                  iconEmoji: "🗺"),
        FieldMedal(id: "fifty_stops",        title: "Ground Force",        description: "Complete 50 stops total",          iconEmoji: "💪"),
        FieldMedal(id: "perfect_day",        title: "Flawless Op",         description: "Finish all stops in one day",      iconEmoji: "⭐️"),
        FieldMedal(id: "template_master",    title: "Blueprint Architect", description: "Create 3 route templates",         iconEmoji: "📐"),
        FieldMedal(id: "overload_survivor",  title: "Pressure Proof",      description: "Complete an overloaded day",       iconEmoji: "🛡"),
        FieldMedal(id: "first_place",        title: "First Stop",          description: "Add your first stop to a zone",    iconEmoji: "🎯"),
        FieldMedal(id: "ten_streak",         title: "Dedicated",            description: "10-day streak",                    iconEmoji: "💎"),
        FieldMedal(id: "five_zones",         title: "District Planner",     description: "Create 5 zones",                   iconEmoji: "🏘"),
        FieldMedal(id: "hundred_stops",       title: "Centurion",           description: "Complete 100 stops total",         iconEmoji: "🏆"),
        FieldMedal(id: "first_blueprint",    title: "Route Designer",      description: "Create your first blueprint",      iconEmoji: "📋"),
        FieldMedal(id: "twenty_places",       title: "Catalog Builder",     description: "Add 20 stops across zones",        iconEmoji: "📚"),
        FieldMedal(id: "dense_day",          title: "Tight Schedule",      description: "Complete a dense day",            iconEmoji: "⏱"),
        FieldMedal(id: "two_weeks",          title: "Fortnight",           description: "14-day streak",                     iconEmoji: "📅"),
        FieldMedal(id: "twenty_five_streak", title: "Unstoppable",         description: "25-day streak",                    iconEmoji: "🌟"),
        FieldMedal(id: "thirty_missions",     title: "Tactician",          description: "Complete 30 missions",             iconEmoji: "⚔️"),
        FieldMedal(id: "fifty_missions",      title: "Veteran",            description: "Complete 50 missions",             iconEmoji: "🎖"),
        FieldMedal(id: "hundred_missions",    title: "Legend",             description: "Complete 100 missions",            iconEmoji: "👑"),
        FieldMedal(id: "zone_week",          title: "Zone Hopper",         description: "Use 3 zones in 7 days",             iconEmoji: "🦘"),
        FieldMedal(id: "perfect_week",       title: "Flawless Week",       description: "7 perfect days in a row",          iconEmoji: "✨"),
        FieldMedal(id: "catalog_master",     title: "Catalog Master",      description: "50 stops in your catalog",         iconEmoji: "📖"),
        FieldMedal(id: "zone_architect",     title: "Zone Architect",      description: "3 zones with 5+ stops each",        iconEmoji: "🏗"),
        FieldMedal(id: "favorite_collector", title: "Favorite Collector",  description: "Mark 10 stops as favorites",        iconEmoji: "❤️"),
        FieldMedal(id: "tag_explorer",       title: "Tag Explorer",        description: "Use all 6 tag types",               iconEmoji: "🏷"),
        FieldMedal(id: "speed_demon",        title: "Speed Demon",         description: "Complete 15 stops in one day",     iconEmoji: "⚡"),
        FieldMedal(id: "comeback_king",      title: "Comeback",            description: "Complete day after abandoning",     iconEmoji: "🔄"),
        FieldMedal(id: "repeat_zone",        title: "Loyal Operator",      description: "Same zone 5 days in a row",         iconEmoji: "🎯"),
        FieldMedal(id: "five_blueprints",    title: "Blueprint Master",    description: "Create 5 blueprints",              iconEmoji: "📐"),
    ]
}

// MARK: - Statistics Snapshot

/// Aggregated stats for analytics screen.
struct IntelReport: Codable {
    var periodDays: Int = 7
    var totalMissions: Int = 0
    var totalStopsCompleted: Int = 0
    var totalMinutesPlanned: Int = 0
    var averageStopsPerDay: Double = 0
    var mostUsedTag: ErrandTag = .other
    var mostActiveZoneTitle: String = ""
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var completionRate: Double = 0  // 0...1
}

// MARK: - Quick-add Presets (for Onboarding)

/// Predefined place presets for fast onboarding.
struct QuickDeployPreset: Identifiable {
    let id = UUID()
    let title: String
    let tag: ErrandTag
    let icon: String

    static let starterKit: [QuickDeployPreset] = [
        QuickDeployPreset(title: "Coffee Shop",    tag: .food,     icon: "cup.and.saucer.fill"),
        QuickDeployPreset(title: "Pharmacy",        tag: .services, icon: "cross.case.fill"),
        QuickDeployPreset(title: "Grocery Store",   tag: .shopping, icon: "cart.fill"),
        QuickDeployPreset(title: "Pickup Point",    tag: .errands,  icon: "shippingbox.fill"),
        QuickDeployPreset(title: "Bank",            tag: .services, icon: "building.columns.fill"),
        QuickDeployPreset(title: "Repair Shop",     tag: .services, icon: "wrench.fill"),
        QuickDeployPreset(title: "Park",            tag: .other,    icon: "leaf.fill"),
        QuickDeployPreset(title: "Meeting Spot",    tag: .meeting,  icon: "person.2.fill"),
    ]
}
