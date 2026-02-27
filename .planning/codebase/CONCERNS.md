# Codebase Concerns

**Analysis Date:** 2026-02-26

## Tech Debt

**Debug Mode in Settings:**
- Issue: DEBUG section hardcoded in `SettingsView.swift` line 410 with developer-specific functions (`generateFakeHistoryData`, `testNotification`)
- Files: `src/HydroBar/HydroBar/SettingsView.swift`
- Impact: Production app displays debug UI; users may accidentally trigger fake data generation or test notifications; unprofessional appearance
- Fix approach: Gate DEBUG section behind a build configuration flag or completely remove from release builds; consider moving to XCTest environment if needed for testing

**Console Logging for Errors:**
- Issue: All error handling uses bare `print()` statements instead of proper logging framework
- Files: Multiple files - `src/HydroBar/HydroBar/HydrationManager.swift`, `src/HydroBar/HydroBar/GlobalHotkeyManager.swift`, `src/HydroBar/HydroBar/FocusModeMonitor.swift`, `src/HydroBar/HydroBar/HydroBarApp.swift`
- Impact: Errors are logged to console only; no persistent error logging; difficult to diagnose production issues; no structured logging for debugging; print statements appear in console even in release builds
- Fix approach: Implement unified logging using `os.log` or create a custom logging wrapper; enable different log levels for debug/release builds

**Conversion Factor Precision:**
- Issue: Unit conversion uses hardcoded decimal `2.957` for oz to cl conversion (line 53 in `HydrationManager.swift`)
- Files: `src/HydroBar/HydroBar/HydrationManager.swift`
- Impact: Precision loss over time; user's historical data conversion may accumulate floating-point errors; 2.957 is rounded from 29.57ml (exact conversion is more complex); affects statistics accuracy
- Fix approach: Use more precise conversion constants with proper documentation; consider using constants like `let OZ_TO_ML: Double = 29.5735...`; add unit tests for conversion accuracy

## Known Issues

**App Language Changes Not Immediately Applied:**
- Issue: Language change in Settings requires app restart to take effect
- Files: `src/HydroBar/HydroBar/HydrationManager.swift` lines 157-163 and `src/HydroBar/HydroBar/HydroBarApp.swift` lines 16-22
- Trigger: User changes language in Settings > observes no immediate change > assumes bug
- Workaround: User must restart application for language change to apply
- Impact: Poor user experience; suggests app is broken or unresponsive to settings changes

**Duplicate History Entry Storage:**
- Issue: Both `DailyEntry` (legacy) and `HistoryEntry` structures are maintained and saved separately
- Files: `src/HydroBar/HydroBar/HydrationManager.swift`
- Trigger: `saveEntry()` saves to both `history.json` (DailyEntry) and `historyEntries.json` (HistoryEntry); each has different retention (7 vs 30 days)
- Impact: Confusing data model; redundant file I/O; potential for data inconsistency between two files; complicates maintenance and debugging; DailyEntry is marked as "legacy" but still actively used
- Current Mitigation: Data is kept somewhat in sync through `saveHistoryEntry()` calls
- Improvement Path: Deprecate DailyEntry entirely; migrate all legacy data to HistoryEntry; consolidate to single history file

## Security Considerations

**Global Hotkey Manager Uses Unmanaged Memory:**
- Risk: `Unmanaged<GlobalHotkeyManager>.fromOpaque()` with `takeUnretainedValue()` creates potential use-after-free scenarios
- Files: `src/HydroBar/HydroBar/GlobalHotkeyManager.swift` lines 129-133
- Current Mitigation: EventHandler callback captures self via unmanaged reference; AppDelegate holds reference to ensure manager lifetime
- Recommendations: Document this pattern clearly; consider safer alternatives if possible; add memory safety tests; ensure event handler is always removed in `deinit`

**Local Notification Actions Not Validated:**
- Risk: Notification action handling in AppDelegate could be exploited if custom URL schemes are added without proper validation
- Files: `src/HydroBar/HydroBar/HydroBarApp.swift`
- Current Mitigation: Currently only handles standard preset amounts via global hotkeys
- Recommendations: If custom URL schemes are exposed, implement strict URL validation; validate all preset indices before use; sanitize any user input from notifications

