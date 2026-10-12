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
    @StateObject private var updateChecker = GitHubUpdateChecker()
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject private var focusMonitor = FocusModeMonitor.shared
    @State private var debugTapCount: Int = 0

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 14) {
            generalSection

            // Section Style Icône Menu Bar + Unités (groupées)
            VStack(alignment: .leading, spacing: 6) {
                Text("MENU BAR ICON STYLE", comment: "Settings section title for menu bar icon style")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Picker("", selection: Binding(
                    get: { manager.menuBarIconStyle },
                    set: { manager.menuBarIconStyle = $0 }
                )) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("UNITS", comment: "Settings section title for units")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Picker("", selection: Binding(
                    get: { manager.selectedUnit },
                    set: { manager.selectedUnit = $0 }
                )) {
                    ForEach(AppUnit.allCases, id: \.self) { unit in
                        Text(verbatim: unit.pickerLabel).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
            }
            
            // Section Objectif
            VStack(alignment: .leading, spacing: 6) {
                Text("DAILY GOAL", comment: "Settings section title for daily goal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    ValidatedNumberField(
                        value: manager.selectedUnit.fromMl(manager.targetMl),
                        range: displayRange(HydrationLimits.goal),
                        format: formatForInput,
                        onCommit: { manager.targetMl = manager.mlValue(from: $0) }
                    )
                    .font(.system(size: 15))

                    Text(verbatim: manager.selectedUnit.symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .leading)
                }
            }

            activeHoursSection

            // Section Verres Rapides
            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK PRESETS", comment: "Settings section title for quick presets")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)


                HStack(spacing: 10) {
                    ForEach(Array(manager.presetsMl.enumerated()), id: \.offset) { index, preset in
                        VStack(spacing: 6) {
                            ValidatedNumberField(
                                value: manager.selectedUnit.fromMl(preset),
                                range: displayRange(HydrationLimits.single),
                                format: formatForInput,
                                alignment: .center,
                                onCommit: { updatePreset(at: index, displayValue: $0) }
                            )
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            
                            Image(systemName: iconForPreset(at: index))
                                .font(.system(size: iconSizeForPreset(at: index)))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Section Raccourcis clavier
            VStack(alignment: .leading, spacing: 6) {
                Text("Keyboard Shortcuts", comment: "Settings section title for keyboard shortcuts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: 6) {
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

            // Section Rappels
            VStack(alignment: .leading, spacing: 6) {
                Text("REMINDERS", comment: "Settings section title for reminders")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)


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
                    .frame(maxWidth: .infinity)

                    // Champ Custom si Perso sélectionné
                    if manager.notificationInterval == .custom {
                        HStack(spacing: 8) {
                            ValidatedNumberField(
                                value: Double(manager.reminderIntervalMinutes),
                                range: Double(HydrationLimits.reminderMinutes.lowerBound)...Double(HydrationLimits.reminderMinutes.upperBound),
                                format: { NumberInput.fieldText($0, fractionDigits: 0...0) },
                                onCommit: { minutes in
                                    manager.customNotificationMinutes = Int(minutes.rounded())
                                    manager.scheduleNotifications()
                                }
                            )
                            .font(.system(size: 13))
                            .frame(width: 80)
                            
                            Text("minutes", comment: "Unit label for custom notification minutes")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    focusModeSection
                    
                    // Toggle Ne pas déranger (manuel si pas de sync)
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .leading)
                        
                        Text("Do Not Disturb Mode", comment: "Toggle label for Do Not Disturb mode")
                            .font(.system(size: 13))
                        
                        Spacer()
                        
                        // Le réglage manuel reste modifiable quand la synchro
                        // Concentration est active : les deux se cumulent.
                        // Le changement reprogramme les rappels (didSet).
                        Toggle("", isOn: Binding(
                            get: { manager.doNotDisturb },
                            set: { manager.doNotDisturb = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    if manager.focusModeAutoSync && manager.focusIsActive && !manager.doNotDisturb {
                        Text("A Focus is on: reminders appear as a badge.",
                             comment: "Shown when a macOS Focus currently silences reminders")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Divider()

            // Section Debug (si activée — accès via 5 taps sur le numéro de version)
            if manager.debugModeEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DEBUG", comment: "Settings section title for debug")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    
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

                        // Journal des deep links — sans lui, un ajout inexpliqué
                        // (script, page web, Raycast) est indébuggable.
                        if !deepLinkRouter.log.isEmpty {
                            Text("RECENT DEEP LINKS", comment: "Debug section title for deep link log")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(deepLinkRouter.log.suffix(10).reversed())) { entry in
                                    HStack(spacing: 6) {
                                        Image(systemName: entry.outcome == "ok"
                                              ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(entry.outcome == "ok" ? .green : .orange)
                                        Text(entry.date, style: .time)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Text(verbatim: entry.url)
                                            .font(.system(size: 10, design: .monospaced))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer(minLength: 0)
                                        Text(verbatim: entry.outcome)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Divider()
            }

            // Section Vérification des mises à jour
            VStack(alignment: .leading, spacing: 6) {
                Text("UPDATES", comment: "Settings section title for updates")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(alignment: .center, spacing: 8) {
                    Text("Version", comment: "Label for current app version")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(verbatim: updateChecker.currentAppVersion)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .onTapGesture {
                            debugTapCount += 1
                            if debugTapCount >= 5 {
                                debugTapCount = 0
                                manager.debugModeEnabled.toggle()
                            }
                        }
                    Spacer()
                    if manager.debugModeEnabled {
                        Image(systemName: "ladybug.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                
                Button(action: { updateChecker.checkForUpdates() }) {
                    HStack(spacing: 6) {
                        if updateChecker.isChecking {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Checking…", comment: "Button label while checking for updates")
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("Check for Updates", comment: "Button to check for app updates")
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(updateChecker.isChecking)
                
                if let result = updateChecker.result {
                    Group {
                        switch result {
                        case .upToDate:
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("You're up to date.", comment: "Message when no update is available")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        case .updateAvailable(let version, let url):
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.blue)
                                    Text(String(format: String(localized: "Version %@ is available.", comment: "Message when update is available"), version))
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                }
                                Button(action: { updateChecker.openUpdateURL(url) }) {
                                    Text("Open Download Page", comment: "Button to open GitHub release page")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.plain)
                            }
                        case .error(let message):
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(message)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Divider()

            // Section Raycast Extension
            VStack(alignment: .leading, spacing: 6) {
                Text("INTEGRATIONS", comment: "Settings section title for integrations")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)


                // Raycast
                Button(action: {
                    if let url = URL(string: "https://github.com/aedhx/HydroBar/tree/main/raycast-hydrobar") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                        Text("Raycast Extension", comment: "Button to open Raycast extension page")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.orange.opacity(0.12))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Deep links : autoriser les actions destructives sans confirmation.
                // Désactivé par défaut — n'importe quelle page web peut ouvrir une URL.
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .leading)

                    Text("Allow destructive links without confirmation", comment: "Toggle label for destructive deep links")
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Toggle("", isOn: $manager.allowDestructiveDeepLinks)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Text("Applies to hydrobar://reset and hydrobar://set-goal. Adding water and undo are never blocked.", comment: "Explanation for destructive deep links toggle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
            }

            Divider()

            // Section Langue (en bas)
            VStack(alignment: .leading, spacing: 6) {
                Text("LANGUAGE", comment: "Settings section title for language")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                
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
            
            // Toggle pour activer le mode debug (caché pour la distribution)
            // Divider()
            //     .padding(.vertical, 2)
            // 
            // VStack(alignment: .leading, spacing: 8) {
            //     Toggle(isOn: $manager.debugModeEnabled) {
            //         HStack {
            //             Image(systemName: "ladybug.fill")
            //                 .font(.system(size: 12))
            //                 .foregroundColor(.orange)
            //             Text("Debug Mode", comment: "Debug mode toggle label")
            //                 .font(.system(size: 13, weight: .regular))
            //         }
            //     }
            //     .toggleStyle(.switch)
            // }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        } // ScrollView
        .onAppear {
            // La source de vérité du lancement au démarrage est le système :
            // l'utilisateur a pu le changer dans Réglages Système entre-temps.
            launchAtLogin.refresh()
        }
    }
    
    // MARK: - Sections extraites
    // Sorties du `body` pour limiter la complexité que le type-checker SwiftUI
    // doit résoudre d'un bloc : ce fichier dépasse les 800 lignes.

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GENERAL", comment: "Settings section title for general options")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .leading)

                Text("Launch at login", comment: "Toggle label for launching the app at login")
                    .font(.system(size: 13))

                Spacer()

                Toggle("", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            // macOS 13+ : l'app est enregistrée mais ne démarrera pas tant que
            // l'utilisateur n'a pas validé l'élément d'ouverture.
            if launchAtLogin.needsApproval {
                Button(action: { launchAtLogin.openLoginItemsSettings() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("Approval needed in System Settings", comment: "Warning when the login item awaits user approval")
                            .font(.system(size: 11))
                            .underline()
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 28)
            }

            // Un échec silencieux serait pire que l'absence de la fonctionnalité :
            // l'utilisateur croirait l'option active.
            if let failure = launchAtLogin.failureMessage {
                Text(failure)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)
            }

            // Problème de persistance : délibérément visible hors mode debug.
            // Un historique mis de côté pour corruption doit se savoir — c'est
            // le genre de perte qu'on ne découvre sinon jamais.
            if let issue = manager.lastDataIssue {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(issue)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
    }

    /// Synchronisation Focus Mode. L'ancien interrupteur activait le réglage sans
    /// jamais demander l'autorisation : il restait allumé alors que la
    /// fonctionnalité ne pouvait pas fonctionner. Chaque cas d'échec est désormais
    /// affiché — voir l'en-tête de FocusModeMonitor.swift.
    private var focusModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                        // L'autorisation est demandée ici, pas au lancement :
                        // une invite système n'a de sens qu'au moment où
                        // l'utilisateur réclame la fonctionnalité.
                        if newValue {
                            focusMonitor.enableAutoSync()
                        } else {
                            focusMonitor.disableAutoSync()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            switch focusMonitor.availability {
            case .denied:
                Button(action: { focusMonitor.openFocusPrivacySettings() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("Access denied — grant it under Privacy & Security › Focus", comment: "Focus Mode authorization denied")
                            .font(.system(size: 11))
                            .underline()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 28)

            case .unavailable:
                Text("Focus status is unreadable. Check that HydroBar is allowed to send notifications — the Focus status also needs it.", comment: "Focus Mode status unreadable despite authorization")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)

            case .authorized, .notRequested:
                if manager.focusModeAutoSync {
                    Text("Do Not Disturb mode automatically follows macOS Focus Mode", comment: "Explanation text for Focus Mode sync")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 28)
                }
            }
        }
    }

    private var activeHoursSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACTIVE HOURS", comment: "Settings section title for active hours")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Picker("", selection: Binding(
                    get: { manager.activeHoursStart },
                    set: { newValue in
                        manager.activeHoursStart = newValue
                        // La plage ne doit jamais passer minuit : la journée est
                        // remise à zéro à 0 h, une plage à cheval porterait sur
                        // deux journées de données différentes.
                        if manager.activeHoursEnd <= newValue {
                            manager.activeHoursEnd = min(newValue + 1, 24)
                        }
                    }
                )) {
                    ForEach(HydrationPace.selectableStartHours, id: \.self) { hour in
                        Text(verbatim: hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 90)

                Text("to", comment: "Separator between start and end hour")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Picker("", selection: Binding(
                    get: { manager.activeHoursEnd },
                    set: { manager.activeHoursEnd = $0 }
                )) {
                    ForEach(HydrationPace.selectableEndHours.filter { $0 > manager.activeHoursStart }, id: \.self) { hour in
                        Text(verbatim: hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 90)

                Spacer(minLength: 0)
            }

            Text("Used by the pace marker on the ring: it shows where you should be at this time of day.", comment: "Explanation for the active hours setting")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Heure formatée selon la locale (« 8 AM » ou « 08:00 » selon la région).
    private func hourLabel(_ hour: Int) -> String {
        // 24 = minuit de fin de journée, affiché comme 0 h.
        let normalized = hour == 24 ? 0 : hour
        guard let date = Calendar.current.date(bySettingHour: normalized, minute: 0, second: 0, of: Date()) else {
            return String(format: "%02d:00", normalized)
        }
        return date.formatted(.dateTime.hour().minute())
    }

    // MARK: - Saisie des quantités

    /// Bornes en millilitres converties dans l'unité affichée.
    private func displayRange(_ mlRange: ClosedRange<Double>) -> ClosedRange<Double> {
        let unit = manager.selectedUnit
        return unit.fromMl(mlRange.lowerBound)...unit.fromMl(mlRange.upperBound)
    }

    private func formatForInput(_ value: Double) -> String {
        NumberInput.fieldText(value, fractionDigits: manager.selectedUnit.inputFractionDigits)
    }

    private func updatePreset(at index: Int, displayValue: Double) {
        var presets = manager.presetsMl
        guard presets.indices.contains(index) else { return }
        presets[index] = manager.mlValue(from: displayValue)
        manager.presetsMl = presets
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
}

#Preview {
    SettingsView(manager: HydrationManager.shared, currentView: .constant(.settings))
        .padding()
        .background(Color.black)
}
