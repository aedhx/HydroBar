//
//  DayPlanTests.swift
//  HydroBarTests
//
//  Jours travaillés et jours off : type de jour, priorités, règles des
//  rappels.
//

import Testing
import Foundation
@testable import HydroBar

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// Septembre 2026 : le 14 est un lundi, le 19 un samedi.
private func at(day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
}

private let work = DayPlan.WorkSettings(startHour: 8, endHour: 20, intervalMinutes: 60)

private func enabledPlan() -> DayPlan {
    var plan = DayPlan()
    plan.enabled = true
    return plan
}

// MARK: - Type de jour

@Test func everyDayIsAWorkDayWhenDisabled() {
    let plan = DayPlan()
    #expect(plan.kind(on: at(day: 19), calendar: utc) == .work)
}

@Test func weekendsAreDaysOffByDefault() {
    let plan = enabledPlan()
    #expect(plan.kind(on: at(day: 14), calendar: utc) == .work)
    #expect(plan.kind(on: at(day: 19), calendar: utc) == .off)
    #expect(plan.kind(on: at(day: 20), calendar: utc) == .off)
}

@Test func aOneDayChoiceOnlyLastsThatDay() {
    var plan = enabledPlan()
    plan.setKind(.off, on: at(day: 15), calendar: utc)
    #expect(plan.kind(on: at(day: 15), calendar: utc) == .off)
    #expect(plan.kind(on: at(day: 16), calendar: utc) == .work)
}

@Test func choosingTheScheduledKindClearsTheChoice() {
    var plan = enabledPlan()
    plan.setKind(.off, on: at(day: 15), calendar: utc)
    plan.setKind(.work, on: at(day: 15), calendar: utc)
    #expect(plan.dayOverrides.isEmpty)
}

@Test func timeOffCoversEveryDayInclusive() {
    var plan = enabledPlan()
    plan.setLeave(from: at(day: 16), to: at(day: 14), calendar: utc)
    #expect(plan.kind(on: at(day: 14), calendar: utc) == .off)
    #expect(plan.kind(on: at(day: 16), calendar: utc) == .off)
    #expect(plan.kind(on: at(day: 17), calendar: utc) == .work)
}

@Test func aFocusWinsOverEverything() {
    var plan = enabledPlan()
    plan.setKind(.off, on: at(day: 15), calendar: utc)
    #expect(plan.kind(on: at(day: 15), calendar: utc, focusKind: .work) == .work)
}

@Test func pastChoicesArePruned() {
    var plan = enabledPlan()
    plan.setKind(.off, on: at(day: 15), calendar: utc)
    plan.pruneOverrides(before: at(day: 16), calendar: utc)
    #expect(plan.dayOverrides.isEmpty)
}

@Test func theLeaveEndIsOnlyReportedWhileItMatters() {
    var plan = enabledPlan()
    plan.setLeave(from: at(day: 14), to: at(day: 16), calendar: utc)
    #expect(plan.leaveEndDate(after: at(day: 15), calendar: utc) == utc.startOfDay(for: at(day: 16)))
    #expect(plan.leaveEndDate(after: at(day: 17), calendar: utc) == nil)
}

@Test func thePlanSurvivesStorage() {
    var plan = enabledPlan()
    plan.offGoalMl = 1500
    plan.setLeave(from: at(day: 14), to: at(day: 16), calendar: utc)
    #expect(DayPlan.decode(plan.encoded()) == plan)
    #expect(DayPlan.decode("garbage") == DayPlan())
}

// MARK: - Règles

@Test func daysOffUseTheirOwnRules() {
    var plan = enabledPlan()
    plan.offStartHour = 10
    plan.offEndHour = 22
    plan.offIntervalMinutes = 120
    let rules = plan.rules(on: at(day: 19), calendar: utc, work: work)
    #expect(rules == DayRules(kind: .off, startHour: 10, endHour: 22, intervalMinutes: 120, remindersEnabled: true))
    #expect(plan.rules(on: at(day: 14), calendar: utc, work: work).startHour == 8)
}

// MARK: - Planificateur

private func plannerContext(now: Date, plan: DayPlan) -> ReminderPlanner.Context {
    ReminderPlanner.Context(now: now, lastDrink: now, intervalMinutes: work.intervalMinutes,
                            activeStartHour: work.startHour, activeEndHour: work.endHour,
                            goalReachedToday: false, behindPace: false, notBefore: nil, calendar: utc,
                            dayRules: { plan.rules(on: $0, calendar: utc, work: work) })
}

@Test func saturdayStartsLaterAndRemindsLessOften() {
    var plan = enabledPlan()
    plan.offStartHour = 10
    plan.offIntervalMinutes = 120
    // Vendredi 19 h 30 : le rappel de 20 h 30 tombe hors plage, et samedi
    // commence à 10 h, avec un rappel toutes les deux heures.
    let dates = ReminderPlanner.upcoming(plannerContext(now: at(day: 18, 19, 30), plan: plan), limit: 2)
    #expect(dates == [at(day: 19, 10), at(day: 19, 12)])
}

@Test func noRemindersOnDaysOffSkipsTheWeekend() {
    var plan = enabledPlan()
    plan.offRemindersEnabled = false
    let dates = ReminderPlanner.upcoming(plannerContext(now: at(day: 18, 19, 30), plan: plan), limit: 1)
    #expect(dates == [at(day: 21, 8)])
}

@Test func noAllowedMomentMeansNoReminder() {
    var plan = enabledPlan()
    plan.offRemindersEnabled = false
    plan.offWeekdays = Set(1...7)
    let context = plannerContext(now: at(day: 18, 10), plan: plan)
    #expect(ReminderPlanner.upcoming(context, limit: 3).isEmpty)
    #expect(!ReminderPlanner.isDue(context))
}
