# Architecture

**Analysis Date:** 2026-02-26

## Pattern Overview

**Overall:** MVVM (Model-View-ViewModel) with Singleton State Management

**Key Characteristics:**
- Single-window menu bar application using NSStatusItem and NSPopover
- Centralized state management via `HydrationManager` singleton
- Reactive UI updates through SwiftUI's @Published properties and ObservableObject
- Modular command structure for Raycast extension
- Cross-platform data persistence (UserDefaults + JSON files)

## Layers

**Presentation Layer (UI):**
- Purpose: Render user interface and handle user interactions
- Location: `src/HydroBar/HydroBar/*View.swift`
- Contains: SwiftUI views (MainView, StatisticsView, SettingsView, StatsComponents)
- Depends on: HydrationManager, FocusModeMonitor
- Used by: User interaction, menu bar button clicks, popover display

**Application Delegate Layer:**
- Purpose: Manage app lifecycle, menu bar integration, notifications, and system event handling
- Location: `src/HydroBar/HydroBar/HydroBarApp.swift` (AppDelegate class)
- Contains: NSStatusItem setup, NSPopover management, notification handling, keyboard shortcut restoration
- Depends on: HydrationManager, GlobalHotkeyManager
- Used by: SwiftUI app entry point, system event dispatching

**State Management Layer:**
- Purpose: Centralize all business logic, data persistence, and notifications
- Location: `src/HydroBar/HydroBar/HydrationManager.swift`
- Contains: Water tracking state, history management, notification scheduling, daily reset logic, undo/redo stack
- Depends on: UserDefaults, FileManager (local JSON storage)
- Used by: All views, AppDelegate, FocusModeMonitor

**System Integration Layer:**
- Purpose: Handle macOS-specific features (keyboard shortcuts, Focus Mode, GitHub API)
- Location: `src/HydroBar/HydroBar/GlobalHotkeyManager.swift`, `FocusModeMonitor.swift`, `GitHubUpdateChecker.swift`
- Contains: Global hotkey registration (Carbon framework), Focus Mode monitoring (Intents framework), update checking (URLSession)
- Depends on: HydrationManager
- Used by: AppDelegate, SettingsView

**Data Persistence Layer:**
- Purpose: Store and retrieve hydration history
- Location: Methods in `HydrationManager.swift`, files stored in `~/Library/Application Support/HydroBar/`
- Contains: JSON serialization/deserialization, UserDefaults access
- Depends on: FileManager
- Used by: HydrationManager

**External Integration Layer (Raycast):**
- Purpose: Provide command-line interface for water intake logging
- Location: `raycast-hydrobar/src/`
- Contains: TypeScript command handlers using Raycast API
- Depends on: HydroBar URL scheme (`hydrobar://add?ml=...` and `hydrobar://add/preset/...`)
- Used by: Raycast launcher

## Data Flow

**Water Addition Flow:**

1. User clicks "Add Water" preset button in popover or uses keyboard shortcut
2. `MainView` or `AppDelegate` calls `HydrationManager.addWater(amount:)`
3. HydrationManager updates `@Published var currentMl`, which:
   - Triggers `didSet` observer
   - Calls `saveTodayEntry()` to persist change
   - Updates `lastWaterAddedDate` to reset reminder timer
   - Sets `showReminderBadge = false`
   - Triggers `scheduleNotifications()` to reschedule reminder
4. SwiftUI re-renders views bound to `currentMl`
5. AppDelegate's timer updates menu bar icon periodically

**Daily Reset Flow:**

1. `setupDailyResetTimer()` checks every 60 seconds if midnight has passed
2. `checkAndResetIfNeeded()` detects day change:
   - Saves yesterday's entry to `historyEntries` and `history`
   - Resets `currentMl` to 0
   - Clears `undoStack`
   - Updates `lastResetDate`
3. Views automatically refresh via @Published property observation

**Notification Reminder Flow:**

1. `setupReminderCheckTimer()` checks every 60 seconds
2. `checkReminderStatus()` evaluates:
   - Time elapsed since last water addition
   - Configured reminder interval
   - Do Not Disturb mode status
3. If interval exceeded:
   - If DnD enabled: display badge in menu bar
   - If DnD disabled: `scheduleNotifications()` sends system notification
4. User taps notification action → AppDelegate calls `addWater(amount: firstPreset)`

**State Management:**

