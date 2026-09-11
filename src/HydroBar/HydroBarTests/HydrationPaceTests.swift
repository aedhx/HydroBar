//
//  HydrationPaceTests.swift
//  HydroBarTests
//
//  Couvre le calcul de l'allure attendue (repère de l'anneau).
//  `HydrationPace` est pur : ces tests n'ont besoin ni de l'app, ni du disque.
//

import Testing
import Foundation
@testable import HydroBar

/// Calendrier et horloge fixes : le résultat ne doit pas dépendre du fuseau
/// de la machine qui exécute les tests.
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func at(_ hour: Int, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(timeZone: TimeZone(identifier: "UTC"),
                                  year: 2026, month: 9, day: 11,
                                  hour: hour, minute: minute))!
}

private func fraction(_ hour: Int, _ minute: Int = 0,
                      from start: Int = 8, to end: Int = 22) -> Double? {
    HydrationPace.expectedFraction(at: at(hour, minute),
                                   startHour: start, endHour: end,
                                   calendar: utc)
}

// MARK: - Progression dans la plage

@Test func noMarkerBeforeTheWindowOpens() {
    // Rien n'est encore attendu à 6 h : afficher un repère à 0 % serait du bruit.
    #expect(fraction(6) == nil)
    #expect(fraction(7, 59) == nil)
}

@Test func startsAtZeroWhenTheWindowOpens() throws {
    let value = try #require(fraction(8))
    #expect(value == 0)
}

@Test func reachesHalfwayAtTheMiddleOfTheWindow() throws {
    // 8 h → 22 h : le milieu est 15 h.
    let value = try #require(fraction(15))
    #expect(abs(value - 0.5) < 0.001)
}

@Test func progressesLinearlyWithinTheWindow() throws {
    // 9 h = 1 h écoulée sur 14 h de plage.
    let value = try #require(fraction(9))
    #expect(abs(value - 1.0 / 14.0) < 0.001)
}

@Test func accountsForMinutesNotOnlyHours() throws {
    let onTheHour = try #require(fraction(9))
    let halfPast = try #require(fraction(9, 30))
    #expect(halfPast > onTheHour)
}

@Test func expectsTheFullGoalAfterTheWindowCloses() {
    #expect(fraction(22) == 1.0)
    #expect(fraction(23, 30) == 1.0)
}

// MARK: - Plages invalides

@Test func rejectsWindowsThatWouldCrossMidnight() {
    // La journée est remise à zéro à minuit : une plage à cheval porterait sur
    // deux journées de données différentes.
    #expect(fraction(23, 0, from: 22, to: 6) == nil)
}

@Test func rejectsEmptyAndOutOfBoundsWindows() {
    #expect(fraction(12, 0, from: 10, to: 10) == nil)
    #expect(fraction(12, 0, from: -1, to: 22) == nil)
    #expect(fraction(12, 0, from: 8, to: 25) == nil)
    #expect(fraction(12, 0, from: 24, to: 24) == nil)
}

@Test func acceptsTheWidestValidWindow() throws {
    let value = try #require(fraction(12, 0, from: 0, to: 24))
    #expect(abs(value - 0.5) < 0.001)
}

// MARK: - Déficit

@Test func reportsNoDeficitWhenAheadOrExactlyOnTrack() {
    #expect(HydrationPace.deficitMl(currentMl: 1000, targetMl: 2000, expectedFraction: 0.5) == nil)
    #expect(HydrationPace.deficitMl(currentMl: 1500, targetMl: 2000, expectedFraction: 0.5) == nil)
}

@Test func reportsTheMissingAmountWhenBehind() throws {
    let deficit = try #require(HydrationPace.deficitMl(currentMl: 600, targetMl: 2000, expectedFraction: 0.5))
    #expect(abs(deficit - 400) < 0.001)
}

@Test func reportsNoDeficitOutsideTheWindow() {
    // Pas de fraction attendue → pas de jugement sur l'avance ou le retard.
    #expect(HydrationPace.deficitMl(currentMl: 0, targetMl: 2000, expectedFraction: nil) == nil)
}

@Test func reportsNoDeficitWhenTheGoalIsZero() {
    // Garde-fou : sans elle, un objectif nul produirait un déficit absurde.
    #expect(HydrationPace.deficitMl(currentMl: 0, targetMl: 0, expectedFraction: 0.5) == nil)
}
