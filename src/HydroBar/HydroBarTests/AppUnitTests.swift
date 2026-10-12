//
//  AppUnitTests.swift
//  HydroBarTests
//
//  Couvre la conversion et le formatage partagés entre l'app et le widget.
//  Les locales sont fixées explicitement : le résultat ne doit pas dépendre de
//  la langue de la machine qui exécute les tests.
//

import Testing
import Foundation
@testable import HydroBar

private let english = Locale(identifier: "en_US")
private let french = Locale(identifier: "fr_FR")

// MARK: - Conversions

@Test func everyUnitRoundTripsThroughMilliliters() {
    for unit in AppUnit.allCases {
        for value in [0.0, 1.0, 2.5, 250.0, 1234.5] {
            #expect(abs(unit.fromMl(unit.toMl(value)) - value) < 1e-9, "\(unit) \(value)")
        }
    }
}

@Test func usesLegallyExactFactors() {
    #expect(AppUnit.ml.toMl(1) == 1)
    #expect(AppUnit.cl.toMl(1) == 10)
    #expect(AppUnit.liter.toMl(1) == 1000)
    #expect(AppUnit.oz.toMl(1) == 29.5735295625)
    #expect(AppUnit.ozUK.toMl(1) == 28.4130625)
}

@Test func distinguishesUSAndUKFluidOunces() {
    // L'once britannique est ~4 % plus petite : la confondre faussait les valeurs.
    let ratio = AppUnit.ozUK.toMl(1) / AppUnit.oz.toMl(1)
    #expect(ratio > 0.95 && ratio < 0.97)
}

@Test func keepsRawValuesStableForStoredPreferences() {
    // Ces valeurs sont persistées : les changer casserait les préférences existantes.
    #expect(AppUnit(rawValue: "cl") == .cl)
    #expect(AppUnit(rawValue: "L") == .liter)
    #expect(AppUnit(rawValue: "oz") == .oz)
}

@Test func offersMilliliters() {
    // Le README promettait le ml ; l'app ne le proposait pas.
    #expect(AppUnit.allCases.contains(.ml))
}

// MARK: - Formatage

@Test func formatsEachUnitInEnglish() {
    #expect(AppUnit.ml.format(ml: 250, locale: english) == "250 ml")
    #expect(AppUnit.cl.format(ml: 250, locale: english) == "25 cl")
    #expect(AppUnit.cl.format(ml: 255, locale: english) == "25.5 cl")
    #expect(AppUnit.liter.format(ml: 2000, locale: english) == "2 L")
    #expect(AppUnit.liter.format(ml: 1500, locale: english) == "1.5 L")
    #expect(AppUnit.liter.format(ml: 250, locale: english) == "0.25 L")
    #expect(AppUnit.oz.format(ml: AppUnit.oz.toMl(8), locale: english) == "8 oz")
}

@Test func usesTheLocaleDecimalSeparator() {
    // Toutes les versions précédentes affichaient « 1.5 L », y compris en français.
    #expect(AppUnit.liter.format(ml: 1500, locale: french).contains("1,5"))
    #expect(!AppUnit.liter.format(ml: 1500, locale: french).contains("1.5"))
}

@Test func separatesNumberFromSymbolForKPICards() {
    // Les cartes KPI des statistiques affichent le nombre et l'unité séparément.
    #expect(AppUnit.cl.formattedNumber(ml: 1500, locale: english) == "150")
    #expect(AppUnit.cl.symbol == "cl")
    #expect(AppUnit.oz.symbol == AppUnit.ozUK.symbol)
}

@Test func neverSwitchesUnitsOnLargeValues() {
    // R2-7 : au-delà de 1 000 ml, les statistiques basculaient en litres, même
    // pour un utilisateur en onces. Le formateur reste dans l'unité demandée.
    #expect(AppUnit.oz.format(ml: 14_000, locale: english).hasSuffix(" oz"))
    #expect(AppUnit.ml.format(ml: 14_000, locale: english) == "14,000 ml")
}
