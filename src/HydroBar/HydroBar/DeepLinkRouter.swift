//
//  DeepLinkRouter.swift
//  HydroBar
//
//  Exécution des deep links `hydrobar://` : limitation de débit, confirmation des
//  actions destructives, callbacks x-callback-url, journal des actions.
//  Voir docs/specs/DEEP_LINKS.md.
//

import Foundation
import AppKit
import Combine
import UserNotifications
import os

// MARK: - Présentation

/// Implémenté par l'AppDelegate : le routeur n'a pas à connaître le popover.
protocol DeepLinkPresenting: AnyObject {
    func presentPopover(showing view: ViewType)
}

/// Vue demandée par un deep link `hydrobar://open/...`, observée par `MainView`.
final class AppNavigation: ObservableObject {
    static let shared = AppNavigation()

    struct Request: Equatable {
        let view: ViewType
        /// Incrémenté à chaque demande pour que deux demandes successives de la même
        /// vue soient bien distinguées par SwiftUI.
        let token: Int
    }

    @Published private(set) var pendingRequest: Request?
    private var token = 0
    private init() {}

    func requestView(_ view: ViewType) {
        token += 1
        pendingRequest = Request(view: view, token: token)
    }
}

// MARK: - Journal

struct DeepLinkLogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let url: String
    let outcome: String
}

// MARK: - Routeur

final class DeepLinkRouter: ObservableObject {

    static let shared = DeepLinkRouter()

    private static let logger = Logger(subsystem: "com.adxcool.HydroBar", category: "deeplink")

    /// 50 dernières actions, consultables en mode debug. Sans ça, un ajout
    /// inexpliqué est indébuggable.
    @Published private(set) var log: [DeepLinkLogEntry] = []
    private static let maxLogEntries = 50

    weak var presenter: DeepLinkPresenting?

    private let manager: HydrationManager

    /// Les URLs reçues avant la fin du lancement sont mises en attente : l'app peut
    /// être démarrée *par* une URL, avant que la barre de menu n'existe.
    private var isReady = false
    private var pendingURLs: [URL] = []

    /// Fenêtre glissante de limitation de débit, appliquée à toutes les actions —
    /// `open` incluse, sinon une page web peut faire clignoter l'app indéfiniment.
    private var recentCalls: [Date] = []
    private static let maxCallsPerSecond = 10

    /// Schémas de callback refusés. `hydrobar` est bloqué pour empêcher une boucle
    /// où une URL se rappelle elle-même.
    private static let blockedCallbackSchemes: Set<String> = [
        "file", "javascript", "data", "about", "hydrobar",
    ]

    init(manager: HydrationManager = .shared) {
        self.manager = manager
    }

    // MARK: Cycle de vie

    /// Appelé en fin de `applicationDidFinishLaunching` : vide la file d'attente.
    func markReady() {
        isReady = true
        let queued = pendingURLs
        pendingURLs.removeAll()
        queued.forEach(handle)
    }

    // MARK: Point d'entrée

