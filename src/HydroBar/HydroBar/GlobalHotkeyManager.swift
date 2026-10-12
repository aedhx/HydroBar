//
//  GlobalHotkeyManager.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import Foundation
import AppKit
import Carbon
import os

// Constantes d'erreur Carbon
private let eventHotKeyExistsErr: OSStatus = OSStatus(-9878)

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
    
    /// Table plutôt que `switch` : 54 branches donnaient une complexité
    /// cyclomatique de 55, pour une simple correspondance.
    private static let keySymbols: [Int: String] = [
        VirtualKeyCodes.zero: "0",
        VirtualKeyCodes.one: "1",
        VirtualKeyCodes.two: "2",
        VirtualKeyCodes.three: "3",
        VirtualKeyCodes.four: "4",
        VirtualKeyCodes.five: "5",
        VirtualKeyCodes.six: "6",
        VirtualKeyCodes.seven: "7",
        VirtualKeyCodes.eight: "8",
        VirtualKeyCodes.nine: "9",
        VirtualKeyCodes.a: "A",
        VirtualKeyCodes.b: "B",
        VirtualKeyCodes.c: "C",
        VirtualKeyCodes.d: "D",
        VirtualKeyCodes.e: "E",
        VirtualKeyCodes.f: "F",
        VirtualKeyCodes.g: "G",
        VirtualKeyCodes.h: "H",
        VirtualKeyCodes.i: "I",
        VirtualKeyCodes.j: "J",
        VirtualKeyCodes.k: "K",
        VirtualKeyCodes.l: "L",
        VirtualKeyCodes.m: "M",
        VirtualKeyCodes.n: "N",
        VirtualKeyCodes.o: "O",
        VirtualKeyCodes.p: "P",
        VirtualKeyCodes.q: "Q",
        VirtualKeyCodes.r: "R",
        VirtualKeyCodes.s: "S",
        VirtualKeyCodes.t: "T",
        VirtualKeyCodes.u: "U",
        VirtualKeyCodes.v: "V",
        VirtualKeyCodes.w: "W",
        VirtualKeyCodes.x: "X",
        VirtualKeyCodes.y: "Y",
        VirtualKeyCodes.z: "Z",
        VirtualKeyCodes.space: "Space",
        VirtualKeyCodes.returnKey: "↩",
        VirtualKeyCodes.enter: "⌤",
        VirtualKeyCodes.tab: "⇥",
        VirtualKeyCodes.delete: "⌫",
        VirtualKeyCodes.escape: "⎋",
        VirtualKeyCodes.f1: "F1",
        VirtualKeyCodes.f2: "F2",
        VirtualKeyCodes.f3: "F3",
        VirtualKeyCodes.f4: "F4",
        VirtualKeyCodes.f5: "F5",
        VirtualKeyCodes.f6: "F6",
        VirtualKeyCodes.f7: "F7",
        VirtualKeyCodes.f8: "F8",
        VirtualKeyCodes.f9: "F9",
        VirtualKeyCodes.f10: "F10",
        VirtualKeyCodes.f11: "F11",
        VirtualKeyCodes.f12: "F12",
    ]

    private static func keyCodeToSymbol(_ keyCode: Int) -> String? {
        keySymbols[keyCode]
    }
}

// MARK: - Erreurs d'enregistrement

/// Pourquoi un raccourci n'a pas pu être enregistré. Auparavant l'échec n'était
/// que journalisé : le raccourci restait affiché comme actif dans les réglages
/// alors qu'il ne faisait rien (cf. AUDIT_TECHNIQUE.md § R2-9).
enum HotkeyRegistrationError: Error, Equatable {
    case invalidKey
    case reservedBySystem
    /// Déjà affecté à un autre preset de HydroBar (index 0-based).
    case usedByPreset(Int)
    /// Déjà pris par une autre application.
    case alreadyInUse
    case failed(OSStatus)

    var localizedMessage: String {
        switch self {
        case .invalidKey:
            return String(localized: "This key can't be used as a shortcut.", comment: "Hotkey registration error")
        case .reservedBySystem:
            return String(localized: "This shortcut is reserved by macOS.", comment: "Hotkey registration error")
        case .usedByPreset(let index):
            return String(format: String(localized: "Already used by Preset %lld.", comment: "Hotkey registration error, %lld is a preset number"),
                          index + 1)
        case .alreadyInUse:
            return String(localized: "Already used by another app.", comment: "Hotkey registration error")
        case .failed:
            return String(localized: "This shortcut couldn't be registered.", comment: "Hotkey registration error")
        }
    }
}

