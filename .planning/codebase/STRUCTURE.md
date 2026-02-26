# Codebase Structure

**Analysis Date:** 2026-02-26

## Directory Layout

```
Hydrobar/
├── src/                                    # Main macOS app source code
│   └── HydroBar/                          # Xcode project root
│       ├── HydroBar/                      # Main app target (Swift source)
│       ├── HydroBar.xcodeproj/            # Xcode project configuration
│       ├── HydroBarTests/                 # Unit tests
│       └── HydroBarUITests/               # UI tests
├── raycast-hydrobar/                      # Raycast extension (TypeScript)
│   ├── src/                               # Extension command handlers
│   ├── assets/                            # Raycast UI assets
│   └── package.json                       # Dependencies and metadata
├── Resources/                             # Shared assets and documentation
├── .planning/                             # GSD planning documents
├── .gitignore                            # Git ignore rules
├── README.md                              # Project documentation
├── RELEASE_NOTES_v1.1.md                 # Version notes
└── package-raycast-extension.sh           # Raycast packaging script
```

## Directory Purposes

**`src/HydroBar/HydroBar/`:**
- Purpose: Core application Swift source code
- Contains: View files (.swift), asset catalogs, entitlements, localization
- Key files: HydroBarApp.swift (entry point), HydrationManager.swift (state), MainView.swift, SettingsView.swift

**`src/HydroBar/HydroBar.xcodeproj/`:**
- Purpose: Xcode project and build configuration
- Contains: Project settings, build phases, code signing, scheme definitions
- Key files: project.pbxproj (project manifest)

**`src/HydroBar/HydroBarTests/`:**
- Purpose: Unit test target
- Contains: HydroBarTests.swift (minimal test stub)
- Status: Minimal coverage

**`src/HydroBar/HydroBarUITests/`:**
- Purpose: UI automation tests
- Contains: HydroBarUITests.swift, HydroBarUITestsLaunchTests.swift
- Status: Minimal coverage

