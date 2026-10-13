//
//  DayTimelineTests.swift
//  HydroBarTests
//
//  Frise de la journée, en aperçu de la page Rappels : plage active, rappels
//  à la cadence choisie, dernier appel.
//

import Testing
@testable import HydroBar

@Test func timelineBandFollowsActiveHours() {
    let layout = DayTimeline.layout(startHour: 6, endHour: 18, intervalMinutes: 60,
                                    remindersEnabled: false, lastCallEnabled: true)
    #expect(layout?.band == 0.25...0.75)
    // Rappels coupés : ni traits, ni dernier appel.
    #expect(layout?.reminders.isEmpty == true)
    #expect(layout?.lastCall == nil)
}

@Test func timelineHasOneTickPerInterval() {
    let layout = DayTimeline.layout(startHour: 8, endHour: 12, intervalMinutes: 60,
                                    remindersEnabled: true, lastCallEnabled: false)
    // 9 h, 10 h et 11 h : un rappel à chaque cadence écoulée, aucun à la fin.
    #expect(layout?.reminders == [9.0 / 24, 10.0 / 24, 11.0 / 24])
    #expect(layout?.lastCall == nil)
}

@Test func timelineLastCallIsOneHourBeforeTheEnd() {
    let layout = DayTimeline.layout(startHour: 8, endHour: 22, intervalMinutes: 120,
                                    remindersEnabled: true, lastCallEnabled: true)
    #expect(layout?.lastCall == 21.0 / 24)
    // Le rappel de 20 h reste : il est à une heure du dernier appel.
    #expect(layout?.reminders.last == 20.0 / 24)
}

@Test func timelineLastCallReplacesAReminderTooClose() {
    let layout = DayTimeline.layout(startHour: 8, endHour: 12, intervalMinutes: 60,
                                    remindersEnabled: true, lastCallEnabled: true)
    // Le rappel de 11 h tombe sur le dernier appel : un seul des deux part.
    #expect(layout?.lastCall == 11.0 / 24)
    #expect(layout?.reminders == [9.0 / 24, 10.0 / 24])
}

@Test func timelineHasNoLastCallInAOneHourDay() {
    let layout = DayTimeline.layout(startHour: 8, endHour: 9, intervalMinutes: 30,
                                    remindersEnabled: true, lastCallEnabled: true)
    #expect(layout?.lastCall == nil)
    #expect(layout?.reminders == [8.5 / 24])
}

@Test func timelineRejectsARangeAcrossMidnight() {
    #expect(DayTimeline.layout(startHour: 22, endHour: 6, intervalMinutes: 60,
                               remindersEnabled: true, lastCallEnabled: true) == nil)
    #expect(DayTimeline.layout(startHour: 8, endHour: 8, intervalMinutes: 60,
                               remindersEnabled: true, lastCallEnabled: true) == nil)
}
