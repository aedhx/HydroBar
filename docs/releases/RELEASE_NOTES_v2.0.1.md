# HydroBar v2.0.1

A design pass on the two places that needed it most, and a download that opens with a double-click.

## What's New

### A New Settings Window
Settings went from seven tabs to four, in a toolbar like Safari's: **General**, **Hydration**, **Reminders** and **Shortcuts**. Each page sits on glass cards and opens with a live preview of what it changes:
- **General** shows your menu bar icon as it will look, ring or percentage, monochrome or colored. Your data (CSV export, backup, restore) lives here too.
- **Hydration** puts your daily goal next to the ring, lets you edit your three presets directly on their keys, and sets a goal for each day of the week in a single row. Leave a day empty and it uses your daily goal.
- **Reminders** opens on a 24-hour timeline: your active hours, one tick per reminder, and the last call. With days off turned on, a second line shows what a day off looks like. Days off, time off and the Focus automation are now part of this page, and only appear once you turn them on.
- **Shortcuts** holds your keyboard shortcuts and the integrations.

### Statistics, Tidied Up
- Every block now lines up on the same left and right edge, including when your Mac always shows scroll bars.
- **This Week** scales to your week instead of always going to 200%, draws your goal as a line, and shows empty days as faint stubs.
- **Regularity** is laid out like a calendar, with the days of the week above it.
- Empty charts say what they are waiting for.

### Signed and Notarized
The direct download is now signed with an Apple Developer ID and notarized by Apple. It opens like any other app: no more "HydroBar is damaged" message, and nothing to type in Terminal. The disk image has a new window, too.

---

## Installation

1. Download **HydroBar-v2.0.1.dmg** from the [Releases](https://github.com/aedhx/HydroBar/releases) page.
2. Open the DMG and drag `HydroBar.app` into your Applications folder.
3. Open HydroBar.

Coming from 2.0 or 1.x? Replace the old app in Applications: your settings and history are kept.

The desktop widget and the Control Center button are not available in the direct download: macOS only loads them from a sandboxed build. They come with the **Mac App Store** version, which is on its way; the link will be on [hydrobar.adx.cool](https://hydrobar.adx.cool/) once it is live.

**Requirements:** macOS 15.1 or later, on Apple Silicon or Intel.

Everything that arrived in 2.0 is in the [2.0 release notes](https://github.com/aedhx/HydroBar/blob/main/docs/releases/RELEASE_NOTES_v2.0.md).
