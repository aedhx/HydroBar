//
//  ReminderPlanner.swift
//  HydroBar
//
//  Rappels intelligents (roadmap F6). L'ancien système était un intervalle fixe
//  qui se réarmait à chaque ajout : il notifiait à 3 h du matin comme à 15 h,
//  et continuait une fois l'objectif atteint.
//
//  Le planificateur calcule les prochains rappels à partir de la dernière
//  prise, en respectant trois règles :
//  1. jamais hors de la plage active (celle du repère d'allure) ;
//  2. plus rien aujourd'hui une fois l'objectif atteint ;
//  3. en retard sur l'allure, la cadence du jour se resserre d'un tiers.
//
//  Pur : aucune lecture de Date(), de l'état de l'app ou du système de
//  notifications. Le manager programme les dates qu'il renvoie.
//

import Foundation

enum ReminderPlanner {

    struct Context {
        var now: Date
        /// Dernière prise, ou moment de référence si aucune.
        var lastDrink: Date
        var intervalMinutes: Int
        var activeStartHour: Int
        var activeEndHour: Int
        var goalReachedToday: Bool
        /// Cadence resserrée aujourd'hui quand l'utilisateur est en retard.
        var behindPace: Bool
        /// Fin d'une pause en cours (F19) : aucun rappel avant.
        var notBefore: Date?
        var calendar: Calendar
        /// Règles propres à chaque journée (jours off). `nil` : tous les jours
        /// suivent la plage et l'intervalle ci-dessus.
        var dayRules: ((Date) -> DayRules)?

        /// Règles de la journée de `date`.
        func rules(on date: Date) -> DayRules {
            dayRules?(date) ?? DayRules(kind: .work, startHour: activeStartHour, endHour: activeEndHour,
                                        intervalMinutes: intervalMinutes, remindersEnabled: true)
        }
    }

    /// Aucun moment autorisé dans les semaines à venir (rappels coupés tous
    /// les jours off, et des congés devant soi).
    static let never = Date.distantFuture

    /// Plancher de la cadence resserrée : au-delà, un rappel devient du harcèlement.
    static let minimumAdaptiveIntervalMinutes = 15

    // MARK: - API

    /// Prochains rappels, dans l'ordre, tous postérieurs à `now`.
    static func upcoming(_ context: Context, limit: Int = 6) -> [Date] {
        var result: [Date] = []
        var candidate = first(context)
        // Borne de sécurité : une journée de pas minimaux, plus la marge.
        for _ in 0..<1_000 {
            if result.count >= limit || candidate == never { break }
            if candidate > context.now { result.append(candidate) }
            candidate = place(candidate.addingTimeInterval(interval(at: candidate, context)), context)
        }
        return result
    }

    /// Un rappel est-il dû maintenant ? Sert à la pastille du mode Ne pas
    /// déranger, qui remplace la notification.
    static func isDue(_ context: Context) -> Bool {
        // Il faut aussi que maintenant soit un moment autorisé : un rappel
        // échu à 21 h ne doit pas allumer la pastille à 23 h.
        first(context) <= context.now && place(context.now, context) == context.now
    }

    // MARK: - Calcul

    /// Premier rappel après la dernière prise. Une prise très ancienne (Mac
    /// éteint plusieurs jours) n'impose pas de rejouer toute la période.
    private static func first(_ context: Context) -> Date {
        let anchor = max(context.lastDrink, context.now.addingTimeInterval(-86_400))
        return place(anchor.addingTimeInterval(interval(at: anchor, context)), context)
    }

    static func interval(at date: Date, _ context: Context) -> TimeInterval {
        let base = TimeInterval(max(context.rules(on: date).intervalMinutes, 1) * 60)
        guard context.behindPace, context.calendar.isDate(date, inSameDayAs: context.now) else { return base }
        return max(base * 2 / 3, TimeInterval(minimumAdaptiveIntervalMinutes * 60))
    }

    /// Déplace une date candidate vers le premier moment autorisé.
    static func place(_ date: Date, _ context: Context) -> Date {
        var placed = date
        if let notBefore = context.notBefore, placed < notBefore {
            placed = notBefore
        }
        if context.goalReachedToday, context.calendar.isDate(placed, inSameDayAs: context.now),
           let tomorrow = context.calendar.date(byAdding: .day, value: 1,
                                                to: context.calendar.startOfDay(for: context.now)) {
            placed = tomorrow
        }
        return intoActiveHours(placed, context)
    }

    private static func intoActiveHours(_ date: Date, _ context: Context) -> Date {
        let calendar = context.calendar
        var candidate = date
        // Une journée sans rappels renvoie au lendemain : on cherche le premier
        // moment autorisé sur deux mois au plus.
        for _ in 0..<62 {
            let day = calendar.startOfDay(for: candidate)
            let rules = context.rules(on: day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return candidate }
            guard rules.remindersEnabled else {
                candidate = nextDay
                continue
            }
            // Plage invalide (vide ou à cheval sur minuit) : pas de contrainte,
            // comme le repère d'allure qui la refuse lui aussi.
            guard (0..<24).contains(rules.startHour),
                  (1...24).contains(rules.endHour),
                  rules.startHour < rules.endHour
            else { return candidate }

            guard let start = calendar.date(byAdding: .hour, value: rules.startHour, to: day),
                  let end = calendar.date(byAdding: .hour, value: rules.endHour, to: day)
            else { return candidate }

            if candidate < start { return start }
            if candidate < end { return candidate }
            candidate = nextDay
        }
        return never
    }
}
