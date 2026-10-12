//
//  ReminderContentTests.swift
//  HydroBarTests
//
//  Texte des rappels, dernier appel et quantité saisie dans la notification.
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

private func ml(_ value: Double) -> String { "\(Int(value)) ml" }

private func day(current: Double, target: Double = 2000) -> ReminderContent.Day {
    ReminderContent.Day(currentMl: current, targetMl: target, startHour: 8, endHour: 22)
}

// MARK: - Message

@Test func anOnTrackReminderSaysWhatIsLeft() {
    // 15 h : la moitié de la journée active, 1 200 ml bus sur 2 000.
    let message = ReminderContent.message(at: at(15), now: at(14), day: day(current: 1200),
                                          calendar: utc, format: ml)
    #expect(!message.isBehind)
    #expect(message.body.contains("800 ml"))
    #expect(message.body.contains("1200 ml"))
}

@Test func aBehindReminderSaysWhereYouShouldBe() {
    // 15 h : 1 000 ml attendus, 400 bus.
    let message = ReminderContent.message(at: at(15), now: at(14), day: day(current: 400),
                                          calendar: utc, format: ml)
    #expect(message.isBehind)
    #expect(message.body.contains("1000 ml"))
}

@Test func tomorrowsReminderStaysGeneric() {
    let message = ReminderContent.message(at: at(day: 16, 9), now: at(21), day: day(current: 400),
                                          calendar: utc, format: ml)
    #expect(!message.isBehind)
    #expect(!message.body.contains("ml"))
}

// MARK: - Dernier appel

@Test func theLastCallComesAnHourBeforeTheEnd() {
    #expect(ReminderContent.lastCallDate(now: at(14), day: day(current: 400), calendar: utc) == at(21))
}

@Test func noLastCallOnceTheGoalIsReachedOrTooLate() {
    #expect(ReminderContent.lastCallDate(now: at(14), day: day(current: 2000), calendar: utc) == nil)
    #expect(ReminderContent.lastCallDate(now: at(21, 30), day: day(current: 400), calendar: utc) == nil)
}

@Test func theLastCallSaysWhatIsLeft() {
    #expect(ReminderContent.lastCallBody(day: day(current: 1500), format: ml).contains("500 ml"))
}

// MARK: - Saisie

@Test func aTypedAmountIsReadInTheDisplayedUnit() {
    let french = Locale(identifier: "fr_FR")
    #expect(ReminderContent.amountMl(fromTyped: "33", unit: .cl, locale: french) == 330)
    #expect(ReminderContent.amountMl(fromTyped: " 33 cl ", unit: .cl, locale: french) == 330)
    #expect(ReminderContent.amountMl(fromTyped: "0,5", unit: .liter, locale: french) == 500)
}

@Test func anUnreadableOrAbsurdAmountIsIgnored() {
    #expect(ReminderContent.amountMl(fromTyped: "beaucoup", unit: .cl) == nil)
    #expect(ReminderContent.amountMl(fromTyped: "999999", unit: .ml) == nil)
}
