# Architecture Patterns

**Domain:** WidgetKit extension + HealthKit integration + data export for macOS SwiftUI menu bar app
**Researched:** 2026-02-26
**Confidence:** HIGH (WidgetKit/HealthKit macOS patterns well-established as of training cutoff; verified against actual codebase files)

---

## Recommended Architecture

The three v1.2 features each require a distinct integration pattern, but they share a foundation: the **App Group shared container** (mandatory for WidgetKit). The existing `HydrationManager` singleton remains the single source of truth. Each new subsystem is additive — no rewrites of existing logic.

```
┌────────────────────────────────────────────────────────────────────┐
│  HydroBar Main App (com.adxcool.HydroBar)                          │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  HydrationManager (existing singleton)                      │    │
│  │  - currentMl, targetMl, historyEntries                      │    │
│  │  - addWater() → (NEW) AppGroupStore.write()                 │    │
│  │  - addWater() → (NEW) WidgetCenter.reloadTimelines()        │    │
│  │  - addWater() → (NEW) HealthKitWriter.write()               │    │
│  └──────┬───────────────────────┬──────────────────────────────┘   │
│         │                       │                                    │
│  ┌──────▼──────────┐  ┌─────────▼──────────┐  ┌────────────────┐  │
│  │ AppGroupStore   │  │ HealthKitWriter     │  │ ExportManager  │  │
│  │ (NEW)           │  │ (NEW)               │  │ (NEW)          │  │
│  │ UserDefaults    │  │ HKHealthStore       │  │ NSSavePanel    │  │
│  │ (suiteName:)    │  │ HKQuantityType      │  │ CSV/JSON       │  │
│  └──────┬──────────┘  │ .dietaryWater       │  │ formatter      │  │
│         │             └────────────────────┘  └────────────────┘  │
└─────────│──────────────────────────────────────────────────────────┘
          │ App Group: group.com.adxcool.HydroBar
          │
┌─────────▼──────────────────────────────────────────────────────────┐
│  HydroBarWidget Extension (com.adxcool.HydroBar.Widget)             │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  HydroBarTimelineProvider : TimelineProvider               │    │
│  │  - Reads AppGroupStore (shared UserDefaults)               │    │
│  │  - Returns Timeline<HydrationEntry> with policy: .never    │    │
│  └────────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  SmallWidgetView / MediumWidgetView / LargeWidgetView      │    │
│  │  - Stateless SwiftUI views                                  │    │
│  │  - Render HydrationEntry snapshot; no @StateObject         │    │
│  └────────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
```

---

## Component Boundaries

| Component | Target | Responsibility | Reads From | Writes To |
|-----------|--------|---------------|------------|-----------|
| `HydrationManager` | Main App | Source of truth — all hydration state and business logic | `@AppStorage` (UserDefaults.standard), JSON files in App Support | UserDefaults.standard, JSON files, App Group store (new side effect) |
| `AppGroupStore` | Main App + Widget | Bridge between main app and widget extension | Called by HydrationManager after each mutation | Shared `UserDefaults(suiteName: "group.com.adxcool.HydroBar")` |
| `HealthKitAuthManager` | Main App | Authorization flow and permission state tracking | `HKHealthStore.authorizationStatus()` | `HKHealthStore.requestAuthorization()` |
| `HealthKitWriter` | Main App | Writes water samples to Apple Health | `HydrationManager.addWater()` call | `HKHealthStore` |
| `ExportManager` | Main App | Formats and saves CSV/JSON export file | `HydrationManager.shared.historyEntries` | File system via `NSSavePanel` |
| `HydroBarTimelineProvider` | Widget Extension | Supplies widget timeline snapshots to WidgetKit | App Group `UserDefaults(suiteName:)` | Nothing (read-only) |
| `SmallWidgetView` / `MediumWidgetView` / `LargeWidgetView` | Widget Extension | Render hydration data as SwiftUI widget views | `HydrationEntry` (timeline entry value) | Nothing |

---

## App Group Shared Container Setup

### What It Is and Why It Is Required

