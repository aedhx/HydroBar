//
//  SettingsView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import UserNotifications

// MARK: - AppLanguage Enum
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case japanese = "ja"
    case chinese = "zh-Hans"
    
    var displayName: String {
        switch self {
        case .system:
            return String(localized: "System", comment: "System language option")
        case .english:
            return "English"
        case .french:
            return "Français"
        case .spanish:
            return "Español"
        case .german:
            return "Deutsch"
        case .italian:
            return "Italiano"
        case .portuguese:
            return "Português"
        case .dutch:
            return "Nederlands"
        case .japanese:
            return "日本語"
        case .chinese:
            return "简体中文"
        }
    }
    
    var flagEmoji: String {
        switch self {
        case .system:
            return "🌐"
        case .english:
            return "🇬🇧"
        case .french:
            return "🇫🇷"
        case .spanish:
            return "🇪🇸"
        case .german:
            return "🇩🇪"
        case .italian:
            return "🇮🇹"
        case .portuguese:
            return "🇵🇹"
        case .dutch:
            return "🇳🇱"
        case .japanese:
            return "🇯🇵"
        case .chinese:
            return "🇨🇳"
        }
    }
    
    var countryName: String {
        switch self {
        case .system:
            return String(localized: "System", comment: "System language option")
        case .english:
            return "United Kingdom"
        case .french:
            return "France"
        case .spanish:
            return "España"
        case .german:
            return "Deutschland"
        case .italian:
            return "Italia"
        case .portuguese:
            return "Portugal"
        case .dutch:
            return "Nederland"
        case .japanese:
            return "日本"
        case .chinese:
            return "中国"
        }
    }
    
    var fullDisplayName: String {
        if self == .system {
            return "\(flagEmoji) \(countryName)"
        }
        return "\(flagEmoji) \(countryName) (\(displayName))"
    }
}

enum NotificationInterval: String, CaseIterable {
    case thirtyMinutes = "30 min"
    case twoHours = "2 h"
    case custom = "Perso"
    
    var localizedString: String {
        switch self {
        case .thirtyMinutes:
            return String(localized: "30 min", comment: "30 minutes notification interval")
        case .twoHours:
            return String(localized: "2 h", comment: "2 hours notification interval")
        case .custom:
            return String(localized: "Custom", comment: "Custom notification interval")
        }
    }
}

