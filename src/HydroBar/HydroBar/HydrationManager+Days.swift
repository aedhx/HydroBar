//
//  HydrationManager+Days.swift
//  HydroBar
//
//  Jours travaillés et jours off : lecture du plan et règles effectives de
//  chaque journée. Le modèle est dans DayPlan.swift.
//

import Foundation

extension HydrationManager {

    var dayPlan: DayPlan {
        get {
            if let cache = dayPlanCache, cache.raw == dayPlanRaw { return cache.plan }
            let plan = DayPlan.decode(dayPlanRaw)
            dayPlanCache = (dayPlanRaw, plan)
            return plan
        }
        set {
            objectWillChange.send()
            var plan = newValue
            plan.pruneOverrides(before: Date(), calendar: .current)
            dayPlanRaw = plan.encoded()
            // L'objectif, la plage active et les rappels du jour peuvent changer.
            goalDidChange()
        }
    }

    var focusDayKind: DayKind? { DayKind(rawValue: focusDayKindRaw) }

    /// Appelée par le filtre de Concentration, `nil` à sa désactivation.
    func setFocusDayKind(_ kind: DayKind?) {
        guard focusDayKind != kind else { return }
        objectWillChange.send()
        focusDayKindRaw = kind?.rawValue ?? ""
        goalDidChange()
    }

    private var workSettings: DayPlan.WorkSettings {
        DayPlan.WorkSettings(startHour: activeHoursStart, endHour: activeHoursEnd,
                             intervalMinutes: reminderIntervalMinutes)
    }

    func dayRules(on date: Date) -> DayRules {
        let calendar = Calendar.current
        // La Concentration ne vaut que pour la journée en cours.
        let focus = calendar.isDate(date, inSameDayAs: Date()) ? focusDayKind : nil
        return dayPlan.rules(on: date, calendar: calendar, work: workSettings, focusKind: focus)
    }

    var todayRules: DayRules { dayRules(on: Date()) }

    var todayKind: DayKind { todayRules.kind }

    /// Le type d'aujourd'hui vient d'une Concentration : un choix ponctuel
    /// n'y changerait rien tant qu'elle est active.
    var todayKindSetByFocus: Bool { dayPlan.enabled && focusDayKind != nil }

    func setTodayKind(_ kind: DayKind) {
        var plan = dayPlan
        plan.setKind(kind, on: Date(), calendar: .current)
        dayPlan = plan
    }

    /// Objectif prévu pour une journée : celui des jours off s'il est fixé,
    /// sinon l'objectif du jour de la semaine, sinon l'objectif par défaut.
    func plannedGoal(on date: Date) -> Double {
        if dayRules(on: date).kind == .off, let offGoal = dayPlan.offGoalMl {
            return offGoal
        }
        return weekdayGoals.goal(on: date, calendar: .current, default: defaultTargetMl)
    }

    /// Règles de chaque journée pour le planificateur de rappels, figées au
    /// moment de la planification : il les lit pour chaque date candidate.
    func dayRulesProvider(now: Date) -> ((Date) -> DayRules)? {
        let plan = dayPlan
        guard plan.enabled else { return nil }
        let work = workSettings
        let focus = focusDayKind
        let calendar = Calendar.current
        return { date in
            plan.rules(on: date, calendar: calendar, work: work,
                       focusKind: calendar.isDate(date, inSameDayAs: now) ? focus : nil)
        }
    }
}
