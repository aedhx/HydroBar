//
//  ReminderContent.swift
//  HydroBar
//
//  Ce que dit un rappel. « Time to hydrate! » n'apprenait rien : le message
//  donne maintenant où l'on en est et ce qu'il reste, ou l'écart avec
//  l'allure quand on est en retard.
//
//  Le texte est calculé au moment de programmer le rappel, pour l'heure où il
//  partira. Chaque prise reprogramme les rappels : il reste donc juste.
//
//  Pur : ni Date(), ni réglages.
//

import Foundation

enum ReminderContent {

    struct Day {
        var currentMl: Double
        var targetMl: Double
        var startHour: Int
        var endHour: Int
    }

    struct Message: Equatable {
        var body: String
        /// En retard sur l'allure à l'heure du rappel : le seul cas sonore.
        var isBehind: Bool
    }

    /// - Parameters:
    ///   - date: heure du rappel.
    ///   - day: état de la journée en cours, au moment de la programmation.
    ///   - format: mise en forme d'une quantité dans l'unité choisie.
    static func message(at date: Date, now: Date, day: Day, calendar: Calendar,
                        format: (Double) -> String) -> Message {
        // Un rappel d'un autre jour ne sait rien de ce jour-là.
        guard calendar.isDate(date, inSameDayAs: now), day.targetMl > 0, day.currentMl < day.targetMl else {
            return Message(body: String(localized: "Time to hydrate!", comment: "Notification body message"),
                           isBehind: false)
        }

        let fraction = HydrationPace.expectedFraction(at: date, startHour: day.startHour,
                                                      endHour: day.endHour, calendar: calendar)
        if HydrationPace.deficitMl(currentMl: day.currentMl, targetMl: day.targetMl,
                                   expectedFraction: fraction) != nil,
           let fraction {
            let body = String(format: String(localized: "You're at %@ of %@. By now, you'd ideally be at %@.",
                                             comment: "Reminder when behind pace; current amount, goal, expected amount"),
                              format(day.currentMl), format(day.targetMl), format(fraction * day.targetMl))
            return Message(body: body, isBehind: true)
        }

        let remaining = format(day.targetMl - day.currentMl)
        guard let end = endOfDay(on: date, endHour: day.endHour, calendar: calendar) else {
            let body = String(format: String(localized: "%@ to go today.", comment: "Reminder; %@ is the amount left"),
                              remaining)
            return Message(body: body, isBehind: false)
        }
        let body = String(format: String(localized: "%@ of %@ · %@ to go by %@.",
                                         comment: "Reminder; current amount, goal, amount left, end time"),
                          format(day.currentMl), format(day.targetMl), remaining,
                          end.formatted(date: .omitted, time: .shortened))
        return Message(body: body, isBehind: false)
    }

    // MARK: Dernier appel

    /// Le dernier appel part une heure avant la fin de la plage active.
    static let lastCallLead: TimeInterval = 3_600

    /// Heure du dernier appel aujourd'hui, `nil` s'il est passé ou sans objet.
    static func lastCallDate(now: Date, day: Day, calendar: Calendar) -> Date? {
        guard day.targetMl > 0, day.currentMl < day.targetMl,
              let end = endOfDay(on: now, endHour: day.endHour, calendar: calendar),
              day.startHour < day.endHour
        else { return nil }
        let date = end.addingTimeInterval(-lastCallLead)
        guard date > now,
              let start = calendar.date(byAdding: .hour, value: day.startHour, to: calendar.startOfDay(for: now)),
              date > start
        else { return nil }
        return date
    }

    static func lastCallBody(day: Day, format: (Double) -> String) -> String {
        String(format: String(localized: "%@ left to reach your goal today.",
                              comment: "Last call notification; %@ is the amount left"),
               format(max(day.targetMl - day.currentMl, 0)))
    }

    // MARK: Saisie libre

    /// Quantité tapée dans la notification (« 33 », « 1,5 »), dans l'unité
    /// affichée, convertie en ml. `nil` si illisible ou hors bornes.
    static func amountMl(fromTyped text: String, unit: AppUnit, locale: Locale = .current) -> Double? {
        let digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet.letters.union(.whitespaces))
        guard let value = NumberInput.parse(digits, locale: locale) else { return nil }
        let ml = unit.toMl(value)
        return ml.isFinite && HydrationLimits.single.contains(ml) ? ml : nil
    }

    // MARK: Outils

    private static func endOfDay(on date: Date, endHour: Int, calendar: Calendar) -> Date? {
        guard (1...24).contains(endHour) else { return nil }
        return calendar.date(byAdding: .hour, value: endHour, to: calendar.startOfDay(for: date))
    }
}
