//
//  ShortcutRecorderView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import AppKit

struct ShortcutRecorderView: View {
    let presetIndex: Int
    @State private var isRecording: Bool = false
    @State private var currentShortcut: Shortcut?
    @State private var eventMonitor: Any?
    
    var body: some View {
        HStack(spacing: 8) {
            // Bouton principal pour afficher/enregistrer le raccourci
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
                        Text(formatShortcut(shortcut))
                            .foregroundColor(.primary)
                    } else {
                        Text("None", comment: "Shortcut recorder state when no shortcut is set")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 13, weight: .regular)) // HIG: Taille minimum 11pt, 13pt pour le texte standard
                .frame(width: 120, alignment: .leading) // Largeur fixe pour alignement cohérent
                .padding(.horizontal, 8) // HIG: Padding horizontal standard
                .padding(.vertical, 4) // HIG: Padding vertical minimal
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
            
            // Bouton pour supprimer le raccourci
            if currentShortcut != nil && !isRecording {
                Button(action: {
                    removeShortcut()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Remove shortcut", comment: "Tooltip for remove shortcut button"))
                .frame(width: 20) // Largeur fixe pour alignement
            } else {
                // Espace réservé pour maintenir l'alignement
                Spacer()
                    .frame(width: 20)
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
        
        // Créer un moniteur d'événements local pour capturer les touches
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            
            // Capturer la combinaison de touches
            let keyCode = Int(event.keyCode)
            
            // Extraire uniquement les modificateurs pertinents
            let relevantModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            let modifiers = Int(relevantModifiers.rawValue)
            
            // Ignorer les touches système (Escape pour annuler)
            if keyCode == VirtualKeyCodes.escape {
                self.stopRecording()
                return nil
            }
            
            // Vérifier qu'il y a au moins un modificateur (pour éviter les touches simples)
            if relevantModifiers.isEmpty {
                // Si pas de modificateur, on peut quand même enregistrer (touche seule)
                // Mais généralement on veut au moins un modificateur pour les raccourcis globaux
                // On peut permettre les touches de fonction seules
                let isFunctionKey = (keyCode >= VirtualKeyCodes.f1 && keyCode <= VirtualKeyCodes.f12)
                if !isFunctionKey {
                    // Ignorer les touches simples (sauf F1-F12)
                    return event
                }
            }
            
                // Arrêter l'enregistrement
                stopRecording()
                
                // Sauvegarder le raccourci
                let shortcut = Shortcut(keyCode: keyCode, modifiers: modifiers)
                saveShortcut(shortcut)
                
                // Enregistrer dans GlobalHotkeyManager
                let success = GlobalHotkeyManager.shared.registerShortcut(
                    for: presetIndex,
                    keyCode: keyCode,
                    modifiers: modifiers
                )
                
                // Si l'enregistrement a échoué, afficher un message à l'utilisateur
                if !success {
                    // Optionnel : afficher une alerte ou un feedback visuel
                    // Pour l'instant, on garde le raccourci sauvegardé même si l'enregistrement a échoué
                    // L'utilisateur pourra réessayer plus tard
                }
            
            // Ne pas propager l'événement
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
    
    // MARK: - Shortcut Management
    
    private func loadShortcut() {
        // Charger depuis UserDefaults
        let key = "shortcut_preset_\(presetIndex)"
        if let data = UserDefaults.standard.data(forKey: key),
           let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
            currentShortcut = shortcut
            
            // S'assurer que le raccourci est enregistré dans GlobalHotkeyManager
            // (au cas où il aurait été désenregistré)
            GlobalHotkeyManager.shared.registerShortcut(
                for: presetIndex,
                keyCode: shortcut.keyCode,
                modifiers: shortcut.modifiers
            )
        }
    }
    
    private func saveShortcut(_ shortcut: Shortcut) {
        currentShortcut = shortcut
        
        // Sauvegarder dans UserDefaults
        let key = "shortcut_preset_\(presetIndex)"
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func removeShortcut() {
        currentShortcut = nil
        
        // Supprimer de UserDefaults
        let key = "shortcut_preset_\(presetIndex)"
        UserDefaults.standard.removeObject(forKey: key)
        
        // Désenregistrer dans GlobalHotkeyManager
        GlobalHotkeyManager.shared.unregisterShortcut(for: presetIndex)
    }
    
    // MARK: - Formatting
    
    private func formatShortcut(_ shortcut: Shortcut) -> String {
        var parts: [String] = []
        
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(shortcut.modifiers))
        
        // Ajouter les modificateurs dans l'ordre standard macOS (⌃ ⌥ ⇧ ⌘)
        if modifiers.contains(.control) {
            parts.append("⌃")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.command) {
            parts.append("⌘")
        }
        
        // Ajouter la touche principale
        if let keySymbol = keyCodeToSymbol(shortcut.keyCode) {
            parts.append(keySymbol)
        } else {
            // Si on ne connaît pas le symbole, afficher le code
            parts.append("Key(\(shortcut.keyCode))")
        }
        
        return parts.isEmpty ? String(localized: "None", comment: "No shortcut configured") : parts.joined(separator: " ")
    }
    
    private func keyCodeToSymbol(_ keyCode: Int) -> String? {
        // Mapping des codes de touches vers leurs symboles/lettres
        switch keyCode {
        // Chiffres
        case VirtualKeyCodes.zero: return "0"
        case VirtualKeyCodes.one: return "1"
        case VirtualKeyCodes.two: return "2"
        case VirtualKeyCodes.three: return "3"
        case VirtualKeyCodes.four: return "4"
        case VirtualKeyCodes.five: return "5"
        case VirtualKeyCodes.six: return "6"
        case VirtualKeyCodes.seven: return "7"
        case VirtualKeyCodes.eight: return "8"
        case VirtualKeyCodes.nine: return "9"
        
        // Lettres
        case VirtualKeyCodes.a: return "A"
        case VirtualKeyCodes.b: return "B"
        case VirtualKeyCodes.c: return "C"
        case VirtualKeyCodes.d: return "D"
        case VirtualKeyCodes.e: return "E"
        case VirtualKeyCodes.f: return "F"
        case VirtualKeyCodes.g: return "G"
        case VirtualKeyCodes.h: return "H"
        case VirtualKeyCodes.i: return "I"
        case VirtualKeyCodes.j: return "J"
        case VirtualKeyCodes.k: return "K"
        case VirtualKeyCodes.l: return "L"
        case VirtualKeyCodes.m: return "M"
        case VirtualKeyCodes.n: return "N"
        case VirtualKeyCodes.o: return "O"
        case VirtualKeyCodes.p: return "P"
        case VirtualKeyCodes.q: return "Q"
        case VirtualKeyCodes.r: return "R"
        case VirtualKeyCodes.s: return "S"
        case VirtualKeyCodes.t: return "T"
        case VirtualKeyCodes.u: return "U"
        case VirtualKeyCodes.v: return "V"
        case VirtualKeyCodes.w: return "W"
        case VirtualKeyCodes.x: return "X"
        case VirtualKeyCodes.y: return "Y"
        case VirtualKeyCodes.z: return "Z"
        
        // Touches spéciales
        case VirtualKeyCodes.space: return "Space"
        case VirtualKeyCodes.returnKey: return "↩"
        case VirtualKeyCodes.enter: return "⌤"
        case VirtualKeyCodes.tab: return "⇥"
        case VirtualKeyCodes.delete: return "⌫"
        case VirtualKeyCodes.escape: return "⎋"
        
        // Touches de fonction
        case VirtualKeyCodes.f1: return "F1"
        case VirtualKeyCodes.f2: return "F2"
        case VirtualKeyCodes.f3: return "F3"
        case VirtualKeyCodes.f4: return "F4"
        case VirtualKeyCodes.f5: return "F5"
        case VirtualKeyCodes.f6: return "F6"
        case VirtualKeyCodes.f7: return "F7"
        case VirtualKeyCodes.f8: return "F8"
        case VirtualKeyCodes.f9: return "F9"
        case VirtualKeyCodes.f10: return "F10"
        case VirtualKeyCodes.f11: return "F11"
        case VirtualKeyCodes.f12: return "F12"
        
        default:
            return nil
        }
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
