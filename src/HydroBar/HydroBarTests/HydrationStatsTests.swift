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

// MARK: - Par heure

private func drink(day: Int, _ hour: Int, _ ml: Double, aggregate: Bool = false) -> IntakeEvent {
    IntakeEvent(date: utc.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!,
                amountMl: ml, isAggregate: aggregate)
}

@Test func averagesEachHourOverTheDaysWithData() {
    let events = [drink(day: 13, 9, 300), drink(day: 14, 9, 500), drink(day: 14, 15, 200)]
    let result = HydrationStats.hourlyAverages(events: events, days: 30, today: now, calendar: utc)
    #expect(result.dayCount == 2)
    #expect(result.averages[9] == 400)
    #expect(result.averages[15] == 100)
    #expect(result.averages[3] == 0)
}

@Test func leavesTodayAndImportedTotalsOut() {
    let events = [drink(day: 15, 9, 500), drink(day: 14, 12, 1800, aggregate: true), drink(day: 14, 10, 250)]
    let result = HydrationStats.hourlyAverages(events: events, days: 30, today: now, calendar: utc)
    #expect(result.dayCount == 1)
    #expect(result.averages[9] == 0)
    #expect(result.averages[12] == 0)
    #expect(result.averages[10] == 250)
}

@Test func findsTheLongestQuietStretchWithinActiveHours() throws {
    var averages = Array(repeating: 200.0, count: 24)
    for hour in 14..<17 { averages[hour] = 0 }      // creux de 3 h
    averages[10] = 0                                  // creux d'1 h : ignoré
    for hour in 0..<8 { averages[hour] = 0 }          // nuit : hors plage
    let stretch = try #require(HydrationStats.quietestStretch(averages: averages, activeStartHour: 8, activeEndHour: 22))
    #expect(stretch.start == 14)
    #expect(stretch.end == 17)
}

@Test func reportsNoQuietStretchWhenIntakeIsEven() {
    let averages = Array(repeating: 150.0, count: 24)
    #expect(HydrationStats.quietestStretch(averages: averages, activeStartHour: 8, activeEndHour: 22) == nil)
}

// MARK: - Bilan de la semaine

@Test func summarizesTheLastSevenDays() {
    let history = [entry(1, 2000), entry(2, 1000), entry(3, 2500), entry(8, 3000)]
    let summary = HydrationStats.weekSummary(history: history, today: today(2000), calendar: utc)
    #expect(summary.goalDays == 3)                     // aujourd'hui, J-1, J-3 ; J-8 hors fenêtre
    #expect(summary.averageMl == 7500.0 / 7)
}

private func calendar(firstWeekday: Int) -> Calendar {
    var calendar = utc
    calendar.firstWeekday = firstWeekday
    return calendar
}

/// 13 septembre 2026 : un dimanche.
private func sunday(_ hour: Int) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: hour))!
}

@Test func sendsTheWeeklySummaryOnTheLastDayOfTheLocalWeek() {
    let monday = calendar(firstWeekday: 2)   // semaine du lundi au dimanche
    #expect(HydrationStats.weeklySummaryKeyIfDue(now: sunday(21), hour: 21, lastSentKey: "", calendar: monday) != nil)
    #expect(HydrationStats.weeklySummaryKeyIfDue(now: sunday(20), hour: 21, lastSentKey: "", calendar: monday) == nil)

    let sundayFirst = calendar(firstWeekday: 1)   // semaine du dimanche au samedi
    #expect(HydrationStats.weeklySummaryKeyIfDue(now: sunday(21), hour: 21, lastSentKey: "", calendar: sundayFirst) == nil)
}

@Test func sendsTheWeeklySummaryOnlyOncePerWeek() throws {
    let monday = calendar(firstWeekday: 2)
    let key = try #require(HydrationStats.weeklySummaryKeyIfDue(now: sunday(21), hour: 21, lastSentKey: "", calendar: monday))
    #expect(HydrationStats.weeklySummaryKeyIfDue(now: sunday(22), hour: 21, lastSentKey: key, calendar: monday) == nil)
}

// MARK: - Objectif par jour et preset suggéré

@Test func usesTheWeekdayGoalWhenThereIsOne() {
    var goals = WeekdayGoals()
    goals.overrides[utc.component(.weekday, from: now)] = 2800
    #expect(goals.goal(on: now, calendar: utc, default: 2000) == 2800)
    #expect(goals.goal(on: daysAgo(1), calendar: utc, default: 2000) == 2000)
}

@Test func weekdayGoalsSurviveStorage() {
    var goals = WeekdayGoals()
    goals.overrides[2] = 2500
    goals.overrides[7] = 1500
    #expect(WeekdayGoals.decode(goals.encoded()) == goals)
    #expect(WeekdayGoals.decode("") == WeekdayGoals())
}

private func glasses(_ ml: Double, count: Int) -> [IntakeEvent] {
    (0..<count).map { IntakeEvent(date: daysAgo($0 + 1).addingTimeInterval(3600 * 10), amountMl: ml) }
}

@Test func suggestsAFrequentAmountThatIsNotAPreset() throws {
    let events = glasses(330, count: 6) + glasses(500, count: 4)
    let suggestion = try #require(PresetSuggestion.suggest(events: events, presets: [200, 500, 750], now: now, calendar: utc))
    #expect(suggestion.amountMl == 330)
    #expect(suggestion.replacingIndex == 2)   // 750 jamais utilisé ; à égalité avec 200, le dernier
}

@Test func doesNotSuggestRareAmountsOrExistingPresets() {
    #expect(PresetSuggestion.suggest(events: glasses(330, count: 4), presets: [200, 500, 750], now: now, calendar: utc) == nil)
    #expect(PresetSuggestion.suggest(events: glasses(505, count: 9), presets: [200, 500, 750], now: now, calendar: utc) == nil)
}

@Test func remembersADismissedSuggestion() {
    let events = glasses(330, count: 6)
    #expect(PresetSuggestion.suggest(events: events, presets: [200, 500, 750], now: now,
                                     dismissed: [330], calendar: utc) == nil)
}
