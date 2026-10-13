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
    let action: HotkeyAction
    @State private var isRecording: Bool = false
    @State private var currentShortcut: Shortcut?
    @State private var eventMonitor: Any?

    /// Message affiché sous l'enregistreur. Auparavant un échec n'était que
    /// journalisé : le raccourci restait affiché comme actif alors qu'il ne
    /// faisait rien (cf. AUDIT_TECHNIQUE.md § R2-9).
    @State private var errorMessage: String?

    var body: some View {
        // Aligné à droite : dans les réglages, l'enregistreur est le contrôle
        // d'une ligne dont le libellé est à gauche.
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                if currentShortcut != nil && !isRecording {
                    Button(action: { removeShortcut() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(Theme.Font.control)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Remove shortcut", comment: "Tooltip for remove shortcut button"))
                }

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
                                .foregroundColor(Theme.water)
                        } else if let shortcut = currentShortcut {
                            Text(shortcut.displayString)
                                .foregroundColor(errorMessage == nil ? .primary : .orange)
                        } else {
                            Text("None", comment: "Shortcut recorder state when no shortcut is set")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(Theme.Font.body)
                    .frame(width: 120)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording ? AnyShapeStyle(Theme.water.opacity(0.1)) : AnyShapeStyle(.quaternary))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Theme.water : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Font.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.trailing)
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
            for: action,
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
            for: action,
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
        guard let data = UserDefaults.standard.data(forKey: action.defaultsKey),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data)
        else { return }

        currentShortcut = shortcut
        if !GlobalHotkeyManager.shared.isRegistered(action) {
            errorMessage = String(localized: "Inactive: another app is using this shortcut.",
                                  comment: "Saved shortcut that failed to register at launch")
        }
    }

    private func saveShortcut(_ shortcut: Shortcut) {
        currentShortcut = shortcut
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: action.defaultsKey)
        }
    }

    private func removeShortcut() {
        currentShortcut = nil
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: action.defaultsKey)
        GlobalHotkeyManager.shared.unregisterShortcut(for: action)
    }
}

#Preview {
    VStack(spacing: 20) {
        ShortcutRecorderView(action: .preset(0))
        ShortcutRecorderView(action: .undo)
        ShortcutRecorderView(action: .togglePopover)
    }
    .padding()
}