A widget extension runs in a **separate sandboxed process** from the main app. It cannot access:
- The main app's `~/Library/Application Support/HydroBar/` directory
- The main app's standard `UserDefaults` container
- Any `@Published` properties, singletons, or live objects from `HydrationManager`

The App Group shared container is the **only sanctioned mechanism** for data sharing between processes in a sandboxed macOS app.

### Required Entitlement Changes

**In `HydroBar.entitlements` (existing main app entitlements file), add:**
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.adxcool.HydroBar</string>
</array>
```

**New entitlements file for the widget extension target (`HydroBarWidget.entitlements`):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.adxcool.HydroBar</string>
    </array>
</dict>
</plist>
```

The group identifier `group.com.adxcool.HydroBar` must be **identical** in both targets. A mismatch causes silent data isolation — the widget reads empty/stale data with no crash or error.

### AppGroupStore Implementation

`AppGroupStore.swift` is added to **both** the main app target and the widget extension target via Xcode's target membership (file inspector). No separate framework needed.

```swift
// AppGroupStore.swift
// Target membership: HydroBar (main app) AND HydroBarWidget (widget extension)

import Foundation

struct AppGroupStore {
    static let suiteName = "group.com.adxcool.HydroBar"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private enum Key {
        static let currentMl  = "widget_currentMl"
        static let targetMl   = "widget_targetMl"
        static let unit       = "widget_unit"
        static let lastUpdated = "widget_lastUpdated"
        static let weekHistory = "widget_weekHistory"
    }

    // Write — called by main app after each addWater() or daily reset
    static func write(
        currentMl: Double,
        targetMl: Double,
        unit: String,
        weekHistory: [HistoryEntrySnapshot]
    ) {
        defaults.set(currentMl, forKey: Key.currentMl)
        defaults.set(targetMl, forKey: Key.targetMl)
        defaults.set(unit, forKey: Key.unit)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastUpdated)
        if let encoded = try? JSONEncoder().encode(weekHistory) {
            defaults.set(encoded, forKey: Key.weekHistory)
        }
    }

    // Read — called by widget TimelineProvider
    static func read() -> HydrationSnapshot {
        HydrationSnapshot(
            currentMl:   defaults.double(forKey: Key.currentMl),
            targetMl:    defaults.double(forKey: Key.targetMl),
            unit:        defaults.string(forKey: Key.unit) ?? "cl",
            lastUpdated: Date(timeIntervalSince1970: defaults.double(forKey: Key.lastUpdated)),
            weekHistory: {
                guard let data = defaults.data(forKey: Key.weekHistory),
                      let decoded = try? JSONDecoder().decode([HistoryEntrySnapshot].self, from: data)
                else { return [] }
                return decoded
            }()
        )
    }
}

// Minimal Codable snapshot — no dependency on HydrationManager or AppKit
struct HydrationSnapshot: Codable {
    let currentMl: Double
    let targetMl: Double
    let unit: String
    let lastUpdated: Date
    let weekHistory: [HistoryEntrySnapshot]

    var progress: Double { min(currentMl / max(targetMl, 1), 1.0) }
}

struct HistoryEntrySnapshot: Codable {
    let date: Date
    let amountMl: Double
    let targetMl: Double
    var isComplete: Bool { amountMl >= targetMl }
}
```

**Why minimal snapshot structs and not reusing `HistoryEntry` directly:**
The widget extension cannot import from the main app target. `HistoryEntry` is defined inside `HydrationManager.swift`, which transitively imports AppKit. Duplicating two small Codable structs avoids this dependency chain without requiring a shared framework.

### Hook into HydrationManager

Add to `HydrationManager.addWater()`, `checkAndResetIfNeeded()`, and any `targetMl` change:

