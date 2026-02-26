---
phase: 01-foundation
plan: 01
subsystem: infra
tags: [entitlements, healthkit, app-group, code-signing, xcode]

# Dependency graph
requires: []
provides:
  - "HydroBar.entitlements with App Group (group.com.adxcool.HydroBar), HealthKit, and file read-write"
  - "HydroBarWidget.entitlements with App Group only"
  - "HealthKit NSUsageDescription keys in Xcode build settings (INFOPLIST_KEY_*)"
affects: [02-foundation, widget, healthkit, export]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "App Group identifier: group.com.adxcool.HydroBar (used in both targets for UserDefaults sharing)"
    - "HealthKit usage strings via INFOPLIST_KEY_* (project uses GENERATE_INFOPLIST_FILE = YES, no standalone Info.plist)"

key-files:
  created:
    - "src/HydroBar/HydroBarWidget/HydroBarWidget.entitlements"
  modified:
    - "src/HydroBar/HydroBar/HydroBar.entitlements"
    - "src/HydroBar/HydroBar.xcodeproj/project.pbxproj"

key-decisions:
  - "HealthKit usage keys added via INFOPLIST_KEY_* build settings (not standalone Info.plist — project uses GENERATE_INFOPLIST_FILE = YES)"
  - "Widget entitlements contain App Group only — no HealthKit or file access (widget is read-only consumer)"
  - "files.user-selected.read-write replaces read-only for export support"

patterns-established:
  - "App Group identifier group.com.adxcool.HydroBar must be identical in all targets that share data"

requirements-completed: [INFRA-03]

# Metrics
duration: 15min
completed: 2026-02-27
---

# Phase 1 Plan 1: Entitlements & HealthKit Baseline Summary

**App Group + HealthKit + file read-write entitlements configured across main app and widget targets; HealthKit usage strings added via Xcode build settings**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-02-26T23:51:47Z
- **Completed:** 2026-02-27T00:06:47Z
- **Tasks:** 3 (+ 1 human-verify checkpoint pending)
- **Files modified:** 3

## Accomplishments
- Updated `HydroBar.entitlements`: upgraded file access to read-write, added App Group `group.com.adxcool.HydroBar`, added `com.apple.developer.healthkit`
- Created `HydroBarWidget.entitlements`: app-sandbox + App Group only (correct minimal set for read-only widget consumer)
- Added `NSHealthUpdateUsageDescription` and `NSHealthShareUsageDescription` via `INFOPLIST_KEY_*` build settings in both Debug and Release configs

## Task Commits

Each task was committed atomically:

1. **Task 1: Update main app entitlements** - `57b7640` (chore)
2. **Task 2: Create widget extension entitlements** - `e483cfd` (chore)
3. **Task 3: Add HealthKit usage description keys** - `da9678e` (chore)

**Plan metadata:** (to be added after final checkpoint approval)

## Files Created/Modified
- `src/HydroBar/HydroBar/HydroBar.entitlements` - Main app entitlements: sandbox, apple-events, network-client, files-read-write, application-groups, developer-healthkit (6 keys)
- `src/HydroBar/HydroBarWidget/HydroBarWidget.entitlements` - Widget entitlements: sandbox, application-groups (2 keys)
- `src/HydroBar/HydroBar.xcodeproj/project.pbxproj` - Added INFOPLIST_KEY_NSHealthUpdateUsageDescription and INFOPLIST_KEY_NSHealthShareUsageDescription to HydroBar target Debug + Release configs

## Decisions Made
- **HealthKit keys via build settings:** No standalone Info.plist exists — project uses `GENERATE_INFOPLIST_FILE = YES`. Added `INFOPLIST_KEY_NSHealthUpdateUsageDescription` and `INFOPLIST_KEY_NSHealthShareUsageDescription` to both Debug and Release build configurations for the HydroBar target. This is the correct approach for this project structure.
- **Widget entitlements scope:** Widget gets App Group only. HealthKit and file access are intentionally excluded — the widget is a read-only display consumer that reads from App Group UserDefaults.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug / Adaptation] HealthKit keys added to Xcode build settings instead of standalone Info.plist**
- **Found during:** Task 3 (Add HealthKit usage description keys to Info.plist)
- **Issue:** Plan specified modifying `src/HydroBar/HydroBar/Info.plist`, which does not exist. The project uses `GENERATE_INFOPLIST_FILE = YES` — Info.plist is auto-generated from build settings. No standalone file can be created.
- **Fix:** Added `INFOPLIST_KEY_NSHealthUpdateUsageDescription` and `INFOPLIST_KEY_NSHealthShareUsageDescription` to both Debug and Release build configurations for the HydroBar target in `project.pbxproj`. The plan itself noted this alternative approach ("If the project uses GENERATE_INFOPLIST_FILE = YES, add the keys via the INFOPLIST_KEY_* build settings approach").
- **Files modified:** `src/HydroBar/HydroBar.xcodeproj/project.pbxproj`
- **Verification:** Both keys present in both configurations; keys will appear in the generated Info.plist at build time
- **Committed in:** `da9678e` (Task 3 commit)

---

**Total deviations:** 1 (anticipated alternative approach — plan provided the solution)
**Impact on plan:** No scope creep. Correct implementation for this project structure. Both HealthKit usage strings will be present in the generated Info.plist at build time.

## Issues Encountered
None — all tasks completed cleanly. The Info.plist deviation was anticipated by the plan itself.

## Signing Notes for Future Reference
- `DEVELOPMENT_TEAM` is set to `""` (empty) in both configs — signing requires a developer team to be configured before App Store distribution
- `CODE_SIGN_STYLE = Manual` in HydroBar target — provisioning profile must be manually assigned when a team is added
- App Group capability requires ADP membership for distribution (tracked in STATE.md open questions)
- Entitlement syntax errors would manifest as build failures with "CODE_SIGNING_ALLOWED" errors — current file syntax is valid XML/plist

## Human Verify Checkpoint
**Status:** PENDING — awaiting Xcode build verification

Steps for user:
1. Open `src/HydroBar/HydroBar.xcodeproj`
2. Select HydroBar target → Signing & Capabilities
3. Confirm App Groups shows `group.com.adxcool.HydroBar`
4. Confirm HealthKit capability is present
5. Confirm App Sandbox shows "User Selected File: Read/Write"
6. Clean build (Product → Clean Build Folder, then Cmd+B)
7. Build must succeed (signing team warnings are OK; entitlement key errors are not)
8. Run app briefly to confirm no crash

## Next Phase Readiness
- Entitlement baseline is set for all three v1.2 features (widget, HealthKit, export)
- Plan 02 (widget extension target creation) can proceed once human-verify checkpoint is approved
- ADP membership status remains an open dependency for distribution (not blocking local development)

---
*Phase: 01-foundation*
*Completed: 2026-02-27*
