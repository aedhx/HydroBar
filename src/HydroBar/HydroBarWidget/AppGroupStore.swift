// AppGroupStore.swift
// Target Membership: HydroBar (main app) AND HydroBarWidget (widget extension)
// Foundation only — no AppKit, no SwiftUI, no HydrationManager

import Foundation

// MARK: - Unités

/// Unité d'affichage. Le stockage interne est **toujours** en millilitres ;
/// l'unité ne concerne que l'affichage et la saisie.
///
/// Définie ici, dans le seul fichier compilé à la fois par l'app et par le widget,
/// pour qu'il n'existe qu'**une** conversion et **un** formatage. Avant, quatre
/// implémentations coexistaient et divergeaient : l'once valait 29,57 ml dans
/// l'app et 29,5735 ml dans le widget, les litres n'avaient pas le même nombre de
/// décimales, les statistiques ignoraient l'unité choisie au-delà d'un litre, et
/// aucune ne respectait le séparateur décimal de la locale.
enum AppUnit: String, CaseIterable, Codable {
    case ml = "ml"
    case cl = "cl"
    case liter = "L"
    /// Once liquide US. La valeur brute `"oz"` est conservée telle quelle pour que
    /// les préférences déjà enregistrées restent valides.
    case oz = "oz"
    /// Once liquide britannique, environ 4 % plus petite que l'once US.
    case ozUK = "oz UK"

    /// Millilitres par unité — valeurs exactes par définition légale.
    var millilitersPerUnit: Double {
        switch self {
        case .ml:    return 1
        case .cl:    return 10
        case .liter: return 1000
        case .oz:    return 29.5735295625
        case .ozUK:  return 28.4130625
        }
    }

    func toMl(_ value: Double) -> Double {
        value * millilitersPerUnit
    }

    func fromMl(_ ml: Double) -> Double {
        ml / millilitersPerUnit
    }

    /// Suffixe affiché après une quantité. Les deux onces partagent « oz » :
    /// l'utilisateur a choisi la sienne, seul le sélecteur a besoin de les distinguer.
    var symbol: String {
        switch self {
        case .ml:         return "ml"
        case .cl:         return "cl"
        case .liter:      return "L"
        case .oz, .ozUK:  return "oz"
        }
    }

    /// Libellé du sélecteur d'unité dans les réglages.
    var pickerLabel: String {
        switch self {
        case .ml:    return "ml"
        case .cl:    return "cl"
        case .liter: return "L"
        case .oz:    return "US oz"
        case .ozUK:  return "UK oz"
        }
    }

    private func fractionDigits(for value: Double) -> ClosedRange<Int> {
        switch self {
        case .ml:         return 0...0
        case .cl:         return 0...1
        case .liter:      return value < 1 ? 0...2 : 0...1
        case .oz, .ozUK:  return 0...1
        }
    }

    /// Nombre seul, formaté selon la locale (« 1,5 » en français, « 1.5 » en anglais).
    func formattedNumber(ml: Double, locale: Locale = .current) -> String {
        let value = fromMl(ml)
        return value.formatted(
            .number
                .precision(.fractionLength(fractionDigits(for: value)))
                .locale(locale)
        )
    }

    /// Quantité avec son unité : « 25 cl », « 1,5 L », « 8.5 oz ».
    func format(ml: Double, locale: Locale = .current) -> String {
        "\(formattedNumber(ml: ml, locale: locale)) \(symbol)"
    }
}

// MARK: - Shared Snapshot Structs
// These are minimal Codable value types — no dependency on HydrationManager or AppKit.
// The widget reads these; HydrationManager writes them.

struct HydrationSnapshot: Codable {
    let currentMl: Double
    let targetMl: Double
    let unit: String          // AppUnit.rawValue — String pour rester décodable par les anciens snapshots
    let lastUpdated: Date
    let weekHistory: [HistoryEntrySnapshot]

    var progress: Double { min(currentMl / max(targetMl, 1.0), 1.0) }
    var rawProgress: Double { currentMl / max(targetMl, 1.0) }

    // Placeholder for widget gallery preview
    static let placeholder = HydrationSnapshot(
        currentMl: 1200,
        targetMl: 2000,
        unit: "cl",
        lastUpdated: Date(),
        weekHistory: []
    )
}

struct HistoryEntrySnapshot: Codable {
    let date: Date
    let amountMl: Double
    let targetMl: Double
    var isComplete: Bool { amountMl >= targetMl }
}

// MARK: - App Group Store

struct AppGroupStore {
    static let suiteName = "group.com.adxcool.HydroBar"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Keys
    private enum Key {
        static let snapshot = "widget_snapshot_v1"
        static let pendingDelta = "widget_pending_delta_ml"
    }

    // MARK: - Write (called by main app only)
    /// Atomically writes the complete hydration snapshot to the shared container.
    /// Called from HydrationManager.syncToAppGroup() after every state mutation.
    static func write(_ snapshot: HydrationSnapshot) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(encoded, forKey: Key.snapshot)
    }

    // MARK: - Pending Delta (widget → main app sync)

    /// Accumulates ml added via widget buttons. Main app consumes and clears on next activation.
    static func addPendingDelta(_ ml: Double) {
        let current = defaults.double(forKey: Key.pendingDelta)
        defaults.set(current + ml, forKey: Key.pendingDelta)
    }

    /// Returns accumulated pending ml and clears the value atomically.
    static func consumePendingDelta() -> Double {
        let delta = defaults.double(forKey: Key.pendingDelta)
        if delta != 0 { defaults.removeObject(forKey: Key.pendingDelta) }
        return delta
    }

    // MARK: - Read (called by widget TimelineProvider)
    /// Returns the latest snapshot written by the main app.
    /// Returns HydrationSnapshot.placeholder if no data has been written yet.
    static func read() -> HydrationSnapshot {
        guard let data = defaults.data(forKey: Key.snapshot),
              let snapshot = try? JSONDecoder().decode(HydrationSnapshot.self, from: data)
        else {
            return .placeholder
        }
        return snapshot
    }
}