```swift
// In HydrationManager.addWater():
func addWater(amount: Double, skipUndo: Bool = false) {
    // ... all existing logic unchanged ...
    currentMl += amount
    saveTodayEntry()
    scheduleNotifications()

    // NEW: sync to App Group for widget
    syncToAppGroup()

    // NEW: trigger widget timeline refresh
    WidgetCenter.shared.reloadTimelines(ofKind: "HydroBarWidget")

    // NEW: write to HealthKit if enabled
    if healthKitEnabled {
        if #available(macOS 13.0, *) {
            HealthKitWriter.write(amountMl: amount, date: Date())
        }
    }
}

// NEW helper method
private func syncToAppGroup() {
    let snapshots = getLast7DaysSnapshotsForWidget()
    AppGroupStore.write(
        currentMl: currentMl,
        targetMl: targetMl,
        unit: selectedUnit.rawValue,
        weekHistory: snapshots
    )
}
```

**Design rule:** The main app is the exclusive writer to the App Group store. The widget extension never writes. This prevents any data integrity issues.

---

## WidgetKit Timeline Provider Architecture

### How TimelineProvider Works

WidgetKit calls the `TimelineProvider` when it needs display data. The provider runs inside the widget extension process, not the main app process. It must:

1. Read current state from the App Group shared `UserDefaults`
2. Construct a `TimelineEntry` value (a snapshot of data at a point in time)
3. Return a `Timeline<Entry>` with a refresh policy

```swift
// HydroBarWidget.swift — Widget Extension target only

import WidgetKit
import SwiftUI

// The data model for one widget "frame"
struct HydrationEntry: TimelineEntry {
    let date: Date
    let snapshot: HydrationSnapshot
}

// The provider — called by WidgetKit when it needs timeline data
struct HydroBarTimelineProvider: TimelineProvider {

    // Called when WidgetKit needs a placeholder (e.g., during widget gallery)
    func placeholder(in context: Context) -> HydrationEntry {
        HydrationEntry(date: Date(), snapshot: HydrationSnapshot(
            currentMl: 1200, targetMl: 2000, unit: "cl",
            lastUpdated: Date(), weekHistory: []
        ))
    }

    // Called for the widget gallery preview — return current state quickly
    func getSnapshot(in context: Context, completion: @escaping (HydrationEntry) -> Void) {
        completion(HydrationEntry(date: Date(), snapshot: AppGroupStore.read()))
    }

    // Called when WidgetKit needs to build a timeline for display
    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        let snapshot = AppGroupStore.read()
        let entry = HydrationEntry(date: Date(), snapshot: snapshot)

        // .never: do not auto-refresh on a schedule.
        // The main app calls WidgetCenter.reloadTimelines() after each water addition.
        // This gives the main app full control over widget freshness.
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// Widget bundle entry point
@main
struct HydroBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        HydroBarWidget()
    }
}

// Widget configuration — declares sizes and binds provider to view
struct HydroBarWidget: Widget {
    let kind = "HydroBarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HydroBarTimelineProvider()) { entry in
            HydroBarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("HydroBar")
        .description("Track your daily hydration.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// Router view — dispatches to size-specific views
struct HydroBarWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HydrationEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        case .systemLarge:  LargeWidgetView(entry: entry)
        default:            SmallWidgetView(entry: entry)
        }
    }
}
```

### Why `.never` as Refresh Policy

Using `.never` means WidgetKit will not automatically refresh the widget on a schedule. Updates happen exclusively when `HydrationManager` calls `WidgetCenter.shared.reloadTimelines(ofKind:)`. This is correct for HydroBar because:
- The data only changes when the user adds water (user-driven, not time-driven)
- No meaningful timeline prediction is possible (we cannot know when the user will next drink)
- `.atEnd` or `.after(Date)` would wake the widget process unnecessarily

### Widget View Architecture

Each widget view is a **stateless SwiftUI view**. No `@StateObject`, no `@EnvironmentObject`, no access to `HydrationManager`. All data is embedded in the `HydrationEntry` that WidgetKit passes at render time.

| Widget Size | Contents | Data From Entry |
|-------------|----------|----------------|
| Small | Progress ring + percentage | `snapshot.currentMl`, `snapshot.targetMl` |
| Medium | Ring + daily amount + goal + streak count | `snapshot.currentMl`, `snapshot.targetMl`, `snapshot.unit` |
| Large | Ring + 7-day bar chart | All of above + `snapshot.weekHistory[7]` |

