//
//  ReminderPlannerTests.swift
//  HydroBarTests
//
//  Rappels intelligents (F6) : plage active, objectif atteint, cadence
//  adaptative, pause.
//

import Testing
import Foundation
@testable import HydroBar

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func at(day: Int = 15, _ hour: Int, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
}

private func context(now: Date, lastDrink: Date, interval: Int = 60,
                     goalReached: Bool = false, behind: Bool = false,
                     notBefore: Date? = nil) -> ReminderPlanner.Context {
    ReminderPlanner.Context(now: now, lastDrink: lastDrink, intervalMinutes: interval,
                            activeStartHour: 8, activeEndHour: 22,
                            goalReachedToday: goalReached, behindPace: behind,
                            notBefore: notBefore, calendar: utc)
}

@Test func remindsOneIntervalAfterTheLastDrink() {
    let dates = ReminderPlanner.upcoming(context(now: at(10), lastDrink: at(10)), limit: 3)
    #expect(dates == [at(11), at(12), at(13)])
}

@Test func neverRemindsOutsideActiveHours() {
    // Dernière prise à 21 h 30 : le rappel de 22 h 30 glisse au lendemain 8 h.
    let dates = ReminderPlanner.upcoming(context(now: at(21, 30), lastDrink: at(21, 30)), limit: 2)
    #expect(dates == [at(day: 16, 8), at(day: 16, 9)])
}

@Test func waitsForTheMorningAtNight() {
    let dates = ReminderPlanner.upcoming(context(now: at(3), lastDrink: at(day: 14, 21)), limit: 1)
    #expect(dates == [at(8)])
}

@Test func stopsForTheDayOnceTheGoalIsReached() {
    let dates = ReminderPlanner.upcoming(context(now: at(15), lastDrink: at(15), goalReached: true), limit: 1)
    #expect(dates == [at(day: 16, 8)])
}

@Test func remindsMoreOftenTodayWhenBehind() {
    // 60 min → 40 min, aujourd'hui seulement.
    let dates = ReminderPlanner.upcoming(context(now: at(10), lastDrink: at(10), behind: true), limit: 2)
    #expect(dates == [at(10, 40), at(11, 20)])
}

@Test func theAdaptiveCadenceNeverGoesBelowFifteenMinutes() {
    let dates = ReminderPlanner.upcoming(context(now: at(10), lastDrink: at(10), interval: 15, behind: true), limit: 1)
    #expect(dates == [at(10, 15)])
}

@Test func tomorrowStartsAgainAtTheNormalCadence() {
    let dates = ReminderPlanner.upcoming(context(now: at(21, 30), lastDrink: at(21, 30), behind: true), limit: 2)
    #expect(dates == [at(day: 16, 8), at(day: 16, 9)])
}

@Test func resumesAfterASnooze() {
    let dates = ReminderPlanner.upcoming(context(now: at(10), lastDrink: at(10), notBefore: at(13, 30)), limit: 2)
    #expect(dates == [at(13, 30), at(14, 30)])
}

@Test func keepsTheCadenceAfterALongAbsence() {
    // Dernière prise à 10 h, retour à 12 h 10 : prochain rappel à 13 h, pas
    // une rafale de rappels en retard.
    let dates = ReminderPlanner.upcoming(context(now: at(12, 10), lastDrink: at(10)), limit: 1)
    #expect(dates == [at(13)])
}

@Test func doesNotReplayDaysOfAbsence() {
    let dates = ReminderPlanner.upcoming(context(now: at(10, 30), lastDrink: at(day: 1, 10)), limit: 1)
    #expect(dates.first.map { $0 > at(10, 30) && $0 <= at(11, 30) } == true)
}

@Test func aReminderIsDueOnlyAfterTheInterval() {
    #expect(!ReminderPlanner.isDue(context(now: at(10, 30), lastDrink: at(10))))
    #expect(ReminderPlanner.isDue(context(now: at(11, 5), lastDrink: at(10))))
    #expect(!ReminderPlanner.isDue(context(now: at(23), lastDrink: at(20))))
}
