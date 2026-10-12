//
//  IntakeLogTests.swift
//  HydroBarTests
//
//  Journal des prises (F5) : agrégation par jour, annulation, fusion, et
//  migration depuis l'ancien format. `IntakeLog` est pur ; `IntakeLogStore`
//  travaille ici dans un dossier temporaire.
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

private func event(day: Int, _ hour: Int, _ ml: Double) -> IntakeEvent {
    IntakeEvent(date: at(day: day, hour), amountMl: ml)
}

// MARK: - Agrégation

@Test func totalsOnlyTheRequestedDay() {
    let log = IntakeLog(events: [event(day: 14, 23, 300), event(day: 15, 0, 200), event(day: 15, 9, 250)])
    #expect(log.total(on: at(day: 15, 12), calendar: utc) == 450)
    #expect(log.total(on: at(day: 14, 12), calendar: utc) == 300)
}

@Test func aGlassJustAfterMidnightBelongsToTheNewDay() {
    // Régression R3-5 : le verre de 0 h 05 était compté la veille.
    let log = IntakeLog(events: [IntakeEvent(date: at(day: 15, 0, 5), amountMl: 250)])
    #expect(log.total(on: at(day: 14, 12), calendar: utc) == 0)
    #expect(log.total(on: at(day: 15, 12), calendar: utc) == 250)
}

@Test func keepsEventsSortedWhatEverTheInsertionOrder() {
    var log = IntakeLog()
    log.add(event(day: 15, 14, 100))
    log.add(event(day: 15, 9, 200))
    log.add(event(day: 15, 11, 300))
    #expect(log.events.map(\.amountMl) == [200, 300, 100])
}

@Test func buildsOneHistoryEntryPerDayWithThatDaysGoal() throws {
    var log = IntakeLog(events: [event(day: 13, 9, 1000), event(day: 13, 15, 500), event(day: 14, 10, 800)])
    log.setGoal(1500, on: at(day: 13, 0), calendar: utc)

    let entries = log.dailyEntries(calendar: utc, defaultGoal: 2000)
    #expect(entries.count == 2)
    let first = try #require(entries.first)
    #expect(first.amountMl == 1500)
    #expect(first.targetMl == 1500)
    // Pas d'objectif noté le 14 : l'objectif par défaut s'applique.
    #expect(entries.last?.targetMl == 2000)
}

// MARK: - Suppression et annulation

@Test func removesASingleEventAndCanPutItBack() throws {
    let lunch = event(day: 15, 12, 500)
    var log = IntakeLog(events: [event(day: 15, 9, 250), lunch])

    let removedEvent = log.remove(id: lunch.id)
    let removed = try #require(removedEvent)
    #expect(log.total(on: at(day: 15, 0), calendar: utc) == 250)

    log.restore([removed])
    #expect(log.total(on: at(day: 15, 0), calendar: utc) == 750)
}

@Test func resettingADayLeavesOtherDaysUntouched() {
    var log = IntakeLog(events: [event(day: 14, 9, 400), event(day: 15, 9, 250), event(day: 15, 10, 250)])
    let removed = log.removeEvents(on: at(day: 15, 0), calendar: utc)
    #expect(removed.count == 2)
    #expect(log.total(on: at(day: 15, 0), calendar: utc) == 0)
    #expect(log.total(on: at(day: 14, 0), calendar: utc) == 400)
}

@Test func restoringTwiceDoesNotDuplicate() {
    let glass = event(day: 15, 9, 250)
    var log = IntakeLog(events: [glass])
    log.restore([glass])
    #expect(log.events.count == 1)
}

// MARK: - Fusion (import)

@Test func mergingTheSameBackupTwiceCountsNothingTwice() {
    let backup = IntakeLog(events: [event(day: 14, 9, 400), event(day: 15, 9, 250)])
    var log = IntakeLog(events: [event(day: 15, 11, 300)])

    #expect(log.merge(backup) == 2)
    #expect(log.merge(backup) == 0)
    #expect(log.total(on: at(day: 15, 0), calendar: utc) == 550)
}

@Test func mergingKeepsTheGoalsAlreadyKnown() {
    var log = IntakeLog()
    log.setGoal(2500, on: at(day: 15, 0), calendar: utc)
    var backup = IntakeLog()
    backup.setGoal(1800, on: at(day: 15, 0), calendar: utc)
    backup.setGoal(1900, on: at(day: 14, 0), calendar: utc)

    log.merge(backup)
    #expect(log.goal(on: at(day: 15, 0), calendar: utc) == 2500)
    #expect(log.goal(on: at(day: 14, 0), calendar: utc) == 1900)
}

// MARK: - Migration depuis la v1

@Test func migratesEachPastDayToOneAggregateEventAtNoon() throws {
    let history = [
        HistoryEntry(date: at(day: 13, 0), amountMl: 1800, targetMl: 2000),
        HistoryEntry(date: at(day: 14, 0), amountMl: 2200, targetMl: 2500),
    ]
    let log = IntakeLog.migrating(history: history, pendingDay: nil, pendingMl: 0,
                                  defaultGoal: 2000, calendar: utc)

    #expect(log.events.count == 2)
    // Calculé hors de #expect : la macro traite allSatisfy (rethrows) comme
    // un appel qui peut lever une erreur.
    let allAggregate = log.events.allSatisfy { $0.isAggregate }
    #expect(allAggregate)
    let first = try #require(log.events.first)
    #expect(utc.component(.hour, from: first.date) == 12)
    #expect(log.goal(on: at(day: 14, 0), calendar: utc) == 2500)
}

