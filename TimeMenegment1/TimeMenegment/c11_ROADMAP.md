# c11 — Roadmap & Improvement Plan

> All improvements are **local-only, offline, single iOS target**.  
> No accounts, no external APIs, no cloud sync, no additional targets.

---

## 🔴 Priority 1 — Critical Fixes & Missing Pieces

These items are needed to make the current build fully functional and stable.

### 1.1 Wire ZoneDetailView into Navigation

**Problem:** `ZoneDetailPlaceholder` is used in `ZonesHubView` navigation destination instead of the real `ZoneDetailView`.

**Fix:** Replace the placeholder in `navigationDestination` with `ZoneDetailPlaceholder.makeReal(zoneId:router:)` factory that already exists in `c11App.swift`. Pass the `router` from `@EnvironmentObject`.

**Effort:** ~15 min

---

### 1.2 Undo System — Full Implementation

**Problem:** `UndoSnapshot` entity exists, `snapshotForUndo()` is called in DataVault, but actual undo execution is not wired.

**Tasks:**
- Store full previous state in `UndoSnapshot.payload` (encode affected entity as JSON Data)
- Add `executeUndo()` method to DataVault that decodes payload and restores state
- Wire undo to toast action button ("Undo" tap → `executeUndo()`)
- Support undo for: delete zone, delete place, delete stop, clear day, reorder
- Auto-expire undo after 10 seconds

**Effort:** ~3–4 hours

---

### 1.3 Edit Place — Proper Update Flow

**Problem:** In `sheetContent(for: .editGroundPoint)` a new `GroundPoint` is created with the same `pointId`, but `updatedAt`, `createdAt`, and `isFavorite` fields are lost.

**Fix:** Load existing point from vault, mutate only changed fields, pass to `updatePlace()`.

**Effort:** ~30 min

---

### 1.4 Data Migration Safety

**Problem:** If entity structures change between versions, JSON decoding will fail silently and return empty arrays.

**Tasks:**
- Add a `schemaVersion: Int` field to each JSON file
- Implement migration logic in `DataVault.loadAll()` — if version mismatch, attempt migration or preserve raw backup
- Add `CodingKeys` with default values for all new optional fields

**Effort:** ~2 hours

---

### 1.5 FlowLayout iOS 15 Compatibility

**Problem:** The custom `FlowLayout` uses the `Layout` protocol which requires iOS 16+. The app targets iOS 15.

**Fix:** Create a fallback `FlowLayout_Legacy` using `GeometryReader` + preference keys for iOS 15, or wrap in `if #available(iOS 16, *)` with a simple `VStack` fallback.

**Effort:** ~1 hour

---

## 🟡 Priority 2 — Core Feature Enhancements

These make the app significantly more useful and complete.

### 2.1 Day History Screen (4th Tab or Sub-screen)

**What:** A scrollable list/calendar of past field days with status, zone, stops count, and completion rate.

**Features:**
- Calendar strip or list view (grouped by week/month)
- Filter by status (accomplished, abandoned, partial)
- Filter by zone
- Tap → read-only day detail with all stops and their accomplished state
- "Copy to Today" action — clone a past day's plan into today
- Stats summary at the top (total days, completion rate for visible range)

**Where:** Either as a 4th tab "Log" or as a push screen from HQ.

**Effort:** ~6–8 hours

---

### 2.2 Drag-and-Drop for Zone Reordering

**What:** Allow users to reorder zones in ZonesHubView via long-press drag.

**Tasks:**
- Add `.onMove` to zones list
- Wire to `DataVault.reorderZones(fromOffsets:toOffset:)`
- Add `normalizeZoneSortIndices()` call after move
- Toggle edit mode via toolbar button

**Effort:** ~1–2 hours

---

### 2.3 Route Blueprints — Full Apply Flow

**What:** Currently blueprints are saved but cannot be applied to today's plan.

**Tasks:**
- Add "Apply Blueprint" button in Today's day editor
- Match blueprint point IDs to current zone catalog
- Auto-add matched places in blueprint order
- Show "2 of 5 places not found" warning for missing ones
- Option to skip missing or quick-create them

**Effort:** ~3 hours

---

### 2.4 Day Variants — Comparison UI

**What:** `AlternativeOps` entity exists but there's no UI to view, switch, or compare variants.

**Tasks:**
- Add variant selector (segmented control) at top of Today view
- Show side-by-side: stops count, total minutes, pressure level
- "Apply Variant" button replaces main queue with variant stops
- "Delete Variant" with undo

**Effort:** ~4 hours