The existing `ProgressRingView.swift` can be reused in the widget by adding it to the widget extension target's membership in Xcode — provided it contains no AppKit imports. Inspect it before adding; if it references `NSColor` or similar AppKit types, create a widget-specific version using only SwiftUI/CoreGraphics.

### macOS Widget Availability

- **Desktop widgets / Notification Center widgets**: macOS 14.0+ (Sonoma)
- **Menu bar widgets**: macOS 14.0+ (Sonoma)
- The main app targets macOS 12.0+. The widget extension can have a higher deployment target (macOS 14.0) without affecting the main app. On macOS 12/13, the widget simply won't be available — this is expected behavior.

---

## HealthKit Integration Architecture

### Platform Constraint — Critical

HealthKit on macOS is available from **macOS 13.0 (Ventura)**. The current deployment target is macOS 12.0. All HealthKit code must be guarded:

```swift
if #available(macOS 13.0, *) {
    // HealthKit code here
}
```

The HealthKit toggle in `SettingsView` must be hidden on macOS 12:

```swift
if #available(macOS 13.0, *) {
    HealthKitSection()
} else {
    Text("Requires macOS 13 or later")
        .foregroundStyle(.secondary)
}
```

### Required Changes

**`HydroBar.entitlements` — add:**
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array>
    <string>HKQuantityTypeIdentifierDietaryWater</string>
</array>
```

**`Info.plist` — add:**
```xml
<key>NSHealthUpdateUsageDescription</key>
<string>HydroBar writes your water intake to Apple Health to keep your health data in one place.</string>
```

**Signing constraint:** HealthKit entitlements require a paid Apple Developer Program membership to be signed. A free personal team cannot enable this entitlement. Development and testing of HealthKit requires a paid account.

### HealthKit Authorization Flow

Authorization is presented once per installation. The system remembers the user's choice; the app checks status rather than re-requesting.

```
SettingsView "Enable Apple Health" toggle → ON
    ↓
HealthKitAuthManager.requestAuthorization()
    ↓
HKHealthStore.requestAuthorization(toShare: [dietaryWater], read: [])
    ↓
System permission sheet presented to user
    ↓
User grants or denies
    ↓
HealthKitAuthManager.checkStatus() → updates @Published isAuthorized
    ↓
SettingsView reflects: "Active" / "Not authorized — open Health settings"
```

```swift
// HealthKitAuthManager.swift — Main app target only

import HealthKit

@available(macOS 13.0, *)
class HealthKitAuthManager: ObservableObject {
    static let shared = HealthKitAuthManager()
    private init() {}

    private let store = HKHealthStore()
    private let waterType = HKQuantityType(.dietaryWater)

    @Published var isAuthorized: Bool = false
    let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()

    func checkStatus() {
        let status = store.authorizationStatus(for: waterType)
        DispatchQueue.main.async {
            self.isAuthorized = (status == .sharingAuthorized)
        }
    }

    func requestAuthorization() async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [waterType], read: [])
            checkStatus()
        } catch {
            print("HealthKit authorization error: \(error)")
        }
    }
}
```

### HealthKitWriter

Stateless writer. Fire-and-forget. Called from `HydrationManager.addWater()` as a side effect.

```swift
// HealthKitWriter.swift — Main app target only

import HealthKit

@available(macOS 13.0, *)
struct HealthKitWriter {
    private static let store = HKHealthStore()

