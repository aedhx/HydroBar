//
//  DeepLinkParserTests.swift
//  HydroBarTests
//
//  Couvre le parsing des deep links `hydrobar://`.
//  `DeepLinkParser.parse` est une fonction pure : ces tests ne touchent ni
//  UserDefaults, ni le disque, ni l'UI.
//

import Testing
import Foundation
@testable import HydroBar

private func parse(_ string: String) throws -> DeepLinkAction {
    try DeepLinkParser.parse(URL(string: string)!)
}

private func error(_ string: String) -> DeepLinkError? {
    do {
        _ = try parse(string)
        return nil
    } catch let error as DeepLinkError {
        return error
    } catch {
        return nil
    }
}

// MARK: - Compatibilité avec l'extension Raycast existante

@Test func parsesFormsAlreadyUsedByRaycast() throws {
    #expect(try parse("hydrobar://add?ml=250") == .add(ml: 250))
    #expect(try parse("hydrobar://add/preset/0") == .addPreset(index: 0))
    #expect(try parse("hydrobar://add/preset/1") == .addPreset(index: 1))
    #expect(try parse("hydrobar://add/preset/2") == .addPreset(index: 2))
}

// MARK: - Unités

@Test func convertsEverySupportedUnitToMilliliters() throws {
    #expect(try parse("hydrobar://add?ml=250") == .add(ml: 250))
    #expect(try parse("hydrobar://add?cl=25") == .add(ml: 250))
    #expect(try parse("hydrobar://add?l=0.25") == .add(ml: 250))

    // L'once suit la conversion d'AppUnit, pour que deep links et UI concordent.
    guard case .add(let ml) = try parse("hydrobar://add?oz=8") else {
        Issue.record("attendu .add"); return
    }
    #expect(abs(ml - AppUnit.oz.toMl(8)) < 0.001)
}

@Test func rejectsSeveralUnitsAtOnce() {
    #expect(error("hydrobar://add?ml=250&cl=25") == .ambiguousUnit)
    #expect(error("hydrobar://add?preset=1&ml=250") == .ambiguousUnit)
}

@Test func rejectsMissingAmount() {
    #expect(error("hydrobar://add") == .invalidAmount)
}

// MARK: - Validation des quantités

@Test func rejectsAmountsOutsideLimits() {
    #expect(error("hydrobar://add?ml=0") == .invalidAmount)
    #expect(error("hydrobar://add?ml=-5") == .invalidAmount)
    #expect(error("hydrobar://add?ml=99999") == .invalidAmount)
}

@Test func rejectsNonNumericAndNonFiniteAmounts() {
    // `Double("inf")` et `Double("nan")` réussissent : sans le test .isFinite,
    // ces valeurs se propagent jusqu'à un Int(NaN) qui piège à l'exécution.
    #expect(error("hydrobar://add?ml=abc") == .invalidAmount)
    #expect(error("hydrobar://add?ml=inf") == .invalidAmount)
    #expect(error("hydrobar://add?ml=nan") == .invalidAmount)
    #expect(error("hydrobar://add?ml=") == .invalidAmount)
}

@Test func acceptsAmountsExactlyOnTheBounds() throws {
    #expect(try parse("hydrobar://add?ml=1") == .add(ml: HydrationLimits.single.lowerBound))
    #expect(try parse("hydrobar://add?ml=5000") == .add(ml: HydrationLimits.single.upperBound))
}

// MARK: - Presets

@Test func mapsOneBasedQueryFormOntoZeroBasedIndex() throws {
    #expect(try parse("hydrobar://add?preset=1") == .addPreset(index: 0))
    #expect(try parse("hydrobar://add?preset=3") == .addPreset(index: 2))
}

@Test func rejectsInvalidPresetIndexes() {
    #expect(error("hydrobar://add?preset=0") == .presetOutOfRange)   // 1-based : 0 invalide
    #expect(error("hydrobar://add/preset/-1") == .presetOutOfRange)
    #expect(error("hydrobar://add/preset/abc") == .presetOutOfRange)
}

// MARK: - Actions destructives

@Test func requiresConfirmationForDestructiveActions() {
    #expect(error("hydrobar://reset") == .confirmationRequired)
    #expect(error("hydrobar://set-goal?ml=2500") == .confirmationRequired)
    #expect(error("hydrobar://reset?confirm=0") == .confirmationRequired)
}

@Test func acceptsDestructiveActionsOnceConfirmed() throws {
    #expect(try parse("hydrobar://reset?confirm=1") == .reset)
    #expect(try parse("hydrobar://set-goal?ml=2500&confirm=1") == .setGoal(ml: 2500))
    #expect(try parse("hydrobar://set-goal?l=2.5&confirm=1") == .setGoal(ml: 2500))
}

@Test func appliesGoalLimitsNotSingleAddLimits() {
    // 8 000 ml dépasse la limite d'un ajout unique mais reste un objectif valide.
    #expect(error("hydrobar://add?ml=8000") == .invalidAmount)
    #expect(error("hydrobar://set-goal?ml=8000&confirm=1") == nil)
    #expect(error("hydrobar://set-goal?ml=100&confirm=1") == .invalidAmount)
}

// MARK: - Navigation

@Test func parsesNavigationTargets() throws {
    #expect(try parse("hydrobar://open") == .open(.main))
    #expect(try parse("hydrobar://open/today") == .open(.main))
    #expect(try parse("hydrobar://open/stats") == .open(.statistics))
    #expect(try parse("hydrobar://open/statistics") == .open(.statistics))
    #expect(try parse("hydrobar://open/settings") == .open(.settings))
}

@Test func rejectsUnknownNavigationTarget() {
    #expect(error("hydrobar://open/nope") == .unknownAction)
}

// MARK: - Actions inconnues et robustesse

@Test func rejectsUnknownActionsAndForeignSchemes() {
    #expect(error("hydrobar://delete-everything") == .unknownAction)
    #expect(error("hydrobar://") == .unknownAction)
    #expect(error("https://add?ml=250") == .unknownAction)
    #expect(error("hydrobar://add/unexpected/path") == .unknownAction)
}

@Test func isCaseInsensitiveOnActionAndParameterNames() throws {
    #expect(try parse("hydrobar://ADD?ML=250") == .add(ml: 250))
    #expect(try parse("hydrobar://Open/Stats") == .open(.statistics))
}

@Test func firstOccurrenceWinsOnDuplicatedParameters() throws {
    // Un doublon ne doit pas permettre d'écraser la valeur initiale.
    #expect(try parse("hydrobar://add?ml=250&ml=4000") == .add(ml: 250))
}

@Test func undoNeedsNoParameters() throws {
    #expect(try parse("hydrobar://undo") == .undo)
}
