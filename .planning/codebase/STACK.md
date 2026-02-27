# Technology Stack

**Analysis Date:** 2026-02-26

## Languages

**Primary:**
- Swift 5.0+ - Main application implementation for macOS menu bar app
- TypeScript 5.0+ - Raycast extension implementation

**Secondary:**
- XML - Configuration and entitlements
- JSON - Raycast extension schema and package configuration

## Runtime

**Environment:**
- macOS 12.0+ (Monterey and later) for main app
- Swift runtime included with Xcode

**Package Manager:**
- npm (for Raycast extension)
- Xcode project configuration (no external Swift package manager used)

## Frameworks

**Core:**
- SwiftUI - UI framework for menu bar interface and all views
- AppKit - Menu bar integration, system-level events, and window management
- Combine - Reactive programming for state management and observation patterns
- Foundation - Core data handling, file I/O, JSON encoding/decoding, UserDefaults

**System Integration:**
- UserNotifications - Local notifications and reminder system
- Carbon - Global hotkey/keyboard event handling
- Intents - Focus Mode monitoring and status checking (macOS 12.0+)

**Testing:**
- XCTest - Unit and UI testing framework
- XCUITest - UI automation testing

**Build/Dev (Raycast):**
- Raycast CLI - Extension development and building
- Ray build - Compilation to Raycast extension format
- ESLint - Linting with Raycast config

## Key Dependencies

**macOS App:**
- No external third-party dependencies - Pure Swift/SwiftUI implementation
- Uses only Apple frameworks

**Raycast Extension:**
- `@raycast/api` ^1.69.0 - Raycast extension API for commands and toasts
- `@raycast/eslint-config` ^1.0.0 (dev) - ESLint configuration for Raycast
- `typescript` ^5.0.0 (dev) - TypeScript compiler

## Configuration

**Environment:**
- Build configuration through Xcode project settings
- Settings stored in UserDefaults (sandboxed)
- No environment variables or .env files used
- Configuration files stored in Application Support directory (`~/Library/Application Support/HydroBar/`)

**Build:**
- Xcode project: `/src/HydroBar/HydroBar.xcodeproj`
- Swift compiler version: 5.0
- Deployment target: macOS 15.1 (built with Xcode 16.2)
- Minimum supported: macOS 12.0
- Build configuration: Release and Debug schemes

**Raycast:**
- `raycast-hydrobar/package.json` - Extension manifest and dependencies

## Platform Requirements

**Development:**
- Xcode 14.0 or later (built with 16.2)
- Swift 5.0+
- macOS 12.0+ for testing
- Node.js (for Raycast development)
- npm packages installed for Raycast extension

**Production:**
- Deployment target: macOS 12.0 (Monterey) or later
- Apple Silicon (M1+) and Intel architecture support (Universal binary)
- Disk space: ~15-20 MB
- Permissions required: Notifications, Accessibility (for global shortcuts)
- Network: Optional (only for GitHub release checking via API)
- Sandboxing: Enabled (com.apple.security.app-sandbox)

## Framework Details

**SwiftUI Usage:**
- All UI views implemented in SwiftUI (`MainView`, `SettingsView`, `StatisticsView`, `StatsComponents`, `ProgressRingView`, `ShortcutRecorderView`)
- Menu bar icon rendering with SwiftUI hosting controllers
- Adaptive dark/light mode support
- Custom shape drawing (progress rings, heatmaps)

**AppKit Integration:**
- NSStatusItem for menu bar icon placement
- NSPopover for popover UI
- NSAlert for dialogs (About, permissions)
- NSMenu and NSMenuItem for context menu
- NSApplication delegate for lifecycle management
- NSWorkspace for opening URLs and launching processes

**Local Persistence:**
- JSON file storage in Application Support directory
- UserDefaults for app preferences (AppStorage decorator)
- Formats: JSON for history data, UserDefaults for UI state

**Networking:**
- URLSession for GitHub API calls (release checking)
- No authentication required (public API)
- Optional feature (can be disabled)

---

*Stack analysis: 2026-02-26*
