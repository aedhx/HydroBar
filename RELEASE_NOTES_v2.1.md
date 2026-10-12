# HydroBar v2.1

## What's New

### Smarter Reminders
Reminders used to fire at a fixed interval, day and night, even after you'd reached your goal. Now:
- they only come during your **active hours** (the same ones as the pace marker);
- they **stop for the day** once your goal is reached, and start again the next morning;
- when you're **behind your pace**, they come about a third more often, never more than every 15 minutes, and say why. You can turn this off with **Adapt to my pace**;
- they pause while your screen is asleep or your session is locked, instead of piling up in Notification Center;
- after a pause, they resume on time, even if HydroBar was idle in the meantime.

### Goal Celebration
A single notification when you cross your daily goal, with your current streak.

### When You Drink
A new **When You Drink** chart in Statistics shows how much you drink at each hour of the day, averaged over the last 30 days. It also tells you your longest dry spell, for example "2:00 PM – 5:00 PM", so you know when a reminder would help most.

### Log an Earlier Drink
Forgot to log a glass yesterday? In **Today's log**, choose **Add an Earlier Drink…**, then pick a date and time up to a year back. Like any entry, it can be undone with ⌘Z.

### Accessibility
- When you reach your goal, the ring now shows a checkmark instead of relying on the switch from blue to green, two colors that are easy to confuse with color blindness.
- The ring and statistics follow **Reduce motion**.
- VoiceOver now describes your progress from the menu bar icon. It can also use the Hold to Add button, which acts like a one-second hold.
- Presets are announced as "Add 25 cl" instead of just "25 cl".

### Menu Bar
- **Option-click** the menu bar icon to log your first preset without opening HydroBar.
- Hover over the icon to see today's progress.

---

## Installation

1. Download **HydroBar-v2.1.dmg** from the [Releases](https://github.com/aedhx/HydroBar/releases) page.
2. Open the DMG and drag `HydroBar.app` into your Applications folder.
3. Open HydroBar.

If macOS says the app "is damaged" or "cannot be opened", the build you downloaded is not notarized. Run this once in Terminal, then open the app normally:

```bash
xattr -cr /Applications/HydroBar.app
```

**Requirements:** macOS 15.1 or later.