---

### 2.5 Batch Add to Today

**What:** In `AddFromCatalogSheet`, add multi-select mode — tap several places, then deploy all at once.

**Tasks:**
- Add selection state (Set<UUID>) to the sheet
- "Deploy Selected (N)" button at bottom
- Haptic + count badge animation
- Sort deployed stops by catalog order

**Effort:** ~2 hours

---

### 2.6 Place Notes — Rich Display

**What:** `GroundPoint.memo` exists but is never shown in cards or stop rows.

**Tasks:**
- Show memo preview (1 line, truncated) in `GroundPointCard` and `DeploymentStopRow`
- Expandable memo on tap in detail view
- Memo icon indicator on cards that have notes

**Effort:** ~1 hour

---

## 🟢 Priority 3 — Gamification & Engagement

### 3.1 Daily Challenge System

**What:** Each day, generate a random challenge based on user's history.

**Examples:**
- "Complete all stops before 3 PM" (honor system — user taps "I did it")
- "Visit a zone you haven't used in 7+ days"
- "Complete a day with 0 buffers"
- "Use all 6 tag categories in one day"
- "Finish an overloaded day"

**Implementation:**
- `DailyChallenge` entity with `id`, `title`, `description`, `type`, `isCompleted`, `dateKey`
- Generate on first launch of the day from a pool of ~20 templates
- Show challenge card at top of Today view
- Award bonus XP (25–50) for completion
- Track challenge completion streak separately

**Effort:** ~4–5 hours

---

### 3.2 Weekly Summary Report

**What:** Every Monday (or configurable day), show a "Week in Review" modal with animated stats.

**Content:**
- Missions completed vs previous week (↑/↓ arrow)
- Total stops accomplished
- Most productive day
- Most visited zone
- Streak status
- Medals earned this week
- Motivational quote (from a local array of ~30 quotes)

**Trigger:** On first app open of the week, before regular UI.

**Effort:** ~3 hours

---

### 3.3 XP Multipliers & Bonus Events

**What:** Make XP earn rate variable to add excitement.

**Rules:**
- Base: 10 XP per stop
- Streak bonus: +2 XP per stop for every consecutive day (cap at +20)
- Overload survivor: 2× XP for all stops in an overloaded day
- Perfect day: +50 XP bonus
- First stop of the day: +5 XP bonus
- Challenge completion: +25–50 XP

**Implementation:**
- `XPCalculator` utility that takes stop context and returns final XP
- Show XP breakdown in a toast or inline "+10 +2 streak = 12 XP"

**Effort:** ~2 hours

---

### 3.4 Expanded Medal System (20+ Medals)

**New medal ideas:**
- "Early Bird" — complete first stop before 9 AM (honor system)
- "Night Owl" — complete last stop after 8 PM
- "Speed Runner" — complete all stops in under 2 hours of planned time
- "Minimalist" — complete a day with exactly 3 stops
- "Heavy Lifter" — complete a day with 10+ stops
- "Zone Collector" — use 5 different zones in 7 days
- "Template Pro" — apply 5 blueprints
- "Streak Legend" — 30-day streak
- "Century" — 100 total stops completed
- "Veteran" — 200 missions accomplished
- "Perfectionist" — 10 perfect days
- "Explorer" — create 20 unique places

**Effort:** ~2–3 hours

---

### 3.5 Rank Perks (Cosmetic Unlocks)

**What:** Higher ranks unlock cosmetic features.

**Ideas:**
- Rank 2 (Scout): Unlock "Nature" emoji section for avatar
- Rank 3 (Pathfinder): Unlock custom zone colors (3 accent options)
- Rank 4 (Navigator): Unlock animated progress ring styles
- Rank 5 (Tactician): Unlock golden zone card borders
- Rank 6 (Strategist): Unlock additional app accent colors
- Rank 7 (Commander): Unlock animated celebration particles style
- Rank 8 (Zone Master): Unlock platinum card style + crown badge on profile

**Implementation:**
- `UnlockableFeature` enum checked against current rank
- Gate cosmetic options in avatar picker and settings
- Show "Unlock at Rank X" label for locked features

**Effort:** ~4–5 hours

---

## 🔵 Priority 4 — UX & Polish

### 4.1 Keyboard Avoidance — Global

**What:** Ensure all text fields scroll into view when keyboard appears.

**Tasks:**
- Add `ScrollViewReader` + `onChange(of: focused)` → `scrollTo(fieldId)`
- Test on iPhone SE (smallest screen) and iPhone 15 Pro Max
- Verify all sheets: AddZone, AddGroundPoint, QuickAdd, AvatarPicker, Onboarding
- Add `@FocusState` bindings to all TextFields

