//
//  IntakeLogStore.swift
//  HydroBar
//
//  Persistance du journal des prises. Le dossier est injecté : les tests
//  travaillent dans un dossier temporaire, l'app dans Application Support.
//

import Foundation

struct IntakeLogStore {

    static let fileName = "intakeLog.json"
    /// Ancien format, un total par jour. Lu une seule fois, pour la migration,
    /// puis laissé en place : on ne détruit pas un fichier utilisateur.
    static let legacyHistoryFileName = "historyEntries.json"

    let directory: URL
    var fileManager: FileManager = .default

    /// Application Support/HydroBar, créé au besoin.
    static func applicationSupport() -> IntakeLogStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return IntakeLogStore(directory: base.appendingPathComponent("HydroBar", isDirectory: true))
    }

    var fileURL: URL { directory.appendingPathComponent(Self.fileName) }
    var legacyHistoryURL: URL { directory.appendingPathComponent(Self.legacyHistoryFileName) }

    // MARK: Lecture

    enum LoadResult: Equatable {
        /// Aucun journal : premier lancement, ou migration à faire.
        case missing
        case loaded(IntakeLog)
        /// Fichier présent mais illisible, mis de côté sous ce nom (`nil` si le
        /// renommage a échoué lui aussi).
        case corrupt(backupName: String?)
    }

    func load() -> LoadResult {
        guard fileManager.fileExists(atPath: fileURL.path) else { return .missing }
        do {
            let data = try Data(contentsOf: fileURL)
            return .loaded(try Self.decoder.decode(IntakeLog.self, from: data))
        } catch {
            return .corrupt(backupName: quarantine(fileURL))
        }
    }

    /// Ancien historique, ou `nil` s'il n'existe pas ou ne se lit pas. Un fichier
    /// illisible n'est pas mis de côté ici : il n'est plus jamais réécrit.
    func loadLegacyHistory() -> [HistoryEntry]? {
        guard let data = try? Data(contentsOf: legacyHistoryURL) else { return nil }
        return try? Self.decoder.decode([HistoryEntry].self, from: data)
    }

    // MARK: Écriture

    /// Écriture atomique : un fichier temporaire renommé à la fin, jamais un
    /// JSON à moitié écrit (cf. AUDIT § P3-3).
    func save(_ log: IntakeLog) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(log)
        try data.write(to: fileURL, options: [.atomic])
    }

    // MARK: Encodage partagé (export, import)

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: Fichier illisible

    /// Renomme le fichier en `<nom>.corrupt-<date>` pour que son contenu reste
    /// récupérable à la main, plutôt que d'être écrasé à la prochaine écriture.
    private func quarantine(_ url: URL) -> String? {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = url.appendingPathExtension("corrupt-\(stamp)")
        do {
            try fileManager.moveItem(at: url, to: backup)
            return backup.lastPathComponent
        } catch {
            return nil
        }
    }
}
