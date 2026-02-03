# HydroBar v1.1 - Release Notes

**Update from v1.0** – Heatmap tooltips & in-app update check

---

## What's New in v1.1

### Statistics – Heatmap tooltips
- **Hover over any day** in the 30-day consistency heatmap to see a tooltip (like GitHub’s contribution graph).
- Tooltip shows:
  - **Date** (localized).
  - **No activity** or **amount / goal (X% of goal)** for that day.
- Uses your chosen unit (L, cl, oz) from Settings.

### Settings – Check for updates
- New **UPDATES** section in Settings:
  - Displays **current app version**.
  - **“Check for Updates”** button: checks [GitHub Releases](https://github.com/aedhx/HydroBar/releases) and compares with the latest version.
  - If an update is available: shows the new version and an **“Open Download Page”** link to the release.
  - If you’re up to date: shows “You’re up to date.”
- Requires network (outgoing connections allowed in the app sandbox).

### Menu bar – Context menu (right-click)
- **Version at the top**: App version displayed at the top of the right-click menu.
- **Keyboard shortcuts**: Submenu listing configured shortcuts for each preset (e.g. Preset 1: ⌘ P).
- **About**: Opens the About dialog (version now read from the app bundle).
- **View Repository**: Opens the [GitHub repository](https://github.com/aedhx/HydroBar) (sources).
- **Quit**: Quit HydroBar.

---

## Installation (v1.1)

1. Download **HydroBar-v1.1.dmg** from [GitHub Releases](https://github.com/aedhx/HydroBar/releases).
2. Mount the DMG and drag `HydroBar.app` into Applications.
3. **First launch**: Right-click the app → **Open** (to bypass Gatekeeper if needed).
4. Optional: Grant **Notifications** and **Accessibility** in System Preferences.

---

## Changelog (v1.0 → v1.1)

| Area        | Change |
|------------|--------|
| Statistics | Heatmap: tooltip on hover with date and daily hydration (or “No activity”). |
| Settings   | New “UPDATES” block: current version, “Check for Updates”, link to GitHub Releases. |
| Menu bar   | Context menu: version at top, keyboard shortcuts submenu, About (dynamic version), View Repository, Quit. |
| Technical  | `com.apple.security.network.client` entitlement for update check. |

---

## Compatibility

- **macOS**: 12.0 (Monterey) or later  
- **Architecture**: Intel and Apple Silicon  

---

**Full changelog**: [v1.0.0...v1.1.0](https://github.com/aedhx/HydroBar/compare/v1.0.0...v1.1.0)
