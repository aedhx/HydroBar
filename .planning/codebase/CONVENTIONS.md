# Coding Conventions

**Analysis Date:** 2026-02-26

## Naming Patterns

**Files:**
- Swift files: PascalCase (e.g., `HydrationManager.swift`, `MainView.swift`, `ProgressRingView.swift`)
- TypeScript files: kebab-case (e.g., `add-water.ts`, `add-preset-1.ts`)

**Functions/Methods:**
- Swift: camelCase with verbs for action methods (e.g., `addWater()`, `undo()`, `setupStatusBar()`, `checkReminderStatus()`)
- TypeScript: default export async functions named `Command` for Raycast commands

**Variables:**
- Swift: camelCase for local variables and properties (e.g., `currentMl`, `targetMl`, `isHolding`, `isGoalReached`)
- Swift: Prefix underscore for private properties (e.g., `_dailyCheckTimer`)
- Swift: ALL_CAPS for constants (e.g., `HYDROBAR_ADD_PRESET`)
- TypeScript: camelCase for local variables

**Types:**
- Swift: PascalCase for structs, classes, enums (e.g., `HydrationManager`, `DailyEntry`, `MenuBarIconStyle`, `AppUnit`)
- Swift: Single letter or short for generic types (e.g., `Element` in extensions)
- TypeScript: Interface/Type naming follows API conventions

## Code Style

**Formatting:**
- Swift: 4-space indentation (standard Xcode default)
- TypeScript: Uses Raycast ESLint config (specified in `raycast-hydrobar/package.json`)
- Line length: No strict limit observed, but generally kept readable

**Linting:**
- Swift: Native Xcode linting via compiler warnings
- TypeScript: `@raycast/eslint-config` (v1.0.0) enforced through `npm run lint`
- ESLint config reference: `.planning/codebase/` (not checked directly)

## Import Organization

**Swift Order:**
1. Standard library imports first (Foundation, SwiftUI, AppKit, UserNotifications)
2. Framework imports (SwiftUI, AppKit)
3. System imports (UserNotifications, UserDefaults, FileManager, URLSession)
4. No external package manager dependencies observed in Swift code

**TypeScript Order:**
1. Raycast API imports (e.g., `@raycast/api`)
2. Constants and configuration below imports
3. Example: `import { open, showToast, Toast } from "@raycast/api";`

**Path Aliases:**
- Not used in this codebase
- Absolute imports preferred

## Error Handling

**Swift Patterns:**
- Try-catch blocks for file operations and encoding/decoding:
  ```swift
  do {
      let data = try Data(contentsOf: historyFileURL)
      let decoder = JSONDecoder()
      let entries = try decoder.decode([DailyEntry].self, from: data)
  } catch {
      history = []
  }
  ```
- Optional handling with `guard` and `if let`:
  ```swift
  guard let button = statusItem?.button else { return }
  if let error = error {
      print("Erreur lors de la sauvegarde: \(error)")
  }
  ```
- Default values for recovery: `Array(rawValue: storedPresetsMlRaw) ?? [200.0, 500.0, 750.0]`

**TypeScript Patterns:**
- Try-catch blocks in async functions:
  ```typescript
  try {
      await open(url);
      await showToast({ style: Toast.Style.Success, title: "Added" });
  } catch (e) {
      await showToast({ style: Toast.Style.Failure, title: "Error" });
  }
  ```
- Simple validation before operations:
  ```typescript
  if (!ml || isNaN(num) || num <= 0) {
      // Show error toast
  }
  ```

## Logging

**Framework:** `print()` for both Swift and TypeScript (console output)

**Patterns:**
- Swift: Primarily for debug/error scenarios:
  ```swift
  print("Erreur lors de la sauvegarde de l'historique: \(error)")
  print("Notification de test envoyée avec succès")
  ```
- Localized user-facing messages use String localization (e.g., `String(localized: "...comment: "...")`)
- User notifications via Raycast `showToast()` in TypeScript
- User alerts via `NSAlert` or notification center in Swift

## Comments

**When to Comment:**
- Section markers: `// MARK: - SectionName` used extensively for code organization
- Temporary explanations for non-obvious logic
- French and English comments mixed throughout (reflects bilingual development)
- Comments inline for complex calculations or state management

**Documentation:**
- Triple-slash comments rare; code structure with MARK comments provides organization
- Function documentation through parameter documentation (seen in `addWater()` function)
- Example: `/// Ajoute de l'eau (amount toujours en ml)`

**MARK Usage Pattern:**
```swift
// MARK: - Section Name
// MARK: - Subsection Name
// Used for organizing large structs/classes:
// MARK: - AppStorage Properties
// MARK: - Published Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - UI Helper Methods
// MARK: - History Management
// MARK: - Notifications
// MARK: - Debug Functions
```

## Function Design

**Size:**
- Swift: Functions typically 10-50 lines, larger data management functions (e.g., `getLast30DaysData`) can reach 50+ lines
- TypeScript: Compact, typically 15-25 lines per command

**Parameters:**
- Swift: Use named parameters in method calls (required by Swift style):
  ```swift
  await showToast(style: Toast.Style.Success, title: "Added")
  manager.addWater(amount: 250.0, skipUndo: false)
  ```
- TypeScript: Destructured arguments common:
  ```typescript
  export default async function Command({ arguments: args }: { arguments: { ml: string } })
  ```

**Return Values:**
- Swift: Use `@discardableResult` for methods that can be ignored:
  ```swift
  @discardableResult
  func undo() -> Bool { ... }
  ```
- Swift: Computed properties preferred for derived values:
  ```swift
  var progress: Double {
      guard manager.targetMl > 0 else { return 0 }
      return manager.currentMl / manager.targetMl
  }
  ```

## Module Design

**Exports:**
- Swift: No explicit exports (all public types/methods available by default)
- TypeScript: Single default export pattern:
  ```typescript
  export default async function Command() { ... }
  ```

**File Structure:**
- One primary type per file in Swift (matching filename: `HydrationManager.swift` contains `HydrationManager` class)
- Helper structs/enums defined in same file with MARK sections
- Related helper types defined together

**State Management:**
- Swift: Centralized in `HydrationManager` singleton with `@Published` properties for SwiftUI observation
- Swift: `@StateObject` used in views for ownership, local `@State` for UI-only state
- AppStorage used for persistence of user preferences

## Bilingual Code

**Languages Mixed:**
- French comments predominant in HydrationManager and core logic
- English comments in UI and configuration sections
- Localization keys use English base with comments in French for context

Example from `HydrationManager.swift`:
```swift
// Configurer la langue de l'application
UNUserNotificationCenter.current().delegate = appDelegate

// MARK: - Notifications

/// Sauvegarde l'entrée du jour actuel
private func saveTodayEntry() { ... }
```

## Standard Patterns Observed

**Singleton Pattern:**
- `HydrationManager.shared` - singleton for app-wide state
- `GlobalHotkeyManager.shared` - shared instance for hotkey management
- `FocusModeMonitor.shared` - singleton for system monitoring

**Observer Pattern:**
- SwiftUI `@ObservedObject` and `@Published` for reactive updates
- Example: `@Published var currentMl: Double` triggers updates when changed

**Manager/Service Pattern:**
- Large classes manage specific domains: HydrationManager, GlobalHotkeyManager, GitHubUpdateChecker
- Methods organized by responsibility with MARK sections

---

*Convention analysis: 2026-02-26*