@Test func thePendingTotalWinsOverAStaleArchivedEntryForTheSameDay() {
    // L'entrée archivée du 15 date de la dernière écriture différée ; le total
    // en cours dans UserDefaults est plus récent.
    let history = [HistoryEntry(date: at(day: 15, 0), amountMl: 500, targetMl: 2000)]
    let log = IntakeLog.migrating(history: history, pendingDay: at(day: 15, 8), pendingMl: 750,
                                  defaultGoal: 2000, calendar: utc)
    #expect(log.total(on: at(day: 15, 0), calendar: utc) == 750)
}

@Test func emptyDaysAreNotMigratedAsEvents() {
    let history = [HistoryEntry(date: at(day: 13, 0), amountMl: 0, targetMl: 2000)]
    let log = IntakeLog.migrating(history: history, pendingDay: nil, pendingMl: 0,
                                  defaultGoal: 2000, calendar: utc)
    #expect(log.events.isEmpty)
    #expect(log.goal(on: at(day: 13, 0), calendar: utc) == 2000)
}

// MARK: - Stockage

private func temporaryStore() throws -> IntakeLogStore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("HydroBarTests-\(UUID().uuidString)", isDirectory: true)
    return IntakeLogStore(directory: directory)
}

@Test func reportsAMissingLogOnFirstLaunch() throws {
    let store = try temporaryStore()
    #expect(store.load() == .missing)
}

@Test func savesAndReloadsTheLogUnchanged() throws {
    let store = try temporaryStore()
    var log = IntakeLog(events: [event(day: 15, 9, 250), event(day: 15, 13, 500)])
    log.setGoal(2200, on: at(day: 15, 0), calendar: utc)

    try store.save(log)
    #expect(store.load() == .loaded(log))
}

@Test func setsACorruptLogAsideInsteadOfOverwritingIt() throws {
    let store = try temporaryStore()
    try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
    try Data("{ pas du json".utf8).write(to: store.fileURL)

    guard case .corrupt(let backupName) = store.load() else {
        Issue.record("Un fichier illisible doit être signalé")
        return
    }
    let name = try #require(backupName)
    #expect(FileManager.default.fileExists(atPath: store.directory.appendingPathComponent(name).path))
    #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
}

@Test func readsTheLegacyHistoryFile() throws {
    let store = try temporaryStore()
    try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
    let legacy = [HistoryEntry(date: at(day: 14, 0), amountMl: 1500, targetMl: 2000)]
    try IntakeLogStore.encoder.encode(legacy).write(to: store.legacyHistoryURL)

    let read = try #require(store.loadLegacyHistory())
    #expect(read.count == 1)
    #expect(read.first?.amountMl == 1500)
}

@Test func decodesEventsWrittenWithoutTheAggregateFlag() throws {
    let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":"2026-09-15T09:00:00Z","amountMl":250}"#
    let decoded = try IntakeLogStore.decoder.decode(IntakeEvent.self, from: Data(json.utf8))
    #expect(decoded.amountMl == 250)
    #expect(!decoded.isAggregate)
}

// MARK: - Mode gourde

@Test func countsOnlyTheCurrentBottleOfTheDay() {
    let events = [
        IntakeEvent(date: at(day: 15, 9), amountMl: 375, bottle: 1),
        IntakeEvent(date: at(day: 15, 10), amountMl: 250),               // prise ordinaire
        IntakeEvent(date: at(day: 15, 14), amountMl: 200, bottle: 2),
        IntakeEvent(date: at(day: 14, 9), amountMl: 500, bottle: 1),     // la veille
    ]
    #expect(Bottle.drunkMl(events: events, bottle: 1, on: at(day: 15, 0), calendar: utc) == 375)
    #expect(Bottle.drunkMl(events: events, bottle: 2, on: at(day: 15, 0), calendar: utc) == 200)
}

@Test func logsOnlyTheDifferenceToTheNextLevel() {
    // Gourde de 750 ml, déjà bue à moitié : passer aux trois quarts ajoute un quart.
    #expect(Bottle.amountToReach(fraction: 0.75, drunkMl: 375, capacityMl: 750) == 188)
    #expect(Bottle.amountToReach(fraction: 1, drunkMl: 375, capacityMl: 750) == 375)
}

@Test func doesNotLogALevelAlreadyReached() {
    #expect(Bottle.amountToReach(fraction: 0.5, drunkMl: 375, capacityMl: 750) == nil)
    #expect(Bottle.amountToReach(fraction: 0.25, drunkMl: 500, capacityMl: 750) == nil)
}

@Test func storesTheBottleNumberWithTheEvent() throws {
    let event = IntakeEvent(date: at(day: 15, 9), amountMl: 375, bottle: 2)
    let data = try IntakeLogStore.encoder.encode(event)
    let decoded = try IntakeLogStore.decoder.decode(IntakeEvent.self, from: data)
    #expect(decoded.bottle == 2)
}