// MARK: - GlobalHotkeyManager
class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private static let logger = Logger(subsystem: "com.adxcool.HydroBar", category: "hotkeys")

    private var registeredHotkeys: [UInt32: (presetIndex: Int, hotKeyRef: EventHotKeyRef?)] = [:]

    /// Raccourci actif de chaque preset, pour détecter les doublons et savoir
    /// si un raccourci sauvegardé est réellement enregistré auprès du système.
    private var activeShortcuts: [Int: Shortcut] = [:]
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
            Self.logger.error("Échec d'installation du gestionnaire de raccourcis: \(status)")
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
    /// Enregistre un raccourci global pour un preset.
    /// - Returns: `.failure` avec la raison, pour que l'interface puisse l'afficher.
    @discardableResult
    func registerShortcut(for presetIndex: Int, keyCode: Int, modifiers: Int) -> Result<Void, HotkeyRegistrationError> {
        unregisterShortcut(for: presetIndex)

        guard (0...127).contains(keyCode) else {
            return fail(.invalidKey, keyCode: keyCode, modifiers: modifiers)
        }
        if isSystemReservedShortcut(keyCode: keyCode, modifiers: modifiers) {
            return fail(.reservedBySystem, keyCode: keyCode, modifiers: modifiers)
        }
        // Deux presets sur la même combinaison : RegisterEventHotKey refuserait le
        // second, mais en le disant on peut nommer le preset en conflit.
        let candidate = Shortcut(keyCode: keyCode, modifiers: modifiers)
        if let owner = activeShortcuts.first(where: { $0.key != presetIndex && $0.value == candidate })?.key {
            return fail(.usedByPreset(owner), keyCode: keyCode, modifiers: modifiers)
        }

        let hotKeyID = nextHotKeyID
        nextHotKeyID += 1

        var hotKeyRef: EventHotKeyRef?
        let eventHotKeyID = EventHotKeyID(signature: FourCharCode(fromString: "HYDR"), id: hotKeyID)

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            convertToCarbonModifiers(modifiers),
            eventHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            let error: HotkeyRegistrationError = status == eventHotKeyExistsErr ? .alreadyInUse : .failed(status)
            return fail(error, keyCode: keyCode, modifiers: modifiers)
        }

        registeredHotkeys[hotKeyID] = (presetIndex: presetIndex, hotKeyRef: ref)
        activeShortcuts[presetIndex] = candidate
        return .success(())
    }

    /// Indique si le raccourci sauvegardé de ce preset est réellement actif.
    /// Un enregistrement peut échouer au lancement — une autre app a pris la
    /// combinaison entre-temps — sans que les réglages ne le sachent.
    func isRegistered(presetIndex: Int) -> Bool {
        activeShortcuts[presetIndex] != nil
    }

    private func fail(_ error: HotkeyRegistrationError, keyCode: Int, modifiers: Int) -> Result<Void, HotkeyRegistrationError> {
        Self.logger.notice("Raccourci refusé (touche \(keyCode), modificateurs \(modifiers)): \(String(describing: error), privacy: .public)")
        return .failure(error)
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
    
    /// Désenregistre un raccourci pour un preset
    func unregisterShortcut(for presetIndex: Int) {
        // Trouver toutes les entrées pour ce presetIndex
        let keysToRemove = registeredHotkeys.filter { $0.value.presetIndex == presetIndex }
        for (hotKeyID, (_, hotKeyRef)) in keysToRemove {
            if let ref = hotKeyRef {
                let status = UnregisterEventHotKey(ref)
                if status != noErr {
                    Self.logger.error("Échec du désenregistrement d'un raccourci: \(status)")
                }
            }
            registeredHotkeys.removeValue(forKey: hotKeyID)
        }
        activeShortcuts.removeValue(forKey: presetIndex)
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
    
    /// Retour sonore d'un ajout réussi. L'ancien `NSSound.beep()` jouait le son
    /// d'alerte du système — celui d'une erreur — à chaque succès.
    private func playFeedbackSound() {
        NSSound(named: "Pop")?.play()
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
