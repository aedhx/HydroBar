//
//  ReminderSnoozeTests.swift
//  HydroBarTests
//
//  Fin de la pause des rappels (F19), alignée sur la plage active.
//

import Testing
import Foundation
@testable import HydroBar

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func at(day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
}

private func end(_ option: SnoozeOption, from now: Date) -> Date {
    option.endDate(from: now, activeStartHour: 8, activeEndHour: 22, calendar: utc)
}

@Test func pausesForOneHour() {
    #expect(end(.oneHour, from: at(day: 15, 14, 30)) == at(day: 15, 15, 30))
}

@Test func pausesUntilTheEndOfActiveHours() {
    #expect(end(.untilEvening, from: at(day: 15, 14)) == at(day: 15, 22))
}

@Test func anEveningPauseTakenLateRunsUntilTomorrowMorning() {
    // Posée à 23 h, une pause « jusqu'à ce soir » ne doit pas s'achever aussitôt.
    #expect(end(.untilEvening, from: at(day: 15, 23)) == at(day: 16, 8))
}

@Test func pausesUntilActiveHoursStartTomorrow() {
    #expect(end(.untilTomorrow, from: at(day: 15, 14)) == at(day: 16, 8))
    #expect(end(.untilTomorrow, from: at(day: 15, 0, 30)) == at(day: 16, 8))
}
