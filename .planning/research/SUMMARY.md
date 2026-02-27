# Project Research Summary

**Project:** HydroBar v1.2 — WidgetKit, HealthKit, Data Export
**Domain:** macOS menu bar hydration tracker — additive feature milestone on existing SwiftUI/AppKit app (v1.1)
**Researched:** 2026-02-26
**Confidence:** HIGH (stack and architecture); MEDIUM (HealthKit distribution path)

## Executive Summary

HydroBar v1.2 adds three distinct but well-bounded features to an existing macOS app: WidgetKit widgets (small, medium, large), HealthKit write integration, and CSV/JSON data export. All three features fit cleanly into the existing architecture without rewriting the `HydrationManager` singleton. The primary new complexity is the WidgetKit extension target, which runs in a separate sandboxed process and can only communicate with the main app via an App Group shared container — this is the foundational infrastructure that must be built first. Export and HealthKit are effectively independent of each other and can be developed in parallel once the App Group is in place.

The recommended approach is to treat the App Group setup as Phase 0 — a non-negotiable prerequisite gate — before any widget code is written. The widget extension then builds on top of that shared container using a stateless `TimelineProvider` and three size-specific SwiftUI views. HealthKit requires a `@available(macOS 13, *)` guard throughout because the current deployment target is macOS 12.0, and HealthKit for `dietaryWater` writes is only available on macOS 13 (Ventura) and later. Export is the simplest feature: one entitlement change (`read-only` to `read-write`) and a new `ExportManager` struct using existing Foundation APIs.

The critical risks are distribution-level, not technical. App Groups require a paid Apple Developer Program (ADP) membership to provision for distribution; so does the HealthKit entitlement. The project currently has no ADP membership. Both of these are go/no-go decision gates that must be resolved before deep implementation begins — otherwise widget and HealthKit work can only be used in local development builds. The technical implementations themselves are straightforward and well-documented; the blocking risk is on the signing and distribution side.

## Key Findings

### Recommended Stack

No new external dependencies are required for v1.2. Three Apple frameworks are added: **WidgetKit** (macOS 11.0+, works unconditionally with the 12.0 minimum), **HealthKit** (macOS 13.0+, requires `@available` guard), and **Foundation/AppKit** (already used — export needs no new frameworks). The App Group shared container uses `UserDefaults(suiteName:)` rather than Core Data or file-based sharing, which is appropriate given the small data footprint (~200 bytes per write for 7-day history snapshots). The file write entitlement must be upgraded from `read-only` to `read-write` for export, and the HealthKit entitlement plus App Group entitlement must be added — all planned and applied as a single upfront entitlements pass.

**Core technologies:**
- **WidgetKit**: native macOS widget extension — the only Apple-sanctioned mechanism for Desktop/Notification Center widgets
- **HealthKit** (`HKQuantityType.dietaryWater`): write-only integration to Apple Health — macOS 13+ with `@available` guard on macOS 12
- **App Group shared UserDefaults** (`group.com.adxcool.HydroBar`): inter-process data bridge between main app and widget extension
- **Foundation** (`NSSavePanel`, `JSONEncoder`, `FileManager`): export — already in the codebase, no new dependencies
- **WidgetCenter.shared.reloadTimelines(ofKind:)**: explicit push trigger from `HydrationManager.addWater()` — `.never` timeline policy keeps widget refresh user-driven

### Expected Features

