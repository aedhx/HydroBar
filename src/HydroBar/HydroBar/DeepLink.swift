//
//  DeepLink.swift
//  HydroBar
//
//  Grammaire et parsing du schéma d'URL `hydrobar://`.
//  Voir docs/specs/DEEP_LINKS.md pour la spécification complète.
//
//  Ce fichier ne contient QUE de la logique pure : pas de UserDefaults, pas de
//  FileManager, pas d'UI. C'est ce qui le rend testable sans lancer l'app.
//

import Foundation

// MARK: - Bornes de validation

/// Bornes partagées par les deep links ET par la saisie dans les réglages.
/// Une seule définition, sinon les deux chemins divergent avec le temps.
enum HydrationLimits {
    /// Objectif quotidien autorisé, en ml.
    static let goal: ClosedRange<Double> = 200...10_000
    /// Quantité autorisée pour un ajout unique, en ml.
    static let single: ClosedRange<Double> = 1...5_000
    /// Garde-fou sur l'index de preset accepté par le parseur.
    /// La borne réelle dépend des presets de l'utilisateur : c'est le routeur qui la vérifie.
    static let maxPresetIndex = 99
}

// MARK: - Actions

enum DeepLinkAction: Equatable {
    case add(ml: Double)
    /// Index 0-based en interne, quelle que soit la forme d'URL utilisée.
    case addPreset(index: Int)
    case undo
    case setGoal(ml: Double)
    case reset
    case open(ViewType)
}

// MARK: - Erreurs

enum DeepLinkError: String, Error, Equatable {
    case unknownAction
    case invalidAmount
    case ambiguousUnit
    case presetOutOfRange
    case confirmationRequired
    case userCancelled
    case rateLimited
    case nothingToUndo

    /// Message court, localisé, destiné à l'utilisateur ou au paramètre `x-error`.
    var localizedMessage: String {
        switch self {
        case .unknownAction:
            return String(localized: "Unknown HydroBar action.", comment: "Deep link error")
        case .invalidAmount:
            return String(localized: "Invalid or out-of-range amount.", comment: "Deep link error")
        case .ambiguousUnit:
            return String(localized: "Several units provided at once.", comment: "Deep link error")
        case .presetOutOfRange:
            return String(localized: "This preset does not exist.", comment: "Deep link error")
        case .confirmationRequired:
            return String(localized: "This action requires confirm=1.", comment: "Deep link error")
        case .userCancelled:
            return String(localized: "Action cancelled.", comment: "Deep link error")
        case .rateLimited:
            return String(localized: "Too many requests, slow down.", comment: "Deep link error")
        case .nothingToUndo:
            return String(localized: "Nothing to undo.", comment: "Deep link error")
        }
    }
}

// MARK: - Parseur

enum DeepLinkParser {

    static let scheme = "hydrobar"

    /// Unités acceptées en paramètre de requête, et leur conversion vers les ml.
    /// S'appuie sur `AppUnit` pour que les deep links et l'UI convertissent à l'identique.
    private static let unitKeys: [String: (Double) -> Double] = [
        "ml": { $0 },
        "cl": { AppUnit.cl.toMl($0) },
        "l":  { AppUnit.liter.toMl($0) },
        "oz": { AppUnit.oz.toMl($0) },
    ]

    /// Transforme une URL en action. Fonction pure : aucun effet de bord.
    static func parse(_ url: URL) throws -> DeepLinkAction {
        guard url.scheme?.lowercased() == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { throw DeepLinkError.unknownAction }

        let action = (components.host ?? "").lowercased()
        let segments = components.path.split(separator: "/").map(String.init)
        let query = queryItems(components)

        switch action {
        case "add":
            return try parseAdd(segments: segments, query: query)

        case "undo":
            return .undo

        case "set-goal", "setgoal":
            try requireConfirmation(query)
            return .setGoal(ml: try amount(from: query, within: HydrationLimits.goal))

        case "reset":
            try requireConfirmation(query)
            return .reset

        case "open":
            return .open(try parseTarget(segments))

        default:
            throw DeepLinkError.unknownAction
        }
    }

    // MARK: Sous-parseurs

    private static func parseAdd(segments: [String],
                                 query: [String: String]) throws -> DeepLinkAction {
        let hasUnit = unitKeys.keys.contains { query[$0] != nil }

        // Forme chemin : hydrobar://add/preset/0 — index 0-based (compatibilité Raycast).
        if segments.count == 2, segments[0].lowercased() == "preset" {
            guard !hasUnit, query["preset"] == nil else { throw DeepLinkError.ambiguousUnit }
            return .addPreset(index: try presetIndex(segments[1], oneBased: false))
        }
        if !segments.isEmpty { throw DeepLinkError.unknownAction }

        // Forme requête : hydrobar://add?preset=1 — index 1-based, aligné sur l'UI.
        if let raw = query["preset"] {
            guard !hasUnit else { throw DeepLinkError.ambiguousUnit }
            return .addPreset(index: try presetIndex(raw, oneBased: true))
        }

        return .add(ml: try amount(from: query, within: HydrationLimits.single))
    }

    private static func parseTarget(_ segments: [String]) throws -> ViewType {
        switch segments.map({ $0.lowercased() }) {
        case []:             return .main
        case ["today"]:      return .main
        case ["stats"]:      return .statistics
        case ["statistics"]: return .statistics
        case ["settings"]:   return .settings
        default:             throw DeepLinkError.unknownAction
        }
    }

    // MARK: Helpers

    /// Extrait la quantité en ml. Exactement une unité doit être fournie : sur une action
    /// qui modifie des données, on refuse d'interpréter « au mieux ».
    private static func amount(from query: [String: String],
                               within range: ClosedRange<Double>) throws -> Double {
        let provided = unitKeys.keys.filter { query[$0] != nil }
        guard !provided.isEmpty else { throw DeepLinkError.invalidAmount }
        guard provided.count == 1, let key = provided.first else { throw DeepLinkError.ambiguousUnit }

        guard let convert = unitKeys[key],
              let raw = query[key],
              let value = Double(raw),
              value.isFinite                       // rejette inf / nan
        else { throw DeepLinkError.invalidAmount }

        let ml = convert(value)
        guard ml.isFinite, range.contains(ml) else { throw DeepLinkError.invalidAmount }
        return ml
    }

    private static func presetIndex(_ raw: String, oneBased: Bool) throws -> Int {
        guard let parsed = Int(raw) else { throw DeepLinkError.presetOutOfRange }
        let index = oneBased ? parsed - 1 : parsed
        guard index >= 0, index <= HydrationLimits.maxPresetIndex else {
            throw DeepLinkError.presetOutOfRange
        }
        return index
    }

    /// `reset` et `set-goal` ne s'exécutent jamais sur une URL nue : n'importe quelle page
    /// web peut déclencher un schéma d'URL. Voir docs/specs/DEEP_LINKS.md § 4.1.
    private static func requireConfirmation(_ query: [String: String]) throws {
        guard query["confirm"] == "1" else { throw DeepLinkError.confirmationRequired }
    }

    private static func queryItems(_ components: URLComponents) -> [String: String] {
        var result: [String: String] = [:]
        for item in components.queryItems ?? [] {
            // Première occurrence gagnante : un doublon ne doit pas pouvoir écraser la valeur.
            let key = item.name.lowercased()
            if result[key] == nil { result[key] = item.value }
        }
        return result
    }
}
