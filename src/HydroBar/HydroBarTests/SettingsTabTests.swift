//
//  SettingsTabTests.swift
//  HydroBarTests
//
//  Onglet des réglages retrouvé à la réouverture : les réglages sont passés
//  de sept onglets à quatre, et l'onglet mémorisé peut porter un ancien nom.
//

import Testing
@testable import HydroBar

@Test func storedTabIsRestored() {
    for tab in SettingsTab.allCases {
        #expect(SettingsTab(storedValue: tab.rawValue) == tab)
    }
}

@Test func formerTabsOpenThePageThatTookTheirContent() {
    #expect(SettingsTab(storedValue: "data") == .general)
    #expect(SettingsTab(storedValue: "days") == .reminders)
    #expect(SettingsTab(storedValue: "integrations") == .shortcuts)
}

@Test func unknownOrMissingTabFallsBackToGeneral() {
    #expect(SettingsTab(storedValue: nil) == .general)
    #expect(SettingsTab(storedValue: "") == .general)
    #expect(SettingsTab(storedValue: "advanced") == .general)
}