struct SettingsView: View {
    @ObservedObject var manager: HydrationManager
    @Binding var currentView: ViewType
    @State private var targetValue: String = ""
    @State private var presetValues: [String] = ["", "", ""]
    @State private var customMinutes: String = "60"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Style Icône Menu Bar
            VStack(alignment: .leading, spacing: 8) {
                Text("MENU BAR ICON STYLE", comment: "Settings section title for menu bar icon style")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Picker("", selection: Binding(
                    get: { manager.menuBarIconStyle },
                    set: { newValue in
                        manager.menuBarIconStyle = newValue
                    }
                )) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Section Unités
            VStack(alignment: .leading, spacing: 8) {
                Text("UNITS", comment: "Settings section title for units")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Picker("", selection: Binding(
                    get: { manager.selectedUnit },
                    set: { newValue in
                        manager.selectedUnit = newValue
                        updateDisplayValues()
                    }
                )) {
                    ForEach(AppUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue.uppercased()).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Section Objectif
            VStack(alignment: .leading, spacing: 8) {
                Text("DAILY GOAL", comment: "Settings section title for daily goal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                HStack(spacing: 8) {
                    TextField("", text: $targetValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 15))
                        .onChange(of: targetValue) { oldValue, newValue in
                            if let value = Double(newValue) {
                                let mlValue = manager.mlValue(from: value)
                                manager.targetMl = mlValue
                            }
                        }
                    
                    Text(manager.selectedUnit.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .leading)
                }
            }
            
            // Section Verres Rapides
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK PRESETS", comment: "Settings section title for quick presets")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                HStack(spacing: 10) {
                    ForEach(Array(manager.presetsMl.enumerated()), id: \.offset) { index, preset in
                        VStack(spacing: 6) {
                            TextField("", text: Binding(
                                get: {
                                    if presetValues.count <= index {
                                        presetValues = Array(repeating: "", count: max(3, manager.presetsMl.count))
                                        updateDisplayValues()
                                    }
                                    return index < presetValues.count ? presetValues[index] : formatPresetValue(preset)
                                },
                                set: { newValue in
                                    if presetValues.count <= index {
                                        presetValues = Array(repeating: "", count: max(3, manager.presetsMl.count))
                                    }
                                    presetValues[index] = newValue
                                    
                                    if let value = Double(newValue) {
                                        let mlValue = manager.mlValue(from: value)
                                        var presets = manager.presetsMl
                                        if presets.count > index {
                                            presets[index] = mlValue
                                            manager.presetsMl = presets
                                        }
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.center)
                            
                            Image(systemName: iconForPreset(at: index))
                                .font(.system(size: iconSizeForPreset(at: index)))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Section Raccourcis clavier
            VStack(alignment: .leading, spacing: 8) {
                Text("KEYBOARD SHORTCUTS", comment: "Settings section title for keyboard shortcuts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(manager.presetsMl.enumerated()), id: \.offset) { index, _ in
                        HStack(alignment: .center, spacing: 12) {
                            Text(String(format: String(localized: "Preset %lld", comment: "Preset label with index"), index + 1))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.primary)
                                .frame(width: 70, alignment: .leading)
                            
                            ShortcutRecorderView(presetIndex: index)
                            
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Section Rappels
            VStack(alignment: .leading, spacing: 8) {
                Text("REMINDERS", comment: "Settings section title for reminders")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                // Toggle Activer les rappels
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .leading)
                    
                    Text("Enable reminders", comment: "Toggle label to enable reminders")
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { manager.notificationsEnabled },
                        set: { newValue in
                            manager.notificationsEnabled = newValue
                            if newValue {
                                manager.scheduleNotifications()
                            } else {
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                
                // Picker Intervalle (segmented)
                if manager.notificationsEnabled {
                    Picker("", selection: Binding(
                        get: { manager.notificationInterval },
                        set: { newValue in
                            manager.notificationInterval = newValue
                            manager.scheduleNotifications()
                        }
                    )) {
                        ForEach(NotificationInterval.allCases, id: \.self) { interval in
                            Text(interval.localizedString).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Champ Custom si Perso sélectionné
                    if manager.notificationInterval == .custom {
                        HStack(spacing: 8) {
                            TextField("", text: Binding(
                                get: { String(manager.customNotificationMinutes) },
                                set: { newValue in
                                    if let minutes = Int(newValue) {
                                        manager.customNotificationMinutes = minutes
                                        manager.scheduleNotifications()
                                    }
                                    customMinutes = newValue
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .frame(width: 80)
                            
                            Text("minutes", comment: "Unit label for custom notification minutes")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Toggle Synchronisation Focus Mode (macOS 12+)
                    if #available(macOS 12.0, *) {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            
                            Text("Sync with Focus Mode", comment: "Toggle label to sync with macOS Focus Mode")
                                .font(.system(size: 13))
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { manager.focusModeAutoSync },
                                set: { newValue in
                                    manager.focusModeAutoSync = newValue
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        
                        if manager.focusModeAutoSync {
                            Text("Do Not Disturb mode automatically follows macOS Focus Mode", comment: "Explanation text for Focus Mode sync")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                    }
                    
                    // Toggle Ne pas déranger (manuel si pas de sync)
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .leading)
                        
                        Text("Do Not Disturb Mode", comment: "Toggle label for Do Not Disturb mode")
                            .font(.system(size: 13))
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { manager.doNotDisturb },
                            set: { newValue in
                                // IMPORTANT: Ne jamais désactiver notificationsEnabled ici
                                if !manager.focusModeAutoSync {
                                    manager.doNotDisturb = newValue
                                    manager.scheduleNotifications()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(manager.focusModeAutoSync)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Section Debug (si activée)
            if manager.debugModeEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DEBUG", comment: "Settings section title for debug")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Bouton pour générer de fausses données
                        Button(action: {
                            manager.generateFakeHistoryData()
                            
                            // Afficher une confirmation
                            let alert = NSAlert()
                            alert.messageText = String(localized: "Fake Data Generated", comment: "Debug alert title")
                            alert.informativeText = String(localized: "Fake history data has been generated for the last 30 days.", comment: "Debug alert message")
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: String(localized: "OK", comment: "OK button"))
                            alert.runModal()
                        }) {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal.fill")
                                    .font(.system(size: 12))
                                Text("Generate Fake History Data", comment: "Debug button to generate fake data")
                                    .font(.system(size: 13, weight: .regular))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        // Bouton pour tester les notifications
                        Button(action: {
                            manager.testNotification()
                            
                            // Afficher une confirmation
                            let alert = NSAlert()
                            alert.messageText = String(localized: "Test Notification Sent", comment: "Debug alert title")
                            alert.informativeText = String(localized: "A test notification will appear in 1 second.", comment: "Debug alert message")
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: String(localized: "OK", comment: "OK button"))
                            alert.runModal()
                        }) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 12))
                                Text("Test Notification", comment: "Debug button to test notification")
                                    .font(.system(size: 13, weight: .regular))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider()
                    .padding(.vertical, 2)
            }
            
            // Section Langue (en bas)
            VStack(alignment: .leading, spacing: 8) {
                Text("LANGUAGE", comment: "Settings section title for language")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Picker("", selection: Binding(
                    get: { manager.appLanguage },
                    set: { newValue in
                        manager.appLanguage = newValue
                        // Afficher un message informatif
                        let alert = NSAlert()
                        alert.messageText = String(localized: "Language Changed", comment: "Language change alert title")
                        alert.informativeText = String(localized: "The app will restart to apply the new language.", comment: "Language change alert message")
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: String(localized: "OK", comment: "OK button"))
                        alert.runModal()
                        
                        // Redémarrer l'app pour appliquer la nouvelle langue
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NSApplication.shared.terminate(nil)
                        }
                    }
                )) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(verbatim: language.fullDisplayName)
                            .tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Toggle pour activer le mode debug (tout en bas)
            Divider()
                .padding(.vertical, 2)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $manager.debugModeEnabled) {
                    HStack {
                        Image(systemName: "ladybug.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("Debug Mode", comment: "Debug mode toggle label")
                            .font(.system(size: 13, weight: .regular))
                    }
                }
                .toggleStyle(.switch)
            }
        }
        .padding(20) // HIG: Padding standard de 20pt pour les fenêtres
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .cornerRadius(10) // HIG: Rayon de coin standard pour macOS (8-12pt)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5) // HIG: Utiliser separatorColor système
        )
        .onAppear {
            // Initialiser presetValues avec la bonne taille
            if presetValues.count < manager.presetsMl.count {
                presetValues = Array(repeating: "", count: manager.presetsMl.count)
            }
            updateDisplayValues()
        }
        .onChange(of: manager.selectedUnit) {
            updateDisplayValues()
        }
    }
    
    private func formatPresetValue(_ preset: Double) -> String {
        let unit = manager.selectedUnit
        let value = unit.fromMl(preset)
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    private func iconForPreset(at index: Int) -> String {
        switch index {
        case 0:
            // Petit verre (250ml)
            return "cup.and.saucer.fill"
        case 1:
            // Moyen verre (500ml)
            return "mug.fill"
        case 2:
            // Grand verre (customisable)
            return "wineglass.fill"
        default:
            return "drop.fill"
        }
    }
    
    private func iconSizeForPreset(at index: Int) -> CGFloat {
        switch index {
        case 0:
            // Petit verre
            return 14
        case 1:
            // Moyen verre
            return 16
        case 2:
            // Grand verre
            return 18
        default:
            return 16
        }
    }
    
    private func updateDisplayValues() {
        // Mettre à jour les valeurs d'affichage selon l'unité choisie
        let unit = manager.selectedUnit
        
        // Objectif
        let target = unit.fromMl(manager.targetMl)
        if target.truncatingRemainder(dividingBy: 1) == 0 {
            targetValue = String(format: "%.0f", target)
        } else {
            targetValue = String(format: "%.1f", target)
        }
        
        // Presets
        if manager.presetsMl.count >= 3 {
            for (index, preset) in manager.presetsMl.enumerated() {
                let value = unit.fromMl(preset)
                if value.truncatingRemainder(dividingBy: 1) == 0 {
                    presetValues[index] = String(format: "%.0f", value)
                } else {
                    presetValues[index] = String(format: "%.1f", value)
                }
            }
        }
    }
}

#Preview {
    SettingsView(manager: HydrationManager.shared, currentView: .constant(.settings))
        .padding()
        .background(Color.black)
}
