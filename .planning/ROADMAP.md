# Roadmap: HydroBar v1.2

## Overview

HydroBar v1.1 is a complete, shipping macOS menu bar app. v1.2 adds three bounded features: native macOS widgets, HealthKit write integration, and data export. The work flows through a hard dependency: App Group infrastructure must exist before any widget code is written. HealthKit and export are independent of widgets and each other, so they land in a single final phase alongside each other to keep scope tight at quick depth.

## Milestones

- Shipped: **v1.0 / v1.1** - Core hydration tracker, stats, notifications, Raycast extension
- In progress: **v1.2 Widgets + Health + Export** - Phases 1-3 (current)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - App Group, shared data container, and all entitlements — the prerequisite gate for everything in v1.2 (completed 2026-02-27)
- [ ] **Phase 2: Widgets** - WidgetKit extension with small, medium, and large widget views, live-refreshing on every water addition
- [ ] **Phase 3: HealthKit + Export** - HealthKit write integration and JSON data export, both independent of widget work

## Phase Details

### Phase 1: Foundation
**Goal**: The app shares hydration data with a widget extension process and all entitlements are cleanly provisioned — no feature code exists yet, but the data pipeline is validated end-to-end
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-03
**Success Criteria** (what must be TRUE):
  1. App Group entitlement is present on both the main app target and the widget extension target, and the app launches cleanly with a clean build
  2. Every water addition, undo, and midnight reset writes a `HydrationSnapshot` to the shared App Group UserDefaults container, readable from outside the main app process
  3. HealthKit and file read-write entitlements are present and the app passes a sandbox validation check without warnings
**Plans**: Plan 01 complete (entitlements pass — pending human-verify checkpoint)

### Phase 2: Widgets
**Goal**: Users can see their hydration progress in three native macOS widget sizes, and each widget updates automatically after every water addition, undo, or daily reset
**Depends on**: Phase 1
**Requirements**: WIDG-01, WIDG-02, WIDG-03, WIDG-04
**Success Criteria** (what must be TRUE):
  1. The small widget displays a progress ring with current percentage, visible in the macOS Notification Center widget gallery and on the Desktop
  2. The medium widget displays a progress ring alongside today's consumed and target amounts
  3. The large widget displays a progress ring alongside a 7-day bar chart matching the in-app stats view
  4. After logging water in the main app, all placed widgets visually update within one second without manual refresh
**Plans**: TBD

### Phase 3: HealthKit + Export
**Goal**: Users can sync daily hydration totals to Apple Health and export their history as a JSON file — both via Settings, both independent of widget work
**Depends on**: Phase 1
**Requirements**: HLTH-01, HLTH-02, HLTH-03, HLTH-04, EXPO-01, EXPO-02, EXPO-03
**Success Criteria** (what must be TRUE):
  1. A HealthKit toggle appears in Settings on macOS 13+ and is completely absent on macOS 12 — no hidden elements, no crashes
  2. Enabling the toggle triggers a system authorization sheet; the app correctly reflects granted or denied state afterward
  3. At midnight reset, the completed day's total is written as a single `HKQuantitySample` to Apple Health, visible in the Health app
  4. Tapping "Export JSON" in Settings opens a save panel; the saved file contains all history entries including today marked as partial
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 2/2 | Complete   | 2026-02-27 |
| 2. Widgets | 0/TBD | Not started | - |
| 3. HealthKit + Export | 0/TBD | Not started | - |
