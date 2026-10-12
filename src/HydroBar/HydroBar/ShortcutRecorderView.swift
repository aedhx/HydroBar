//
//  ShortcutRecorderView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import AppKit

/// Clé UserDefaults d'un raccourci de preset. Partagée avec l'AppDelegate, qui
/// enregistre les raccourcis sauvegardés au lancement.
func shortcutDefaultsKey(forPreset index: Int) -> String {
    "shortcut_preset_\(index)"
}

struct ShortcutRecorderView: View {
    let presetIndex: Int
    @State private var isRecording: Bool = false
    @State private var currentShortcut: Shortcut?
    @State private var eventMonitor: Any?

    /// Message affiché sous l'enregistreur. Auparavant un échec n'était que
    /// journalisé : le raccourci restait affiché comme actif alors qu'il ne
    /// faisait rien (cf. AUDIT_TECHNIQUE.md § R2-9).
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    HStack(spacing: 6) {
                        if isRecording {
                            Text("Press...", comment: "Shortcut recorder state when recording")
                                .foregroundColor(.blue)
                        } else if let shortcut = currentShortcut {
                            Text(shortcut.displayString)
                                .foregroundColor(errorMessage == nil ? .primary : .orange)
                        } else {
                            Text("None", comment: "Shortcut recorder state when no shortcut is set")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 13, weight: .regular))
                    .frame(width: 120, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                if currentShortcut != nil && !isRecording {
                    Button(action: { removeShortcut() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Remove shortcut", comment: "Tooltip for remove shortcut button"))
                    .frame(width: 20)
                } else {
                    // Espace réservé pour maintenir l'alignement
                    Spacer()
                        .frame(width: 20)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            loadShortcut()
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Recording Logic

    private func startRecording() {
        isRecording = true
        errorMessage = nil

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let keyCode = Int(event.keyCode)
            let relevantModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            let modifiers = Int(relevantModifiers.rawValue)

            // Échap annule l'enregistrement.
            if keyCode == VirtualKeyCodes.escape {
                self.stopRecording()
                return nil
            }

            // Une touche seule n'est acceptée que si c'est une touche de fonction :
            // sans modificateur, un raccourci global volerait une touche ordinaire
            // à toutes les autres applications.
            if relevantModifiers.isEmpty {
                let isFunctionKey = (keyCode >= VirtualKeyCodes.f1 && keyCode <= VirtualKeyCodes.f12)
                if !isFunctionKey {
                    return event
                }
            }

            stopRecording()
            apply(Shortcut(keyCode: keyCode, modifiers: modifiers))
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    /// N'enregistre le raccourci que si le système l'a accepté. L'ancien code le
    /// sauvegardait dans tous les cas, puis ignorait l'échec.
    private func apply(_ shortcut: Shortcut) {
        let result = GlobalHotkeyManager.shared.registerShortcut(
            for: presetIndex,
            keyCode: shortcut.keyCode,
            modifiers: shortcut.modifiers
        )

        switch result {
        case .success:
            saveShortcut(shortcut)
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedMessage
            // L'ancien raccourci a été désenregistré par la tentative : on le
            // restaure pour ne pas perdre un raccourci qui fonctionnait.
            restorePreviousShortcut()
        }
    }

    private func restorePreviousShortcut() {
        guard let previous = currentShortcut else { return }
        GlobalHotkeyManager.shared.registerShortcut(
            for: presetIndex,
            keyCode: previous.keyCode,
            modifiers: previous.modifiers
        )
    }

    // MARK: - Shortcut Management

    /// Lit le raccourci sauvegardé sans le ré-enregistrer : l'AppDelegate le fait
    /// déjà au lancement, et le refaire à chaque ouverture des réglages créait une
    /// seconde source de vérité (R2-13). On vérifie en revanche qu'il est
    /// réellement actif — un enregistrement peut avoir échoué au lancement.
    private func loadShortcut() {
        let key = shortcutDefaultsKey(forPreset: presetIndex)
        guard let data = UserDefaults.standard.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data)
        else { return }

        currentShortcut = shortcut
        if !GlobalHotkeyManager.shared.isRegistered(presetIndex: presetIndex) {
            errorMessage = String(localized: "Inactive: another app is using this shortcut.",
                                  comment: "Saved shortcut that failed to register at launch")
        }
    }

    private func saveShortcut(_ shortcut: Shortcut) {
        currentShortcut = shortcut
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: shortcutDefaultsKey(forPreset: presetIndex))
        }
    }

    private func removeShortcut() {
        currentShortcut = nil
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: shortcutDefaultsKey(forPreset: presetIndex))
        GlobalHotkeyManager.shared.unregisterShortcut(for: presetIndex)
    }
}

#Preview {
    VStack(spacing: 20) {
        ShortcutRecorderView(presetIndex: 0)
        ShortcutRecorderView(presetIndex: 1)
        ShortcutRecorderView(presetIndex: 2)
    }
    .padding()
}
