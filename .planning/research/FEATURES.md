# Feature Landscape

**Domain:** macOS hydration tracking app — v1.2 milestone (WidgetKit, HealthKit, Data Export)
**Researched:** 2026-02-26
**Research basis:** Training knowledge (Apple APIs, cutoff August 2025) + project context files. External web search unavailable during this session. Confidence levels reflect source quality.

---

## Table Stakes

Features users expect. Missing = product feels broken or incomplete.

### WidgetKit Widgets

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Small widget showing progress ring | Standard for glanceable data; users expect the app's core visual at a glance | Medium | Requires WidgetKit extension target, App Group, TimelineProvider |
| Medium widget showing ring + today's stats | Standard medium widget content — progress + context | Medium | Same infrastructure as small; add KPI summary (today vs goal) |
| Large widget with weekly chart | Standard large widget content — the chart already exists in the app | Medium-High | Reuse chart rendering logic, but must work in WidgetKit context (no ObservableObject, no @Published) |
| Widget updates when water is logged | Users will open the app, log water, and expect widget to reflect it | Medium | Main app must call `WidgetCenter.shared.reloadAllTimelines()` after addWater(); timeline refresh is near-instant |
| Widget taps open the app | Standard widget behavior — tapping navigates into the app | Low | `widgetURL()` modifier on widget view; deep link back to main popover |
| Shared data container via App Group | Required for widget to read data the main app writes | High | Must migrate UserDefaults and/or history files to App Group container; this is the largest architectural change |

### HealthKit Write

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Permission request on first HealthKit use | HealthKit requires explicit user consent before any read/write | Low | `HKHealthStore.requestAuthorization(toShare:read:)` shows system sheet; must handle denial gracefully |
| Write each water log entry to Apple Health | Core purpose of the integration; users expect every addition to sync | Medium | Create `HKQuantitySample` per add event; save via `HKHealthStore.save()` |
| Toggle to enable/disable HealthKit sync | Not all users want Apple Health sync; some prefer local-only | Low | Single toggle in Settings; persist in UserDefaults |
| Correct unit mapping (mL → HKUnit) | Apple Health stores water in liters internally | Low | `HKUnit.liter()` with fractional value; convert from internal mL representation |
| Info.plist usage description | Required by Apple or app crashes/is rejected | Low | `NSHealthUpdateUsageDescription` key in Info.plist |

### Data Export

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| CSV export | Universal format; users expect to open health data in Excel/Numbers/Google Sheets | Low | Format: date, amount_ml, goal_ml, completion_pct; use existing DailyEntry/HistoryEntry data |
| JSON export | Developer-friendly; power users expect raw data access | Low | Direct serialization of existing HistoryEntry array; minimal new code |
| NSSavePanel (save dialog) | Standard macOS file-save UX; users expect to choose location | Low | `NSSavePanel` with suggested filename including date; app is sandboxed so NSSavePanel is required |
| Export button in Settings | Logical location; users look for data management in Settings | Low | Two buttons (Export CSV, Export JSON) under a "Data" section |
| Sensible default filename | Good UX; avoids unnamed files | Low | `HydroBar-export-YYYY-MM-DD.csv` / `.json` |

---

## Differentiators

Features that set the product apart. Not expected, but valued when present.

### WidgetKit Widgets

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Interactive widget buttons (log preset amounts directly from widget) | Skip opening the app entirely; true frictionless logging | High | Requires macOS 14+ and `AppIntent` framework; breaks macOS 12/13 compatibility unless guarded with `@available`; significant extra scope |
| Widget accent color matching user's system accent | Polish; feels native and personalized | Low | Use `Color.accentColor` in widget view; automatic |
| Multiple widget configurations (choose which preset sizes to show, unit display) | Power user appeal | Medium | Requires `IntentConfiguration` and a custom intent definition; adds complexity |
| Widget background adapts to light/dark mode | Expected but worth noting; looks professional | Low | Use system adaptive colors; already done in the main app |

### HealthKit Write

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Retroactive sync on enable (write historical data on first toggle) | Users who enable HealthKit after weeks of tracking lose historical data without this | Medium | Optional: offer "sync last 30 days" prompt on first enable; use bulk save; risk of duplicates if toggled on/off |
| Display HealthKit sync status in Settings | Transparency; users want to know if sync is working | Low | Show last sync timestamp or "X entries synced today" |
| Graceful HealthKit unavailable state | HealthKit may not be available (e.g., managed devices, VM); show informative message | Low | `HKHealthStore.isHealthDataAvailable()` check; hide toggle if unavailable |

### Data Export

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Date range selection for export | Power users want to export specific periods, not all data | Medium | Date picker with from/to; filter HistoryEntry array before export |
| Export preview showing record count | Confidence before committing; "You are about to export 30 days of data" | Low | Display count in export confirmation or as inline label |
| Include unit in CSV header | Clarity for spreadsheet analysis | Low | Header row: `date,amount_ml,amount_oz,goal_ml,completion_pct` |
| Clipboard copy option (no file) | Quick pasting into notes apps; some users don't want a file | Low | `NSPasteboard` write; nice-to-have |

---

## Anti-Features

