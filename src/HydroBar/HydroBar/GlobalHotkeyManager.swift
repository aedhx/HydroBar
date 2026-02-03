//
//  GlobalHotkeyManager.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import Foundation
import AppKit
import Carbon

// Constantes d'erreur Carbon
private let eventHotKeyExistsErr: OSStatus = OSStatus(-9878)
private let eventParameterNotFoundErr: OSStatus = OSStatus(-9868)

// MARK: - Shortcut Structure
struct Shortcut: Codable, Equatable {
    let keyCode: Int
    let modifiers: Int
    
    init(keyCode: Int, modifiers: Int) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    /// Formatted string for display (e.g. "⌘ P", "⌘⇧ P")
    var displayString: String {
        var parts: [String] = []
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(self.modifiers))
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        if let keySymbol = Self.keyCodeToSymbol(keyCode) {
            parts.append(keySymbol)
        } else {
            parts.append("Key(\(keyCode))")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
    }
    
    private static func keyCodeToSymbol(_ keyCode: Int) -> String? {
        switch keyCode {
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
        case VirtualKeyCodes.space: return "Space"
        case VirtualKeyCodes.returnKey: return "↩"
        case VirtualKeyCodes.enter: return "⌤"
        case VirtualKeyCodes.tab: return "⇥"
        case VirtualKeyCodes.delete: return "⌫"
        case VirtualKeyCodes.escape: return "⎋"
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
        default: return nil
        }
    }
}

