//
//  FocusModeMonitor.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//
//  Surveille le mode de concentration de macOS pour mettre les rappels en pause.
//
//  ⚠️ Trois conditions sont nécessaires pour lire le statut de concentration, et
//  l'absence de l'une d'elles se traduit par un `isFocused` à `nil` — donc par un
//  échec silencieux. Cette classe les rend visibles plutôt que de les subir :
//
//  1. La capability **Communication Notifications** sur la cible HydroBar.
//     À activer dans Xcode → cible HydroBar → Signing & Capabilities → « + » →
//     Communication Notifications. Xcode écrit lui-même l'entitlement associé ;
//     le deviner à la main est le moyen sûr de casser la signature. Demande un
//     compte développeur payant, car la capability se provisionne côté App ID.
//  2. La clé `NSFocusStatusUsageDescription` dans Info.plist — présente.
//  3. L'autorisation explicite de l'utilisateur via `requestAuthorization`.
//
//  Si 1 manque alors que 3 est accordée, `availability` passe à `.unavailable` et
//  les réglages l'affichent.
//

import Foundation
import Intents
import Combine
import AppKit
import os

final class FocusModeMonitor: ObservableObject {

    static let shared = FocusModeMonitor()

    private static let logger = Logger(subsystem: "com.adxcool.HydroBar", category: "focus-mode")

    /// Ce que le système nous laisse réellement faire.
    enum Availability: Equatable {
        /// Autorisation jamais demandée.
        case notRequested
        /// Autorisée et le statut est lisible.
        case authorized
        /// L'utilisateur a refusé, ou le système l'interdit.
        case denied
        /// Autorisée, mais le statut reste `nil` : signature d'une capability
        /// Communication Notifications absente de la cible.
        case unavailable
    }

    @Published private(set) var isAutoSyncEnabled: Bool = false
    @Published private(set) var availability: Availability = .notRequested

    private var checkTimer: Timer?
    private weak var hydrationManager: HydrationManager?

    private init() {}

    // MARK: - Cycle de vie

    func startMonitoring(manager: HydrationManager) {
        self.hydrationManager = manager
        availability = Self.availability(for: INFocusStatusCenter.default.authorizationStatus)
        startPeriodicCheck()
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Autorisation

    /// Demande l'autorisation puis active la synchronisation seulement si elle est
    /// accordée. L'ancien code activait le réglage sans rien demander : l'interrupteur
    /// restait allumé alors que la fonctionnalité ne pouvait pas marcher.
    func enableAutoSync(completion: ((Bool) -> Void)? = nil) {
        INFocusStatusCenter.default.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.availability = Self.availability(for: status)

                guard status == .authorized else {
                    Self.logger.notice("Autorisation Focus refusée (\(String(describing: status), privacy: .public))")
                    // Ne pas persister un réglage que le système empêche d'honorer.
                    self.hydrationManager?.focusModeAutoSync = false
                    completion?(false)
                    return
                }

                self.hydrationManager?.focusModeAutoSync = true
                completion?(true)
            }
        }
    }

    func disableAutoSync() {
        hydrationManager?.focusModeAutoSync = false
    }

    /// Ouvre Réglages Système → Confidentialité et sécurité, où se trouve l'entrée
    /// « Concentration ». On vise le panneau racine plutôt qu'une ancre précise :
    /// une ancre inexistante ouvrirait silencieusement le mauvais panneau.
    func openFocusPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func availability(for status: INFocusStatusAuthorizationStatus) -> Availability {
        switch status {
        case .authorized:    return .authorized
        case .denied:        return .denied
        case .restricted:    return .denied
        case .notDetermined: return .notRequested
        @unknown default:    return .notRequested
        }
    }

    // MARK: - Synchronisation

    /// Appelé par `HydrationManager.focusModeAutoSync.didSet` pour refléter l'état
    /// persisté, y compris au lancement.
    func setAutoSync(_ enabled: Bool) {
        isAutoSyncEnabled = enabled
        if enabled { checkFocusStatus() }
    }

    func checkFocusStatus() {
        guard isAutoSyncEnabled, let manager = hydrationManager else { return }

        let status = INFocusStatusCenter.default.authorizationStatus
        availability = Self.availability(for: status)
        guard status == .authorized else { return }

        guard let isFocused = INFocusStatusCenter.default.focusStatus.isFocused else {
            // Autorisé mais illisible : la capability manque sur la cible.
            // C'est exactement le cas qui échouait en silence avant.
            availability = .unavailable
            Self.logger.error("Statut Focus nil malgré l'autorisation — capability Communication Notifications absente ?")
            return
        }

        guard manager.doNotDisturb != isFocused else { return }

        // Couper temporairement la synchro pour éviter la cascade de didSet.
        // Contournement fragile, conservé tel quel : le corriger proprement est
        // l'objet de P1-7 (séparer intention utilisateur et état effectif).
        let wasAutoSync = manager.focusModeAutoSync
        manager.focusModeAutoSync = false
        manager.doNotDisturb = isFocused
        manager.focusModeAutoSync = wasAutoSync

        if manager.notificationsEnabled {
            manager.scheduleNotifications()
            manager.checkReminderStatus()
        }
    }

    private func startPeriodicCheck() {
        // INFocusStatusCenter n'émet pas de notification de changement : il faut
        // interroger. 30 s est un compromis entre réactivité et réveils inutiles.
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkFocusStatus()
        }
        checkTimer?.tolerance = 5.0
        if let checkTimer {
            RunLoop.current.add(checkTimer, forMode: .common)
        }
        checkFocusStatus()
    }
}
