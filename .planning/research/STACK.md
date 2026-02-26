# Technology Stack

**Project:** HydroBar v1.2 — WidgetKit, HealthKit, Data Export
**Researched:** 2026-02-26
**Scope:** Additive stack for an existing Swift/SwiftUI macOS app (v1.1). Only new frameworks and configuration are documented here. The existing stack (SwiftUI, AppKit, Combine, Carbon, UserNotifications) is unchanged.

---

## New Frameworks Required

### WidgetKit
| Property | Value |
|----------|-------|
| Framework | WidgetKit |
| Minimum macOS | 11.0 (Big Sur) |
| HydroBar constraint | None — project minimum is macOS 12.0, so WidgetKit works unconditionally |
| Confidence | HIGH — verified via `developer.apple.com/tutorials/data/documentation/widgetkit.json` |

**Why WidgetKit:** It is the only Apple-provided framework for native macOS widgets. There is no alternative.

**Widget families to implement** (all available since macOS 11.0, HIGH confidence):

| Family | Purpose for HydroBar | Notes |
|--------|---------------------|-------|
| `.systemSmall` | Progress ring + percentage | Quick glance widget |
| `.systemMedium` | Ring + today's KPI stats | Moderate information density |
| `.systemLarge` | Ring + weekly bar chart | Full summary view |

`.systemExtraLarge` is available on macOS 11.0+ but out of scope for v1.2 (no use case).

Accessory families (`.accessoryCircular`, `.accessoryRectangular`) are watchOS/iOS Lock Screen only — not available on macOS.

**What WidgetKit requires architecturally:**
- A new widget extension target in Xcode (separate build target, separate bundle ID)
- Bundle ID convention: `com.adxcool.HydroBar.Widget`
- App Group entitlement on both the main app target and widget extension target
- The widget extension reads shared data; it cannot call the main app's code directly
- The main app calls `WidgetCenter.shared.reloadAllTimelines()` after every water addition to trigger widget refresh

---

### HealthKit
| Property | Value |
|----------|-------|
| Framework | HealthKit |
| Minimum macOS | 13.0 (Ventura) |
| HydroBar constraint | macOS 12.0 users cannot use HealthKit — must be gated with `@available(macOS 13, *)` |
| Confidence | HIGH — verified via `developer.apple.com/tutorials/data/documentation/healthkit/hkhealthstore.json` |

**Why HealthKit:** It is the Apple-provided framework for writing health data to Apple Health on macOS. No alternative achieves the same outcome (writing to the system health store visible in the Health app on iPhone/Apple Watch via iCloud sync).

**Key type:**

| Identifier | Unit | Aggregation style |
|------------|------|-------------------|
| `HKQuantityTypeIdentifier.dietaryWater` | Volume (`HKUnit.literUnit(with: .milli)` = mL) | Cumulative |

HydroBar stores data internally in milliliters (via centiliter to mL conversion: 1 cl = 10 mL). Convert cl to mL before writing to HealthKit.

**macOS 12 compatibility strategy:** HealthKit integration must be wrapped in `@available(macOS 13, *)`. Users on macOS 12 will not see the HealthKit toggle in Settings — it will be hidden with a `#available` check. This is the correct approach; do not raise the minimum deployment target.

**What HealthKit requires architecturally:**
- HealthKit entitlement on the main app target only (widget does not write health data)
- `NSHealthUpdateUsageDescription` in Info.plist (write permission string, shown to user in authorization dialog)
- `NSHealthShareUsageDescription` in Info.plist (read permission string — required by the OS even for write-only access)
- `HKHealthStore.isHealthDataAvailable()` check at runtime before any HealthKit calls
- Authorization request before first write using `HKHealthStore.requestAuthorization(toShare:read:)`
- No Apple Developer Program membership means HealthKit cannot be tested on the Mac App Store build — only development builds. This is a known constraint documented in PROJECT.md.

