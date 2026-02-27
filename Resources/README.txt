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
After first launch, grant the following permissions:

  • Notifications — System Settings → Notifications → HydroBar
  • Accessibility — System Settings → Privacy & Security
                    → Accessibility → add HydroBar
    (required for global keyboard shortcuts)


WIDGETS
───────
HydroBar includes Small and Medium macOS widgets.
Add them via the Notification Center widget gallery
or right-click your desktop → Edit Widgets.


MORE INFO
─────────
Full documentation: https://github.com/aedhx/HydroBar

──────────────────────────────────────────