// MARK: - GlobalHotkeyManager
class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var registeredHotkeys: [UInt32: (presetIndex: Int, hotKeyRef: EventHotKeyRef?)] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var eventHandler: EventHandlerRef?
    
    private init() {
        setupEventHandler()
    }
    
    deinit {
        unregisterAllShortcuts()
        removeEventHandler()
    }
    
    // MARK: - Event Handler Setup
    
    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let eventHandlerCallback: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData,
                  let event = theEvent else { return OSStatus(eventNotHandledErr) }
            
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handleHotKeyEvent(event: event)
        }
        
        let userData = Unmanaged.passUnretained(self).toOpaque()
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandlerCallback,
            1,
            &eventSpec,
            userData,
            &eventHandler
        )
        
        if status != noErr {
            print("Erreur lors de l'installation du gestionnaire d'événements: \(status)")
        }
    }
    
    private func removeEventHandler() {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    // MARK: - Hotkey Registration
    
    /// Enregistre un raccourci global pour un preset
    /// - Parameters:
    ///   - presetIndex: Index du preset (0, 1, ou 2)
    ///   - keyCode: Code de la touche (voir VirtualKeyCodes)
    ///   - modifiers: Modificateurs (cmdKey, shiftKey, optionKey, controlKey)
    /// - Returns: true si l'enregistrement a réussi, false sinon
    @discardableResult
    func registerShortcut(for presetIndex: Int, keyCode: Int, modifiers: Int) -> Bool {
        // Désenregistrer l'ancien raccourci s'il existe
        unregisterShortcut(for: presetIndex)
        
        // Vérifier que les paramètres sont valides
        guard keyCode >= 0 && keyCode <= 127 else {
            print("Code de touche invalide: \(keyCode)")
            return false
        }
        
        // Vérifier que ce n'est pas un raccourci système réservé
        if isSystemReservedShortcut(keyCode: keyCode, modifiers: modifiers) {
            print("Ce raccourci est réservé par le système macOS")
            return false
        }
        
        let hotKeyID = nextHotKeyID
        nextHotKeyID += 1
        
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID_ = EventHotKeyID(signature: FourCharCode(fromString: "HYDR"), id: hotKeyID)
        
        // Convertir les modificateurs NSEvent vers Carbon
        let carbonModifiers = convertToCarbonModifiers(modifiers)
        
        // Vérifier que l'EventTarget est valide
        let eventTarget = GetApplicationEventTarget()
        guard eventTarget != nil else {
            print("Erreur: EventTarget invalide")
            return false
        }
        
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID_,
            eventTarget,
            0,
            &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            registeredHotkeys[hotKeyID] = (presetIndex: presetIndex, hotKeyRef: ref)
            return true
        } else {
            // Gérer les erreurs spécifiques
            let errorMessage = errorMessageForStatus(status)
            print("Erreur lors de l'enregistrement du raccourci (\(keyCode), mod: \(modifiers)): \(status) - \(errorMessage)")
            
            // Ne pas réessayer automatiquement pour éviter les boucles infinies
            // L'utilisateur devra réessayer manuellement si le raccourci est déjà utilisé
            return false
        }
    }
    
    /// Convertit les modificateurs NSEvent vers les modificateurs Carbon
    private func convertToCarbonModifiers(_ nsModifiers: Int) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        let flags = NSEvent.ModifierFlags(rawValue: UInt(nsModifiers))
        
        if flags.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if flags.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if flags.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        
        return carbonModifiers
    }
    
    /// Vérifie si un raccourci est réservé par le système macOS
    private func isSystemReservedShortcut(keyCode: Int, modifiers: Int) -> Bool {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        
        // Cmd+Q (quitter) - réservé
        if flags.contains(.command) && keyCode == VirtualKeyCodes.q {
            return true
        }
        
        // Cmd+W (fermer fenêtre) - réservé
        if flags.contains(.command) && keyCode == VirtualKeyCodes.w {
            return true
        }
        
        // Cmd+M (minimiser) - réservé
        if flags.contains(.command) && keyCode == VirtualKeyCodes.m {
            return true
        }
        
        // Cmd+H (masquer) - réservé
        if flags.contains(.command) && keyCode == VirtualKeyCodes.h {
            return true
        }
        
        // Cmd+Option+H (masquer les autres) - réservé
        if flags.contains([.command, .option]) && keyCode == VirtualKeyCodes.h {
            return true
        }
        
        return false
    }
    
    /// Retourne un message d'erreur lisible pour un code d'erreur Carbon
    private func errorMessageForStatus(_ status: OSStatus) -> String {
        if status == noErr {
            return "Succès"
        } else if status == eventHotKeyExistsErr {
            return "Le raccourci est déjà utilisé par une autre application"
        } else if status == eventParameterNotFoundErr {
            return "Paramètre non trouvé - le raccourci est peut-être réservé par le système"
        } else if status == OSStatus(eventNotHandledErr) {
            return "Événement non géré"
        } else {
            return "Erreur inconnue (\(status))"
        }
    }
    
    /// Désenregistre un raccourci pour un preset
    func unregisterShortcut(for presetIndex: Int) {
        // Trouver toutes les entrées pour ce presetIndex
        let keysToRemove = registeredHotkeys.filter { $0.value.presetIndex == presetIndex }
        for (hotKeyID, (_, hotKeyRef)) in keysToRemove {
            if let ref = hotKeyRef {
                let status = UnregisterEventHotKey(ref)
                if status != noErr {
                    print("Erreur lors du désenregistrement du raccourci: \(status)")
                }
            }
            registeredHotkeys.removeValue(forKey: hotKeyID)
        }
    }
    
    /// Désenregistre un raccourci par son ID interne (pour usage interne)
    private func unregisterShortcutByID(_ hotKeyID: UInt32) {
        if let (_, hotKeyRef) = registeredHotkeys[hotKeyID], let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            registeredHotkeys.removeValue(forKey: hotKeyID)
        }
    }
    
    /// Désenregistre tous les raccourcis
    func unregisterAllShortcuts() {
        // Collecter tous les presetIndex uniques
        let uniquePresetIndices = Set(registeredHotkeys.values.map { $0.presetIndex })
        for presetIndex in uniquePresetIndices {
            unregisterShortcut(for: presetIndex)
        }
    }
    
    // MARK: - Event Handling
    
    private func handleHotKeyEvent(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        guard status == noErr else { return status }
        
        // Vérifier que c'est notre signature
        guard hotKeyID.signature == FourCharCode(fromString: "HYDR") else {
            return OSStatus(eventNotHandledErr)
        }
        
        // Trouver le preset correspondant via le hotKeyID
        if let (presetIndex, _) = registeredHotkeys[hotKeyID.id] {
            if let presetMl = getPresetAmount(for: presetIndex) {
                DispatchQueue.main.async {
                    self.triggerPreset(presetIndex: presetIndex, amount: presetMl)
                }
                return noErr
            }
        }
        
        return OSStatus(eventNotHandledErr)
    }
    
    private func getPresetAmount(for index: Int) -> Double? {
        let manager = HydrationManager.shared
        guard index >= 0 && index < manager.presetsMl.count else { return nil }
        return manager.presetsMl[index]
    }
    
    private func triggerPreset(presetIndex: Int, amount: Double) {
        // Ajouter l'eau
        HydrationManager.shared.addWater(amount: amount)
        
        // Jouer un son de feedback
        playFeedbackSound()
    }
    
    private func playFeedbackSound() {
        // Utiliser le son système par défaut
        NSSound.beep()
        
        // Alternative : utiliser un son personnalisé
        // if let sound = NSSound(named: "Glass") {
        //     sound.play()
        // }
    }
}

