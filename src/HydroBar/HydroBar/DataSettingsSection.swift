//
//  DataSettingsSection.swift
//  HydroBar
//
//  Section « Données » des réglages : export CSV, sauvegarde et restauration
//  JSON (roadmap F4). La logique est dans `DataPortability`.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DataSettingsSection: View {
    @ObservedObject var manager: HydrationManager

    /// Le résultat s'affiche dans une alerte, pas dans la vue : le popover est
    /// transitoire et se ferme dès qu'un panneau d'enregistrement s'ouvre.
    private enum Outcome {
        case success(String)
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATA", comment: "Settings section title for data export and import")
                .font(Theme.Font.sectionTitle)
                .foregroundColor(.secondary)

            actionButton(String(localized: "Export as CSV…", comment: "Button: export daily totals as CSV"),
                         systemImage: "tablecells", action: exportCSV)
            actionButton(String(localized: "Back Up (JSON)…", comment: "Button: export the full intake log as JSON"),
                         systemImage: "externaldrive", action: exportBackup)
            actionButton(String(localized: "Restore from Backup…", comment: "Button: import a JSON backup"),
                         systemImage: "arrow.down.doc", action: importBackup)

            Text("Restoring adds the entries you don't have yet: importing the same backup twice changes nothing.",
                 comment: "Explanation under the data import button")
                .font(Theme.Font.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(Theme.Font.callout)
                    .frame(width: 20, alignment: .leading)
                Text(title)
                    .font(Theme.Font.body)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func exportCSV() {
        let csv = DataPortability.dailyCSV(from: manager.log, calendar: .current, defaultGoal: manager.targetMl)
        save(Data(csv.utf8), type: .commaSeparatedText, ext: "csv")
    }

    private func exportBackup() {
        do {
            save(try DataPortability.backupJSON(from: manager.log), type: .json, ext: "json")
        } catch {
            show(.failure(error.localizedDescription))
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        // App de barre de menu : sans activation, le panneau s'ouvre derrière
        // la fenêtre active.
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let outcome: Outcome
        do {
            let data = try Data(contentsOf: url)
            let backup = try DataPortability.readBackup(data, calendar: .current, defaultGoal: manager.targetMl)
            let added = manager.importBackup(backup)
            outcome = .success(String(format: String(localized: "%lld entries restored.",
                                                     comment: "Import result; %lld is the number of entries added"),
                                      added))
        } catch DataPortability.ImportError.invalidAmounts {
            outcome = .failure(String(localized: "This file contains invalid amounts. Nothing was imported.",
                                      comment: "Import error: amounts out of range"))
        } catch {
            outcome = .failure(String(localized: "This file is not a HydroBar backup. Nothing was imported.",
                                      comment: "Import error: unrecognized file"))
        }
        show(outcome)
    }

    private func save(_ data: Data, type: UTType, ext: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = DataPortability.suggestedFileName(extension: ext, date: Date(), calendar: .current)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            show(.failure(error.localizedDescription))
        }
    }

    /// Un export réussi se passe de confirmation : le fichier est là où
    /// l'utilisateur l'a demandé. Un import, lui, doit dire ce qu'il a fait.
    private func show(_ outcome: Outcome) {
        let alert = NSAlert()
        switch outcome {
        case .success(let message):
            alert.alertStyle = .informational
            alert.messageText = message
        case .failure(let message):
            alert.alertStyle = .warning
            alert.messageText = message
        }
        alert.addButton(withTitle: String(localized: "OK", comment: "OK button"))
        alert.runModal()
    }
}
