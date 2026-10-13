//
//  ShortcutsSettingsPage.swift
//  HydroBar
//
//  Page « Raccourcis » des réglages : raccourcis clavier globaux et
//  intégrations (Raycast, deep links), plus la section de débogage quand
//  elle est ouverte.
//

import SwiftUI
import AppKit

struct ShortcutsSettingsPage: View {
    @ObservedObject var manager: HydrationManager
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared

    var body: some View {
        SettingsPage {
            shortcutsSection
            integrationsSection
            if manager.debugModeEnabled {
                debugSection
                if !deepLinkRouter.log.isEmpty {
                    deepLinkLogSection
                }
            }
        }
    }

    // MARK: - Raccourcis clavier

    private var shortcutsSection: some View {
        SettingsCard(title: Text("Keyboard Shortcuts", comment: "Settings section title for keyboard shortcuts")) {
            ForEach(Array(manager.presetsMl.indices), id: \.self) { index in
                shortcutRow(for: .preset(index))
            }
            // Au-delà des presets (F20).
            ForEach(HotkeyAction.general, id: \.self) { action in
                shortcutRow(for: action)
            }
        }
    }

    private func shortcutRow(for action: HotkeyAction) -> some View {
        LabeledContent {
            ShortcutRecorderView(action: action)
        } label: {
            Text(verbatim: action.localizedName)
        }
    }

    // MARK: - Intégrations

    private var integrationsSection: some View {
        SettingsCard(title: Text("Integrations", comment: "Settings section title for integrations")) {
            LabeledContent {
                Button(String(localized: "View Repository", comment: "Menu item to open GitHub repository")) {
                    if let url = URL(string: "https://github.com/aedhx/HydroBar/tree/main/src/raycast-hydrobar") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } label: {
                Text("Raycast Extension", comment: "Settings row: the Raycast extension")
            }

            // Deep links : autoriser les actions destructives sans confirmation.
            // Désactivé par défaut — n'importe quelle page web peut ouvrir une URL.
            Toggle(isOn: $manager.allowDestructiveDeepLinks) {
                Text("Allow destructive links without confirmation", comment: "Toggle label for destructive deep links")
                Text("Applies to hydrobar://reset and hydrobar://set-goal. Adding water and undo are never blocked.",
                     comment: "Explanation for destructive deep links toggle")
            }
        }
    }

    // MARK: - Débogage

    /// Accès par cinq clics sur le numéro de version, page Général.
    private var debugSection: some View {
        SettingsCard(title: Text("DEBUG", comment: "Settings section title for debug")) {
            // Réservé aux builds Debug : la section s'ouvre aussi en
            // version publiée (5 clics sur la version), et ce bouton
            // remplace tout l'historique réel, sans confirmation.
            #if DEBUG
            Button(action: {
                manager.generateFakeHistoryData()
                confirm(title: String(localized: "Fake Data Generated", comment: "Debug alert title"),
                        message: String(localized: "Fake history data has been generated for the last 30 days.",
                                        comment: "Debug alert message"))
            }) {
                Label {
                    Text("Generate Fake History Data", comment: "Debug button to generate fake data")
                } icon: {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                }
            }
            #endif

            Button(action: {
                manager.testNotification()
                confirm(title: String(localized: "Test Notification Sent", comment: "Debug alert title"),
                        message: String(localized: "A test notification will appear in 1 second.",
                                        comment: "Debug alert message"))
            }) {
                Label {
                    Text("Test Notification", comment: "Debug button to test notification")
                } icon: {
                    Image(systemName: "bell.badge.fill")
                }
            }
        }
    }

    private func confirm(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK", comment: "OK button"))
        alert.runModal()
    }

    /// Journal des deep links — sans lui, un ajout inexpliqué (script, page
    /// web, Raycast) est indébuggable.
    private var deepLinkLogSection: some View {
        SettingsCard(title: Text("RECENT DEEP LINKS", comment: "Debug section title for deep link log")) {
            ForEach(Array(deepLinkRouter.log.suffix(10).reversed())) { entry in
                HStack(spacing: 6) {
                    Image(systemName: entry.outcome == "ok" ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(entry.outcome == "ok" ? Theme.goal : Theme.warning)
                    Text(entry.date, style: .time)
                        .foregroundStyle(.secondary)
                    Text(verbatim: entry.url)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Text(verbatim: entry.outcome)
                        .foregroundStyle(.secondary)
                }
                .font(Theme.Font.mono)
            }
        }
    }
}
