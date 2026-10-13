//
//  DayPlan.swift
//  HydroBar
//
//  Jours travaillés et jours off. Les réglages habituels (plage active,
//  cadence des rappels, objectif) décrivent un jour de travail ; un jour off
//  a les siens : on se lève plus tard, on veut moins de rappels, parfois un
//  autre objectif.
//
//  Le type de jour se décide, du plus fort au plus faible :
//  1. une Concentration macOS qui le fixe (filtre de Concentration) ;
//  2. un choix ponctuel pour une journée (« aujourd'hui : jour off ») ;
//  3. une période de congés ;
//  4. le jour de la semaine.
//
//  Pur : ni Date(), ni UserDefaults.
//

import Foundation

enum DayKind: String, Codable, CaseIterable {
    case work
    case off
}

/// Règles effectives d'une journée, lues par le planificateur de rappels et
/// le repère d'allure.
struct DayRules: Equatable {
    var kind: DayKind
    var startHour: Int
    var endHour: Int
    var intervalMinutes: Int
    var remindersEnabled: Bool
}

struct DayPlan: Codable, Equatable {
    /// Les jours off ont leurs propres réglages. Désactivé, chaque jour suit
    /// les réglages habituels : rien ne change pour qui n'en veut pas.
    var enabled = false
    /// Composants `.weekday` (1 = dimanche … 7 = samedi) des jours off.
    var offWeekdays: Set<Int> = [1, 7]

    var offStartHour = 10
    var offEndHour = 22
    var offIntervalMinutes = 90
    var offRemindersEnabled = true
    /// Objectif des jours off ; `nil` : le même que d'habitude.
    var offGoalMl: Double?

    /// Choix ponctuels, par clé de journée `yyyy-MM-dd`.
    var dayOverrides: [String: DayKind] = [:]
    /// Congés : journées off de `leaveStart` à `leaveEnd` inclus.
    var leaveStart: String?
    var leaveEnd: String?

    static let selectableIntervals = [30, 45, 60, 90, 120, 180]

    // MARK: Type de jour

    /// - Parameter focusKind: type imposé par une Concentration, valable
    ///   pour la journée en cours seulement.
    func kind(on date: Date, calendar: Calendar, focusKind: DayKind? = nil) -> DayKind {
        guard enabled else { return .work }
        if let focusKind { return focusKind }
        let key = IntakeLog.dayKey(for: date, calendar: calendar)
        if let override = dayOverrides[key] { return override }
        if isOnLeave(key) { return .off }
        return offWeekdays.contains(calendar.component(.weekday, from: date)) ? .off : .work
    }

    /// Type que la journée aurait sans choix ponctuel : sert à savoir si
    /// « aujourd'hui : jour off » change quelque chose.
    func scheduledKind(on date: Date, calendar: Calendar) -> DayKind {
        var plan = self
        plan.dayOverrides = [:]
        return plan.kind(on: date, calendar: calendar)
    }

    private func isOnLeave(_ key: String) -> Bool {
        guard let leaveStart, let leaveEnd else { return false }
        // Les clés `yyyy-MM-dd` se comparent comme des dates.
        return leaveStart <= key && key <= leaveEnd
    }

    // MARK: Règles

    struct WorkSettings: Equatable {
        var startHour: Int
        var endHour: Int
        var intervalMinutes: Int
    }

    func rules(on date: Date, calendar: Calendar, work: WorkSettings, focusKind: DayKind? = nil) -> DayRules {
        switch kind(on: date, calendar: calendar, focusKind: focusKind) {
        case .work:
            return DayRules(kind: .work, startHour: work.startHour, endHour: work.endHour,
                            intervalMinutes: work.intervalMinutes, remindersEnabled: true)
        case .off:
            return DayRules(kind: .off, startHour: offStartHour, endHour: offEndHour,
                            intervalMinutes: offIntervalMinutes, remindersEnabled: offRemindersEnabled)
        }
    }

    // MARK: Écriture

    /// Fixe le type d'une journée. Choisir le type qu'elle aurait de toute
    /// façon efface le choix ponctuel au lieu de l'enregistrer.
    mutating func setKind(_ kind: DayKind, on date: Date, calendar: Calendar) {
        let key = IntakeLog.dayKey(for: date, calendar: calendar)
        dayOverrides[key] = nil
        if scheduledKind(on: date, calendar: calendar) != kind {
            dayOverrides[key] = kind
        }
        pruneOverrides(before: date, calendar: calendar)
    }

    mutating func setLeave(from start: Date, to end: Date, calendar: Calendar) {
        let first = min(start, end), last = max(start, end)
        leaveStart = IntakeLog.dayKey(for: first, calendar: calendar)
        leaveEnd = IntakeLog.dayKey(for: last, calendar: calendar)
    }

    mutating func clearLeave() {
        leaveStart = nil
        leaveEnd = nil
    }

    /// Fin des congés en cours ou à venir, `nil` s'ils sont passés.
    func leaveEndDate(after date: Date, calendar: Calendar) -> Date? {
        guard let leaveEnd, leaveEnd >= IntakeLog.dayKey(for: date, calendar: calendar) else { return nil }
        return Self.date(fromKey: leaveEnd, calendar: calendar)
    }

    /// Les choix ponctuels des jours passés ne servent plus à rien.
    mutating func pruneOverrides(before date: Date, calendar: Calendar) {
        let today = IntakeLog.dayKey(for: date, calendar: calendar)
        dayOverrides = dayOverrides.filter { $0.key >= today }
    }

    static func date(fromKey key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    // MARK: Stockage

    static func decode(_ raw: String) -> DayPlan {
        guard let data = raw.data(using: .utf8),
              let plan = try? JSONDecoder().decode(DayPlan.self, from: data)
        else { return DayPlan() }
        return plan
    }

    func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