**No Data Encryption for Local Files:**
- Risk: User's water intake history is stored as plaintext JSON in ~/Library/Application Support/HydroBar/
- Files: `src/HydroBar/HydroBar/HydrationManager.swift` (history file paths lines 488-509)
- Current Mitigation: Relies on filesystem permissions and user login password
- Recommendations: Consider using Keychain for sensitive settings; use NSDataProtectionComplete for history files; document data storage location

## Performance Bottlenecks

**Timer-Based Daily Reset and Reminder Checks:**
- Problem: Running timers every 60 seconds for daily check and every 60 seconds for reminder check; 2 Timer instances active at all times
- Files: `src/HydroBar/HydroBar/HydrationManager.swift` lines 295-317
- Cause: Polling approach instead of event-driven; constant checking even when app is backgrounded or inactive
- Improvement Path: Use DispatchSourceTimer for more efficient scheduling; use system calendar notifications for midnight resets instead of polling; consolidate timers into single timer with multiple checks

**Focus Mode Polling Every 30 Seconds:**
- Problem: `FocusModeMonitor` polls Focus Mode status every 30 seconds even when autosync is disabled
- Files: `src/HydroBar/HydroBar/FocusModeMonitor.swift` lines 106-120
- Cause: No direct notification API for INFocusStatusCenter changes; timer runs unconditionally in startPeriodicCheck
- Improvement Path: Only start timer if autosync is enabled; use DispatchSourceTimer instead of Timer; investigate notification-based alternatives; stop timer when app backgrounded

**Large History Data in Memory:**
- Problem: All 30 days of history loaded into memory via `@Published var historyEntries: [HistoryEntry]`; every day adds new entry without cleanup
- Files: `src/HydroBar/HydroBar/HydrationManager.swift` lines 179-180
- Cause: Simple array storage; no lazy loading or pagination
- Improvement Path: Use Core Data for history management; implement lazy loading for statistics view; paginate history display; archive old data after 90 days

**Notification Rescheduling on Every Water Addition:**
- Problem: `addWater()` calls `scheduleNotifications()` which removes all pending notifications and recreates them
- Files: `src/HydroBar/HydroBar/HydrationManager.swift` lines 369-396
- Cause: Inefficient notification management; reschedules even if same interval unchanged
- Improvement Path: Only reschedule if interval changed; track last schedule time; batch notification updates; defer rescheduling to avoid excessive operations

## Fragile Areas

**Global Hotkey System Tight Coupling to Carbon Event System:**
- Files: `src/HydroBar/HydroBar/GlobalHotkeyManager.swift`
- Why Fragile: Low-level Carbon API; complex memory management with unmanaged references; system-reserved shortcuts detection is incomplete (only checks 5 shortcuts); event handler callback must avoid touching Swift objects that might be deallocated
- Safe Modification: Add integration tests for all hotkey operations; document all assumptions about event handler lifetime; avoid adding new Carbon API calls without understanding memory implications; test with third-party hotkey managers
- Test Coverage: No test coverage for hotkey registration/unregistration; no tests for error handling (9 different error cases)

**AppDelegate Status Bar Integration:**
- Files: `src/HydroBar/HydroBar/HydroBarApp.swift` (AppDelegate starting line 142)
- Why Fragile: Manual NSStatusItem and NSPopover management; multiple asynchronous operations update UI (0.5s timer for checks, notification handling); popover size is dynamically calculated via PreferenceKey; tight coupling between status bar icon and main view updates
- Safe Modification: Understand popover lifecycle; ensure all UI updates happen on main thread (current code does this); test with multiple display configurations; be careful when changing layout as it affects popover sizing
- Test Coverage: No tests for status bar functionality; no UI tests for popover behavior

**Notification System with Multiple State Variables:**
- Files: `src/HydroBar/HydroBar/HydrationManager.swift`
- Why Fragile: Multiple state variables control notification behavior (`notificationsEnabled`, `doNotDisturb`, `focusModeAutoSync`); complex interdependencies - DnD affects notification display but not scheduling; focus mode autosync can override doNotDisturb; state stored across multiple AppStorage keys
- Safe Modification: Understand state machine: notifications disabled = all off; enabled + DnD = badge only; enabled + focus active + autosync = badge only; trace through all didSet handlers before changing logic; test interaction between all settings combinations
- Test Coverage: Only example placeholder test exists; no tests for state transitions or edge cases

## Scaling Limits

