//
//  FocusModeMonitor.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import Foundation
import Intents
import Combine

/// Gestionnaire pour surveiller et synchroniser le Focus Mode de macOS
class FocusModeMonitor: ObservableObject {
    static let shared = FocusModeMonitor()
    
    private var focusStatusObserver: NSObjectProtocol?
    private var checkTimer: Timer?
    private weak var hydrationManager: HydrationManager?
    
    /// Indique si la synchronisation automatique est activée
    @Published var isAutoSyncEnabled: Bool = false
    
    private init() {}
    
    /// Démarre la surveillance du Focus Mode
    func startMonitoring(manager: HydrationManager) {
        self.hydrationManager = manager
        
        // Vérifier si INFocusStatusCenter est disponible (macOS 12+)
        if #available(macOS 12.0, *) {
            setupFocusStatusObserver()
            startPeriodicCheck()
        } else {
            // macOS < 12 : pas de Focus Mode, utiliser le toggle manuel
            print("Focus Mode non disponible sur cette version de macOS")
        }
    }
    
    /// Arrête la surveillance
    func stopMonitoring() {
        if let observer = focusStatusObserver {
            NotificationCenter.default.removeObserver(observer)
            focusStatusObserver = nil
        }
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    /// Active ou désactive la synchronisation automatique
    func setAutoSync(_ enabled: Bool) {
        isAutoSyncEnabled = enabled
        
        if enabled {
            // Vérifier immédiatement l'état
            checkFocusStatus()
        }
    }
    
    /// Vérifie l'état actuel du Focus Mode et synchronise si nécessaire
    @available(macOS 12.0, *)
    func checkFocusStatus() {
        guard isAutoSyncEnabled else { return }
        
        let focusStatusCenter = INFocusStatusCenter.default
        
        // Accéder directement à la propriété focusStatus (synchrone)
        let focusStatus = focusStatusCenter.focusStatus
        
        // isFocused peut être nil si le statut n'est pas disponible
        guard let isFocused = focusStatus.isFocused else {
            // Si le statut n'est pas disponible, on ne peut pas synchroniser
            return
        }
        
        // Synchroniser avec le manager
        guard let manager = self.hydrationManager else { return }
        
        // Ne mettre à jour que si différent pour éviter les boucles infinies
        if manager.doNotDisturb != isFocused {
            // Mettre à jour en désactivant temporairement la sync pour éviter la boucle
            let wasAutoSync = manager.focusModeAutoSync
            manager.focusModeAutoSync = false
            
            // Mettre à jour la valeur doNotDisturb (cela déclenchera didSet)
            manager.doNotDisturb = isFocused
            
            // Réactiver la sync
            manager.focusModeAutoSync = wasAutoSync
            
            // Forcer la mise à jour des notifications et du badge
            // IMPORTANT: Ne jamais désactiver notificationsEnabled ici
            if manager.notificationsEnabled {
                manager.scheduleNotifications()
                manager.checkReminderStatus()
            }
        }
    }
    
    @available(macOS 12.0, *)
    private func setupFocusStatusObserver() {
        // Observer les changements de focus status
        // Note: INFocusStatusCenter n'a pas de notifications directes,
        // donc on utilise un timer pour vérifier périodiquement
    }
    
    private func startPeriodicCheck() {
        // Vérifier toutes les 30 secondes si le Focus Mode a changé
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            if #available(macOS 12.0, *) {
                self?.checkFocusStatus()
            }
        }
        
        RunLoop.current.add(checkTimer!, forMode: .common)
        
        // Vérifier immédiatement
        if #available(macOS 12.0, *) {
            checkFocusStatus()
        }
    }
}

