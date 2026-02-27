# HydroBar

## What This Is

HydroBar is a native macOS menu bar application that helps users track their daily water intake and maintain healthy hydration habits. It lives discreetly in the status bar with real-time animated progress tracking, smart reminder notifications, advanced statistics, global keyboard shortcuts, and support for 9 languages. Built entirely in Swift/SwiftUI with no external dependencies.

## Core Value

Users can effortlessly track their water intake throughout the day without leaving their current workflow — one click or one keyboard shortcut from anywhere on macOS.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. Existing v1.1 capabilities. -->

- ✓ Real-time progress ring with animated visual feedback — v1.0
- ✓ Customizable daily goal with unit selection (cl, L, oz) — v1.0
- ✓ 3 customizable quick preset buttons — v1.0
- ✓ Hold-to-Add continuous mode — v1.0
- ✓ Automatic daily reset at midnight — v1.0
- ✓ Menu bar icon options (pie ring or percentage text) — v1.0
- ✓ Reminder badge indicator — v1.0
- ✓ Weekly bar chart (last 7 days) — v1.0
- ✓ 30-day heatmap with hover tooltips — v1.1
- ✓ KPI cards (daily average, weekly total, streak, completion rate) — v1.0
- ✓ Configurable notification reminders — v1.0
- ✓ Focus Mode integration (auto-sync with macOS Do Not Disturb) — v1.0
- ✓ Global keyboard shortcuts (system-wide, per-preset) — v1.0
- ✓ Multi-language support (EN, FR, ES, DE, IT, PT, NL, JA, ZH) — v1.0
- ✓ Undo/redo (50 levels) — v1.0
- ✓ GitHub-based update checker — v1.1
- ✓ Context menu with version, shortcuts, About, repository link — v1.1
- ✓ Raycast extension for quick-add via launcher — v1.1

### Active

<!-- v1.2 scope. Building toward these. -->

- [ ] Native macOS widgets (small: progress ring, medium: ring + stats, large: ring + weekly chart)
- [ ] HealthKit integration (write hydration data to Apple Health)
- [ ] Data export (CSV and JSON formats via Settings)

### Out of Scope

<!-- Explicit boundaries. -->

- iCloud sync — Adds complexity, privacy-first approach preferred for now
- iOS/iPadOS companion app — macOS-only focus for this version
- HealthKit read (bidirectional) — Write-only for v1.2, read can come later
- Dynamic daily goal adjustment (weather, activity, weight) — Interesting but complex, defer to future
- Custom visual themes — Current system appearance adaptation is sufficient
- Automatic periodic export — Simple manual export is enough for v1.2

## Context

HydroBar v1.1 is a well-structured, ~4,000-line Swift/SwiftUI app with clean MVVM architecture. The codebase uses no external dependencies — only Apple frameworks. State is managed centrally through `HydrationManager` singleton with `@AppStorage` (UserDefaults) for preferences and JSON files in `~/Library/Application Support/HydroBar/` for history.

Key architectural considerations for v1.2:
- **Widgets** require WidgetKit framework, an App Group for shared data between the main app and widget extension, and a new widget extension target in Xcode
- **HealthKit** requires the HealthKit framework, entitlements, and user permission. Writing water intake data uses `HKQuantityType(.dietaryWater)`. The app is sandboxed so entitlements must be properly configured
- **Export** is straightforward — the history data already exists as JSON, just needs a file save dialog and CSV formatter

The app currently persists data in two formats: `history.json` (7-day legacy) and `historyEntries.json` (30-day current). Both use `HistoryEntry` and `DailyEntry` Codable structs.

## Constraints

- **Platform**: macOS 12.0+ (Monterey) — must maintain backward compatibility
- **Dependencies**: Zero external dependencies policy — Apple frameworks only
- **Signing**: No Apple Developer Program membership — limits HealthKit testing to development builds
- **Sandbox**: App is sandboxed — HealthKit and widget entitlements must be configured correctly
- **Privacy**: 100% local data, no cloud services, no tracking

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| HealthKit write-only (not bidirectional) | Simpler implementation, avoids data conflict resolution | — Pending |
| Three widget sizes (S/M/L) | Covers all use cases from quick glance to detailed view | — Pending |
| Simple manual export (no auto-export) | Minimal complexity, covers primary backup use case | — Pending |
| Apple frameworks only (no SPM packages) | Maintains zero-dependency philosophy of existing codebase | — Pending |

---
*Last updated: 2026-02-26 after initialization*