**Effort:** ~2 hours

---

### 4.2 Reduce Motion Support

**What:** Respect `UIAccessibility.isReduceMotionEnabled`.

**Tasks:**
- Create `@Environment(\.accessibilityReduceMotion)` checks
- Replace spring animations with simple opacity fades
- Disable particle fields, rotation effects, pulsing dots
- Keep functional animations (progress bar fill, reorder)

**Effort:** ~2 hours

---

### 4.3 Dynamic Type Support

**What:** All text should scale with system Dynamic Type settings.

**Tasks:**
- Replace fixed `Signal` font sizes with `.scaled()` variants or use `@ScaledMetric`
- Test with all accessibility sizes (xSmall → AX5)
- Ensure cards don't clip at largest sizes — use flexible heights
- Add `minimumScaleFactor` where truncation is critical

**Effort:** ~3 hours

---

### 4.4 Haptic Feedback — Expanded

**What:** Add haptics to more interactions.

**Map:**
- Toggle accomplished → `.medium` ✅ (done)
- Drag start → `.light`
- Drag drop → `.medium`
- Swipe delete → `.warning`
- Sheet dismiss → `.light`
- Tab switch → `.light` (subtle)
- Overload threshold crossed → `.warning`
- Medal unlock → `.success` ✅ (done)
- Progress ring complete → `.success`

**Effort:** ~1 hour

---

### 4.5 Empty State Illustrations

**What:** Replace simple SF Symbols in empty states with richer custom illustrations.

**Approach:** Build illustrations from composed SF Symbols + shapes in SwiftUI (no image assets needed).

**Screens:**
- No zones → Animated map with floating pins
- No stops in zone → Building with pulsing door
- Empty today queue → Flag planting animation
- No mission today → Compass spinning

**Effort:** ~3–4 hours

---

### 4.6 Smooth iOS 26 (Liquid Glass) Preparation

**What:** Ensure the app looks great on both iOS 16 and iOS 26 with potential Liquid Glass design changes.

**Tasks:**
- Use `.background(.regularMaterial)` / `.ultraThinMaterial` as alternatives to solid colors where appropriate
- Add `if #available(iOS 26, *)` blocks for new glass effects
- Test tab bar, navigation bar, and sheets with new system styles
- Keep `.toolbarColorScheme(.dark)` for explicit dark mode
- Consider `.glassEffect()` modifier on key cards when available

**Effort:** ~2–3 hours

---

### 4.7 Confirmation Dialogs → Swipe-to-Delete

**What:** Replace some Alert-based confirmations with native swipe-to-delete + undo toast pattern (feels more iOS-native).

**Where:**
- Zone deletion: swipe → delete → "Zone removed • Undo" toast (10s)
- Stop deletion: already has swipe, add undo toast
- Place deletion: already has swipe, add undo toast

**Effort:** ~2 hours

---

## 🟣 Priority 5 — Power User Features

### 5.1 Search Across Everything

**What:** Global search that finds zones, places, and past days.

**Implementation:**
- Search bar on a dedicated screen or in HQ
- Results grouped: "Zones", "Stops", "Past Days"
- Tap result → navigate to detail
- Debounced, in-memory filtering (no need for full-text index at this scale)

**Effort:** ~3 hours

---

### 5.2 Bulk Edit Mode for Places

**What:** Select multiple places in a zone catalog and perform bulk actions.

**Actions:**
- Delete selected
- Change tag for all selected
- Add all selected to today
- Set duration for all selected
- Create blueprint from selected

**UI:**
- Toggle "Select" mode in toolbar
- Checkbox on each card
- Bottom action bar with available operations

**Effort:** ~4 hours

---

### 5.3 Place Duplication Across Zones

**What:** Copy a place from one zone to another.

**Flow:**
- Long-press place → "Copy to Zone…" → zone picker → confirm
- Creates a new GroundPoint with same properties in target zone

**Effort:** ~1–2 hours

---

### 5.4 Recurring Day Templates

**What:** Save an entire day plan as a reusable template (not just route order, but full stop snapshots).

**Implementation:**
- "Save Day as Template" action in day editor
- `DayTemplate` entity: name, zone reference, ordered stops with durations
- "Apply Day Template" in zone picker or today view
- Template management screen in HQ

**Effort:** ~4 hours

---

### 5.5 Time-of-Day Hints

**What:** Optional start time + sequential time labels for each stop.

