# HydroBar v1.2

## What's New

### macOS Widgets
HydroBar is now available as a native macOS widget on your desktop and in Notification Center.

- **Small widget** — progress ring with daily percentage and 3 quick-add buttons, without opening the app
- **Medium widget** — 7-day consistency heatmap and quick-add buttons side by side
- Widget buttons work even when the app is closed — water is synced on next launch
- Real-time sync: the widget updates instantly when you log water in the app

To add the widget: right-click your desktop → Edit Widgets → HydroBar

### Haptic Feedback
The Hold-to-Add button now provides haptic feedback on each sip added.

### Progress Ring
- New angular gradient: blue → cyan while in progress, green → mint when goal is reached
- Smooth animation on popover open

### Settings
- New **Integrations** section grouping the macOS widget and the Raycast extension
- Segmented pickers (icon style, units) now stretch to full width

---

## Bug Fixes
- Fixed a `UNErrorDomain Code=1` error logged on every launch when notification permissions had been denied — the app now checks authorization status before requesting
- Fixed multiple "Publishing changes from within view updates" SwiftUI warnings caused by redundant `objectWillChange` calls and synchronous `@Published` mutations in `didSet`

---

## Installation

1. Download **HydroBar-v1.2.dmg** from the [Releases](https://github.com/aedhx/HydroBar/releases) page
2. Mount the DMG and drag `HydroBar.app` into your Applications folder
3. **First launch** — macOS may block the app because it is not notarized. Use one of the methods below.

### If macOS says "app is damaged" or "cannot be opened"

HydroBar is open-source and not signed with a paid Apple Developer certificate. macOS quarantines apps downloaded from the internet. This is expected and safe to bypass.

**Method 1 — Terminal (recommended, one command):**
```bash
xattr -cr /Applications/HydroBar.app
```
Then double-click the app normally.

**Method 2 — System Settings:**
1. Try to open the app once (it will be blocked)
2. Go to **System Settings → Privacy & Security**
3. Scroll down to the Security section — you will see *"HydroBar was blocked"*
4. Click **Open Anyway**

**Method 3 — Right-click:**
1. Right-click `HydroBar.app` → **Open**
2. Click **Open** in the dialog that appears

> If the app still won't open after Method 2 or 3, use Method 1 — it is the most reliable and removes the quarantine flag that causes the "damaged" message.

---

## Compatibility

- **macOS**: 13.0 (Ventura) or later — widgets require macOS 13+
- **Architecture**: Universal (Apple Silicon and Intel)

---

**Full changelog**: [v1.1.0...v1.2.0](https://github.com/aedhx/HydroBar/compare/v1.1.0...v1.2.0)
