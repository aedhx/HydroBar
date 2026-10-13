//
//  GeneralSettingsPage.swift
//  HydroBar
//
//  Page « Général » des réglages : icône de la barre des menus (avec son
//  aperçu), ouverture de session, langue, unité, données, version et mises
//  à jour.
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
            MenuBarPreview(manager: manager)
            menuBarCard
            appCard
            DataSettingsSection(manager: manager)
            aboutCard
        }
    }

    // MARK: - Barre des menus

    private var menuBarCard: some View {
        SettingsCard {
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

    // MARK: - App

    private var appCard: some View {
        SettingsCard {
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

            LabeledContent {
                languagePicker
            } label: {
                languageLabel
            }

            LabeledContent {
                Picker(selection: Binding(
                    get: { manager.selectedUnit },
                    set: { manager.selectedUnit = $0 }
                )) {
                    ForEach(AppUnit.allCases, id: \.self) { unit in
                        Text(verbatim: unit.pickerLabel).tag(unit)
                    }
                } label: {
                    unitLabel
                }
                .labelsHidden()
                .fixedSize()
            } label: {
                unitLabel
            }

            // Problème de persistance : délibérément visible hors mode debug.
            // Un historique mis de côté pour corruption doit se savoir — c'est
            // le genre de perte qu'on ne découvre sinon jamais.
            if let issue = manager.lastDataIssue {
                SettingsWarning(message: issue)
            }
        }
    }

    private var languageLabel: Text {
        Text("Language", comment: "Settings row: app language")
    }

    private var unitLabel: Text {
        Text("Unit", comment: "Settings row: unit used to display amounts")
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
                Text(verbatim: language.displayName)
                    .tag(language.rawValue)
            }
        } label: {
            languageLabel
        }
        .labelsHidden()
        .fixedSize()
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

    // MARK: - Version et mises à jour

    private var aboutCard: some View {
        SettingsCard(footer: Self.updatesFooter) {
            LabeledContent {
                #if !APP_STORE
                Button(action: { updateChecker.checkForUpdates() }) {
                    Text("Check for Updates", comment: "Button to check for app updates")
                }
                .disabled(updateChecker.isChecking)
                #endif
            } label: {
                HStack(spacing: 6) {
                    Text("Version", comment: "Label for current app version")
                    // Cinq clics sur le numéro ouvrent ou referment la section
                    // de débogage, page Raccourcis.
                    Text(verbatim: Self.appVersion)
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            debugTapCount += 1
                            if debugTapCount >= 5 {
                                debugTapCount = 0
                                manager.debugModeEnabled.toggle()
                            }
                        }
                    if manager.debugModeEnabled {
                        Image(systemName: "ladybug.fill")
                            .foregroundStyle(Theme.warning)
                    }
                }
                #if !APP_STORE
                updateStatus
                #endif
            }
        }
    }

    private static var updatesFooter: Text? {
        #if APP_STORE
        return Text("Updates are installed by the App Store.", comment: "Settings: App Store build, no update check")
        #else
        return nil
        #endif
    }

    /// Version affichée, avec le numéro de build : « 2.0.1 (5) ».
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    #if !APP_STORE
    /// Résultat de la dernière vérification, sous la version.
    @ViewBuilder
    private var updateStatus: some View {
        if updateChecker.isChecking {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
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
            case .updateAvailable(let version, let url):
                Label {
                    Text(String(format: String(localized: "Version %@ is available.",
                                               comment: "Message when update is available"), version))
                } icon: {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Theme.water)
                }
                Button(action: { updateChecker.openUpdateURL(url) }) {
                    Text("Open Download Page", comment: "Button to open GitHub release page")
                        // Un sous-titre de ligne est gris : le lien garde sa couleur.
                        .foregroundStyle(Color(nsColor: .linkColor))
                }
                .buttonStyle(.link)
            case .error(let message):
                SettingsWarning(message: message)
            case nil:
                EmptyView()
            }
        }
    }
    #endif
}
