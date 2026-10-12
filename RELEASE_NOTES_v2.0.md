# HydroBar v2.0

HydroBar 2.0 rebuilds how your data is stored and fixes two bugs that could silently erase your history. It adds the features that were missing for daily use: a log of today's drinks, export, Shortcuts, smarter reminders and a welcome screen. It also gives HydroBar a new look that fits the macOS menu bar.

## What's New

### A Menu Bar Icon That Fits In
The icon is now monochrome and follows your menu bar: light, dark, or tinted. A checkmark appears when you reach your goal. If you prefer the colored icon, turn on **Colored icon** in Settings.

### Livelier Progress
- The ring fills with a little spring. Above 100%, a second, darker lap shows how far past your goal you are, so 130% no longer looks like 100%.
- Numbers roll to their new value instead of jumping.
- When you reach your goal, the checkmark bounces, a ring of droplets bursts once, and your trackpad gives a light tap.
- The pace marker pulses three times when you fall behind, then settles.
- **Hold to Add** fills up like a glass while you hold it, and shows the running total.

### Today's Log
Expand **Today's log** under the Hold to Add button to see every drink logged today, with its time. Remove any entry on its own; ⌘Z brings it back. Forgot to log a glass yesterday? Choose **Add an Earlier Drink…** and pick a date and time up to a year back.

### Smarter Reminders
Reminders used to fire at a fixed interval, day and night, even after you'd reached your goal. Now:
- they only come during your **active hours** (the same ones as the pace marker);
- they **stop for the day** once your goal is reached, and start again the next morning;
- when you're **behind your pace**, they come about a third more often, never more than every 15 minutes. You can turn this off with **Adapt to my pace**;
- they pause while your screen is asleep or your session is locked, instead of piling up in Notification Center;
- with a **Focus filter** (System Settings › Focus), any Focus can turn them into a menu bar badge. It needs no extra permission;
- a **weekly summary** arrives on the last evening of the week: days on goal, daily average and streak;
- you can **pause** them for 1 hour, until this evening or until tomorrow, from the notification itself, the menu bar icon's context menu, or Settings. The pause ends by itself;
- a single notification celebrates the moment you cross your daily goal, with your current streak.

### Bottle Mode
Drink from a bottle at your desk? Turn on **Bottle mode** in Settings › Hydration. The popover then shows your bottle, and you log how much of it you've had: a quarter, half, three quarters, or finished. HydroBar records the difference each time and draws the bottle emptying. Undo puts the water back.

### Goals That Fit Your Week
Set a different goal for any day of the week: higher on sports days, lower on weekends. Days without their own goal use your daily goal.

### Presets That Learn
When you keep logging the same amount, for example 33 cl, HydroBar suggests turning it into a preset. It replaces the one you use least, and remembers if you say no.

### Statistics
- **When You Drink**: how much you drink at each hour of the day, averaged over the last 30 days, with your longest dry spell, for example "2:00 PM – 5:00 PM".
- **This Month**: a recap card with your daily average, days on goal, best day and streak, which you can share or copy as an image.
- **Your Year**: your daily average for each of the last 12 months, against your goal.

### Shortcuts, Spotlight and Siri
Five actions for the Shortcuts app: **Log Water**, **Log a Preset**, **Get Hydration Status**, **Undo Last Drink** and **Set Daily Goal**. They return values, so you can build automations around them, such as logging a glass every morning or showing your progress in a widget of your own.

### Export and Backup
In the new **Data** tab of Settings:
- **Export as CSV** gives you one line per day: date, amount, goal, and whether you reached it. It opens the same way in any spreadsheet app.
- **Back Up (JSON)** saves every drink.
- **Restore from Backup** adds only the entries you don't already have, so importing the same backup twice changes nothing. Backups from v1 can be restored too.

### A Real Settings Window
Settings now open in their own window, organized in tabs: **General**, **Hydration**, **Reminders**, **Keyboard Shortcuts**, **Data** and **Integrations**. Open it from the gear in the popover, from the menu bar icon's context menu (⌘,), or with `hydrobar://open/settings`.

### Feedback Outside the Popover
When you log a drink without opening HydroBar, the menu bar icon flashes and a "+20 cl" label appears below it. This covers keyboard shortcuts, the Shortcuts app, the widget and deep links. You can also **Option-click** the icon to log your first preset.

### Control Center
On macOS 26, add the **Add Water** control to Control Center or the menu bar to log your first preset from anywhere.

### More Keyboard Shortcuts
Global shortcuts are no longer limited to presets: you can now set one to **Undo** and one to **Open HydroBar** from anywhere.

### Welcome Screen
New installs start with a short setup: unit and daily goal, presets, then reminders. If you're unsure about your goal, HydroBar can suggest one from your weight, at about 30 ml per kilogram. This is a starting point, not medical advice, and your weight is never saved. HydroBar now asks for notification permission only when you turn reminders on.

### Accessibility
- Reaching your goal shows a checkmark, not just a color change from blue to green, two colors that are easy to confuse with color blindness.
- Every animation respects **Reduce motion**.
- VoiceOver describes your progress from the menu bar icon. It can also use the Hold to Add button, which acts like a one-second hold.

### Also New
- **Milliliters** and **UK fluid ounces** units.
- The desktop widget shows your own presets, resets at midnight, and stays in sync with the app.
- On macOS 26, preset buttons use the Liquid Glass material.
- Every string is translated into all 9 languages, including the widget.
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
- Hold to Add now adds 200 ml per second instead of 500.

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
