# Testing Patterns

**Analysis Date:** 2026-02-26

## Test Framework

**Runner:**
- Apple Testing framework (Swift 5.9+)
- Config: Xcode project configuration in `HydroBar.xcodeproj`
- Located: `src/HydroBar/HydroBarTests/` and `src/HydroBar/HydroBarUITests/`

**Test Target Structure:**
- `HydroBarTests` - Unit tests
- `HydroBarUITests` - UI automation tests

**Run Commands:**
```bash
# Through Xcode (primary method)
xcodebuild test -scheme HydroBar -configuration Debug

# Or via Xcode UI: Product > Test (Cmd+U)
```

**Assertion Library:**
- Apple's native `Testing` framework macros (e.g., `#expect(...)`)
- Import: `import Testing`

## Test File Organization

**Location:**
- Unit tests: `src/HydroBar/HydroBarTests/`
- UI tests: `src/HydroBar/HydroBarUITests/`
- Separate target from main app

**Naming:**
- Filename: `{ModuleName}Tests.swift` (e.g., `HydroBarTests.swift`)
- Test struct: `{ModuleName}Tests` struct
- Test functions: `@Test func {description}() async throws`

**Structure:**
```
src/HydroBar/
├── HydroBar/              # Main app source
├── HydroBarTests/         # Unit tests
│   └── HydroBarTests.swift
└── HydroBarUITests/       # UI tests
    ├── HydroBarUITests.swift
    └── HydroBarUITestsLaunchTests.swift
```

## Test Structure

**Suite Organization:**
```swift
import Testing
@testable import HydroBar

struct HydroBarTests {
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)`
        // to check expected conditions.
    }
}
```

**Patterns:**
- Uses modern Swift Testing framework (not XCTest legacy)
- Async/await syntax: `async throws` in test function signatures
- No setup/teardown methods observed (minimal test infrastructure currently)
- Declarative macro-based assertions

## Mocking

**Framework:** Not yet implemented in test suite

**Current State:**
- Test file exists but contains only placeholder test
- No mocking framework detected (no MockObjectBox, Combine mocks, etc.)
- Tests are minimal/non-functional

**Recommendation:**
- For mocking SwiftUI ObservedObject: Create test doubles of `HydrationManager`
- For mocking system frameworks: Use `@testable import` to access internal types
- Consider using Foundation's `URLSession` mocking via custom URLProtocol

## Fixtures and Factories

**Test Data:**
Not yet implemented. Debug functions exist in main code for data generation:

```swift
// In HydrationManager.swift (MARK: - Debug Functions)
func generateFakeHistoryData() {
    // Generates random but realistic test data for 30 days
    let randomFactor = Double.random(in: 0.5...1.5)
    let fakeAmount = targetMl * randomFactor
    let isEmptyDay = Int.random(in: 1...10) == 1 // 10% chance
}

func testNotification() {
    // Sends test notification immediately
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
}
```

**Location:**
- Debug functions co-located in `HydrationManager.swift` (lines 917-982)
- Not in separate fixtures directory
- Accessible via debug mode flag: `HydrationManager.shared.debugModeEnabled`

**Usage Pattern:**
```swift
@AppStorage("debugModeEnabled") var debugModeEnabled: Bool = false

// In SettingsView, can call:
HydrationManager.shared.generateFakeHistoryData()
HydrationManager.shared.testNotification()
```

## Coverage

**Requirements:** Not enforced

**View Coverage:**
Not configured in build settings. No coverage reports detected.

**Current Test Status:**
- Minimal: Only placeholder tests exist
- `HydroBarTests.swift`: Single empty test marked with `@Test`
- `HydroBarUITestsLaunchTests.swift`: UI launch test template

## Test Types

**Unit Tests:**
- Location: `src/HydroBar/HydroBarTests/HydroBarTests.swift`
- Scope: Currently placeholder-only
- Should test:
  - `HydrationManager` singleton state management
  - Unit conversion logic (`AppUnit` enum `toCl()`, `fromCl()`, `toMl()`, `fromMl()`)
  - History calculations (`getLast7DaysData()`, `currentStreak()`, `completionRate()`)
  - Date/calendar logic for daily reset

**Integration Tests:**
- UI/state integration with mock data
- Could use `generateFakeHistoryData()` from debug functions

**UI Tests:**
- Location: `src/HydroBar/HydroBarUITests/HydroBarUITests.swift`
- Scope: Launch test template exists
- Should test:
  - MenuBar icon display states (pie ring vs percentage)
  - Main popover interactions (add water, undo)
  - Settings form interactions

**E2E Tests:**
Not applicable for this menu bar app. UI tests serve E2E purpose.

## Testing Debug Features

**Built-in Test Helpers:**

Debug Mode (`debugModeEnabled`):
```swift
@AppStorage("debugModeEnabled") var debugModeEnabled: Bool = false
```

Available debug functions:
1. `generateFakeHistoryData()` - Creates 30 days of randomized test history
2. `testNotification()` - Sends immediate test notification (1 second delay)

**Usage in Development:**
These are enabled through `SettingsView` when debug mode is active. No UI currently exposed but functions are callable.

## Test Execution

**Current Infrastructure:**
- Xcode testing framework (Swift Testing)
- Testable import pattern: `@testable import HydroBar`
- No CI/CD pipeline detected (no GitHub Actions, etc.)
- Manual testing via Xcode UI required

**Manual Testing Approach:**
1. Use debug functions to populate test data
2. Manually verify UI behavior with `generateFakeHistoryData()`
3. Verify notifications with `testNotification()`

## Common Test Patterns to Implement

**Async Testing (for notification/network code):**
```swift
@Test func notificationScheduling() async throws {
    let manager = HydrationManager()
    manager.notificationsEnabled = true
    manager.scheduleNotifications()
    // Verify notification center state
}
```

**State Testing (for HydrationManager):**
```swift
@Test func addWaterUpdatesCurrentMl() throws {
    let manager = HydrationManager()
    let initialMl = manager.currentMl
    manager.addWater(amount: 250.0)
    #expect(manager.currentMl == initialMl + 250.0)
}
```

**Unit Conversion Testing:**
```swift
@Test func unitConversion() throws {
    let cl = AppUnit.cl
    let liter = AppUnit.liter

    #expect(cl.toCl(25) == 25)
    #expect(liter.toCl(1) == 100)
    #expect(cl.toMl(25) == 250)
}
```

**History Calculation Testing:**
```swift
@Test func streakCalculation() throws {
    // Populate historyEntries with known data
    // Call calculateStreak()
    // Verify result
}
```

## TypeScript Testing (Raycast Extension)

**Framework:** Not configured

**Current State:**
- `raycast-hydrobar/` has no test files or test configuration
- ESLint configured for linting: `@raycast/eslint-config`
- No Jest/Vitest config detected

**Commands Available:**
```bash
npm run lint      # Lint TypeScript code
npm run dev       # Development mode
npm run build     # Production build
```

**Recommendation for Future:**
- Add Vitest or Jest for TypeScript unit tests
- Mock Raycast API: `@raycast/api`
- Test URL construction and error handling in command files

## Test Organization Best Practices

**Current Gaps:**
- No test data fixtures directory
- No mock objects or test doubles
- Limited test coverage
- No automated test execution (CI/CD)

**Recommended Structure:**
```
HydroBarTests/
├── HydroBarTests.swift           # Main unit tests
├── Mocks/
│   ├── MockHydrationManager.swift
│   └── MockNotificationCenter.swift
└── Fixtures/
    ├── TestData.swift
    └── SampleHistoryEntries.swift
```

---

*Testing analysis: 2026-02-26*