---

### No New Framework for Data Export
| Property | Value |
|----------|-------|
| Framework | Foundation (already used) |
| New dependency | None |
| Confidence | HIGH |

Data export (CSV + JSON) uses only:
- `NSSavePanel` (AppKit, already used) for the file save dialog
- `FileManager` (Foundation, already used) for file writing
- `JSONEncoder` (Foundation, already used) for JSON serialization
- String formatting for CSV generation

No new frameworks are needed. The existing `HistoryEntry` and `DailyEntry` Codable structs already serialize to JSON. CSV is a string transformation of the same data.

The existing entitlement `com.apple.security.files.user-selected.read-only` must be **upgraded** to `com.apple.security.files.user-selected.read-write` to allow writing exported files to user-selected locations. This is the only entitlement change required for export.

---

## Configuration Changes Required

### App Group (WidgetKit data sharing)

Both the main app target and the widget extension target must have the App Groups capability enabled with the same group identifier.

| Property | Value |
|----------|-------|
| Entitlement key | `com.apple.security.application-groups` |
| Group identifier | `group.com.adxcool.HydroBar` |
| Applies to | Main app target + Widget extension target |
| Confidence | HIGH — standard pattern for WidgetKit data sharing |

**Data sharing pattern:**
- Main app writes current hydration state to `UserDefaults(suiteName: "group.com.adxcool.HydroBar")` on every change
- Widget extension reads from the same shared `UserDefaults` in its `TimelineProvider`
- Main app calls `WidgetCenter.shared.reloadAllTimelines()` after every water addition

Keys to write to shared UserDefaults (minimal set for widget display):
```swift
let shared = UserDefaults(suiteName: "group.com.adxcool.HydroBar")
shared?.set(currentMl, forKey: "widget.currentMl")
shared?.set(targetMl, forKey: "widget.targetMl")
shared?.set(historyEntriesData, forKey: "widget.historyEntriesJSON") // last 7 days encoded
```

**Why UserDefaults over shared file container:** UserDefaults with a suite name is simpler, faster to read from within WidgetKit's constrained timeline provider execution, and sufficient for the small data set a widget needs. File-based sharing is appropriate for large datasets (Core Data, etc.) — not needed here.

### HealthKit Entitlements

| Entitlement | Value | Target |
|-------------|-------|--------|
| `com.apple.developer.healthkit` | `true` | Main app only |
| `com.apple.developer.healthkit.access` | `["health-records"]` | NOT needed (dietary data, not health records) |

Info.plist keys (main app):
```xml
<key>NSHealthUpdateUsageDescription</key>
<string>HydroBar writes your water intake to Apple Health to keep your health data in sync.</string>

<key>NSHealthShareUsageDescription</key>
<string>HydroBar accesses Apple Health to verify hydration data has been saved.</string>
```

Note: `NSHealthShareUsageDescription` is required by the OS even when the app only writes data (not reads). Omitting it causes a runtime crash on authorization request.

### File Write Entitlement (Data Export)

The existing read-only entitlement must be changed:

```xml
<!-- Current (read-only): -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>

<!-- Replace with (read-write): -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

This change is additive — it does not break any existing functionality. The app currently has this entitlement for user file selection (e.g., GitHub release checking reads no user files, but the entitlement was set defensively).

---

## Entitlements Summary (Full Updated Set)

The updated `HydroBar.entitlements` file after v1.2 changes:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Existing -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Changed: read-only → read-write for data export -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- New: App Group for widget data sharing -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.adxcool.HydroBar</string>
    </array>

    <!-- New: HealthKit write access -->
    <key>com.apple.developer.healthkit</key>
    <true/>
</dict>
</plist>
```

A separate `HydroBarWidget.entitlements` file for the widget extension target needs only:
```xml
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.adxcool.HydroBar</string>
    </array>
</dict>
```

---

## What NOT to Use

