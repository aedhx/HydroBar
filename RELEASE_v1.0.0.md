# 🎉 HydroBar v1.0.0 - Release

**Release Date:** January 2026  
**First Stable Release**

---

## 📦 Download

### DMG Installation (Recommended)
Download the ready-to-install DMG file:
- **[HydroBar-v1.0.0.dmg](https://github.com/aedhx/HydroBar/releases/download/v1.0.0/HydroBar-v1.0.0.dmg)**

### System Requirements
- macOS 12.0 (Monterey) or later
- Intel or Apple Silicon (Universal Binary)
- ~15-20 MB disk space

---

## ✨ What's New

### Core Features
- ✅ Daily hydration tracking with customizable goals
- ✅ Real-time progress visualization with animated ring
- ✅ Quick preset buttons (20cl, 50cl, 75cl)
- ✅ Hold-to-Add mode for continuous intake
- ✅ Automatic daily reset at midnight

### Statistics & Analytics
- ✅ Weekly bar chart (7 days)
- ✅ 30-day consistency heatmap
- ✅ Daily average and weekly totals
- ✅ Color-coded progress indicators

### Smart Reminders
- ✅ Customizable notification intervals
- ✅ Focus Mode synchronization (Do Not Disturb)
- ✅ Visual badge in menu bar
- ✅ Quick actions from notifications

### Keyboard Shortcuts
- ✅ Global keyboard shortcuts for each preset
- ✅ System-wide functionality
- ✅ Stream Deck compatible (one-click hydration)
- ✅ Intuitive shortcut recorder

### Interface
- ✅ Modern, clean design following macOS HIG
- ✅ Adaptive dark/light mode
- ✅ Customizable menu bar icon (Ring or Percentage)
- ✅ Smooth animations and transitions

### Internationalization
- ✅ 9 languages supported:
  - English, French, Spanish, German, Italian
  - Portuguese, Dutch, Japanese, Simplified Chinese
- ✅ Automatic language detection
- ✅ Manual language selection

### Additional Features
- ✅ Undo/Redo support (Cmd+Z)
- ✅ Complete local history
- ✅ Privacy-first (no data collection)
- ✅ No internet connection required

---

## 🐛 Bug Fixes

- Fixed keyboard shortcut alignment in settings
- Improved icon visibility when progress is zero
- Fixed popover positioning on small screens (MacBook Pro)
- Optimized statistics charts (removed goal line causing layout issues)
- Reduced weekday labels to 2 letters for better spacing

---

## 🔧 Technical Improvements

- MVVM architecture for maintainable codebase
- Local persistence (all data stays on your Mac)
- Optimized performance (minimal memory usage)
- Universal binary (Intel + Apple Silicon)
- Ad hoc code signing for better compatibility

---

## 📝 Installation Instructions

### First Launch (Important)

macOS will display a security warning because the app is not signed by an identified Apple developer. This is normal for open-source applications.

**Recommended method:**
1. Open Applications folder
2. **Right-click** on `HydroBar.app`
3. Select **"Open"**
4. Click **"Open"** in the security dialog

### Required Permissions

After first launch, grant permissions in System Preferences:
- **Notifications**: System Preferences > Notifications > Enable for HydroBar
- **Accessibility**: System Preferences > Security & Privacy > Privacy > Accessibility > Add HydroBar
  - Required for global keyboard shortcuts

---

## 🔒 Privacy & Security

- ✅ 100% local storage (no cloud sync)
- ✅ No internet connection required
- ✅ No tracking or analytics
- ✅ Open source code (inspectable)
- ✅ No personal data collection

---

## 📚 Documentation

- **[README.md](README.md)** - Complete documentation
- **[Release Notes](RELEASE_NOTES_v1.0.md)** - Detailed feature list

---

## 🛠️ Building from Source

```bash
git clone https://github.com/aedhx/HydroBar.git
cd HydroBar/src/HydroBar
open HydroBar.xcodeproj
```

**Requirements:**
- Xcode 14.0+
- macOS 12.0+
- Swift 5.0+

---

## 🙏 Acknowledgments

Thank you for using HydroBar! If you find it useful, please consider:
- ⭐ Starring the repository
- 🐛 Reporting bugs
- 💡 Suggesting features
- 🔄 Sharing with others

---

## 👨‍💻 Developer

**Antoine Deshoux**
- 🌐 Website: [https://adx.cool/](https://adx.cool/)
- 💼 LinkedIn: [https://www.linkedin.com/in/deshouxantoine/](https://www.linkedin.com/in/deshouxantoine/)

---

## 📄 License

This project is licensed under the MIT License.

---

## 🔗 Links

- **GitHub Repository:** https://github.com/aedhx/HydroBar
- **Issues:** https://github.com/aedhx/HydroBar/issues
- **Releases:** https://github.com/aedhx/HydroBar/releases

---

**Version 1.0.0** - January 2026