Features to explicitly NOT build in v1.2.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| HealthKit read (bidirectional sync) | Requires conflict resolution (what wins — app data or Health app data?); doubles complexity; out of scope per PROJECT.md | Write-only; explicitly document this in the UI ("HydroBar writes to Apple Health; edits in the Health app are not reflected here") |
| Automatic periodic export / export scheduler | Adds complexity, requires persistent background task or launch agent; users don't need it | Manual export on demand is sufficient; future version concern |
| iCloud sync | Significant complexity; multi-device conflict resolution; Apple Developer account requirement for CloudKit; explicitly out of scope per PROJECT.md | Local-only; document as intentional |
| Widget with live activity or lock screen widget | Lock screen widgets are iOS-only; Live Activities are iOS-only | macOS Desktop/Notification Center widgets only |
| Interactive widgets on macOS 12/13 | AppIntents interactive widget buttons require macOS 14+; supporting older OS with interactive widgets is not possible | Non-interactive widgets for macOS 12/13; display-only with tap-to-open |
| HealthKit sync for all historical data by default | Bulk writes to Apple Health on first launch could confuse users who expect it to be opt-in | Opt-in toggle; consider offering retroactive sync as a separate explicit action |
| Custom export format (XML, PDF, charts) | Scope creep; CSV and JSON cover all realistic use cases | CSV for spreadsheet users, JSON for developers; that is sufficient |
| Widget configuration requiring WidgetKit intent UI | Complex to build, requires IntentDefinition.intentdefinition file; out of scope for v1.2 | Static widgets with fixed content layout; defer configurability to v1.3+ |

---

## Feature Dependencies

```
App Group (shared UserDefaults / shared data path)
  → Small widget (reads today's intake + goal)
  → Medium widget (reads today's intake + goal + unit)
  → Large widget (reads today's intake + 7-day history)

WidgetCenter.shared.reloadAllTimelines()
  → Must be called in HydrationManager.addWater() (and undo, reset)
  → Depends on: App Group already configured

HealthKit entitlement (com.apple.developer.healthkit)
  → HealthKit write toggle (Settings)
  → Write sample on addWater()
  → Depends on: Apple Developer account for distribution (local dev builds work without)

Data export
  → No dependencies on WidgetKit or HealthKit
  → Reads existing HistoryEntry / DailyEntry arrays directly
  → NSSavePanel works in sandboxed apps with no extra entitlements
```

**Dependency order:**
1. App Group setup (unblocks all widget work)
2. Widget Extension target + TimelineProvider (unblocks all widget rendering)
3. HealthKit entitlement + Info.plist (unblocks HealthKit)
4. Export is independent — can be built in any order

---

## MVP Recommendation

For v1.2, prioritize in this order:

**Must ship (table stakes for stated v1.2 goals):**
1. App Group migration + shared data container (foundation for all widgets)
2. Small widget — progress ring (most used widget size; highest value for effort)
3. Medium widget — ring + today stats (natural extension of small)
4. Large widget — ring + weekly chart (completes the three-size promise)
5. HealthKit write toggle + per-entry write on addWater()
6. CSV export via NSSavePanel
7. JSON export via NSSavePanel

**Should ship (differentiators that are low complexity):**
8. HealthKit sync status indicator in Settings
9. Export filename with date suggestion
10. Widget reloads on add/undo/reset (makes widgets feel alive)

**Defer:**
- Interactive widget buttons (macOS 14+ only, high complexity, breaks macOS 12 compatibility)
- Retroactive HealthKit sync of historical data (medium complexity, edge case)
- Date range selection for export (medium complexity, power user feature)

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| WidgetKit widget sizes (small/medium/large on macOS) | HIGH | Well-established Apple API; confirmed in training data through WWDC 2024 |
| App Group requirement for widget data sharing | HIGH | Fundamental WidgetKit constraint; documented extensively |
| Interactive widgets requiring macOS 14+ / AppIntents | HIGH | API availability confirmed; `@available` guards required |
| HealthKit entitlement requirement | HIGH | Security requirement; documented in Apple's provisioning process |
| HealthKit unavailable on macOS 12 for write | MEDIUM | macOS 13 added full HealthKit parity; macOS 12 support for write is limited. Flag for verification against deployment target (macOS 12.0+) |
| NSSavePanel works in sandboxed apps for export | HIGH | Standard macOS pattern; sandbox allows user-initiated save dialogs |
| WidgetCenter.reloadAllTimelines() is the refresh mechanism | HIGH | Standard pattern for widget updates triggered by main app |

---

## Key Risk: HealthKit on macOS 12 (Monterey)

HydroBar targets macOS 12.0+. HealthKit on macOS has been available since macOS 13 (Ventura) for dietaryWater writes with full parity. macOS 12 may have limited or no HealthKit write support.

**Mitigation:** Gate HealthKit feature with `if #available(macOS 13, *)` and show informative "Requires macOS 13 or later" message for macOS 12 users. This is cleaner than shipping broken behavior.

**Verification needed:** Confirm exact HealthKit write availability for `dietaryWater` on macOS 12 before implementation. If macOS 12 is fully supported, the `@available` guard is unnecessary.

---

## Key Risk: App Group Entitlement Without Apple Developer Program

The project notes "No Apple Developer Program membership." App Group entitlements require a team ID. Without a paid Developer account:
- Development/local testing works with self-signed entitlements
- Distribution via GitHub Releases as a DMG with a self-signed or ad-hoc cert may work if users allow it in Gatekeeper
- Widgets in a distributed app require proper App Group entitlements signed with a team certificate

**Mitigation:** App Group setup must be tested early in development. If widgets cannot be distributed without a paid account, this is a blocking issue for the widget milestone. The project should validate this before deep widget implementation.

---

## Sources

- Training knowledge: WidgetKit documentation patterns (WWDC 2021-2024), HealthKit API reference, macOS app export conventions — confidence HIGH for established APIs
- Project context: `.planning/PROJECT.md`, `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/INTEGRATIONS.md`, `.planning/codebase/CONCERNS.md`, `.planning/codebase/STACK.md`
- No external web search available during this session — verify HealthKit macOS 12 availability and App Group signing requirements against current Apple documentation before implementation
