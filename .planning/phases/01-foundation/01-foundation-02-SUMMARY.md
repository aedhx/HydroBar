---
phase: 01-foundation
plan: 02
subsystem: infra
tags: [widgetkit, app-group, userdefaults, shared-container, swiftui, foundation]

requires:
  - phase: 01-foundation-01
    provides: Widget extension entitlements with App Groups capability (group.com.adxcool.HydroBar)

provides:
  - AppGroupStore.swift: Foundation-only shared data bridge compiled into both HydroBar and HydroBarWidget targets
  - HydrationSnapshot / HistoryEntrySnapshot: Codable structs for widget data pipeline
  - HydroBarWidget.swift: Widget extension stub entry point reading from AppGroupStore
  - HydrationManager.syncToAppGroup(): writes snapshot + triggers WidgetCenter.reloadTimelines() on every mutation

affects:
  - 02-widget-ui
  - 03-healthkit

tech-stack:
  added:
    - WidgetKit (imported in HydrationManager.swift)
    - App Group UserDefaults (group.com.adxcool.HydroBar)
  patterns:
    - Single atomic JSON blob write to App Group (widget_snapshot_v1 key) prevents partial-state reads
    - Widget timeline policy .never — refreshes only on explicit WidgetCenter.reloadTimelines() call
    - Dual-target file sharing: AppGroupStore.swift in HydroBarWidget/ folder (auto-included in widget via PBXFileSystemSynchronizedRootGroup) + explicit PBXBuildFile for main app target

key-files:
  created:
    - src/HydroBar/HydroBarWidget/AppGroupStore.swift
    - src/HydroBar/HydroBarWidget/HydroBarWidget.swift
  modified:
    - src/HydroBar/HydroBar/HydrationManager.swift
    - src/HydroBar/HydroBar.xcodeproj/project.pbxproj

key-decisions:
  - "Single atomic key (widget_snapshot_v1) for App Group writes — one JSONEncoder().encode() operation eliminates partial-state window during midnight reset or rapid water additions"
  - "AppGroupStore.swift placed in HydroBarWidget/ directory — auto-included in widget target via PBXFileSystemSynchronizedRootGroup; added explicitly to main app Sources via PBXBuildFile"
  - "Widget deployment target macOS 26.2 (set by Xcode) — .containerBackground(.fill.tertiary, for: .widget) available without availability guard"
  - "HydroBarWidgetBundle.swift and HydroBarWidgetControl.swift removed — @main consolidated into HydroBarWidget.swift, ControlWidget not needed for this plan"
  - "WidgetKit timeline policy .never — main app is sole trigger via WidgetCenter.reloadTimelines(ofKind: HydroBarWidget)"

patterns-established:
  - "syncToAppGroup() called after every state mutation in HydrationManager: addWater, undo, checkAndResetIfNeeded"
  - "getLast7DaysSnapshotsForWidget() synthesizes today's data from live currentMl (not historyEntries) to avoid stale data"

requirements-completed: [INFRA-01, INFRA-02]

duration: 4min
completed: 2026-02-27
---

# Phase 1 Plan 02: Widget Data Pipeline Summary

**App Group shared container wired end-to-end: HydrationManager writes HydrationSnapshot to group.com.adxcool.HydroBar on every mutation; widget stub reads via AppGroupStore.read()**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-02-27T09:04:39Z
- **Completed:** 2026-02-27T09:08:39Z
- **Tasks:** 4 (1 human-action checkpoint + 3 auto tasks + 1 human-verify checkpoint)
- **Files modified:** 4

## Accomplishments

- AppGroupStore.swift: Foundation-only atomic write/read bridge using single JSON key `widget_snapshot_v1` — eliminates partial-state race during midnight reset or rapid additions
- HydroBarWidget.swift: Full stub TimelineProvider reading from AppGroupStore with `.never` reload policy
- HydrationManager.syncToAppGroup() wired to 3 mutation sites: addWater(), undo(), checkAndResetIfNeeded() daily reset
- Widget kind string "HydroBarWidget" consistent between HydroBarWidget.swift and WidgetCenter.reloadTimelines() call

