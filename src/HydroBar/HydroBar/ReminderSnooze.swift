//
//  ReminderSnooze.swift
//  HydroBar
//
//  Mise en pause des rappels (roadmap F19). Le mode Ne pas déranger est
//  binaire : sans « pas maintenant », l'utilisateur en réunion coupait les
//  rappels et oubliait de les réactiver. Une pause, elle, se termine seule.
//

import Foundation

enum SnoozeOption: String, CaseIterable, Identifiable {
    case oneHour
    case untilEvening
    case untilTomorrow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneHour:
            return String(localized: "For 1 Hour", comment: "Snooze reminders option")
        case .untilEvening:
            return String(localized: "Until This Evening", comment: "Snooze reminders option: until the end of active hours")
        case .untilTomorrow:
            return String(localized: "Until Tomorrow", comment: "Snooze reminders option: until active hours start tomorrow")
        }
    }

    /// Fin de la pause. « Ce soir » et « demain » s'alignent sur la plage
    /// active réglée par l'utilisateur (repère d'allure), pas sur des heures
    /// arbitraires.
    func endDate(from now: Date, activeStartHour: Int, activeEndHour: Int, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: today)
            .flatMap { calendar.date(bySettingHour: activeStartHour, minute: 0, second: 0, of: $0) }
            ?? now.addingTimeInterval(12 * 3600)

        switch self {
        case .oneHour:
            return now.addingTimeInterval(3600)
        case .untilEvening:
            // Déjà le soir : la pause court jusqu'à demain matin plutôt que de
            // s'achever aussitôt posée.
            guard let evening = calendar.date(bySettingHour: activeEndHour, minute: 0, second: 0, of: today),
                  evening > now
            else { return tomorrowStart }
            return evening
        case .untilTomorrow:
            return tomorrowStart
        }
    }
}