**History File Size Without Bounds:**
- Current Capacity: Stores 30 days of HistoryEntry (1 per day = ~300 bytes each = ~9KB); 7 days of DailyEntry in separate file
- Limit: No automatic archival or cleanup; if app runs indefinitely, HistoryEntry file grows by ~9KB per month; no database indices
- Scaling Path: Migrate to Core Data with proper indexing; implement archival after 1 year; use sqlite3 for scalable querying; add data migration support for long-term users

**Menu Bar Popover Content Recalculation:**
- Current Capacity: Currently handles 3 views (main, statistics, settings); statistics view recalculates 7 and 30-day data on each display
- Limit: Statistics calculations iterate through arrays (getLast30DaysData creates 30 HistoryEntry objects every call); no caching of computed properties; could slow down with future features
- Scaling Path: Cache computed statistics; implement lazy evaluation; optimize array filtering; consider virtualizing long lists in future UI

## Dependencies at Risk

**Apple Carbon Framework for Global Hotkeys:**
- Risk: Carbon is deprecated; no public macOS API replacement for global hotkeys; reliant on low-level event handling
- Impact: Could break on future macOS versions; Apple could remove Carbon support; already requires private API workarounds
- Migration Plan: Monitor Apple's frameworks for AppKit alternatives; consider migrating to IPC with system service if Carbon is removed; add feature flag to gracefully disable hotkeys if API becomes unavailable; investigate Swift alternatives like IOKit

**Direct Access to INFocusStatusCenter (macOS 12+ only):**
- Risk: Apple could change or remove INFocusStatusCenter API
- Impact: Focus Mode sync would break on new macOS versions
- Migration Plan: Add version-specific guards; implement graceful degradation (focus sync disabled on unsupported versions); monitor Apple's Human Activity API for changes

## Missing Critical Features

**No Data Backup or Export:**
- Problem: User data stored only in ~/Library/Application Support/HydroBar/ ; no export function; no iCloud sync
- Blocks: Users cannot backup history before uninstall; cannot access data after app deletion; cannot migrate to new Mac
- Approach: Add JSON export in Settings; consider adding CSV export for analysis; could add optional iCloud sync with user consent; document manual export workaround

**No Error Recovery or Data Integrity Checks:**
- Problem: If JSON files become corrupted, app fails silently or crashes; no validation of loaded data
- Blocks: Users cannot recover from accidental data corruption; no file integrity verification
- Approach: Add try-catch for file loading; implement JSON validation; add repair function in debug menu; create checksums for important files

## Test Coverage Gaps

**HydrationManager Untested:**
- What's Not Tested: addWater/undo operations; daily reset logic; history persistence; notification scheduling; streak calculation; completion rate statistics
- Files: `src/HydroBar/HydroBar/HydrationManager.swift` (983 lines) + `src/HydroBar/HydroBar/FocusModeMonitor.swift`
- Risk: Core business logic untested; daily reset could silently fail and lose data; undo stack could corrupt state; statistics could display wrong values; no regression tests for calculation accuracy
- Priority: High - this is the core data model

**GlobalHotkeyManager Untested:**
- What's Not Tested: Hotkey registration/unregistration; event handling; modifier key conversion; system-reserved shortcut detection; error cases (key already in use, invalid key code, missing permissions)
- Files: `src/HydroBar/HydroBar/GlobalHotkeyManager.swift` (472 lines)
- Risk: Global hotkeys could silently fail to register; user's configured shortcuts may not work; no visibility into why a shortcut fails
- Priority: High - users depend on hotkey functionality

**UI Integration Tests Missing:**
- What's Not Tested: Popover opens/closes; view switching; button interactions; text input handling; settings persistence
- Files: `src/HydroBar/HydroBar/MainView.swift`, `src/HydroBar/HydroBar/SettingsView.swift`, `src/HydroBar/HydroBar/StatisticsView.swift`
- Risk: UI changes could break without notice; settings changes may not persist; view state could become inconsistent
- Priority: Medium - affects user experience but core logic is more critical

**Notification Scheduling Untested:**
- What's Not Tested: Notification request creation; interval changes; do-not-disturb interaction; focus mode sync; reminder badge logic
- Files: `src/HydroBar/HydroBar/HydrationManager.swift` (notification functions) + `src/HydroBar/HydroBar/FocusModeMonitor.swift`
- Risk: Notifications might not schedule at configured intervals; badge might not appear when expected; do-not-disturb could fail to suppress notifications
- Priority: High - users rely on reminders to stay hydrated

---

*Concerns audit: 2026-02-26*
