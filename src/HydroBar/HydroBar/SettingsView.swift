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

/// Onglets de la fenêtre de réglages (v2). Douze sections s'empilaient
/// dans un popover de 320 px.
enum SettingsTab: String {
    case general, hydration, reminders, shortcuts, data, integrations
}

struct SettingsView: View {
    @ObservedObject var manager: HydrationManager
    /// Onglet affiché, retrouvé à la réouverture de la fenêtre.
    @AppStorage("settingsTab") private var selectedTab: SettingsTab = .general
    @StateObject private var updateChecker = GitHubUpdateChecker()
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject private var focusMonitor = FocusModeMonitor.shared
    @State private var debugTapCount: Int = 0
    /// Le système a refusé les notifications à l'activation des rappels.
    @State private var notificationsDenied = false

    var body: some View {
        TabView(selection: $selectedTab) {
            page { generalSection; appearanceSection; languageSection; updatesSection }
                .tabItem { Label(String(localized: "General", comment: "Settings tab"), systemImage: "gearshape") }
                .tag(SettingsTab.general)
            page { goalSection; activeHoursSection; presetsSection }
                .tabItem { Label(String(localized: "Hydration", comment: "Settings tab"), systemImage: "drop") }
                .tag(SettingsTab.hydration)
            page { remindersSection }
                .tabItem { Label(String(localized: "Reminders", comment: "Onboarding step title"), systemImage: "bell") }
                .tag(SettingsTab.reminders)
            page { shortcutsSection }
                .tabItem { Label(String(localized: "Keyboard Shortcuts", comment: "Settings section title for keyboard shortcuts"), systemImage: "keyboard") }
                .tag(SettingsTab.shortcuts)
            page { DataSettingsSection(manager: manager) }
                .tabItem { Label(String(localized: "Data", comment: "Settings tab"), systemImage: "externaldrive") }
                .tag(SettingsTab.data)
            page { integrationsSection; debugSection }
                .tabItem { Label(String(localized: "Integrations", comment: "Settings tab"), systemImage: "puzzlepiece.extension") }
                .tag(SettingsTab.integrations)
        }
        .frame(width: 520, height: 580)
        .onAppear {
            // La source de vérité du lancement au démarrage est le système :
            // l'utilisateur a pu le changer dans Réglages Système entre-temps.
            launchAtLogin.refresh()
        }
    }

    /// Une page d'onglet : défilante, avec les marges d'une fenêtre de réglages.
    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sections des onglets

    @ViewBuilder
    private var appearanceSection: some View {
            // Section Style Icône Menu Bar + Unités (groupées)
            VStack(alignment: .leading, spacing: 6) {
                Text("MENU BAR ICON STYLE", comment: "Settings section title for menu bar icon style")
                    .font(Theme.Font.sectionTitle)
                    .foregroundColor(.secondary)
                Picker("", selection: Binding(
                    get: { manager.menuBarIconStyle },
                    set: { manager.menuBarIconStyle = $0 }
                )) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        Text(verbatim: style.localizedName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)

                Toggle(isOn: Binding(get: { manager.coloredMenuBarIcon },
                                     set: { manager.coloredMenuBarIcon = $0 })) {
                    Text("Colored icon", comment: "Toggle: show the menu bar icon in color instead of monochrome")
                        .font(Theme.Font.body)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("UNITS", comment: "Settings section title for units")
                    .font(Theme.Font.sectionTitle)
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
    }

    @ViewBuilder
    private var goalSection: some View {
            // Section Objectif
            VStack(alignment: .leading, spacing: 6) {
                Text("DAILY GOAL", comment: "Settings section title for daily goal")
                    .font(Theme.Font.sectionTitle)
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
                        .font(Theme.Font.bodyMedium)
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .leading)
                }
            }
    }

    @ViewBuilder
    private var presetsSection: some View {
            // Section Verres Rapides
            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK PRESETS", comment: "Settings section title for quick presets")
                    .font(Theme.Font.sectionTitle)
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
                            .font(Theme.Font.controlMedium)
                            .frame(maxWidth: .infinity)
                            
                            Image(systemName: iconForPreset(at: index))
                                .font(.system(size: iconSizeForPreset(at: index)))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
    }