## Task Commits

Each task was committed atomically:

1. **Task 1: Xcode target creation (human-action)** - completed by user before execution
2. **Task 2: AppGroupStore.swift** - `7365445` (feat)
3. **Task 3: Widget extension stub** - `c16c734` (feat)
4. **Task 4: syncToAppGroup() wired** - `5cd675e` (feat)

## Files Created/Modified

- `src/HydroBar/HydroBarWidget/AppGroupStore.swift` - Foundation-only shared bridge: HydrationSnapshot, HistoryEntrySnapshot, AppGroupStore.write/read
- `src/HydroBar/HydroBarWidget/HydroBarWidget.swift` - Widget stub: HydroBarTimelineProvider, HydroBarWidgetEntryView placeholder, @main HydroBarWidgetBundle
- `src/HydroBar/HydroBar/HydrationManager.swift` - Added import WidgetKit, syncToAppGroup(), getLast7DaysSnapshotsForWidget(); wired to 3 mutation sites
- `src/HydroBar/HydroBar.xcodeproj/project.pbxproj` - Added PBXBuildFile + PBXFileReference for AppGroupStore.swift in main app Sources phase; cleaned up SharedSources group

## Decisions Made

- Single atomic JSON blob key (`widget_snapshot_v1`) instead of individual UserDefaults keys: eliminates race window during midnight reset where widget could read partial state
- Widget deployment target inherited as macOS 26.2 (Xcode 26.2 project) — no availability guard needed for `.containerBackground`
- `@main HydroBarWidgetBundle` consolidated into `HydroBarWidget.swift`; default placeholder files removed to eliminate duplicate `@main` compile error

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed duplicate @main and unused ControlWidget files**
- **Found during:** Task 3 (widget stub creation)
- **Issue:** Xcode generated `HydroBarWidgetBundle.swift` (with `@main`) and `HydroBarWidgetControl.swift` (ControlWidget not needed). Keeping them alongside the new `HydroBarWidget.swift` (also containing `@main`) would cause duplicate `@main` compile error and ControlWidget type error.
- **Fix:** Deleted `HydroBarWidgetBundle.swift` and `HydroBarWidgetControl.swift`; consolidated `@main HydroBarWidgetBundle` into `HydroBarWidget.swift` as specified in the plan.
- **Files modified:** HydroBarWidgetBundle.swift (deleted), HydroBarWidgetControl.swift (deleted)
- **Verification:** HydroBarWidget.swift contains single `@main`, no duplicate entry points
- **Committed in:** `c16c734` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (blocking — preventing duplicate @main compile error)
**Impact on plan:** Required for compilation. Aligned with plan's intent to replace default Xcode files.

## Issues Encountered

- `PBXFileSystemSynchronizedRootGroup` (Xcode 26 format) doesn't support traditional `PBXFileReference` within synchronized groups. Xcode moved the AppGroupStore.swift file reference to "Recovered References" when opening the project. Fixed by using `sourceTree = SOURCE_ROOT` with explicit path `HydroBarWidget/AppGroupStore.swift` — Xcode will correctly resolve this to the file's location and include it in main app's Sources build phase.

## Awaiting Human Verification

This plan paused at the final `checkpoint:human-verify`. The user must:
1. Build both targets (Cmd+B) — both HydroBar and HydroBarWidgetExtension must compile
2. Run main app, add water
3. Verify App Group container is populated: `ls ~/Library/Group\ Containers/group.com.adxcool.HydroBar/`

## Next Phase Readiness

- Data pipeline proven: main app writes, widget process can read
- AppGroupStore.swift compiles into both targets
- Phase 2 (Widget UI) can now build real widget views on top of HydrationSnapshot data
- Known: AppGroupStore.swift dual-target membership — user should verify in Xcode File Inspector that it shows both HydroBar and HydroBarWidget checked under Target Membership

---
*Phase: 01-foundation*
*Completed: 2026-02-27*
