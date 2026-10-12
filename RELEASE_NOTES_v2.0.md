# HydroBar v2.0

HydroBar 2.0 rebuilds how your data is stored, fixes two bugs that could silently erase your history, and adds the features that were missing for daily use: a log of today's drinks, export, Shortcuts, snoozing reminders and a proper welcome.

## What's New

### Today's Log
Expand **Today's log** under the Hold to Add button to see every drink logged today, with its time. Remove any entry on its own; ⌘Z brings it back.

### Shortcuts, Spotlight and Siri
Five actions for the Shortcuts app: **Log Water**, **Log a Preset**, **Get Hydration Status**, **Undo Last Drink** and **Set Daily Goal**. They return values, so you can build automations around them, such as logging a glass every morning or showing your progress in a widget of your own.

### Export and Backup
A new **Data** section in Settings:
- **Export as CSV** gives you one line per day: date, amount, goal, and whether you reached it. It opens the same way in any spreadsheet app.
- **Back Up (JSON)** saves every drink.
- **Restore from Backup** adds only the entries you don't already have, so importing the same backup twice changes nothing. Backups from v1 can be restored too.

### Pause Reminders
Pause reminders **for 1 hour**, **until this evening** or **until tomorrow**. You can do it from the notification itself, from the menu bar icon's context menu, or from Settings. The pause ends by itself, and Settings always shows when it ends.

### More Keyboard Shortcuts
Global shortcuts are no longer limited to presets: you can now set one to **Undo** and one to **Open HydroBar** from anywhere.

### Welcome Screen
New installs start with a short setup: unit and daily goal, presets, then reminders. If you're unsure about your goal, HydroBar can suggest one from your weight, at about 30 ml per kilogram. This is a starting point, not medical advice, and your weight is never saved. HydroBar now asks for notification permission only when you turn reminders on.

### Also New
- **Milliliters** and **UK fluid ounces** units.
- The desktop widget shows your own presets, resets at midnight, and stays in sync with the app.
- The widget's text is translated into all 9 languages, and every string missing in the app has been translated too.
- Number fields accept your locale's decimal separator (`1,5` or `1.5`) and show the allowed range.
- The menu bar icon's context menu lists your real presets.
- **Reset my day** can now be undone.

---

## Your Data

HydroBar now stores **one entry per drink** instead of one total per day. The first time v2.0 launches, your existing history is converted automatically:
- each past day becomes a single entry dated at noon, since v1 never recorded the time of each drink;
- today's total is carried over;
- your old `historyEntries.json` file is kept, untouched.

History is no longer cut off after 30 days. v1 deleted older data; v2 keeps all of it.

---

## Bug Fixes

- **Your whole history could be erased when HydroBar launched on a new day**, for example after the Mac had been turned off overnight.
- **A hidden debug option could replace your history with fake data** in the released app. It is now only included in developer builds.
- The desktop widget never saw the app's data, and drinks added from the widget were not counted until the next launch.
- A drink logged just after midnight was counted on the previous day.
- Setting a custom reminder interval of 0 minutes crashed the app.
- Your streak dropped to zero as soon as you logged your first glass of the day.
- Switching the language back to **System** had no effect.
- Turning off a macOS Focus also turned off a Do Not Disturb you had set manually.
- Settings now update instantly, without timers polling in the background.
- HydroBar uses much less disk activity: Hold to Add used to rewrite your history files 20 times a second.
- Hold to Add now adds 200 ml per second instead of 500, and shows the running total on the button.

---

## Installation

1. Download **HydroBar-v2.0.dmg** from the [Releases](https://github.com/aedhx/HydroBar/releases) page.
2. Open the DMG and drag `HydroBar.app` into your Applications folder.
3. Open HydroBar.

If macOS says the app "is damaged" or "cannot be opened", the build you downloaded is not notarized. Run this once in Terminal, then open the app normally:

```bash
xattr -cr /Applications/HydroBar.app
```

**Requirements:** macOS 15.1 or later.