**`raycast-hydrobar/`:**
- Purpose: Raycast extension for water logging via launcher
- Contains: TypeScript command handlers, extension metadata
- Key files: package.json (commands configuration), src/*.ts (individual command implementations)

**`raycast-hydrobar/src/`:**
- Purpose: Raycast command implementations
- Contains: add-preset-1.ts, add-preset-2.ts, add-preset-3.ts, add-water.ts
- Pattern: Each file exports default async function handling one Raycast command

**`Resources/`:**
- Purpose: Shared assets and documentation
- Contains: Marketing images (hero-banner.png, stream-deck.png)
- Used by: README, GitHub repository display

**`.planning/codebase/`:**
- Purpose: GSD analysis documents
- Generated: Yes (auto-created by GSD tools)
- Committed: Yes

## Key File Locations

**Entry Points:**
- `src/HydroBar/HydroBar/HydroBarApp.swift`: @main app entry point and AppDelegate
- `src/HydroBar/HydroBar/MainView.swift`: Primary popover content view
- `raycast-hydrobar/src/add-water.ts`: Raycast custom water entry command

**Configuration:**
- `src/HydroBar/HydroBar.xcodeproj/project.pbxproj`: Xcode build config
- `src/HydroBar/HydroBar/HydroBar.entitlements`: macOS entitlements (menu bar, notifications, accessibility)
- `raycast-hydrobar/package.json`: Raycast extension metadata and command definitions

**Core Logic:**
- `src/HydroBar/HydroBar/HydrationManager.swift`: State management, persistence, notifications, history
- `src/HydroBar/HydroBar/GlobalHotkeyManager.swift`: Keyboard shortcut registration and handling
- `src/HydroBar/HydroBar/FocusModeMonitor.swift`: macOS Focus Mode integration
- `src/HydroBar/HydroBar/GitHubUpdateChecker.swift`: Update checking logic

**Views (Presentation):**
- `src/HydroBar/HydroBar/MainView.swift`: Header and view router (main/stats/settings)
- `src/HydroBar/HydroBar/SettingsView.swift`: Configuration UI (language, notifications, shortcuts)
- `src/HydroBar/HydroBar/StatisticsView.swift`: Statistics display container
- `src/HydroBar/HydroBar/StatsComponents.swift`: Reusable stat components (header, weekly chart, heatmap)
- `src/HydroBar/HydroBar/ProgressRingView.swift`: Animated progress ring visualization
- `src/HydroBar/HydroBar/ShortcutRecorderView.swift`: Keyboard shortcut input UI

**Utilities & Helpers:**
- `src/HydroBar/HydroBar/ContentView.swift`: Unused placeholder view

**Testing:**
- `src/HydroBar/HydroBarTests/HydroBarTests.swift`: Minimal test stubs
- `src/HydroBar/HydroBarUITests/HydroBarUITests.swift`: UI automation stubs

**Localization:**
- `src/HydroBar/HydroBar/Localizable.xcstrings`: Localization strings (9 languages)

## Naming Conventions

**Files:**
- View files: `{Name}View.swift` (e.g., MainView.swift, SettingsView.swift)
- Manager classes: `{Name}Manager.swift` (e.g., HydrationManager.swift, GlobalHotkeyManager.swift)
- Utility classes: `{Name}.swift` (e.g., GitHubUpdateChecker.swift, FocusModeMonitor.swift)
- Component structs: `{Name}Components.swift` (e.g., StatsComponents.swift)
- Raycast commands: `{action-name}.ts` (e.g., add-water.ts, add-preset-1.ts)

**Directories:**
- Feature bundles: `{FeatureName}/` (e.g., HydroBar/ for main app)
- Target bundles: `{TargetName}.xcodeproj/` (e.g., HydroBar.xcodeproj)
- Test bundles: `{TargetName}Tests/` (e.g., HydroBarTests, HydroBarUITests)

**Structures & Classes:**
- PascalCase for type names (e.g., HydrationManager, MainView, MenuBarIconView)
- Enum values: camelCase (e.g., `.pieRing`, `.percentage`, `.main`, `.settings`)
- Computed properties: camelCase (e.g., `currentStreak`, `weeklyTotal`, `displayProgress`)

**Functions & Methods:**
- camelCase for public methods (e.g., `addWater()`, `calculateStreak()`, `getLast7DaysData()`)
- camelCase with verb prefix (e.g., `checkAndResetIfNeeded()`, `setupStatusBar()`)
- Private methods: underscore prefix avoided, marked with `private func` (e.g., `saveTodayEntry()`)

## Where to Add New Code

**New Feature (Hydration Tracking Enhancement):**
- Primary code: `src/HydroBar/HydroBar/HydrationManager.swift` (add state/methods)
- UI layer: `src/HydroBar/HydroBar/MainView.swift` or new `{Feature}View.swift`
- Tests: `src/HydroBar/HydroBarTests/HydroBarTests.swift` (extend test class)

**New Component/Module (e.g., MachineLearning Prediction):**
- Implementation: Create `src/HydroBar/HydroBar/{Name}.swift`
- Add to Xcode project: Include in Build Phases > Compile Sources
- Integration: Inject into HydrationManager or AppDelegate as needed

**Utilities/Helpers (e.g., DateFormatter extensions):**
- Shared helpers: Add to existing utility file or create `src/HydroBar/HydroBar/{Name}Utilities.swift`
- Extensions: Group in same file as the type they extend

**Raycast Extension Command:**
- Implementation: Create `raycast-hydrobar/src/{command-name}.ts`
- Register: Add entry to `raycast-hydrobar/package.json` commands array
- Pattern: Follow `add-water.ts` pattern (import Raycast API, export default async function, use `open()` for URL scheme)

## Special Directories

**`Assets.xcassets`:**
- Purpose: Image, color, and app icon assets
- Generated: No
- Committed: Yes
- Contains: AppIcon.appiconset (1024x1024 app icon), AccentColor.colorset

**`Preview Content/`:**
- Purpose: SwiftUI preview resources
- Generated: No
- Committed: Yes
- Contains: Preview Assets.xcassets (preview-specific images)

**`~/Library/Application Support/HydroBar/`:**
- Purpose: User data persistence directory
- Generated: Yes (created at runtime by HydrationManager)
- Committed: No
- Contains: `history.json` (7-day history), `historyEntries.json` (30-day history with targets)

**`.xcodeproj/xcshareddata/xcschemes/`:**
- Purpose: Shared build schemes
- Generated: No
- Committed: Yes
- Contains: HydroBar.xcscheme (run configuration)

---

*Structure analysis: 2026-02-26*
