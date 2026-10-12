//
//  DataPortabilityTests.swift
//  HydroBarTests
//
//  Export CSV, sauvegarde et restauration JSON (F4).
//

import Testing
import Foundation
@testable import HydroBar

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func at(day: Int, _ hour: Int) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
}

private func sampleLog() -> IntakeLog {
    var log = IntakeLog(events: [
        IntakeEvent(date: at(day: 14, 9), amountMl: 1200),
        IntakeEvent(date: at(day: 14, 15), amountMl: 1000),
        IntakeEvent(date: at(day: 15, 10), amountMl: 333.3),
    ])
    log.setGoal(2000, on: at(day: 14, 0), calendar: utc)
    return log
}

// MARK: - CSV

@Test func exportsOneCSVLinePerDayWithAHeader() {
    let csv = DataPortability.dailyCSV(from: sampleLog(), calendar: utc, defaultGoal: 2500)
    #expect(csv == """
        date,amount_ml,target_ml,goal_reached
        2026-09-14,2200,2000,true
        2026-09-15,333.3,2500,false

        """)
}

@Test func writesDecimalsWithAPointWhateverTheLocale() {
    // Une virgule décimale casserait les colonnes du CSV.
    let csv = DataPortability.dailyCSV(from: sampleLog(), calendar: utc, defaultGoal: 2500)
    #expect(!csv.contains("333,3"))
}

// MARK: - Sauvegarde et restauration

@Test func aBackupRestoresExactly() throws {
    let log = sampleLog()
    let data = try DataPortability.backupJSON(from: log)
    let restored = try DataPortability.readBackup(data, calendar: utc, defaultGoal: 2000)
    #expect(restored.events.map(\.id) == log.events.map(\.id))
    #expect(restored.goal(on: at(day: 14, 0), calendar: utc) == 2000)
}

@Test func restoresAVersionOneHistoryFile() throws {
    let legacy = [HistoryEntry(date: at(day: 14, 0), amountMl: 1800, targetMl: 2000)]
    let data = try IntakeLogStore.encoder.encode(legacy)
    let restored = try DataPortability.readBackup(data, calendar: utc, defaultGoal: 2000)
    #expect(restored.total(on: at(day: 14, 0), calendar: utc) == 1800)
}

@Test func rejectsFilesThatAreNotBackups() {
    #expect(throws: DataPortability.ImportError.unrecognizedFormat) {
        try DataPortability.readBackup(Data(#"{"hello":"world"}"#.utf8), calendar: utc, defaultGoal: 2000)
    }
}

@Test func rejectsBackupsWithImpossibleAmounts() throws {
    let log = IntakeLog(events: [IntakeEvent(date: at(day: 14, 9), amountMl: 99_999)])
    let data = try DataPortability.backupJSON(from: log)
    #expect(throws: DataPortability.ImportError.invalidAmounts) {
        try DataPortability.readBackup(data, calendar: utc, defaultGoal: 2000)
    }
}

@Test func suggestsADatedFileName() {
    #expect(DataPortability.suggestedFileName(extension: "csv", date: at(day: 15, 10), calendar: utc)
            == "HydroBar-2026-09-15.csv")
}
