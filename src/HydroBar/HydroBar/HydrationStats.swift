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

    // MARK: - Par heure (rendu possible par le journal, F5)

    /// Quantité moyenne bue à chaque heure (24 valeurs), sur les `days` jours
    /// complets qui précèdent `today`.
    ///
    /// La moyenne se fait sur les jours où au moins une prise a été notée :
    /// un jour sans l'app (vacances, Mac éteint) ne doit pas faire croire que
    /// l'on boit moins à toutes les heures. Les totaux repris de la v1, sans
    /// heure réelle, sont ignorés.
    static func hourlyAverages(events: [IntakeEvent],
                               days: Int,
                               today: Date,
                               calendar: Calendar = .current) -> (averages: [Double], dayCount: Int) {
        let todayStart = calendar.startOfDay(for: today)
        guard days > 0, let windowStart = calendar.date(byAdding: .day, value: -days, to: todayStart) else {
            return (Array(repeating: 0, count: 24), 0)
        }

        var sums = Array(repeating: 0.0, count: 24)
        var activeDays = Set<Date>()
        for event in events where !event.isAggregate && event.date >= windowStart && event.date < todayStart {
            sums[calendar.component(.hour, from: event.date)] += event.amountMl
            activeDays.insert(calendar.startOfDay(for: event.date))
        }
        guard !activeDays.isEmpty else { return (sums, 0) }
        let count = Double(activeDays.count)
        return (sums.map { $0 / count }, activeDays.count)
    }

    /// Plus longue suite d'heures creuses dans la plage active, au moins deux
    /// heures : celles où l'on boit moins d'un quart de la moyenne horaire de la
    /// plage. `nil` sans données ou sans creux marqué.
    ///
    /// - Returns: heure de début et heure de fin (exclue).
    static func quietestStretch(averages: [Double], activeStartHour: Int, activeEndHour: Int) -> (start: Int, end: Int)? {
        guard averages.count == 24,
              (0..<24).contains(activeStartHour), (1...24).contains(activeEndHour),
              activeStartHour < activeEndHour
        else { return nil }

        let hours = Array(activeStartHour..<activeEndHour)
        let mean = hours.map { averages[$0] }.reduce(0, +) / Double(hours.count)
        guard mean > 0 else { return nil }
        let threshold = mean / 4

        var best: (start: Int, end: Int)?
        var runStart: Int?
        for hour in hours + [activeEndHour] {
            let isQuiet = hour < activeEndHour && averages[hour] < threshold
            if isQuiet {
                if runStart == nil { runStart = hour }
            } else if let start = runStart {
                if hour - start >= 2, hour - start > (best.map { $0.end - $0.start } ?? 0) {
                    best = (start, hour)
                }
                runStart = nil
            }
        }
        return best
    }

    private static func entry(on day: Date, in history: [HistoryEntry], calendar: Calendar) -> HistoryEntry? {
        history.first { calendar.isDate($0.date, inSameDayAs: day) }
    }
}
