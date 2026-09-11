//
//  LaunchAtLogin.swift
//  HydroBar
//
//  Lancement automatique à l'ouverture de session, via SMAppService (macOS 13+).
//

import Foundation
import Combine
import ServiceManagement
import os

/// Encapsule `SMAppService.mainApp`.
///
/// L'état ne vit pas dans UserDefaults : la source de vérité est le système, et
/// l'utilisateur peut le changer à tout moment dans Réglages Système → Ouverture.
/// On relit donc le statut réel plutôt que de mémoriser une préférence qui
/// pourrait mentir.
final class LaunchAtLoginManager: ObservableObject {

    static let shared = LaunchAtLoginManager()

    private static let logger = Logger(subsystem: "com.adxcool.HydroBar", category: "launch-at-login")

    @Published private(set) var status: SMAppService.Status

    /// Dernière erreur d'enregistrement, à afficher dans les réglages.
    /// Un échec silencieux serait le pire des cas : l'utilisateur croirait l'option active.
    @Published private(set) var failureMessage: String?

    private init() {
        status = SMAppService.mainApp.status
    }

    var isEnabled: Bool { status == .enabled }

    /// macOS 13+ : l'utilisateur doit valider l'élément d'ouverture dans Réglages Système.
    /// Tant qu'il ne l'a pas fait, l'app est enregistrée mais ne démarrera pas.
    var needsApproval: Bool { status == .requiresApproval }

    /// Relit l'état réel du système. À appeler à l'ouverture des réglages.
    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        failureMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Cas courants : app lancée depuis DerivedData plutôt que /Applications,
            // ou signature absente. Le message système est plus précis que tout ce
            // qu'on pourrait inventer ici.
            Self.logger.error("register/unregister a échoué: \(error.localizedDescription, privacy: .public)")
            failureMessage = error.localizedDescription
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
