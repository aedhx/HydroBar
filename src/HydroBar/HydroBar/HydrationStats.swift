//
//  HydrationStats.swift
//  HydroBar
//
//  Calculs des statistiques, sans état : l'historique, la journée en cours et
//  le calendrier sont passés en paramètres. Ils vivaient dans HydrationManager,
//  qui lit Date(), UserDefaults et le disque en dur — donc impossibles à tester
//  (cf. AUDIT_TECHNIQUE.md § P3-1).
//

import Foundation

enum HydrationStats {

    /// Journée en cours. Elle fait foi plutôt que l'entrée d'historique du jour,
    /// dont l'écriture est différée et peut avoir un temps de retard.
    struct Today {
        let date: Date
        let amountMl: Double
        let targetMl: Double
    }

    /// Total des `days` derniers jours, aujourd'hui inclus. Un jour absent de
    /// l'historique compte pour zéro.
    static func total(lastDays days: Int,
                      history: [HistoryEntry],
                      today: Today,
                      calendar: Calendar = .current) -> Double {
        guard days > 0 else { return 0 }
        let start = calendar.startOfDay(for: today.date)
        var total = today.amountMl
        for offset in 1..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { continue }
            total += entry(on: day, in: history, calendar: calendar)?.amountMl ?? 0
        }
        return total
    }

    /// Jours consécutifs où l'objectif a été atteint, en remontant depuis hier.
    /// Aujourd'hui s'y ajoute dès que l'objectif du jour est atteint.
    ///
    /// L'ancienne version renvoyait 0 dès le premier verre du matin : un jour
    /// commencé mais pas encore terminé cassait la série. Il ne la casse plus
    /// tant qu'il n'est pas fini.
    static func streak(history: [HistoryEntry],
                       today: Today,
                       calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: today.date)
        var streak = (today.targetMl > 0 && today.amountMl >= today.targetMl) ? 1 : 0

        var day = start
        while let previous = calendar.date(byAdding: .day, value: -1, to: day),
              let entry = entry(on: previous, in: history, calendar: calendar),
              entry.targetMl > 0,
              entry.amountMl >= entry.targetMl {
            streak += 1
            day = previous
        }
        return streak
    }

    private static func entry(on day: Date, in history: [HistoryEntry], calendar: Calendar) -> HistoryEntry? {
        history.first { calendar.isDate($0.date, inSameDayAs: day) }
    }
}