| Approach | Why Not |
|----------|---------|
| SwiftData / Core Data for widget sharing | Overkill for the data volume (a few Double values + 7-day history). Adds significant complexity. UserDefaults with App Group is sufficient and matches the existing persistence pattern. |
| AppIntent / WidgetKit interactive widgets | Out of scope for v1.2. Interactive widgets (tap to add water from widget) require macOS 14.0+ and are a separate feature. Build static display-only widgets first. |
| HealthKit read (bidirectional sync) | Explicitly out of scope per PROJECT.md. Write-only is simpler and avoids data conflict resolution logic. |
| CloudKit or iCloud for widget data | The existing app is privacy-first with local-only data. Widget sharing via App Group maintains this principle. |
| Third-party HealthKit wrappers | Violates the zero-external-dependencies constraint. The HealthKit API for a single `dietaryWater` write is simple enough to implement directly. |
| Raising minimum deployment target to macOS 13 | Unnecessary. WidgetKit works from macOS 11.0. HealthKit can be `@available(macOS 13, *)` gated. Keep 12.0 minimum. |

---

## Development Constraints

| Constraint | Impact | Mitigation |
|------------|--------|------------|
| No Apple Developer Program | HealthKit entitlement `com.apple.developer.healthkit` cannot be used in distribution builds (Mac App Store/Notarized) without ADP membership | Test with development signing only; document this as a known limitation |
| macOS 12 users | HealthKit is unavailable (macOS 13+ required) | `@available(macOS 13, *)` guard; hide HealthKit toggle in Settings on macOS 12 |
| Widget extension sandbox | Widget runs in a separate process, cannot import HydrationManager directly | Extract shared data models to a shared source or framework; use App Group UserDefaults for data transfer |
| Xcode project structure | Adding widget extension adds a new target, new bundle ID, new entitlements file | Follow standard Xcode "Add Widget Extension" flow; do not create manually |

---

## Minimum Version Reference

| Feature | Framework | Minimum macOS | HydroBar minimum | Action needed |
|---------|-----------|---------------|-----------------|---------------|
| Widgets | WidgetKit | 11.0 | 12.0 | None — works unconditionally |
| Widget reload | WidgetCenter | 11.0 | 12.0 | None |
| HealthKit access | HealthKit | 13.0 | 12.0 | `@available(macOS 13, *)` guard |
| HealthKit write | HKHealthStore | 13.0 | 12.0 | Same guard |
| dietaryWater type | HealthKit | 13.0 | 12.0 | Same guard |
| Data export | Foundation/AppKit | 11.0 | 12.0 | None |
| NSSavePanel | AppKit | 10.0 | 12.0 | None |

---

## Sources

| Claim | Source | Confidence |
|-------|--------|------------|
| WidgetKit macOS 11.0 minimum | `developer.apple.com/tutorials/data/documentation/widgetkit.json` | HIGH |
| systemSmall/Medium/Large on macOS 11.0 | `developer.apple.com/tutorials/data/documentation/widgetkit/widgetfamily.json` | HIGH |
| WidgetCenter macOS 11.0 | `developer.apple.com/tutorials/data/documentation/widgetkit/widgetcenter.json` | HIGH |
| HealthKit macOS 13.0 minimum | `developer.apple.com/tutorials/data/documentation/healthkit/hkhealthstore.json` | HIGH |
| dietaryWater macOS 13.0, volume unit | `developer.apple.com/tutorials/data/documentation/healthkit/hkquantitytypeidentifier/dietarywater.json` | HIGH |
| App Group entitlement pattern | Apple standard documentation, widely established pattern | HIGH |
| NSHealthUpdateUsageDescription required even for write-only | Training data + established pattern | MEDIUM — verify in Xcode at build time |
| HealthKit unavailable without ADP for distribution | Training data + PROJECT.md | MEDIUM — verify when attempting to notarize |

---

*Stack research: 2026-02-26*
