//
//  HydrationStatsTests.swift
//  HydroBarTests
//
//  Série de jours consécutifs et total hebdomadaire. `HydrationStats` est pur :
//  l'historique, la journée en cours et le calendrier sont passés en paramètres.
//

import Testing
import Foundation
@testable import HydroBar

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// Midi le 15 septembre 2026, en UTC.
private let now: Date = utc.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 12))!

private func daysAgo(_ days: Int) -> Date {
    utc.date(byAdding: .day, value: -days, to: utc.startOfDay(for: now))!
}

private func entry(_ days: Int, _ amount: Double, goal: Double = 2000) -> HistoryEntry {
    HistoryEntry(date: daysAgo(days), amountMl: amount, targetMl: goal)
}

private func today(_ amount: Double, goal: Double = 2000) -> HydrationStats.Today {
    HydrationStats.Today(date: now, amountMl: amount, targetMl: goal)
}

// MARK: - Série

@Test func countsConsecutiveCompletedDaysBeforeToday() {
    let history = [entry(1, 2000), entry(2, 2500), entry(3, 2100)]
    #expect(HydrationStats.streak(history: history, today: today(0), calendar: utc) == 3)
}

@Test func aStartedButUnfinishedDayDoesNotBreakTheStreak() {
    // Régression : le premier verre du matin remettait la série à zéro.
    let history = [entry(1, 2000), entry(2, 2000)]
    #expect(HydrationStats.streak(history: history, today: today(300), calendar: utc) == 2)
}

@Test func reachingTodaysGoalExtendsTheStreak() {
    let history = [entry(1, 2000), entry(2, 2000)]
    #expect(HydrationStats.streak(history: history, today: today(2000), calendar: utc) == 3)
}

@Test func stopsAtTheFirstMissedDay() {
    let history = [entry(1, 2000), entry(2, 1500), entry(3, 2000)]
    #expect(HydrationStats.streak(history: history, today: today(0), calendar: utc) == 1)
}

@Test func stopsAtTheFirstDayWithoutData() {
    let history = [entry(1, 2000), entry(3, 2000)]
    #expect(HydrationStats.streak(history: history, today: today(0), calendar: utc) == 1)
}

@Test func judgesEachDayAgainstItsOwnGoal() {
    // L'objectif a changé entre-temps : 1500 suffisait avant-hier.
    let history = [entry(1, 2000), entry(2, 1500, goal: 1500)]
    #expect(HydrationStats.streak(history: history, today: today(0, goal: 3000), calendar: utc) == 2)
}

@Test func ignoresTheHistoryEntryForToday() {
    // L'entrée du jour peut être en retard sur la valeur en mémoire.
    let history = [entry(0, 2000), entry(1, 2000)]
    #expect(HydrationStats.streak(history: history, today: today(100), calendar: utc) == 1)
}

@Test func emptyHistoryHasNoStreak() {
    #expect(HydrationStats.streak(history: [], today: today(0), calendar: utc) == 0)
}

// MARK: - Total

@Test func sumsTheLastSevenDaysIncludingToday() {
    let history = (1...6).map { entry($0, 1000) }
    #expect(HydrationStats.total(lastDays: 7, history: history, today: today(500), calendar: utc) == 6500)
}

@Test func excludesDaysOutsideTheWindow() {
    let history = [entry(1, 1000), entry(7, 9999), entry(30, 9999)]
    #expect(HydrationStats.total(lastDays: 7, history: history, today: today(0), calendar: utc) == 1000)
}

@Test func usesTheLiveValueForTodayRatherThanTheHistory() {
    let history = [entry(0, 100)]
    #expect(HydrationStats.total(lastDays: 7, history: history, today: today(800), calendar: utc) == 800)
}

@Test func anEmptyWindowTotalsZero() {
    #expect(HydrationStats.total(lastDays: 0, history: [entry(1, 1000)], today: today(500), calendar: utc) == 0)
}
