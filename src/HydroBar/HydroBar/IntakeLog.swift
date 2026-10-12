//
//  IntakeLog.swift
//  HydroBar
//
//  Journal des prises : un événement par verre, au lieu d'un total par jour
//  (roadmap F5). Le total d'une journée devient une agrégation, pas une donnée
//  stockée — ce qui supprime toute la classe de bugs où un total en cache était
//  réécrit sur la mauvaise journée (cf. AUDIT § R3-1, R3-5).
//
//  Ce fichier est pur : aucune lecture de Date(), de UserDefaults ni du disque.
//  La persistance est dans `IntakeLogStore`.
//

import Foundation

// MARK: - Événement

struct IntakeEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let amountMl: Double
    /// Journée reprise de l'ancien format, qui ne stockait qu'un total : ce n'est
    /// pas une prise réelle, et elle est datée à midi plutôt que d'inventer une
    /// répartition dans la journée.
    let isAggregate: Bool

    init(id: UUID = UUID(), date: Date, amountMl: Double, isAggregate: Bool = false) {
        self.id = id
        self.date = date
        self.amountMl = amountMl
        self.isAggregate = isAggregate
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, amountMl, isAggregate
    }

    // `isAggregate` est facultatif à la lecture : un fichier importé écrit à la
    // main, ou par un futur outil, n'a pas à le préciser.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        amountMl = try container.decode(Double.self, forKey: .amountMl)
        isAggregate = try container.decodeIfPresent(Bool.self, forKey: .isAggregate) ?? false
    }
}

// MARK: - Journal

struct IntakeLog: Codable, Equatable {
    static let currentVersion = 2

    private(set) var version: Int = IntakeLog.currentVersion
    /// Triés par date croissante.
    private(set) var events: [IntakeEvent] = []
    /// Objectif de chaque journée, par clé `yyyy-MM-dd` dans le calendrier local.
    /// Une journée se juge contre l'objectif qu'elle avait, pas contre l'actuel.
    private(set) var dailyGoals: [String: Double] = [:]

    init(events: [IntakeEvent] = [], dailyGoals: [String: Double] = [:]) {
        self.events = events.sorted { $0.date < $1.date }
        self.dailyGoals = dailyGoals
    }

    // MARK: Clé de journée

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: Lecture

    func events(on day: Date, calendar: Calendar) -> [IntakeEvent] {
        events.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func total(on day: Date, calendar: Calendar) -> Double {
        events(on: day, calendar: calendar).reduce(0) { $0 + $1.amountMl }
    }

    func goal(on day: Date, calendar: Calendar) -> Double? {
        dailyGoals[Self.dayKey(for: day, calendar: calendar)]
    }

    var lastEvent: IntakeEvent? { events.last }

    /// Une entrée par journée ayant au moins une prise, triées par date.
    /// Une journée sans objectif enregistré prend `defaultGoal`.
    func dailyEntries(calendar: Calendar, defaultGoal: Double) -> [HistoryEntry] {
        var totals: [Date: Double] = [:]
        for event in events {
            totals[calendar.startOfDay(for: event.date), default: 0] += event.amountMl
        }
        return totals.keys.sorted().map { day in
            HistoryEntry(date: day,
                         amountMl: totals[day] ?? 0,
                         targetMl: goal(on: day, calendar: calendar) ?? defaultGoal)
        }
    }

    // MARK: Écriture

    mutating func add(_ event: IntakeEvent) {
        // Insertion à sa place : un import ou un widget peuvent livrer un
        // événement plus ancien que le dernier.
        let index = events.firstIndex { $0.date > event.date } ?? events.endIndex
        events.insert(event, at: index)
    }

    /// Retire un événement et le renvoie, pour qu'il puisse être restauré.
    @discardableResult
    mutating func remove(id: UUID) -> IntakeEvent? {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return nil }
        return events.remove(at: index)
    }

    /// Retire toutes les prises d'une journée et les renvoie.
    @discardableResult
    mutating func removeEvents(on day: Date, calendar: Calendar) -> [IntakeEvent] {
        let removed = events(on: day, calendar: calendar)
        let ids = Set(removed.map(\.id))
        events.removeAll { ids.contains($0.id) }
        return removed
    }

    /// Remet des événements retirés. Ignore ceux déjà présents.
    mutating func restore(_ restored: [IntakeEvent]) {
        let existing = Set(events.map(\.id))
        for event in restored where !existing.contains(event.id) {
            add(event)
        }
    }

    mutating func setGoal(_ goalMl: Double, on day: Date, calendar: Calendar) {
        dailyGoals[Self.dayKey(for: day, calendar: calendar)] = goalMl
    }

    // MARK: Fusion

    /// Ajoute les événements d'un autre journal qui n'existent pas encore ici.
    /// Les identifiants rendent l'opération idempotente : importer deux fois la
    /// même sauvegarde ne compte rien en double. Un objectif déjà connu pour une
    /// journée n'est pas écrasé.
    ///
    /// - Returns: le nombre d'événements ajoutés.
    @discardableResult
    mutating func merge(_ other: IntakeLog) -> Int {
        let existing = Set(events.map(\.id))
        let incoming = other.events.filter { !existing.contains($0.id) }
        for event in incoming { add(event) }
        for (key, goal) in other.dailyGoals where dailyGoals[key] == nil {
            dailyGoals[key] = goal
        }
        return incoming.count
    }

    // MARK: Migration

    /// Construit le journal à partir de l'ancien format (un total par jour).
    ///
    /// - Parameters:
    ///   - history: contenu de historyEntries.json.
    ///   - pendingDay: journée du total en cours stocké dans UserDefaults
    ///     (`currentMl`), qui peut être plus récent que l'historique : il n'était
    ///     archivé qu'à la bascule de jour, ou par l'écriture différée.
    ///   - pendingMl: ce total.
    static func migrating(history: [HistoryEntry],
                          pendingDay: Date?,
                          pendingMl: Double,
                          defaultGoal: Double,
                          calendar: Calendar) -> IntakeLog {
        var log = IntakeLog()
        let pendingKey = pendingDay.map { dayKey(for: $0, calendar: calendar) }

        for entry in history {
            let day = calendar.startOfDay(for: entry.date)
            let key = dayKey(for: day, calendar: calendar)
            log.dailyGoals[key] = entry.targetMl
            // La valeur en cours fait foi sur l'entrée archivée du même jour.
            guard key != pendingKey, entry.amountMl > 0 else { continue }
            log.add(aggregateEvent(on: day, amountMl: entry.amountMl, calendar: calendar))
        }

        if let pendingDay, pendingMl > 0 {
            let day = calendar.startOfDay(for: pendingDay)
            log.add(aggregateEvent(on: day, amountMl: pendingMl, calendar: calendar))
            if log.goal(on: day, calendar: calendar) == nil {
                log.setGoal(defaultGoal, on: day, calendar: calendar)
            }
        }
        return log
    }

    private static func aggregateEvent(on day: Date, amountMl: Double, calendar: Calendar) -> IntakeEvent {
        let noon = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
        return IntakeEvent(date: noon, amountMl: amountMl, isAggregate: true)
    }
}