**Must have (table stakes for v1.2):**
- App Group migration + shared data container — foundational, unblocks all widget work
- Small widget (progress ring + percentage) — highest-value widget for effort
- Medium widget (ring + today's stats) — natural extension of small
- Large widget (ring + 7-day bar chart) — completes three-size promise
- Widget updates on every water addition (`WidgetCenter.reloadTimelines`)
- HealthKit write toggle in Settings (macOS 13+ only, hidden on macOS 12)
- Per-entry `HKQuantitySample` write on `addWater()` with undo pairing
- CSV export via `NSSavePanel`
- JSON export via `NSSavePanel`

**Should have (low-complexity differentiators):**
- HealthKit sync status indicator in Settings (last sync timestamp or authorization state)
- Export filename with date suggestion (`HydroBar-2026-02-26.csv`)
- Widget accent color inheriting system accent (`Color.accentColor`)
- Export preview showing record count before save

**Defer to v1.3+:**
- Interactive widget buttons (requires macOS 14+ `AppIntent`; breaks macOS 12/13 support)
- Retroactive HealthKit sync of historical data (medium complexity, edge case)
- Date range selection for export (power user feature)
- Widget configurability via `IntentConfiguration`

### Architecture Approach

The existing `HydrationManager` singleton remains the single source of truth. Each new subsystem is an additive side effect off `addWater()` rather than a structural change. Three new components are introduced in the main app target: `AppGroupStore` (dual-target file also compiled into the widget extension), `HealthKitWriter` (fire-and-forget `@available(macOS 13, *)` struct), and `ExportManager` (stateless struct). The widget extension target gets `HydroBarTimelineProvider` (reads `AppGroupStore`), and three stateless SwiftUI views (`SmallWidgetView`, `MediumWidgetView`, `LargeWidgetView`). The key architectural constraint is that the widget extension cannot import any main app type that transitively depends on AppKit — shared types (`HydrationSnapshot`, `HistoryEntrySnapshot`) are minimal Codable structs compiled into both targets via dual target membership, not a shared framework.

**Major components:**
1. `AppGroupStore` — bridge: main app writes, widget reads; dual-target membership; all shared data in one atomic Codable snapshot
2. `HydroBarTimelineProvider` — widget process entry point; reads `AppGroupStore`; uses `.never` refresh policy (main app triggers explicit reloads)
3. `HealthKitAuthManager` / `HealthKitWriter` — authorization flow + fire-and-forget write; all macOS 13+ guarded
4. `ExportManager` — stateless CSV/JSON formatter + `NSSavePanel` coordinator; reads `HydrationManager.historyEntries`
5. `HydrationManager` (modified) — adds `syncToAppGroup()`, `WidgetCenter.reloadTimelines()`, and conditional `HealthKitWriter.write()` as side effects in `addWater()`

### Critical Pitfalls

1. **App Group not configured before shared code (P-W1)** — Configure the App Group entitlement on both targets and write `AppGroupStore` before creating any `TimelineProvider`. Skipping this means widget data access is fundamentally broken and requires refactoring already-written code.

2. **ADP membership required for App Groups and HealthKit distribution (P-W2, P-H1)** — Both widget distribution and HealthKit distribution require a paid Apple Developer account. Make a go/no-go decision before committing implementation effort. For local development, a free personal team ID suffices; for shipping, a paid account is a hard prerequisite.

3. **Duplicate HealthKit entries on undo/redo (P-H4)** — Every `addWater()` creates an `HKQuantitySample`. Every `undoLastAction()` must delete the corresponding sample using its stored UUID. Alternatively, write end-of-day totals instead of per-sip samples to eliminate this complexity entirely. The undo stack must be extended to carry `healthKitSampleID: UUID?`.

4. **Exporting wrong data set — legacy vs current history (P-E2)** — `HydrationManager` maintains two history stores (`history.json` / `DailyEntry` for 7 days; `historyEntries.json` / `HistoryEntry` for 30 days). Export must use `historyEntries` (`[HistoryEntry]`) as the canonical source. This is also an opportunity to resolve the dual-history tech debt noted in CONCERNS.md.

5. **All entitlement changes should be made in a single upfront pass (P-X1, P-H5)** — Three entitlement changes are required (App Group, HealthKit, file write). Adding them incrementally across sessions risks cumulative signing failures with cryptic error messages. Apply all changes in one commit before writing any feature code, then do a clean build to verify the app launches cleanly.

## Implications for Roadmap

Based on research, the dependency graph strongly suggests a 4-phase structure. App Group is the hard prerequisite for widgets; HealthKit and Export are parallel and independent; widget views build on the data layer.

### Phase 1: Foundation and Entitlements
**Rationale:** All three features require entitlement changes; two require the App Group. Doing this first prevents signing failures from accumulating. This is a zero-feature-code phase — purely infrastructure.
**Delivers:** Updated `HydroBar.entitlements` (App Group + HealthKit + file read-write), new `HydroBarWidget.entitlements`, confirmed clean build
**Addresses:** App Group setup prerequisite (all widget features), file write for export, HealthKit signing setup
**Avoids:** P-X1 (incremental signing breakage), P-H5 (entitlement conflicts), P-W2/P-H1 (ADP decision gate forced upfront)
**Research flag:** None — standard Xcode capability configuration, well-documented patterns

### Phase 2: Widget Data Layer
**Rationale:** App Group infrastructure must exist before any widget or `TimelineProvider` code is written. Validating the data pipeline (main app writes → shared UserDefaults → readable from widget process) before building UI prevents fundamental architectural rework.
**Delivers:** `AppGroupStore.swift` (dual-target), `HydrationSnapshot` + `HistoryEntrySnapshot` structs, `syncToAppGroup()` hook in `HydrationManager.addWater()`, widget extension Xcode target (no UI yet), validated data flow
**Addresses:** App Group shared container (table stakes), widget updates on add/undo/reset
**Avoids:** P-W1 (App Group before code), P-W4 (no HydrationManager in widget target), P-X2 (atomic snapshot prevents read races)
**Research flag:** None — architecture is fully specified in ARCHITECTURE.md with implementation-ready code

### Phase 3: Widget Views
**Rationale:** Data layer is proven; now build the three display sizes. Small and medium are straightforward; large reuses the existing weekly chart logic but must be ported to stateless WidgetKit view (no `@StateObject`).
**Delivers:** `HydroBarTimelineProvider`, `SmallWidgetView`, `MediumWidgetView`, `LargeWidgetView`, `WidgetCenter.reloadTimelines()` hook in `addWater()`, widget tap behavior (opens main app)
**Addresses:** Small/medium/large widget (all table stakes), widget accent color (differentiator)
**Avoids:** P-W3 (debounced `reloadTimelines` to avoid budget exhaustion), P-W5 (test on actual macOS 12/13 hardware)
**Research flag:** LOW — verify `ProgressRingView.swift` has no AppKit imports before adding to widget target; if it does, create a widget-specific copy

### Phase 4: HealthKit Integration
**Rationale:** Fully independent of widget work; can be developed concurrently with Phase 3 if resources allow, or sequentially after. Treating it as a distinct phase makes the ADP go/no-go gate explicit.
**Delivers:** `HealthKitAuthManager`, `HealthKitWriter`, HealthKit hook in `addWater()` (with undo UUID tracking), HealthKit Settings section (macOS 13+ only), sync status indicator
**Addresses:** HealthKit write toggle, per-entry write, `NSHealthUpdateUsageDescription` Info.plist key, macOS 12 graceful hide
**Avoids:** P-H1 (ADP gate confirmed in Phase 1), P-H2 (`isHealthDataAvailable()` check at every call site), P-H3 (auth status checked after request, not assumed), P-H4 (undo stack extended with `healthKitSampleID`)
**Research flag:** MEDIUM — undo/delete pairing (`HKHealthStore.delete()`) needs testing; alternatively, adopt end-of-day write strategy to skip undo complexity entirely. Decision should be made at phase start.

### Phase 5: Data Export
**Rationale:** Simplest feature with no dependencies on Phases 2-4. Can be developed fully in parallel after Phase 1. Placed last in sequential ordering only because it has the lowest risk and can absorb any schedule slip from earlier phases.
**Delivers:** `ExportManager` (CSV + JSON), export buttons in Settings, `NSSavePanel` integration, UTF-8 BOM in CSV, today's partial-data row with `status` column
**Addresses:** CSV export, JSON export, sensible default filenames, export record count preview
**Avoids:** P-E1 (file write entitlement from Phase 1), P-E2 (`historyEntries` as canonical source, legacy `DailyEntry` explicitly excluded), P-E3 (UTF-8 BOM + English column headers), P-E4 (today's row with `is_partial` field)
**Research flag:** None — pure Foundation/AppKit, all APIs well-established

### Phase Ordering Rationale

- Phase 1 is non-negotiable first because three separate features each touch entitlements; a single entitlements pass avoids compounding signing problems.
- Phase 2 must precede Phase 3 because WidgetKit views cannot be meaningfully built or tested without a working data pipeline.
- Phases 3, 4, and 5 are logically independent once Phase 2 is done; a parallel track (3 and 4/5 simultaneously) is viable if developer time allows.
- The ADP membership decision is forced into Phase 1 because both App Groups and HealthKit distribution depend on it — delaying this decision wastes implementation effort if the answer is "we can't distribute either feature."

### Research Flags

Phases needing deeper research or explicit decisions before implementation:
- **Phase 4 (HealthKit):** The undo/HealthKit sample deletion strategy needs an explicit upfront decision: per-sip writes with UUID-tracked deletion vs. end-of-day batch writes. The latter avoids `P-H4` entirely at the cost of delayed Health data. Decision should be in the phase plan.
- **Phase 3 (Widgets):** Verify `ProgressRingView.swift` AppKit independence before including in widget target. Low risk but flag for code review at phase start.

Phases with well-documented patterns (no additional research needed):
- **Phase 1:** Standard Xcode capability configuration.
- **Phase 2:** App Group UserDefaults pattern is thoroughly documented and directly applicable.
- **Phase 5:** All export APIs are standard Foundation/AppKit with no ambiguity.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All frameworks verified against Apple documentation (training cutoff Aug 2025); WidgetKit and HealthKit macOS availability windows confirmed |
| Features | HIGH | Table stakes features well-established; macOS 12 HealthKit availability confirmed as requiring `@available(macOS 13, *)` guard |
| Architecture | HIGH | Architecture verified against actual codebase files (`HydroBar.entitlements`, `project.pbxproj`, `HydrationManager.swift`); implementation-ready code provided |
| Pitfalls | HIGH | Critical pitfalls are grounded in known API constraints (App Group signing, HealthKit availability, sandbox entitlements), not speculation |

**Overall confidence:** HIGH for technical implementation; MEDIUM for distribution (ADP membership status is the unresolved external dependency)

### Gaps to Address

- **ADP membership go/no-go:** Must be resolved before Phase 1 begins. Both App Group widget distribution and HealthKit distribution are blocked without it. If unresolved, widgets and HealthKit should be developed behind `#if DEBUG` flags only.
- **HealthKit undo strategy:** Per-sip write with UUID deletion vs. end-of-day batch write. Both are valid; end-of-day is simpler. This choice must be explicit in the Phase 4 plan because it affects the undo stack data model.
- **`ProgressRingView` AppKit dependency:** Unknown until the file is inspected. If it has AppKit imports, a widget-specific copy is needed. Low effort, but not yet confirmed.
- **macOS 12 HealthKit availability:** Research confirms macOS 13 is required for `dietaryWater` writes. The `@available(macOS 13, *)` guard is the correct mitigation. No further validation needed before implementation.

## Sources

### Primary (HIGH confidence)
- `developer.apple.com/tutorials/data/documentation/widgetkit.json` — WidgetKit macOS 11.0 minimum, `TimelineProvider`, `WidgetCenter`, `StaticConfiguration`, supported families
- `developer.apple.com/tutorials/data/documentation/widgetkit/widgetfamily.json` — `systemSmall/Medium/Large` availability on macOS 11.0+
- `developer.apple.com/tutorials/data/documentation/healthkit/hkhealthstore.json` — HealthKit macOS 13.0 minimum
- `developer.apple.com/tutorials/data/documentation/healthkit/hkquantitytypeidentifier/dietarywater.json` — `dietaryWater` macOS 13.0, volume unit (mL)
- Codebase: `HydroBar.entitlements`, `project.pbxproj`, `HydrationManager.swift`, `CONCERNS.md`, `INTEGRATIONS.md` — verified against actual source files

### Secondary (MEDIUM confidence)
- Training knowledge: App Group UserDefaults pattern, WidgetKit `TimelineProvider` implementation patterns, HealthKit sandbox entitlement behavior — well-established pre-cutoff patterns
- Training knowledge: `NSHealthUpdateUsageDescription` required even for write-only HealthKit — flag for verification at build time (Xcode will warn if missing)
- Training knowledge: ADP membership required for HealthKit and App Group distribution entitlements — verify against current Apple provisioning documentation before Phase 1 commit

### Tertiary (LOW confidence — validate during implementation)
- HealthKit distribution without ADP on free personal team: local development builds may work; unconfirmed for ad-hoc or direct download distribution
- `ProgressRingView.swift` AppKit independence: assumed clean but not verified in this research pass

---
*Research completed: 2026-02-26*
*Ready for roadmap: yes*
