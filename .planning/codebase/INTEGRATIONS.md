# External Integrations

**Analysis Date:** 2026-02-26

## APIs & External Services

**GitHub Releases API:**
- Service: GitHub API for release checking
- What it's used for: Fetching latest HydroBar release version to notify users of updates
- SDK/Client: `URLSession` (native Swift networking)
- Implementation: `GitHubUpdateChecker.swift`
- Endpoint: `https://api.github.com/repos/aedhx/HydroBar/releases/latest`
- Auth: None (public API, no authentication needed)
- Optional: Yes (update check feature can be disabled in settings)

## Data Storage

**Local Storage:**
- Type: Local filesystem (Application Support directory)
- Location: `~/Library/Application Support/HydroBar/`
- Files:
  - `history.json` - Historical water intake data (DailyEntry format, legacy)
  - `historyEntries.json` - Historical entries with target tracking (HistoryEntry format)
- Retention: 7 days for weekly chart, 30 days for heatmap
- Client: Swift's `FileManager` and `JSONEncoder/JSONDecoder`

**User Preferences:**
- Storage: macOS UserDefaults (sandboxed container)
- Key-value pairs for app settings (goals, units, notifications, shortcuts)
- Implementation: `@AppStorage` property wrapper and direct UserDefaults access

**File Storage:**
- Type: Not applicable - no cloud file storage
- Location: Local filesystem only

**Caching:**
- Type: None - in-memory state management only
- Data refreshes on app startup and at daily reset

## Authentication & Identity

**Auth Provider:**
- Type: None - app is single-user, local-only
- No user accounts or authentication system
- Accessibility permissions required for global keyboard shortcuts (system-level, not authentication)

## Monitoring & Observability

**Error Tracking:**
- Type: None - no external error tracking service
- Local logging only via `print()` statements in debug builds

**Logs:**
- Type: Local console output
- Location: Xcode console during development
- Production: Silent operation (no persistent logs)
- Notable log points:
  - `HydrationManager.swift`: History save errors, notification scheduling
  - `GlobalHotkeyManager.swift`: Event handler setup errors
  - `GitHubUpdateChecker.swift`: Network request errors
  - `FocusModeMonitor.swift`: macOS version compatibility notes

## CI/CD & Deployment

**Hosting:**
- Platform: GitHub Releases
- Distribution: DMG file containing universal binary
- Build outputs: `HydroBar-v{version}.dmg`
- Location: `https://github.com/aedhx/HydroBar/releases`

**CI Pipeline:**
- Type: None detected - manual builds via Xcode
- Build method: Xcode project configured for Release and Debug schemes
- Distribution script: `package-raycast-extension.sh` (for packaging Raycast extension)

**Raycast Distribution:**
- Platform: Raycast Extension Store
- Package format: ZIP containing extension source
- Build command: `ray build -e dist`
- Development: `ray develop` for local testing

## Environment Configuration

**Required env vars:**
- None - all configuration via UI settings and UserDefaults

**Secrets location:**
- Not applicable - no external secrets management
- No API keys, credentials, or sensitive data required
- Application runs fully sandboxed

## Webhooks & Callbacks

**Incoming:**
- Type: None - app doesn't expose any server endpoints

**Outgoing:**
- Type: None - no callback webhooks sent to external services
- Only outbound connection: GET request to GitHub API for release checking

## Notification System

**Local Notifications:**
- Framework: UserNotifications (Apple native)
- Type: Local scheduled notifications
- Trigger: Time-interval based (customizable 15min to 4 hours)
- Customization: Title, body, sound, category, actions
- Actions: "Drink a glass" button (adds preset amount)
- Focus Mode Integration: Respects system Focus Mode settings (Do Not Disturb toggle)
- Implementation: `HydrationManager.setupNotificationCategories()` and `scheduleNotifications()`

## Accessibility & System Integration

**Keyboard Shortcuts:**
- Type: Global system-wide shortcuts
- Framework: Carbon Event Manager (for low-level hotkey handling)
- Permission Required: Accessibility permission (System Preferences > Privacy > Accessibility)
- Storage: UserDefaults (serialized Shortcut objects with keyCode and modifiers)
- Implementation: `GlobalHotkeyManager.swift`

**Focus Mode Integration:**
- Framework: INFocusStatusCenter (macOS 12.0+)
- Type: Read-only access to system Focus Mode status
- Auto-Sync: Optional feature (can be toggled in settings)
- Implementation: `FocusModeMonitor.swift`
- Behavior: Automatically enables "Do Not Disturb" in app when system Focus Mode is active

**System Integration:**
- Menu bar presence: NSStatusBar integration
- Context menu: Native macOS right-click menu
- Opens links: GitHub repository, releases page

## Raycast Integration

**Platform:**
- Name: Raycast (command launcher/productivity tool for macOS)
- Location: `raycast-hydrobar/` directory

**Commands:**
- `add-preset-1`: Add 0.3 L water
- `add-preset-2`: Add 0.5 L water
- `add-preset-3`: Add 1 L water
- `add-water`: Add custom amount in ml

**Communication:**
- Type: Shell script execution or process launch
- Method: Each command triggers HydroBar app to add water programmatically
- No inter-process communication protocol - commands invoke HydroBar directly

**Requirements:**
- HydroBar must be installed and running in menu bar
- Raycast must be installed and the extension loaded

## Missing Integrations

**Not Integrated:**
- Apple Health app (planned for future)
- iCloud sync (planned for future)
- CloudKit (no cloud features)
- Analytics or telemetry
- Third-party authentication providers
- Slack, Discord, or messaging integrations
- Weather APIs or location services

---

*Integration audit: 2026-02-26*
