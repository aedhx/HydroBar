# Project State: HydroBar

## Project Reference

**Core value:** Users can effortlessly track their water intake throughout the day without leaving their current workflow — one click or one keyboard shortcut from anywhere on macOS.

**Current milestone:** v1.2 — Widgets, HealthKit, Export

**Current focus:** Phase 1 — Foundation (App Group + entitlements)

---

## Current Position

**Phase:** 1 — Foundation
**Plan:** None started
**Status:** Not started

**Milestone progress:**
```
Phase 1 [          ] Not started
Phase 2 [          ] Not started
Phase 3 [          ] Not started
```

**Overall v1.2:** 0% complete

---

## Key Decisions Locked

| Decision | Rationale |
|----------|-----------|
| HealthKit batch write at end of day (not per-sip) | Avoids undo/redo UUID-deletion complexity; simpler implementation |
| Three widget sizes (S/M/L), read-only | macOS 12 target excludes AppIntent interactive widgets (macOS 14+) |
| JSON-only export for v1.2 | CSV deferred to v2; JSON covers backup use case without extra complexity |
| App Group UserDefaults (not file-based sharing) | ~200 bytes per snapshot, no Core Data overhead, atomic writes |
| All entitlements in a single upfront pass | Prevents compounding signing failures across sessions |

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

**Last updated:** 2026-02-26
**Last action:** Roadmap created — 3 phases, 14/14 requirements mapped

**To resume:** Run `/gsd:plan-phase 1` to plan Foundation phase.

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases defined | 3 |
| Requirements mapped | 14/14 |
| Plans written | 0 |
| Plans complete | 0 |