    @ViewBuilder
    private var shortcutsSection: some View {
            // Section Raccourcis clavier
            VStack(alignment: .leading, spacing: 6) {
                Text("Keyboard Shortcuts", comment: "Settings section title for keyboard shortcuts")
                    .font(Theme.Font.sectionTitle)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(manager.presetsMl.indices), id: \.self) { index in
                        shortcutRow(for: .preset(index))
                    }
                    // Au-delà des presets (F20).
                    ForEach(HotkeyAction.general, id: \.self) { action in
                        shortcutRow(for: action)
                    }
                }
            }
    }

    @ViewBuilder
    private var remindersSection: some View {
            // Section Rappels
            VStack(alignment: .leading, spacing: 6) {
                Text("REMINDERS", comment: "Settings section title for reminders")
                    .font(Theme.Font.sectionTitle)
                    .foregroundColor(.secondary)


                // Toggle Activer les rappels
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(Theme.Font.body)
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .leading)
                    
                    Text("Enable reminders", comment: "Toggle label to enable reminders")
                        .font(Theme.Font.body)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { manager.notificationsEnabled },
                        set: { newValue in
                            // Le didSet de notificationsEnabled programme ou
                            // annule les rappels.
                            manager.setRemindersEnabled(newValue) { granted in
                                notificationsDenied = newValue && !granted
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                
                // Refus visible et rattrapable, au lieu d'un interrupteur qui
                // revient en arrière sans explication.
                if notificationsDenied {
                    Button(action: { manager.openNotificationSettings() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(Theme.Font.caption)
                                .foregroundColor(.orange)
                            Text("Notifications are turned off for HydroBar in System Settings.",
                                 comment: "Shown when the user enables reminders but notifications are denied")
                                .font(Theme.Font.caption)
                                .underline()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 28)
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
                            .font(Theme.Font.body)
                            .frame(width: 80)
                            
                            Text("minutes", comment: "Unit label for custom notification minutes")
                                .font(Theme.Font.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    adaptiveRemindersRow

                    snoozeRow

                    focusModeSection
                    
                    // Toggle Ne pas déranger (manuel si pas de sync)
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "moon.fill")
                            .font(Theme.Font.body)
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .leading)
                        
                        Text("Do Not Disturb Mode", comment: "Toggle label for Do Not Disturb mode")
                            .font(Theme.Font.body)
                        
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
                            .font(Theme.Font.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
    }

    @ViewBuilder
    private var debugSection: some View {
            // Section Debug (si activée — accès via 5 taps sur le numéro de version)
            if manager.debugModeEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DEBUG", comment: "Settings section title for debug")
                        .font(Theme.Font.sectionTitle)
                        .foregroundColor(.secondary)

                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Réservé aux builds Debug : le panneau s'ouvre aussi en
                        // version publiée (5 clics sur la version), et ce bouton
                        // remplace tout l'historique réel, sans confirmation.
                        #if DEBUG
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
                                    .font(Theme.Font.callout)
                                Text("Generate Fake History Data", comment: "Debug button to generate fake data")
                                    .font(Theme.Font.body)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        #endif

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
                                    .font(Theme.Font.callout)
                                Text("Test Notification", comment: "Debug button to test notification")
                                    .font(Theme.Font.body)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Theme.water.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        // Journal des deep links — sans lui, un ajout inexpliqué
                        // (script, page web, Raycast) est indébuggable.
                        if !deepLinkRouter.log.isEmpty {
                            Text("RECENT DEEP LINKS", comment: "Debug section title for deep link log")
                                .font(Theme.Font.footnoteEmphasis)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(deepLinkRouter.log.suffix(10).reversed())) { entry in
                                    HStack(spacing: 6) {
                                        Image(systemName: entry.outcome == "ok"
                                              ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .font(Theme.Font.micro)
                                            .foregroundColor(entry.outcome == "ok" ? Theme.goal : .orange)
                                        Text(entry.date, style: .time)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Text(verbatim: entry.url)
                                            .font(.system(size: 10, design: .monospaced))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer(minLength: 0)
                                        Text(verbatim: entry.outcome)
                                            .font(Theme.Font.micro)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Divider()
            }
    }

    @ViewBuilder
    private var updatesSection: some View {
            // Section Vérification des mises à jour
            VStack(alignment: .leading, spacing: 6) {
                Text("UPDATES", comment: "Settings section title for updates")
                    .font(Theme.Font.sectionTitle)
                    .foregroundColor(.secondary)

                HStack(alignment: .center, spacing: 8) {
                    Text("Version", comment: "Label for current app version")
                        .font(Theme.Font.body)
                        .foregroundColor(.secondary)
                    Text(verbatim: updateChecker.currentAppVersion)
                        .font(Theme.Font.bodyMedium)
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
                            .font(Theme.Font.footnote)
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
                                .font(Theme.Font.callout)
                            Text("Check for Updates", comment: "Button to check for app updates")
                        }
                    }
                    .font(Theme.Font.bodyMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.water.opacity(0.15))
                    .foregroundColor(Theme.water)
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
                                    .foregroundColor(Theme.goal)
                                Text("You're up to date.", comment: "Message when no update is available")
                                    .font(Theme.Font.callout)
                                    .foregroundColor(.secondary)
                            }
                        case .updateAvailable(let version, let url):
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(Theme.water)
                                    Text(String(format: String(localized: "Version %@ is available.", comment: "Message when update is available"), version))
                                        .font(Theme.Font.callout)
                                        .foregroundColor(.primary)
                                }
                                Button(action: { updateChecker.openUpdateURL(url) }) {
                                    Text("Open Download Page", comment: "Button to open GitHub release page")
                                        .font(Theme.Font.calloutMedium)
                                }
                                .buttonStyle(.plain)
                            }
                        case .error(let message):
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(message)
                                    .font(Theme.Font.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
    }

    @ViewBuilder
    private var integrationsSection: some View {
            // Section Raycast Extension
            VStack(alignment: .leading, spacing: 6) {
                Text("INTEGRATIONS", comment: "Settings section title for integrations")
                    .font(Theme.Font.sectionTitle)
                    .foregroundColor(.secondary)


                // Raycast
                Button(action: {
                    if let url = URL(string: "https://github.com/aedhx/HydroBar/tree/main/raycast-hydrobar") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(Theme.Font.callout)
                        Text("Raycast Extension", comment: "Button to open Raycast extension page")
                            .font(Theme.Font.bodyMedium)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(Theme.Font.caption)
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
                        .font(Theme.Font.body)
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .leading)

                    Text("Allow destructive links without confirmation", comment: "Toggle label for destructive deep links")
                        .font(Theme.Font.body)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Toggle("", isOn: $manager.allowDestructiveDeepLinks)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Text("Applies to hydrobar://reset and hydrobar://set-goal. Adding water and undo are never blocked.", comment: "Explanation for destructive deep links toggle")
                    .font(Theme.Font.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
            }
    }

    @ViewBuilder
    private var languageSection: some View {
            // Section Langue (en bas)
            VStack(alignment: .leading, spacing: 6) {
                Text("LANGUAGE", comment: "Settings section title for language")
                    .font(Theme.Font.sectionTitle)
                    .foregroundColor(.secondary)

                
                Picker("", selection: Binding(
                    get: { manager.appLanguage },
                    set: { newValue in
                        guard newValue != manager.appLanguage else { return }
                        manager.appLanguage = newValue
                        // Hors de la mise à jour de la vue : une alerte modale
                        // ouverte depuis le setter d'un Binding bloquait le rendu.
                        DispatchQueue.main.async { promptToApplyLanguage() }
                    }
                )) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(verbatim: language.fullDisplayName)
                            .tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
    }

    
    // MARK: - Sections extraites
    // Sorties du `body` pour limiter la complexité que le type-checker SwiftUI
    // doit résoudre d'un bloc : ce fichier dépasse les 800 lignes.

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GENERAL", comment: "Settings section title for general options")
                .font(Theme.Font.sectionTitle)
                .foregroundColor(.secondary)

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "power")
                    .font(Theme.Font.body)
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .leading)

                Text("Launch at login", comment: "Toggle label for launching the app at login")
                    .font(Theme.Font.body)

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
                            .font(Theme.Font.caption)
                            .foregroundColor(.orange)
                        Text("Approval needed in System Settings", comment: "Warning when the login item awaits user approval")
                            .font(Theme.Font.caption)
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
                    .font(Theme.Font.caption)
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
                        .font(Theme.Font.caption)
                        .foregroundColor(.orange)
                    Text(issue)
                        .font(Theme.Font.caption)
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
                    .font(Theme.Font.body)
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .leading)

                Text("Sync with Focus Mode", comment: "Toggle label to sync with macOS Focus Mode")
                    .font(Theme.Font.body)

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
                            .font(Theme.Font.caption)
                            .foregroundColor(.orange)
                        Text("Access denied — grant it under Privacy & Security › Focus", comment: "Focus Mode authorization denied")
                            .font(Theme.Font.caption)
                            .underline()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 28)

            case .unavailable:
                Text("Focus status is unreadable. Check that HydroBar is allowed to send notifications — the Focus status also needs it.", comment: "Focus Mode status unreadable despite authorization")
                    .font(Theme.Font.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)

            case .authorized, .notRequested:
                if manager.focusModeAutoSync {
                    Text("Do Not Disturb mode automatically follows macOS Focus Mode", comment: "Explanation text for Focus Mode sync")
                        .font(Theme.Font.caption)
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
                .font(Theme.Font.sectionTitle)
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
                    .font(Theme.Font.callout)
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
                .font(Theme.Font.caption)
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

    private func shortcutRow(for action: HotkeyAction) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(verbatim: action.localizedName)
                .font(Theme.Font.body)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 90, alignment: .leading)

            ShortcutRecorderView(action: action)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Rappels intelligents (F6)

    private var adaptiveRemindersRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(Theme.Font.body)
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .leading)
                Text("Adapt to my pace", comment: "Toggle: remind more often when behind schedule")
                    .font(Theme.Font.body)
                Spacer()
                Toggle("", isOn: Binding(get: { manager.adaptiveReminders },
                                         set: { manager.adaptiveReminders = $0 }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            Text("Reminders follow your active hours, stop once your goal is reached, and come a bit more often when you're behind.",
                 comment: "Explanation of how reminders are scheduled")
                .font(Theme.Font.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 28)
        }
    }

    // MARK: - Pause des rappels (F19)

    /// L'état de la pause est toujours visible et annulable : c'est ce qui
    /// manque au mode Ne pas déranger, qu'on oublie de désactiver.
    @ViewBuilder
    private var snoozeRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "zzz")
                .font(Theme.Font.body)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)

            if let until = manager.remindersSnoozedUntil {
                Text(String(format: String(localized: "Paused until %@",
                                           comment: "Reminders snooze status; %@ is a time"),
                            until.formatted(date: .omitted, time: .shortened)))
                    .font(Theme.Font.body)
                Spacer()
                Button(String(localized: "Resume", comment: "Button to end the reminders pause")) {
                    manager.resumeReminders()
                }
                .controlSize(.small)
            } else {
                Text("Pause reminders", comment: "Label of the snooze menu in settings")
                    .font(Theme.Font.body)
                Spacer()
                Menu {
                    ForEach(SnoozeOption.allCases) { option in
                        Button(option.title) { manager.snoozeReminders(option) }
                    }
                } label: {
                    Text("Pause…", comment: "Snooze menu button")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    // MARK: - Langue

    /// L'ancienne alerte annonçait un redémarrage, mais l'app se contentait de
    /// quitter, sans laisser le choix. Relancer soi-même une app sandboxée
    /// impose un processus auxiliaire ; on laisse plutôt l'utilisateur quitter
    /// maintenant ou plus tard.
    private func promptToApplyLanguage() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Language Changed", comment: "Language change alert title")
        alert.informativeText = String(localized: "HydroBar will use the new language the next time it opens.",
                                       comment: "Language change alert message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Quit Now", comment: "Quit to apply the new language"))
        alert.addButton(withTitle: String(localized: "Later", comment: "Apply the new language at next launch"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
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
    SettingsView(manager: HydrationManager.shared)
        .padding()
        .background(Color.black)
}