    /// Write a single water intake sample to Apple Health.
    /// amountMl is always in milliliters (matches HydrationManager's internal unit).
    static func write(amountMl: Double, date: Date = Date()) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let waterType = HKQuantityType(.dietaryWater)
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: amountMl)
        let sample = HKQuantitySample(
            type: waterType,
            quantity: quantity,
            start: date,
            end: date
        )
        store.save(sample) { _, error in
            if let error = error {
                print("HealthKit write error: \(error.localizedDescription)")
            }
        }
    }
}
```

**Why write-only (no read):** Reading HealthKit data creates bidirectional sync. If the user also logs water in another app, the imported values would inflate `HydrationManager`'s `currentMl`. A feedback loop is possible (read-in → add to currentMl → write back). Write-only avoids this entirely and matches the v1.2 spec.

### HealthKit Settings UI

```
SettingsView (macOS 13+ only section)
├── Toggle: "Write water intake to Apple Health"  [@AppStorage("healthKitEnabled")]
│   └── onChange(of: isOn) { if isOn { Task { await HealthKitAuthManager.shared.requestAuthorization() } } }
├── Status label:
│   ├── isAuthorized == true → "Active"
│   ├── isAvailable == false → "Apple Health is not available on this Mac"
│   └── else → "Not authorized — enable in System Settings > Privacy > Health"
└── "Open Health Settings" button → NSWorkspace.shared.open(URL for Health prefs)
```

---

## Data Export Architecture

Export is the simplest feature. No new process, no extension target, no HealthKit-like entitlement complexity. The data already exists in `HydrationManager.shared.historyEntries`.

### Required Entitlement Change

The current entitlements file has `com.apple.security.files.user-selected.read-only`. Saving a file via `NSSavePanel` requires write permission. Replace:

```xml
<!-- Remove: -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>

<!-- Add: -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

This is a straightforward entitlement upgrade. It does not affect any existing functionality.

### ExportManager

```swift
// ExportManager.swift — Main app target only

import AppKit
import Foundation

enum ExportFormat {
    case csv
    case json
}

struct ExportManager {

    // MARK: - Formatting

    static func generateCSV(from entries: [HistoryEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        var lines = ["Date,Amount (ml),Target (ml),Completion (%)"]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            let pct = Int((entry.amountMl / max(entry.targetMl, 1)) * 100)
            lines.append([
                formatter.string(from: entry.date),
                String(Int(entry.amountMl)),
                String(Int(entry.targetMl)),
                String(pct)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func generateJSON(from entries: [HistoryEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries.sorted { $0.date < $1.date })
    }

    // MARK: - Save Panel

    @MainActor
    static func export(entries: [HistoryEntry], format: ExportFormat) {
        let panel = NSSavePanel()
        let dateTag = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")

        switch format {
        case .csv:
            panel.title = String(localized: "Export Hydration History as CSV")
            panel.nameFieldStringValue = "HydroBar-\(dateTag).csv"
            panel.allowedContentTypes = [.commaSeparatedText]
        case .json:
            panel.title = String(localized: "Export Hydration History as JSON")
            panel.nameFieldStringValue = "HydroBar-\(dateTag).json"
            panel.allowedContentTypes = [.json]
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            switch format {
            case .csv:
                let csv = generateCSV(from: entries)
                try csv.write(to: url, atomically: true, encoding: .utf8)
            case .json:
                let json = try generateJSON(from: entries)
                try json.write(to: url)
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "Export Failed")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
```

### Export Data Source

`ExportManager` reads `HydrationManager.shared.historyEntries` — the 30-day `[HistoryEntry]` already in memory. To include the current day (which may not yet be persisted as a completed entry), add a synthetic entry for today:

```swift
// In SettingsView or wherever export is triggered:
var entriesToExport = HydrationManager.shared.historyEntries
let todayEntry = HistoryEntry(date: Calendar.current.startOfDay(for: Date()),
                               amountMl: HydrationManager.shared.currentMl,
                               targetMl: HydrationManager.shared.targetMl)
// Add if not already present
if !entriesToExport.contains(where: { Calendar.current.isDateInToday($0.date) }) {
    entriesToExport.append(todayEntry)
}
ExportManager.export(entries: entriesToExport, format: .csv)
```

---

## Data Flow (Complete Picture)

### Water Addition — Full Chain