    func handle(_ url: URL) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.handle(url) }
            return
        }
        guard isReady else {
            pendingURLs.append(url)
            return
        }

        do {
            let action = try DeepLinkParser.parse(url)
            try checkRateLimit()
            let added = try execute(action)
            record(url, outcome: "ok")
            succeed(url: url, added: added)
        } catch let error as DeepLinkError {
            record(url, outcome: error.rawValue)
            fail(url: url, error: error)
        } catch {
            record(url, outcome: "unexpected")
            Self.logger.error("Deep link inattendu: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Exécution

    /// - Returns: la quantité ajoutée en ml, pour le callback de succès.
    private func execute(_ action: DeepLinkAction) throws -> Double {
        switch action {
        case .add(let ml):
            manager.addWater(amount: ml)
            return ml

        case .addPreset(let index):
            let presets = manager.presetsMl
            guard index < presets.count else { throw DeepLinkError.presetOutOfRange }
            manager.addWater(amount: presets[index])
            return presets[index]

        case .undo:
            guard manager.undo() else { throw DeepLinkError.nothingToUndo }
            return 0

        case .setGoal(let ml):
            try confirmIfNeeded(
                title: String(localized: "Change your daily goal?",
                              comment: "Deep link confirmation title"),
                message: String(format: String(localized: "A deep link is asking to set your daily goal to %@.",
                                               comment: "Deep link confirmation message for goal"),
                                manager.displayValue(for: ml))
            )
            manager.targetMl = ml
            return 0

        case .reset:
            try confirmIfNeeded(
                title: String(localized: "Reset today's intake?",
                              comment: "Deep link confirmation title"),
                message: String(localized: "A deep link is asking to reset today's intake to zero. This cannot be undone.",
                                comment: "Deep link confirmation message for reset")
            )
            manager.resetDay()
            return 0

        case .open(let view):
            presenter?.presentPopover(showing: view)
            return 0
        }
    }

    // MARK: Garde-fous

    private func checkRateLimit() throws {
        let now = Date()
        recentCalls.removeAll { now.timeIntervalSince($0) > 1.0 }
        guard recentCalls.count < Self.maxCallsPerSecond else {
            throw DeepLinkError.rateLimited
        }
        recentCalls.append(now)
    }

    /// `confirm=1` est déjà exigé par le parseur ; cette alerte est le second verrou.
    /// Elle peut être désactivée explicitement par l'utilisateur dans les réglages.
    private func confirmIfNeeded(title: String, message: String) throws {
        guard !manager.allowDestructiveDeepLinks else { return }

        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Continue", comment: "Confirmation button"))
        alert.addButton(withTitle: String(localized: "Cancel", comment: "Cancel button"))
        guard alert.runModal() == .alertFirstButtonReturn else {
            throw DeepLinkError.userCancelled
        }
    }

    // MARK: Retour utilisateur

    private func succeed(url: URL, added: Double) {
        if !isSilent(url) {
            NSSound(named: "Pop")?.play()
        }
        guard let callback = callbackURL(in: url, key: "x-success") else { return }
        let target = manager.targetMl
        NSWorkspace.shared.open(callback.appending([
            "currentMl": String(format: "%.0f", manager.currentMl),
            "targetMl": String(format: "%.0f", target),
            "percent": target > 0 ? String(Int((manager.currentMl / target) * 100)) : "0",
            "added": String(format: "%.0f", added),
        ]))
    }

    private func fail(url: URL, error: DeepLinkError) {
        Self.logger.error("Deep link rejeté (\(error.rawValue, privacy: .public)): \(url.absoluteString, privacy: .public)")

        if let callback = callbackURL(in: url, key: "x-error") {
            NSWorkspace.shared.open(callback.appending([
                "errorCode": error.rawValue,
                "errorMessage": error.localizedMessage,
            ]))
            return
        }

        // Pas de callback : l'erreur reste visible via une notification locale
        // (au mieux — elle dépend de l'autorisation) et toujours dans le journal.
        // `userCancelled` : l'utilisateur vient de refuser, il sait déjà.
        // `rateLimited` : notifier 10 fois par seconde serait la nuisance qu'on évite.
        guard error != .userCancelled, error != .rateLimited, !isSilent(url) else { return }
        notifyFailure(error)
    }

    private func notifyFailure(_ error: DeepLinkError) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "HydroBar link ignored", comment: "Deep link failure notification title")
        content.body = error.localizedMessage
        let request = UNNotificationRequest(
            identifier: "DEEPLINK_ERROR_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Callbacks

    private func isSilent(_ url: URL) -> Bool {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.lowercased() == "silent" })?
            .value == "1"
    }

    /// Un callback est fourni par l'appelant, donc potentiellement hostile :
    /// on refuse les schémas qui feraient de HydroBar un intermédiaire complaisant.
    private func callbackURL(in url: URL, key: String) -> URL? {
        guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name.lowercased() == key })?
                .value,
              let callback = URL(string: raw),
              let scheme = callback.scheme?.lowercased(),
              !Self.blockedCallbackSchemes.contains(scheme)
        else { return nil }
        return callback
    }

    // MARK: Journal

    private func record(_ url: URL, outcome: String) {
        log.append(DeepLinkLogEntry(date: Date(), url: url.absoluteString, outcome: outcome))
        if log.count > Self.maxLogEntries { log.removeFirst() }
    }
}

// MARK: - Helper

private extension URL {
    /// Ajoute des paramètres à l'URL en conservant ceux déjà présents.
    func appending(_ parameters: [String: String]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        var items = components.queryItems ?? []
        items.append(contentsOf: parameters.map { URLQueryItem(name: $0.key, value: $0.value) })
        components.queryItems = items
        return components.url ?? self
    }
}
