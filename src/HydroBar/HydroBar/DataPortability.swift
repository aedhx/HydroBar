//
//  DataPortability.swift
//  HydroBar
//
//  Export et import des données (roadmap F4). Des données qu'on ne peut pas
//  sortir sont des données prises en otage.
//
//  - CSV : un total par jour, pour un tableur.
//  - JSON : le journal complet, prise par prise — une sauvegarde qui se
//    réimporte sans rien compter deux fois.
//

import Foundation

enum DataPortability {

    // MARK: Export

    /// CSV quotidien : `date,amount_ml,target_ml,goal_reached`.
    ///
    /// Points fixes, pas de séparateur de milliers, dates ISO : le fichier doit
    /// s'ouvrir de la même façon dans un tableur français ou américain, et se
    /// relire par un script.
    static func dailyCSV(from log: IntakeLog, calendar: Calendar, defaultGoal: Double) -> String {
        var lines = ["date,amount_ml,target_ml,goal_reached"]
        for entry in log.dailyEntries(calendar: calendar, defaultGoal: defaultGoal) {
            let reached = entry.targetMl > 0 && entry.amountMl >= entry.targetMl
            lines.append([
                IntakeLog.dayKey(for: entry.date, calendar: calendar),
                number(entry.amountMl),
                number(entry.targetMl),
                reached ? "true" : "false",
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Sauvegarde JSON du journal complet.
    static func backupJSON(from log: IntakeLog) throws -> Data {
        let encoder = IntakeLogStore.encoder
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(log)
    }

    static func suggestedFileName(extension ext: String, date: Date, calendar: Calendar) -> String {
        "HydroBar-\(IntakeLog.dayKey(for: date, calendar: calendar)).\(ext)"
    }

    // MARK: Import

    enum ImportError: Error, Equatable {
        /// Ni une sauvegarde HydroBar, ni un ancien historique.
        case unrecognizedFormat
        /// Contient des quantités négatives, infinies ou démesurées.
        case invalidAmounts
    }

    /// Lit une sauvegarde : le journal de la v2, ou l'ancien historique
    /// (`historyEntries.json`) pour restaurer une sauvegarde de la v1.
    static func readBackup(_ data: Data, calendar: Calendar, defaultGoal: Double) throws -> IntakeLog {
        let decoder = IntakeLogStore.decoder
        let log: IntakeLog
        if let current = try? decoder.decode(IntakeLog.self, from: data) {
            log = current
        } else if let legacy = try? decoder.decode([HistoryEntry].self, from: data) {
            log = IntakeLog.migrating(history: legacy, pendingDay: nil, pendingMl: 0,
                                      defaultGoal: defaultGoal, calendar: calendar)
        } else {
            throw ImportError.unrecognizedFormat
        }

        // Un fichier importé vient de l'extérieur : mêmes bornes que la saisie.
        // Un événement agrégé représente une journée entière, d'où une borne
        // plus large que pour une prise.
        let valid = log.events.allSatisfy { event in
            let limit = event.isAggregate ? HydrationLimits.goal.upperBound * 2 : HydrationLimits.single.upperBound
            return event.amountMl.isFinite && event.amountMl > 0 && event.amountMl <= limit
        }
        guard valid else { throw ImportError.invalidAmounts }
        return log
    }

    // MARK: Formatage

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
