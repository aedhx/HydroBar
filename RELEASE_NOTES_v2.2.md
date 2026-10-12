# HydroBar v2.2

A design release: HydroBar now looks at home in the macOS menu bar, gives you clearer feedback when you log a drink, and has a proper Settings window.

## What's New

### A Menu Bar Icon That Fits In
The icon is now monochrome and follows your menu bar: light, dark, or tinted. A checkmark appears when you reach your goal. If you prefer the colored icon, turn on **Colored icon** in Settings.

### Livelier Progress
- The ring fills with a little spring. Above 100%, a second, darker lap shows how far past your goal you are, so 130% no longer looks like 100%.
- Numbers roll to their new value instead of jumping.
- When you reach your goal, the checkmark bounces, a ring of droplets bursts once, and your trackpad gives a light tap.
- The pace marker pulses three times when you fall behind, then settles.
- **Hold to Add** fills up like a glass while you hold it.
- Entries slide into **Today's log** and fold away when you remove them.

### Feedback Outside the Popover
When you log a drink without opening HydroBar, the menu bar icon flashes and a "+20 cl" label appears below it. This covers keyboard shortcuts, Option-click, Shortcuts, the widget and deep links. Before, only a sound confirmed it.

### A Real Settings Window
Settings now open in their own window, organized in tabs: **General**, **Hydration**, **Reminders**, **Keyboard Shortcuts**, **Data** and **Integrations**. Open it from the gear in the popover, from the menu bar icon's context menu (⌘,), or with `hydrobar://open/settings`. It remembers its tab and position.

### Liquid Glass
On macOS 26, preset buttons use the Liquid Glass material.

### Accessibility
Every animation respects **Reduce motion**.

---

## Installation

1. Download **HydroBar-v2.2.dmg** from the [Releases](https://github.com/aedhx/HydroBar/releases) page.
2. Open the DMG and drag `HydroBar.app` into your Applications folder.
3. Open HydroBar.

If macOS says the app "is damaged" or "cannot be opened", the build you downloaded is not notarized. Run this once in Terminal, then open the app normally:

```bash
xattr -cr /Applications/HydroBar.app
```

**Requirements:** macOS 15.1 or later.