**Implementation:**
- Optional "Day starts at" time picker in Today view header
- Calculate cumulative time: Stop 1 at 9:00, Stop 2 at 9:30, etc.
- Show time labels next to each stop in deployment queue
- Update dynamically when stops are reordered

**Effort:** ~3 hours

---

### 5.6 Local Notifications (Optional)

**What:** Reminders to plan tomorrow's zone, or streak-preservation alerts.

**Types:**
- Evening reminder: "Plan tomorrow's zone?" (configurable time)
- Morning reminder: "Today's mission: [Zone Name] — [N stops]"
- Streak at risk: "Don't break your [N]-day streak!"

**Implementation:**
- `UNUserNotificationCenter` — fully local, no server
- Toggle on/off in HQ settings
- Time picker for reminder times

**Effort:** ~3 hours

---

### 5.7 Data Export — JSON Backup/Restore

**What:** Allow users to export all data as a single JSON file and reimport it.

**Implementation:**
- "Export Backup" → creates a `.c11backup` JSON file with all entities
- Share via `UIActivityViewController` (save to Files, AirDrop, etc.)
- "Import Backup" → file picker → decode → confirm overwrite → apply
- Include schema version in export for forward compatibility

**Effort:** ~3–4 hours

---

## ⚪ Priority 6 — Nice-to-Have Enhancements

### 6.1 Zone Color Accents

Allow each zone to have one of 6 accent colors (from a preset palette). Show the color as a left border stripe on zone cards and in the Today header.

### 6.2 Stop Sorting Options

In zone detail, add sort options: by name, by tag, by duration, by date added, by most used. Default: favorites first + date added.

### 6.3 Shake to Undo

Implement `UIResponder` shake gesture → trigger last undo if available.

### 6.4 Long-Press Quick Actions (Home Screen)

Add `UIApplicationShortcutItem` for:
- "New Zone"
- "Open Today"
- "Quick Add Stop"

### 6.5 Widget Support (WidgetKit)

A small home screen widget showing:
- Today's zone name
- Progress ring (done/total)
- Streak count

> Note: This requires a widget extension target, which is a second target. Include only if "single target" rule is relaxed.

### 6.6 Animated Tab Bar Badge

Show a badge on the Today tab when there are uncompleted stops, pulsing dot on HQ when a new medal is unlocked.

### 6.7 Confetti Particles on Perfect Day

Replace the simple celebration overlay with a full confetti particle system (gold + green particles falling from top, randomized sizes and velocities).

### 6.8 Onboarding — "See Example" Flow

The welcome screen has "See Example" button but no example flow. Create a pre-populated sample zone ("Demo District") with 5 sample places that the user can explore, then delete.

---

## 📊 Effort Summary

| Priority | Items | Est. Total Hours |
|----------|-------|-----------------|
| 🔴 P1 — Critical Fixes | 5 | ~8 hours |
| 🟡 P2 — Core Features | 6 | ~18 hours |
| 🟢 P3 — Gamification | 5 | ~16 hours |
| 🔵 P4 — UX & Polish | 7 | ~16 hours |
| 🟣 P5 — Power User | 7 | ~21 hours |
| ⚪ P6 — Nice-to-Have | 8 | ~12 hours |
| **Total** | **38 items** | **~91 hours** |

---

## 🗓 Suggested Sprint Plan

### Sprint 1 (Week 1–2): Stability
- All P1 critical fixes
- Keyboard avoidance (P4.1)
- Reduce Motion (P4.2)
- Undo system wired

### Sprint 2 (Week 3–4): Core Completeness
- Day History screen (P2.1)
- Blueprint apply flow (P2.3)
- Day Variants UI (P2.4)
- Place notes display (P2.6)

### Sprint 3 (Week 5–6): Gamification Push
- Daily challenges (P3.1)
- XP multipliers (P3.3)
- Expanded medals (P3.4)
- Weekly summary (P3.2)

### Sprint 4 (Week 7–8): Polish & Power
- Dynamic Type (P4.3)
- Empty state illustrations (P4.5)
- iOS 26 preparation (P4.6)
- Global search (P5.1)
- Time-of-day hints (P5.5)

### Sprint 5 (Week 9–10): Advanced
- Rank perks (P3.5)
- Bulk edit mode (P5.2)
- Recurring day templates (P5.4)
- JSON backup/restore (P5.7)
- Local notifications (P5.6)

---

*Last updated: February 2026*
*Target: iOS 15+ • Single target • Offline-only • SwiftUI + VIPER*