```
User action (button / hotkey / Raycast URL scheme / notification action)
    ↓
HydrationManager.addWater(amount:)
    ├── currentMl += amount (in-memory @Published → SwiftUI re-render)
    ├── storedCurrentMl = currentMl (@AppStorage → UserDefaults.standard)
    ├── saveTodayEntry() → historyEntries array + historyEntries.json
    ├── scheduleNotifications() (existing)
    ├── [NEW] syncToAppGroup() → AppGroupStore.write() → UserDefaults(suiteName:)
    ├── [NEW] WidgetCenter.shared.reloadTimelines(ofKind: "HydroBarWidget")
    └── [NEW] if healthKitEnabled && macOS 13+ → HealthKitWriter.write(amountMl:)

WidgetKit (separate process, triggered by reloadTimelines):
    HydroBarTimelineProvider.getTimeline()
        ↓ AppGroupStore.read() from shared UserDefaults
        ↓ Timeline([HydrationEntry(snapshot)], policy: .never)
    Widget view renders updated progress ring / chart
```

### Widget Read Path

```
Shared UserDefaults (group.com.adxcool.HydroBar)
    ↓ read by HydroBarTimelineProvider (widget process)
    ↓ HydrationEntry { date, snapshot: { currentMl, targetMl, unit, weekHistory } }
WidgetKit routes to SmallWidgetView / MediumWidgetView / LargeWidgetView
    Small: progress ring (currentMl / targetMl)
    Medium: ring + unit-converted amount + goal
    Large: ring + 7-bar chart from weekHistory
```

### Export Data Path

```
SettingsView "Export CSV" / "Export JSON" button tap
    ↓ @MainActor
ExportManager.export(entries: assembledEntries, format: .csv/.json)
    ↓ NSSavePanel.runModal() → user picks destination
    ↓ generateCSV() / generateJSON() → formats data
    ↓ write to file URL
Success: file saved. Failure: NSAlert displayed.
```

### HealthKit Write Path

```
HydrationManager.addWater(amountMl:)
    ↓ [if #available(macOS 13.0, *) && healthKitEnabled]
HealthKitWriter.write(amountMl: amount, date: Date())
    ↓ HKQuantity(unit: .literUnit(with: .milli), doubleValue: amountMl)
    ↓ HKQuantitySample(type: .dietaryWater, quantity:, start: date, end: date)
    ↓ HKHealthStore.save(sample) { _, error in ... } — async, background callback
Apple Health database updated
```

---

## Patterns to Follow

### Pattern 1: App Group as Write-Once-Read-Many Mirror

**What:** The App Group shared UserDefaults is a **one-way mirror** of the minimum data the widget needs. The main app is the exclusive writer; the widget is read-only.

**When:** Always. Never write to the App Group from the widget extension.

**Why:** Bidirectional writes would require synchronization logic and conflict resolution. The main app already owns all state mutations. Mirror only what the widget needs (not the full `historyEntries` array — just 7 days of snapshots).

### Pattern 2: `WidgetCenter.reloadTimelines(ofKind:)` as Explicit Push

**What:** Use `.never` as the timeline policy. The main app calls `WidgetCenter.shared.reloadTimelines(ofKind: "HydroBarWidget")` as an explicit push trigger after every data change.

**When:** In `addWater()`, `checkAndResetIfNeeded()`, and on `targetMl` changes.

**Why:** The water-tracking use case is user-event-driven, not time-driven. Scheduled auto-refresh would wake the widget process unnecessarily. Explicit reload gives the main app precise control over widget freshness.

### Pattern 3: Stateless Widget Views

**What:** All widget views are pure `SwiftUI.View` structs with no `@StateObject`, `@EnvironmentObject`, or `ObservableObject`. They receive a `HydrationEntry` value type from WidgetKit.

**When:** All widget views, always.

**Why:** Widget extensions are short-lived. State objects would be recreated on every render. WidgetKit does not support persistent view state — all data must travel through the `TimelineEntry`.

### Pattern 4: Write-Only HealthKit

**What:** Request only `toShare` permission for `HKQuantityType(.dietaryWater)`. Pass an empty set for `read:`.

**When:** Always for v1.2.

```swift
try await store.requestAuthorization(toShare: [waterType], read: [])
```

**Why:** Read access creates a bidirectional sync problem. If the user logs water in Apple Health directly or in another app, reading it back into HydroBar would double-count. Write-only avoids this. The spec explicitly calls this out.

