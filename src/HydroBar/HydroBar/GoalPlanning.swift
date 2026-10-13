//
//  GoalPlanning.swift
//  HydroBar
//
//  Objectif par jour de la semaine, et preset suggéré à partir des habitudes.
//  Pur : ni Date(), ni UserDefaults.
//

import Foundation

// MARK: - Objectif par jour de la semaine

/// Un objectif plus haut les jours de sport, plus bas le week-end. Les jours
/// sans surcharge prennent l'objectif par défaut.
struct WeekdayGoals: Codable, Equatable {
    /// Clé : composant `.weekday` du calendrier (1 = dimanche … 7 = samedi).
    var overrides: [Int: Double] = [:]

    func goal(on date: Date, calendar: Calendar, default fallback: Double) -> Double {
        overrides[calendar.component(.weekday, from: date)] ?? fallback
    }

    static func decode(_ raw: String) -> WeekdayGoals {
        guard let data = raw.data(using: .utf8),
              let goals = try? JSONDecoder().decode(WeekdayGoals.self, from: data)
        else { return WeekdayGoals() }
        return goals
    }

    func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Preset suggéré

enum PresetSuggestion {
    /// Une quantité doit revenir au moins autant de fois sur 30 jours.
    static let minimumOccurrences = 5

    /// Quantité saisie souvent (arrondie à 10 ml) qui ne correspond à aucun
    /// preset, et le preset le moins utilisé qu'elle pourrait remplacer.
    ///
    /// Les totaux repris de la v1 sont ignorés : ce ne sont pas des prises.
    static func suggest(events: [IntakeEvent],
                        presets: [Double],
                        now: Date,
                        dismissed: Set<Double> = [],
                        calendar: Calendar = .current) -> (amountMl: Double, replacingIndex: Int)? {
        guard !presets.isEmpty,
              let windowStart = calendar.date(byAdding: .day, value: -30, to: now)
        else { return nil }

        let recent = events.filter { !$0.isAggregate && $0.date >= windowStart && $0.date <= now }
        var counts: [Double: Int] = [:]
        for event in recent {
            counts[(event.amountMl / 10).rounded() * 10, default: 0] += 1
        }

        func matchesPreset(_ amount: Double) -> Bool {
            presets.contains { abs($0 - amount) <= max($0 * 0.05, 5) }
        }

        guard let best = counts
            .filter({ !matchesPreset($0.key) && !dismissed.contains($0.key) })
            .max(by: { ($0.value, $0.key) < ($1.value, $1.key) }),
              best.value >= minimumOccurrences
        else { return nil }
        let amount = best.key, count = best.value

        // Le preset le moins utilisé ; à égalité, le dernier.
        let usage = presets.map { preset in
            recent.filter { abs($0.amountMl - preset) <= max(preset * 0.05, 5) }.count
        }
        guard let fewest = usage.min(),
              let replacing = usage.lastIndex(of: fewest),
              fewest < count
        else { return nil }
        return (amount, replacing)
    }
}
