──────────────────────────────────────────
  HydroBar — Installation Guide
──────────────────────────────────────────

INSTALLATION
────────────
1. Drag HydroBar.app into your Applications folder.
2. Double-click HydroBar.app to launch it.


IF macOS SAYS "APP IS DAMAGED" OR "CANNOT BE OPENED"
─────────────────────────────────────────────────────
This is a Gatekeeper warning. HydroBar is not notarized with a paid
Apple Developer certificate — it is safe to use.

  Method 1 — Terminal (most reliable):
  Open Terminal and run:

    xattr -cr /Applications/HydroBar.app

  Then double-click the app normally.

  Method 2 — System Settings:
  Open the app once (it will be blocked), then go to:
    System Settings → Privacy & Security → Open Anyway

  Method 3 — Right-click:
  Right-click HydroBar.app → Open → Open in the dialog.


PERMISSIONS
───────────
HydroBar asks for one permission, and only when you turn
reminders on:

  • Notifications — System Settings → Notifications → HydroBar

Keyboard shortcuts, the Focus filter and call detection need
no permission.


UPGRADING FROM 1.x
──────────────────
Replace the old app in Applications. Your settings and history
are converted the first time 2.0 launches; the old history file
is kept, untouched.


WIDGET AND CONTROL CENTER
─────────────────────────
The desktop widget and the Control Center button are not
available in this direct download: macOS only loads them from
a build signed by Apple. They come with the Mac App Store
version.


MORE INFO
─────────
Full documentation: https://github.com/aedhx/HydroBar

──────────────────────────────────────────