- **Reactive state**: `@Published` properties in HydrationManager trigger SwiftUI updates
- **Persistent state**: `@AppStorage` properties auto-save to UserDefaults
- **File-based state**: `historyEntries` and `history` saved to JSON files
- **Undo stack**: In-memory array of past actions (`undoStack: [(amount, timestamp)]`)
- **Transient state**: Menu bar icon refresh via 0.5s timer (not stored)

## Key Abstractions

**HydrationManager:**
- Purpose: Single source of truth for all hydration data and business logic
- Examples: `currentMl`, `targetMl`, `historyEntries`, `presetsMl`
- Pattern: Singleton with lazy initialization, property observers for side effects

**MenuBarIconView:**
- Purpose: Render pie ring or percentage text in menu bar
- Examples: `src/HydroBar/HydroBar/HydroBarApp.swift` (MenuBarIconView struct)
- Pattern: Parametric geometry rendering with swappable display modes

**NotificationInterval Enum:**
- Purpose: Standardize reminder interval configuration
- Pattern: Codable enum with raw values for persistence

**AppUnit Enum:**
- Purpose: Abstract unit conversion (cl, L, oz)
- Examples: `toCl()`, `fromMl()` methods
- Pattern: Unit converter with internal ml representation

**HistoryEntry & DailyEntry:**
- Purpose: Encode historical data for persistence
- Pattern: Codable structs with ISO8601 date formatting

**Shortcut Struct:**
- Purpose: Represent keyboard shortcut configuration
- Examples: `displayString`, `keyCodeToSymbol()` for UI rendering
- Pattern: Value type with computed display properties

## Entry Points

**Application Entry Point:**
- Location: `src/HydroBar/HydroBar/HydroBarApp.swift` (@main HydroBarApp struct)
- Triggers: App launch via Finder or shell
- Responsibilities: Initialize AppDelegate, setup notification permissions, return empty Settings scene

**AppDelegate.applicationDidFinishLaunching:**
- Location: `src/HydroBar/HydroBar/HydroBarApp.swift` (AppDelegate class)
- Triggers: After SwiftUI app initialization
- Responsibilities: Setup menu bar status item, popover, load saved shortcuts, start monitoring timers

**Menu Bar Button Click:**
- Location: `statusBarButtonClicked()` in AppDelegate
- Triggers: Left click (toggle popover) or right click (show context menu)
- Responsibilities: Route to popover toggle or context menu display

**Raycast Commands:**
- Location: `raycast-hydrobar/src/{add-preset-1,2,3,add-water}.ts`
- Triggers: Raycast launcher command invocation
- Responsibilities: Parse arguments, open `hydrobar://` URL scheme, show toast feedback

**URL Scheme Handler:**
- Location: Not shown in provided files, but referenced in package.json and code
- Triggers: `hydrobar://add?ml=250` or `hydrobar://add/preset/0`
- Responsibilities: Parse URL parameters, call HydrationManager.addWater()

## Error Handling

**Strategy:** Graceful degradation with user-facing feedback

**Patterns:**

- **File I/O**: Try/catch blocks log errors to console, fallback to empty collections
- **Notifications**: Try/catch blocks with error printing; notification failures don't crash app
- **GitHub API**: UpdateCheckResult enum with `.error(message:)` case; displayed in UI without blocking
- **Keyboard Shortcuts**: Carbon framework errors caught and logged; app continues without global hotkeys
- **Focus Mode**: Graceful fallback if INFocusStatusCenter unavailable on older macOS
- **URL Scheme**: Raycast toast shows failure message if HydroBar not running

## Cross-Cutting Concerns

**Logging:**
- Console output via `print()` statements in HydrationManager, GlobalHotkeyManager, GitHubUpdateChecker
- No centralized logging framework used

**Validation:**
- Raycast commands validate ml input (non-empty, numeric, positive)
- Unit conversion validates input > 0
- Daily reset validates date comparison

**Authentication:**
- GitHub API: Public endpoint, no authentication required
- Focus Mode: Requires system permission (Intents framework)
- Accessibility: Global hotkeys require Accessibility permission (macOS Security & Privacy)

**Localization:**
- String(localized:comment:) syntax used throughout views and managers
- Supported languages: English, French, Spanish, German, Italian, Portuguese, Dutch, Japanese, Simplified Chinese
- Language selection stored in AppStorage, applied at app init via UserDefaults.set([language], forKey: "AppleLanguages")

---

*Architecture analysis: 2026-02-26*