// MARK: - Helper Extension
extension FourCharCode {
    init(fromString string: String) {
        var result: FourCharCode = 0
        for (index, char) in string.utf8.prefix(4).enumerated() {
            result |= FourCharCode(char) << (8 * (3 - index))
        }
        self = result
    }
}

// MARK: - Virtual Key Codes (exemples courants)
struct VirtualKeyCodes {
    static let space: Int = 0x31
    static let returnKey: Int = 0x24
    static let enter: Int = 0x4C
    static let tab: Int = 0x30
    static let delete: Int = 0x33
    static let escape: Int = 0x35
    static let f1: Int = 0x7A
    static let f2: Int = 0x78
    static let f3: Int = 0x63
    static let f4: Int = 0x76
    static let f5: Int = 0x60
    static let f6: Int = 0x61
    static let f7: Int = 0x62
    static let f8: Int = 0x64
    static let f9: Int = 0x65
    static let f10: Int = 0x6D
    static let f11: Int = 0x67
    static let f12: Int = 0x6F
    
    // Chiffres
    static let zero: Int = 0x1D
    static let one: Int = 0x12
    static let two: Int = 0x13
    static let three: Int = 0x14
    static let four: Int = 0x15
    static let five: Int = 0x17
    static let six: Int = 0x16
    static let seven: Int = 0x1A
    static let eight: Int = 0x1C
    static let nine: Int = 0x19
    
    // Lettres
    static let a: Int = 0x00
    static let b: Int = 0x0B
    static let c: Int = 0x08
    static let d: Int = 0x02
    static let e: Int = 0x0E
    static let f: Int = 0x03
    static let g: Int = 0x05
    static let h: Int = 0x04
    static let i: Int = 0x22
    static let j: Int = 0x26
    static let k: Int = 0x28
    static let l: Int = 0x25
    static let m: Int = 0x2E
    static let n: Int = 0x2D
    static let o: Int = 0x1F
    static let p: Int = 0x23
    static let q: Int = 0x0C
    static let r: Int = 0x0F
    static let s: Int = 0x01
    static let t: Int = 0x11
    static let u: Int = 0x20
    static let v: Int = 0x09
    static let w: Int = 0x0D
    static let x: Int = 0x07
    static let y: Int = 0x10
    static let z: Int = 0x06
}

// MARK: - Modifier Flags
struct ModifierFlags {
    static let command: Int = Int(cmdKey)
    static let shift: Int = Int(shiftKey)
    static let option: Int = Int(optionKey)
    static let control: Int = Int(controlKey)
    
    // Combinaisons courantes
    static func commandShift() -> Int {
        return Int(cmdKey | shiftKey)
    }
    
    static func commandOption() -> Int {
        return Int(cmdKey | optionKey)
    }
    
    static func commandControl() -> Int {
        return Int(cmdKey | controlKey)
    }
}
