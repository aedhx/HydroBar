//
//  NumberInputTests.swift
//  HydroBarTests
//
//  Lecture des nombres saisis dans les réglages. Les champs utilisaient
//  Double(String), qui ignore la locale : « 1,5 » était refusé en français.
//

import Testing
import Foundation
@testable import HydroBar

private let french = Locale(identifier: "fr_FR")
private let english = Locale(identifier: "en_US")

// MARK: - Séparateur décimal de la locale

@Test func readsTheLocaleDecimalSeparator() {
    #expect(NumberInput.parse("1,5", locale: french) == 1.5)
    #expect(NumberInput.parse("0,75", locale: french) == 0.75)
    #expect(NumberInput.parse("1.5", locale: english) == 1.5)
}

// MARK: - L'autre séparateur

@Test func readsTheOtherSeparatorAsDecimalWhenFollowedByOneOrTwoDigits() {
    // Un francophone sur un clavier anglais, et inversement.
    #expect(NumberInput.parse("1.5", locale: french) == 1.5)
    #expect(NumberInput.parse("1,5", locale: english) == 1.5)
    #expect(NumberInput.parse("12,34", locale: english) == 12.34)
}

@Test func readsTheOtherSeparatorAsGroupingWhenFollowedByThreeDigits() {
    #expect(NumberInput.parse("1.500", locale: french) == 1500)
    #expect(NumberInput.parse("1,500", locale: english) == 1500)
    #expect(NumberInput.parse("2,000,000", locale: english) == 2_000_000)
}

@Test func readsGroupingAndDecimalTogether() {
    #expect(NumberInput.parse("1.500,5", locale: french) == 1500.5)
    #expect(NumberInput.parse("1,500.5", locale: english) == 1500.5)
}

// MARK: - Espaces

@Test func ignoresSpacesUsedAsGroupingSeparators() {
    #expect(NumberInput.parse("1 500", locale: french) == 1500)
    #expect(NumberInput.parse("1\u{00A0}500", locale: french) == 1500)
    #expect(NumberInput.parse("1\u{202F}500,5", locale: french) == 1500.5)
    #expect(NumberInput.parse("  250 ", locale: english) == 250)
}

// MARK: - Rejets

@Test func rejectsEmptyAndNonNumericInput() {
    #expect(NumberInput.parse("", locale: french) == nil)
    #expect(NumberInput.parse("   ", locale: french) == nil)
    #expect(NumberInput.parse("abc", locale: english) == nil)
    #expect(NumberInput.parse("1,2,3", locale: french) == nil)
}

@Test func rejectsNonFiniteValues() {
    #expect(NumberInput.parse("inf", locale: english) == nil)
    #expect(NumberInput.parse("nan", locale: english) == nil)
}

// MARK: - Mise en forme

@Test func formatsFieldTextWithoutGroupingSoItReadsBack() throws {
    let text = NumberInput.fieldText(1500, fractionDigits: 0...0, locale: french)
    #expect(text == "1500")
    #expect(NumberInput.parse(text, locale: french) == 1500)
}

@Test func formatsFieldTextWithTheLocaleDecimalSeparator() {
    #expect(NumberInput.fieldText(1.5, fractionDigits: 0...2, locale: french) == "1,5")
    #expect(NumberInput.fieldText(0.25, fractionDigits: 0...2, locale: english) == "0.25")
    #expect(NumberInput.fieldText(2, fractionDigits: 0...2, locale: english) == "2")
}
