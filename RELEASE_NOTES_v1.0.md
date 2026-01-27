# 🎉 HydroBar v1.0 - Release Notes

**First stable release of HydroBar** - Hydration tracking app for macOS

---

## ✨ New Features

### 📊 Daily Tracking
- **Real-time tracking** of your daily water consumption
- **Customizable goal** (ml, cl, oz, etc.)
- **Visual display** with animated progress ring
- **Quick presets** to add water with one click
- **Hold-to-Add mode**: hold the button to progressively add water

### 📈 Advanced Statistics
- **Weekly view**: bar chart of the last 7 days
- **Monthly view**: 30-day consistency heatmap
- **Daily average** and weekly total
- **Visual indicators**: different colors based on goal achievement

### 🔔 Smart Reminders
- **Customizable notifications** with configurable intervals
- **Focus Mode synchronization** with macOS (Do Not Disturb)
- **Reminder badge** in the menu bar
- **Quick actions** from notifications

### ⌨️ Global Keyboard Shortcuts
- **Configurable shortcuts** for each preset
- **Global functionality**: use them from any application
- **Intuitive interface** to record your shortcuts

### 🎨 Modern Interface
- **Clean design** following Apple's Human Interface Guidelines
- **Dark/Light mode** adaptive
- **Smooth animations** and elegant transitions
- **Customizable menu bar icon** (ring or percentage)

### 🌍 Multi-language Support
- **9 languages supported**:
  - 🇬🇧 English
  - 🇫🇷 French (Français)
  - 🇪🇸 Spanish (Español)
  - 🇩🇪 German (Deutsch)
  - 🇮🇹 Italian (Italiano)
  - 🇵🇹 Portuguese (Português)
  - 🇳🇱 Dutch (Nederlands)
  - 🇯🇵 Japanese (日本語)
  - 🇨🇳 Simplified Chinese (简体中文)

### 🔄 Advanced Features
- **Undo/Redo** (Cmd+Z) functionality
- **Complete history** saved locally
- **Automatic daily reset**
- **Data export** (planned for future versions)

---

## 🛠️ Technical Improvements

- **MVVM architecture** for maintainable codebase
- **Local persistence**: all your data stays on your Mac
- **Optimized performance**: minimal memory consumption
- **Compatibility**: macOS 12.0 (Monterey) and later
- **Universal support**: Intel and Apple Silicon

---

## 📦 Installation

### Recommended Method
1. Download the DMG from [GitHub Releases](https://github.com/aedhx/HydroBar/releases)
2. Mount the DMG and drag `HydroBar.app` to the Applications folder
3. **First launch**: Right-click > Open (required to bypass Gatekeeper)
4. Grant permissions in System Preferences:
   - Notifications
   - Accessibility (for keyboard shortcuts)

### From Source
```bash
git clone https://github.com/aedhx/HydroBar.git
cd HydroBar/src/HydroBar
open HydroBar.xcodeproj
```

---

## 🔒 Security and Privacy

- ✅ **No data collection**: everything stays local on your Mac
- ✅ **No Internet connection** required
- ✅ **Open source**: inspect the code at any time
- ✅ **Privacy-first**: no tracking, no analytics

---

## 🐛 Bug Fixes

- Fixed keyboard shortcut alignment in settings
- Improved icon visibility in zero state
- Fixed popover positioning on small screens
- Optimized statistics charts (removed goal line that caused layout issues)
- Reduced weekday display to 2 letters for better visibility

---

## 📝 Important Notes

### Gatekeeper
The application is not signed by an identified Apple developer (requires a paid developer account). On first launch:
- **Right-click** on the application > **Open**
- Click **"Open"** in the security window
- macOS will remember your choice for future launches

### Required Permissions
- **Notifications**: for hydration reminders
- **Accessibility**: for global keyboard shortcuts

---

## 🙏 Acknowledgments

Thank you for using HydroBar! If you encounter any issues or have suggestions, feel free to:
- 📝 [Open an issue](https://github.com/aedhx/HydroBar/issues)
- ⭐ Star the project if you like it
- 🔄 Share with your friends and colleagues

---

## 👨‍💻 Developer

**Antoine Deshoux**
- 🌐 Website: [https://adx.cool/](https://adx.cool/)
- 💼 LinkedIn: [https://www.linkedin.com/in/deshouxantoine/](https://www.linkedin.com/in/deshouxantoine/)

---

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for more details.

---

**Version 1.0** - January 2026
