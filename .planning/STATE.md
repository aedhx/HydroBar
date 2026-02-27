---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: milestone
status: executing
last_updated: "2026-02-27T09:09:41.318Z"
progress:
  total_phases: 1
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
---

# Project State: HydroBar

## Project Reference

**Core value:** Users can effortlessly track their water intake throughout the day without leaving their current workflow — one click or one keyboard shortcut from anywhere on macOS.

**Current milestone:** v1.2 — Widgets, HealthKit, Export

**Current focus:** Phase 1 — Foundation (App Group + entitlements)

---

## Current Position

**Phase:** 1 — Foundation
**Plan:** 2 complete (awaiting human-verify checkpoint)
**Status:** In progress

**Milestone progress:**
```
Phase 1 [####      ] 2/? plans complete
Phase 2 [          ] Not started
Phase 3 [          ] Not started
```

**Overall v1.2:** ~14% complete

---

## Key Decisions Locked

| Decision | Rationale |
|----------|-----------|
| HealthKit batch write at end of day (not per-sip) | Avoids undo/redo UUID-deletion complexity; simpler implementation |
| Three widget sizes (S/M/L), read-only | macOS 12 target excludes AppIntent interactive widgets (macOS 14+) |
| JSON-only export for v1.2 | CSV deferred to v2; JSON covers backup use case without extra complexity |
| App Group UserDefaults (not file-based sharing) | ~200 bytes per snapshot, no Core Data overhead, atomic writes |
| All entitlements in a single upfront pass | Prevents compounding signing failures across sessions |
| HealthKit usage keys via INFOPLIST_KEY_* build settings | Project uses GENERATE_INFOPLIST_FILE = YES; no standalone Info.plist exists |
| Widget entitlements: App Group only | Widget is read-only consumer — no HealthKit or file access needed |
| Single atomic App Group key (widget_snapshot_v1) | Eliminates partial-state race window during midnight reset or rapid water additions |
| AppGroupStore.swift in HydroBarWidget/ + explicit PBXBuildFile for main app | PBXFileSystemSynchronizedRootGroup format requires explicit file reference for cross-target sharing |
| WidgetKit timeline policy .never | HydrationManager is sole trigger via WidgetCenter.reloadTimelines(ofKind: HydroBarWidget) |

## Critical Prerequisites

- [ ] ADP membership go/no-go decision (required for App Group + HealthKit distribution)
- [ ] Confirm `ProgressRingView.swift` has no AppKit imports before adding to widget target

## Accumulated Context

### Architecture Notes
- `HydrationManager` singleton remains single source of truth — no structural changes
- New components: `AppGroupStore` (dual-target), `HealthKitWriter` (macOS 13+ only), `ExportManager` (stateless)
- Widget extension uses `.never` timeline policy — main app triggers `WidgetCenter.reloadTimelines()` explicitly
- Export reads from `historyEntries` (`[HistoryEntry]`) — NOT the legacy `history.json` / `DailyEntry` store
- HealthKit writes use `HKQuantityType(.dietaryWater)` with `HKUnit.literUnit(with: .milli)`

### Known Tech Debt
- Dual history stores (`history.json` 7-day legacy + `historyEntries.json` 30-day current) — export phase is an opportunity to address this

### Blockers
None currently.

### Open Questions
- ADP membership status (unresolved external dependency; blocks widget + HealthKit distribution)

---

## Session Continuity

**Last updated:** 2026-02-27T09:08:39Z
**Last action:** Completed 01-foundation-02-PLAN.md (widget data pipeline) — awaiting human-verify checkpoint

**To resume:** User verifies both targets build (Cmd+B) and App Group container is populated after adding water. Then continue to next plan.

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases defined | 3 |
| Requirements mapped | 14/14 |
| Plans written | 1 |
| Plans complete | 1 (pending human-verify) |
| Duration (01-foundation-01) | ~15 min |
| Files modified (01-foundation-01) | 3 |
| Phase 01-foundation P02 | 4 | 3 tasks | 4 files |

