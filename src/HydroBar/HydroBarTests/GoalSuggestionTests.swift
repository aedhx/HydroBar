//
//  GoalSuggestionTests.swift
//  HydroBarTests
//
//  Suggestion d'objectif à partir du poids (F21).
//

import Testing
import Foundation
@testable import HydroBar

@Test func suggestsAbout30MillilitersPerKilogramRoundedTo50() {
    #expect(GoalSuggestion.goalMl(forWeightKg: 70) == 2100)
    #expect(GoalSuggestion.goalMl(forWeightKg: 62) == 1850)   // 1 860 → 1 850
    #expect(GoalSuggestion.goalMl(forWeightKg: 85) == 2550)
}

@Test func staysWithinTheGoalBounds() {
    #expect(GoalSuggestion.goalMl(forWeightKg: 300) == 9000)
    let suggestion = GoalSuggestion.goalMl(forWeightKg: 25)
    #expect(suggestion.map { HydrationLimits.goal.contains($0) } == true)
}

@Test func refusesImplausibleWeights() {
    #expect(GoalSuggestion.goalMl(forWeightKg: 0) == nil)
    #expect(GoalSuggestion.goalMl(forWeightKg: 5) == nil)
    #expect(GoalSuggestion.goalMl(forWeightKg: 900) == nil)
    #expect(GoalSuggestion.goalMl(forWeightKg: .nan) == nil)
}

@Test func convertsPoundsToKilograms() {
    #expect(abs(GoalSuggestion.kilograms(fromPounds: 154) - 69.85) < 0.01)
}

@Test func usesPoundsOnlyWhereTheUSSystemIsTheNorm() {
    #expect(GoalSuggestion.prefersPounds(locale: Locale(identifier: "en_US")))
    #expect(!GoalSuggestion.prefersPounds(locale: Locale(identifier: "fr_FR")))
    #expect(!GoalSuggestion.prefersPounds(locale: Locale(identifier: "en_GB")))
}
