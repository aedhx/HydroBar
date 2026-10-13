//
//  GeneralSettingsPage.swift
//  HydroBar
//
//  Page « Général » des réglages : ouverture de session, langue, unité, icône
//  de la barre des menus, données, version et mises à jour.
//

import SwiftUI
import AppKit

struct GeneralSettingsPage: View {
    @ObservedObject var manager: HydrationManager
    #if !APP_STORE
    // Build DMG seulement : sur le Mac App Store, c'est le Store qui met à jour.
    @StateObject private var updateChecker = GitHubUpdateChecker()
    #endif
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @State private var debugTapCount: Int = 0

    var body: some View {
        SettingsPage {
            appSection
            menuBarSection
            DataSettingsSection(manager: manager)
            aboutSection
        }
    }

    // MARK: - App

    private var appSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            )) {
                Text("Launch at login", comment: "Toggle label for launching the app at login")
            }

            // macOS 13+ : l'app est enregistrée mais ne démarrera pas tant que
            // l'utilisateur n'a pas validé l'élément d'ouverture.
            if launchAtLogin.needsApproval {
                SettingsLink(title: Text("Approval needed in System Settings",
                                         comment: "Warning when the login item awaits user approval"),
                             isWarning: true,
                             action: { launchAtLogin.openLoginItemsSettings() })
            }

            // Un échec silencieux serait pire que l'absence de la fonctionnalité :
            // l'utilisateur croirait l'option active.
            if let failure = launchAtLogin.failureMessage {
                SettingsWarning(message: failure)
            }

            languagePicker

            Picker(selection: Binding(
                get: { manager.selectedUnit },
                set: { manager.selectedUnit = $0 }
            )) {
                ForEach(AppUnit.allCases, id: \.self) { unit in
                    Text(verbatim: unit.pickerLabel).tag(unit)
                }
            } label: {
                Text("Unit", comment: "Settings row: unit used to display amounts")
            }

            // Problème de persistance : délibérément visible hors mode debug.
            // Un historique mis de côté pour corruption doit se savoir — c'est
            // le genre de perte qu'on ne découvre sinon jamais.
            if let issue = manager.lastDataIssue {
                SettingsWarning(message: issue)
            }
        }
    }

    private var languagePicker: some View {
        Picker(selection: Binding(
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
        } label: {
            Text("Language", comment: "Settings row: app language")
        }
    }

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

    // MARK: - Barre des menus

    private var menuBarSection: some View {
        Section {
            LabeledContent {
                Picker(selection: Binding(
                    get: { manager.menuBarIconStyle },
                    set: { manager.menuBarIconStyle = $0 }
                )) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        Text(verbatim: style.localizedName).tag(style)
                    }
                } label: {
                    menuBarIconLabel
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            } label: {
                menuBarIconLabel
            }

            Toggle(isOn: Binding(get: { manager.coloredMenuBarIcon },
                                 set: { manager.coloredMenuBarIcon = $0 })) {
                Text("Colored icon", comment: "Toggle: show the menu bar icon in color instead of monochrome")
            }
        }
    }

    private var menuBarIconLabel: Text {
        Text("Menu bar icon", comment: "Settings row: style of the menu bar icon")
    }

    // MARK: - Version et mises à jour

    @ViewBuilder
    private var aboutSection: some View {
        #if APP_STORE
        Section {
            versionRow
        } footer: {
            SettingsFooter(Text("Updates are installed by the App Store.",
                                comment: "Settings: App Store build, no update check"))
        }
        #else
        Section {
            versionRow
            updateRows
        }
        #endif
    }

    private var versionRow: some View {
        LabeledContent {
            HStack(spacing: 6) {
                if manager.debugModeEnabled {
                    Image(systemName: "ladybug.fill")
                        .foregroundStyle(Theme.warning)
                }
                // Cinq clics sur la version ouvrent ou referment la section
                // de débogage, page Raccourcis.
                Text(verbatim: Self.appVersion)
                    .onTapGesture {
                        debugTapCount += 1
                        if debugTapCount >= 5 {
                            debugTapCount = 0
                            manager.debugModeEnabled.toggle()
                        }
                    }
            }
        } label: {
            Text("Version", comment: "Label for current app version")
        }
    }

    /// Version affichée, avec le numéro de build : « 2.0 (4) ».
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    #if !APP_STORE
    @ViewBuilder
    private var updateRows: some View {
        if case .updateAvailable(let version, let url) = updateChecker.result {
            LabeledContent {
                Button(action: { updateChecker.openUpdateURL(url) }) {
                    Text("Open Download Page", comment: "Button to open GitHub release page")
                }
            } label: {
                Label {
                    Text(String(format: String(localized: "Version %@ is available.",
                                               comment: "Message when update is available"), version))
                } icon: {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Theme.water)
                }
            }
        }

        LabeledContent {
            Button(action: { updateChecker.checkForUpdates() }) {
                Text("Check for Updates", comment: "Button to check for app updates")
            }
            .disabled(updateChecker.isChecking)
        } label: {
            updateStatus
        }
    }

    /// Résultat de la dernière vérification, à gauche du bouton.
    @ViewBuilder
    private var updateStatus: some View {
        if updateChecker.isChecking {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking…", comment: "Button label while checking for updates")
            }
        } else {
            switch updateChecker.result {
            case .upToDate:
                Label {
                    Text("You're up to date.", comment: "Message when no update is available")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.goal)
                }
            case .error(let message):
                SettingsWarning(message: message)
            case .updateAvailable, nil:
                EmptyView()
            }
        }
    }
    #endif
}
