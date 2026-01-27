╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                         HydroBar - Installation Guide                        ║
║                              Version 1.0                                     ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 INSTALLATION - DETAILED STEPS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STEP 1: MOUNT THE DMG
─────────────────────
1. Double-click the "HydroBar-v1.0.dmg" file
2. A Finder window will open with the DMG contents

STEP 2: INSTALL THE APPLICATION
────────────────────────────────
1. In the DMG window, you will see:
   • HydroBar.app (the application)
   • Applications (symbolic link to your Applications folder)

2. Drag "HydroBar.app" onto the "Applications" folder
   OR
   Drag "HydroBar.app" directly into your Applications folder
   (accessible via Finder > Applications)

3. Wait for the copy to complete

STEP 3: FIRST LAUNCH (IMPORTANT - macOS SECURITY)
───────────────────────────────────────────────────

⚠️  macOS will display a security warning because the application is not signed
    by an identified Apple developer. This is normal and safe.

RECOMMENDED METHOD (Right-Click):
─────────────────────────────────
1. Open the Applications folder (Finder > Applications or Cmd+Shift+A)

2. Locate "HydroBar.app"

3. ⚠️  DO NOT double-click directly on the application

4. Right-click on "HydroBar.app"

5. In the context menu, select "Open"

6. A security window will appear with the message:
   "HydroBar.app cannot be opened because the developer cannot be verified."

7. Click the "Open" button in this window

8. The application should now launch

9. The first time, macOS may ask for your administrator password

ALTERNATIVE 1 - Via System Preferences:
────────────────────────────────────────
If you have already tried to open the application and it was blocked:

1. Go to: System Preferences > Security & Privacy
   (or: System Settings > Privacy & Security on macOS Ventura+)

2. In the "General" tab, you should see a message regarding HydroBar

3. Click "Open Anyway" next to the message

4. Confirm with your administrator password if requested

5. The application should now open

ALTERNATIVE 2 - Via Terminal (Advanced Users Only):
─────────────────────────────────────────────────────
⚠️  WARNING: This method removes the quarantine flag from the application.
    Only use this if you trust the source of the application and understand
    the security implications.

⚠️  DISCLAIMER: The developer is not responsible for any security issues
    that may arise from using this command. Use at your own risk. This
    command should only be used if you have downloaded HydroBar from the
    official GitHub repository or a trusted source.

If you are comfortable using Terminal and understand the risks:

1. Open Terminal (Applications > Utilities > Terminal)

2. Type the following command and press Enter:
   
   xattr -d com.apple.quarantine /Applications/HydroBar.app

3. If prompted, enter your administrator password

4. The quarantine flag will be removed, allowing you to open the
   application normally

5. You can now double-click HydroBar.app to launch it

⚠️  IMPORTANT NOTES:
   • This command removes macOS's quarantine protection for this specific
     application
   • Only use this command if you are certain the application is from a
     trusted source
   • If you downloaded HydroBar from an untrusted source, do NOT use this
     command
   • The recommended method (Right-click > Open) is safer and should be
     preferred for most users
   • If you encounter any issues after using this command, re-download
     the application from the official source

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔐 REQUIRED PERMISSIONS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HydroBar requires certain permissions to function properly.
macOS will request these permissions automatically when you first use the
relevant features.

1. NOTIFICATIONS
───────────────
   • Open: System Preferences > Notifications
   • Find "HydroBar" in the list
   • Enable notifications for HydroBar
   • You can customize notification types (banner, alerts, etc.)

2. ACCESSIBILITY (For global keyboard shortcuts)
─────────────────────────────────────────────────
   • Open: System Preferences > Security & Privacy > Privacy
     (or: System Settings > Privacy & Security on macOS Ventura+)
   • Select "Accessibility" from the left list
   • Click the lock icon at the bottom left and enter your password
   • Add "HydroBar" to the list (click the "+" button)
   • Check the box next to "HydroBar"

   ⚠️  Without this permission, global keyboard shortcuts will not work.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ FEATURES

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Daily hydration tracking with customizable goal
• Customizable reminders with notifications
• Detailed statistics (7 days and 30 days)
• Global keyboard shortcuts to quickly add water
• Synchronization with macOS Focus Mode (Do Not Disturb)
• Modern and intuitive interface
• Multi-language support (English, French, Spanish, German, Italian,
  Portuguese, Dutch, Japanese, Simplified Chinese)
• Debug mode for developers

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 USAGE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• HydroBar works as a menu bar application
• The icon appears in the menu bar at the top of the screen (on the right)
• Click the icon to open the main panel
• Right-click the icon to access the context menu
• Use global keyboard shortcuts to quickly add water
  (configurable in Settings)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🐛 TROUBLESHOOTING

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PROBLEM: Application won't open
────────────────────────────────
✓ Make sure you followed the "FIRST LAUNCH" steps above
✓ Ensure you use the "Right-click > Open" method
✓ Verify you are using macOS 12.0 (Monterey) or later

PROBLEM: Notifications not working
───────────────────────────────────
✓ Check that notifications are enabled in System Preferences
✓ Check that notifications are enabled in HydroBar Settings
✓ Check that "Do Not Disturb" mode is not enabled

PROBLEM: Keyboard shortcuts not working
───────────────────────────────────────
✓ Check that "Accessibility" permission is granted (see above)
✓ Restart the application after granting permission
✓ Verify that shortcuts are properly configured in Settings

PROBLEM: Icon doesn't appear in menu bar
─────────────────────────────────────────
✓ Check that the application is running (it should appear in the Dock
  or Activity Monitor)
✓ On some MacBook with Retina display, the icon may be very small
✓ Try restarting the application

PROBLEM: Data not being saved
──────────────────────────────
✓ Check that the application has write permissions in its folder
  (normally automatic)
✓ Restart the application
✓ Check that there is no disk space issue

OTHER PROBLEMS
──────────────
✓ Restart the application
✓ Restart your Mac if the problem persists
✓ Verify you are using the latest compatible macOS version
✓ Check the GitHub repository for updates and support:
  https://github.com/aedhx/HydroBar

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 SYSTEM INFORMATION

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Minimum version required: macOS 12.0 (Monterey) or later
• Architecture: Universal (Intel and Apple Silicon)
• Approximate size: ~15-20 MB

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔒 SECURITY AND PRIVACY

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• HydroBar does not collect any personal data
• All data is stored locally on your Mac
• No Internet connection required
• Open source code available on GitHub

The macOS security warning is normal for applications not signed by an
identified Apple developer. HydroBar is open-source and secure software.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📞 SUPPORT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• GitHub Repository: https://github.com/aedhx/HydroBar
• Report a bug: https://github.com/aedhx/HydroBar/issues
• Request a feature: https://github.com/aedhx/HydroBar/issues

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👨‍💻 DEVELOPER

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Antoine Deshoux
• Website: https://adx.cool/
• LinkedIn: https://www.linkedin.com/in/deshouxantoine/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Version 1.0
© 2026 - HydroBar
MIT License - Open Source

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