### Pattern 5: Dual Target Membership over Shared Framework

**What:** Files shared between main app and widget extension (`AppGroupStore.swift`, snapshot structs) are added to both targets via Xcode's target membership checkbox, not via a separate Swift package or embedded framework.

**When:** For this project (zero-dependency philosophy, 2-3 shared files).

**Why:** A shared framework target adds signing complexity, provisioning profile entries, and framework embedding configuration. For two small files, dual membership is simpler and consistent with the existing codebase philosophy.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Importing HydrationManager into the Widget Extension

**What goes wrong:** Adding `HydrationManager.swift` to the widget extension target so the `TimelineProvider` can call `HydrationManager.shared` directly.

**Why bad:** `HydrationManager.swift` uses `@AppStorage`, which requires the main app's standard UserDefaults suite. More critically, `HydroBarApp.swift` imports AppKit types (`NSStatusItem`, `NSPopover`) that are **not available in widget extensions**. The build will fail.

**Instead:** The widget reads only from `AppGroupStore` and the minimal snapshot structs. `HydrationManager` stays in the main app target exclusively.

### Anti-Pattern 2: Moving All `@AppStorage` Keys to the App Group Suite

**What goes wrong:** Replacing `UserDefaults.standard` with `UserDefaults(suiteName: "group.com.adxcool.HydroBar")` for all existing `@AppStorage` properties.

**Why bad:** `@AppStorage` without an explicit `store:` parameter writes to `UserDefaults.standard`. The existing user data (preferences, current ml, history) is in `.standard`. Changing the backing store breaks the `@AppStorage` property wrappers and loses existing stored values. Migration code would be required for every key.

**Instead:** Keep all existing `@AppStorage` properties writing to `.standard`. The App Group container is a parallel, lightweight write-mirror containing only the 5-6 values the widget needs.

### Anti-Pattern 3: Requesting HealthKit Authorization at App Launch

**What goes wrong:** Calling `requestAuthorization()` during `applicationDidFinishLaunching` before the user has opted in.

**Why bad:** The system permission sheet appears unexpectedly. Apple's HIG guidelines require permission requests to be presented in context, when the feature is first used.

**Instead:** Request authorization only when the user first enables the "Write to Apple Health" toggle in `SettingsView`.

### Anti-Pattern 4: Calling HealthKit Save Synchronously on Main Thread

**What goes wrong:** `await store.save(sample)` inside `addWater()` on the main actor.

**Why bad:** `addWater()` is called at up to 20Hz during Hold-to-Add mode. Awaiting HealthKit's save on every call would introduce latency and potential UI jank.

**Instead:** `HealthKitWriter.write()` uses the callback-based `store.save(_:withCompletion:)` and ignores the completion result (fire-and-forget). The completion handler runs on a background queue. Errors are logged but not user-visible (individual water samples failing silently is acceptable).

### Anti-Pattern 5: Serializing All 30 Days of History into App Group UserDefaults

**What goes wrong:** On every `addWater()`, serializing the full `historyEntries: [HistoryEntry]` (30 entries) into the shared UserDefaults.

**Why bad:** `addWater()` is called at 20Hz during Hold-to-Add. Serializing 30 `HistoryEntry` objects on every call is ~2KB JSON per write at high frequency. UserDefaults has performance degradation above ~1MB and ipc-level overhead. The large widget only needs 7 days.

**Instead:** Write only `currentMl`, `targetMl`, `unit`, `lastUpdated`, and 7 `HistoryEntrySnapshot` values (compact Codable structs, ~200 bytes total) to the App Group store.

---

## Scalability Considerations

| Concern | At v1.2 | Future |
|---------|---------|--------|
| Widget App Group data size | ~200 bytes per write (7 snapshots + scalars) | Fixed size by design — will not grow |
| HealthKit write frequency | 1 sample per water addition (~5–20/day typical) | HealthKit is designed for thousands of samples/day; no concern |
| Export file size | 30-day history ~9KB CSV | Grows linearly; if history window extends, add date-range picker to export UI |
| Widget process memory | Minimal — no singletons, stateless views | Fixed by architecture; widgets have strict memory budgets enforced by system |
| `reloadTimelines()` throttling | WidgetKit throttles calls; expect 0–5s delay after addWater | Acceptable for hydration tracking use case |

