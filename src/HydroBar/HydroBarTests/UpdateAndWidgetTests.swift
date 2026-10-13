//
//  UpdateAndWidgetTests.swift
//  HydroBarTests
//
//  Comparaison de versions du vérificateur de mises à jour, instantané
//  partagé avec le widget, et affichage des raccourcis.
//

import Testing
import Foundation
import AppKit
@testable import HydroBar

// MARK: - Versions

@Test func detectsANewerVersion() {
    #expect(isVersionNewer(current: "1.0.0", latest: "1.1.0"))
    #expect(isVersionNewer(current: "1.9.0", latest: "1.10.0"))
    #expect(isVersionNewer(current: "1.0", latest: "1.0.1"))
}

@Test func ignoresTheTagPrefix() {
    #expect(isVersionNewer(current: "1.0.0", latest: "v1.0.1"))
    #expect(!isVersionNewer(current: "v1.0.1", latest: "1.0.1"))
}

@Test func doesNotOfferTheSameOrAnOlderVersion() {
    #expect(!isVersionNewer(current: "1.2.0", latest: "1.2.0"))
    #expect(!isVersionNewer(current: "1.2", latest: "1.2.0"))
    #expect(!isVersionNewer(current: "2.0.0", latest: "1.9.9"))
}

// MARK: - Instantané du widget

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func snapshot(at date: Date, presets: [Double]? = nil) -> HydrationSnapshot {
    HydrationSnapshot(currentMl: 1200, targetMl: 2000, unit: "cl",
                      lastUpdated: date, weekHistory: [], presetsMl: presets)
}

@Test func keepsTodaysTotalOnTheSameDay() {
    let morning = utc.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 9))!
    let evening = utc.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 23))!
    #expect(snapshot(at: morning).asOf(evening, calendar: utc).currentMl == 1200)
}

@Test func startsFromZeroAfterMidnight() {
    let evening = utc.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 23))!
    let midnight = utc.date(from: DateComponents(year: 2026, month: 9, day: 16))!
    let rolled = snapshot(at: evening, presets: [250]).asOf(midnight, calendar: utc)
    #expect(rolled.currentMl == 0)
    #expect(rolled.targetMl == 2000)
    #expect(rolled.presetsMl == [250])
}

@Test func showsTheUsersPresetsInTheWidget() {
    #expect(snapshot(at: .now, presets: [150, 330, 1000, 2000]).widgetPresetsMl == [150, 330, 1000])
}

@Test func fallsBackToDefaultPresetsForOlderSnapshots() throws {
    #expect(snapshot(at: .now, presets: nil).widgetPresetsMl == HydrationSnapshot.defaultPresetsMl)

    // Un instantané écrit avant l'ajout du champ doit rester décodable.
    let legacy = #"{"currentMl":500,"targetMl":2000,"unit":"ml","lastUpdated":0,"weekHistory":[]}"#
    let decoded = try JSONDecoder().decode(HydrationSnapshot.self, from: Data(legacy.utf8))
    #expect(decoded.presetsMl == nil)
    #expect(decoded.widgetPresetsMl == HydrationSnapshot.defaultPresetsMl)
}

// MARK: - Raccourcis

@Test func displaysShortcutsWithModifierSymbols() {
    let modifiers = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
    #expect(Shortcut(keyCode: VirtualKeyCodes.p, modifiers: modifiers).displayString == "⇧ ⌘ P")
    #expect(Shortcut(keyCode: VirtualKeyCodes.f5, modifiers: 0).displayString == "F5")
}

@Test func fallsBackToTheRawCodeForUnmappedKeys() {
    // 0x7E : flèche haut, absente de la table des symboles.
    #expect(Shortcut(keyCode: 0x7E, modifiers: 0).displayString == "Key(126)")
}
