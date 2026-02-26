# Requirements: HydroBar v1.2

**Defined:** 2026-02-26
**Core Value:** Users can effortlessly track their water intake throughout the day without leaving their current workflow

## v1 Requirements

Requirements for v1.2 release. Each maps to roadmap phases.

### Infrastructure

- [ ] **INFRA-01**: App Group shared container configured for main app and widget extension
- [ ] **INFRA-02**: Hydration data (currentMl, targetMl, presets, history) mirrored to shared UserDefaults
- [x] **INFRA-03**: Entitlements updated (App Group, HealthKit, file read-write)

### Widgets

- [ ] **WIDG-01**: Small widget displays progress ring with current percentage
- [ ] **WIDG-02**: Medium widget displays progress ring + daily stats (consumed/target)
- [ ] **WIDG-03**: Large widget displays progress ring + weekly bar chart
- [ ] **WIDG-04**: Widgets auto-refresh after each water addition, undo, or daily reset

### HealthKit

- [ ] **HLTH-01**: User can enable/disable HealthKit sync in Settings
- [ ] **HLTH-02**: App requests HealthKit authorization when user enables sync
- [ ] **HLTH-03**: Daily water total written to Apple Health at midnight reset (batch)
- [ ] **HLTH-04**: HealthKit toggle hidden on macOS < 13 with availability gate

### Export

- [ ] **EXPO-01**: User can export hydration history as JSON file via Settings
- [ ] **EXPO-02**: Export uses NSSavePanel for file location selection
- [ ] **EXPO-03**: Export includes all history entries with today marked as partial

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Widgets

- **WIDG-05**: Interactive widgets with quick-add buttons (requires macOS 14+ / AppIntent)
- **WIDG-06**: Lock Screen widgets

### HealthKit

- **HLTH-05**: Bidirectional HealthKit sync (read water data from Apple Health)
- **HLTH-06**: Per-sip HealthKit writes with UUID-tracked undo deletion

### Export

- **EXPO-04**: CSV export format with UTF-8 BOM for Excel compatibility
- **EXPO-05**: Date range selection for partial export
- **EXPO-06**: Automatic periodic export (scheduled backup)

### General

- **GENL-01**: iCloud sync for cross-device hydration data
- **GENL-02**: Custom visual themes (dark/light + color schemes)
- **GENL-03**: Dynamic daily goal adjustment (weather, activity, weight)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Interactive widgets (macOS 14+) | Requires AppIntent framework, incompatible with macOS 12+ target |
| CSV export | User chose JSON-only for v1.2; CSV can be added later |
| Per-sip HealthKit writes | Complex undo/redo pairing; batch end-of-day is simpler and sufficient |
| HealthKit read (bidirectional) | Write-only keeps implementation simple; read can come in v2 |
| iCloud sync | Privacy-first approach; adds significant complexity |
| iOS/iPadOS companion app | macOS-only focus for this version |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Pending |
| INFRA-02 | Phase 1 | Pending |
| INFRA-03 | Phase 1 | Complete |
| WIDG-01 | Phase 2 | Pending |
| WIDG-02 | Phase 2 | Pending |
| WIDG-03 | Phase 2 | Pending |
| WIDG-04 | Phase 2 | Pending |
| HLTH-01 | Phase 3 | Pending |
| HLTH-02 | Phase 3 | Pending |
| HLTH-03 | Phase 3 | Pending |
| HLTH-04 | Phase 3 | Pending |
| EXPO-01 | Phase 3 | Pending |
| EXPO-02 | Phase 3 | Pending |
| EXPO-03 | Phase 3 | Pending |

**Coverage:**
- v1.2 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0

---
*Requirements defined: 2026-02-26*
*Last updated: 2026-02-27 after 01-foundation-01 execution (INFRA-03 complete)*