---

## Build Order (Dependency Graph)

The three features have the following dependency constraints:

```
App Group Capability (Xcode setting + entitlements)
    └── required before any Group UserDefaults code
        └── AppGroupStore.swift (dual target file)
            └── syncToAppGroup() in HydrationManager ← validates data flow
                └── Widget Extension Target (new Xcode target)
                    └── App Group Capability on widget target
                        └── HydroBarTimelineProvider
                            └── SmallWidgetView / MediumWidgetView / LargeWidgetView
                                └── WidgetCenter.reloadTimelines() hook in addWater()

HealthKit Capability + Entitlement (independent of widget)
    └── HealthKitAuthManager
        └── HealthKitWriter
            └── addWater() HealthKit hook
                └── HealthKit UI in SettingsView

files.user-selected.read-write entitlement (independent)
    └── ExportManager
        └── Export buttons in SettingsView
```

**Recommended phase ordering:**

| Step | Task | Rationale |
|------|------|-----------|
| 1 | Add App Group capability to main app target | Foundation for widget; must exist before any code compiles |
| 2 | Create `AppGroupStore.swift` + snapshot structs | Dual-target file; validates shared container before widget target exists |
| 3 | Add `syncToAppGroup()` to `HydrationManager` | Validates write path; can test that shared UserDefaults is populated |
| 4 | Create widget extension Xcode target | Requires App Group to be configured first |
| 5 | Add App Group capability to widget extension target | Widget target must exist |
| 6 | Add `AppGroupStore.swift` to widget target membership | Both targets must exist |
| 7 | Implement `HydroBarTimelineProvider` | App Group read path must work (step 3 validates this) |
| 8 | Implement Small / Medium / Large widget views | Provider must compile |
| 9 | Add `WidgetCenter.reloadTimelines()` to `addWater()` + `checkAndResetIfNeeded()` | Widget views must exist |
| 10 | Add HealthKit capability + entitlement + Info.plist key | Independent of all widget work |
| 11 | Implement `HealthKitAuthManager` | Entitlement must be configured |
| 12 | Implement `HealthKitWriter` | Auth manager must exist |
| 13 | Add HealthKit hook to `addWater()` | Writer must be implemented |
| 14 | Add HealthKit section to `SettingsView` | All HealthKit code in place |
| 15 | Change entitlement: `read-only` → `read-write` for user-selected files | Independent of all other work |
| 16 | Implement `ExportManager` | Entitlement must allow writes |
| 17 | Add export buttons to `SettingsView` | `ExportManager` must be implemented |

Steps 10–14 (HealthKit) and steps 15–17 (Export) can be developed in parallel with widget work after step 3.

---

## Sources

- WidgetKit `TimelineProvider` protocol, `StaticConfiguration`, `WidgetCenter.shared.reloadTimelines()` — HIGH confidence, Apple training documentation, cutoff Aug 2025
- App Group container: `UserDefaults(suiteName:)`, `com.apple.security.application-groups` entitlement — HIGH confidence
- HealthKit on macOS: `HKHealthStore`, `HKQuantityType(.dietaryWater)`, `HKQuantitySample`, `HKQuantity(.literUnit(with: .milli))` — HIGH confidence, pre-cutoff Apple documentation
- macOS HealthKit availability (macOS 13.0+) — HIGH confidence
- `NSSavePanel` with `.commaSeparatedText` and `.json` UTType content types — HIGH confidence
- `com.apple.security.files.user-selected.read-write` entitlement for sandboxed file write access — HIGH confidence
- Existing codebase: `HydroBar.entitlements` (confirmed sandbox + file entitlements), `project.pbxproj` (bundle ID `com.adxcool.HydroBar`), `HydrationManager.swift` (addWater, historyEntries, HistoryEntry struct) — VERIFIED against actual files

---

*Architecture research: 2026-02-26*
