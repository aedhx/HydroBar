//
//  Bottle.swift
//  HydroBar
//
//  Mode gourde : beaucoup de gens boivent au bureau dans une gourde remplie le
//  matin. Plutôt que de convertir « la moitié de ma gourde » en millilitres, on
//  note son niveau — un quart, la moitié, trois quarts, finie — et HydroBar
//  enregistre la différence.
//
//  Le niveau se déduit du journal (les prises marquées avec le numéro de la
//  gourde du jour) : annuler une prise fait redescendre la gourde, sans état à
//  maintenir en parallèle. Pur.
//

import Foundation

enum Bottle {
    /// Bornes de la contenance réglable, en ml.
    static let capacityRange: ClosedRange<Double> = 100...3_000
    static let defaultCapacityMl: Double = 750
    /// Niveaux proposés : un quart, la moitié, trois quarts, finie.
    static let marks: [Double] = [0.25, 0.5, 0.75, 1]

    /// Quantité déjà bue dans la gourde `bottle` du jour `day`.
    static func drunkMl(events: [IntakeEvent], bottle: Int, on day: Date, calendar: Calendar) -> Double {
        events
            .filter { $0.bottle == bottle && calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.amountMl }
    }

    /// Quantité à enregistrer pour atteindre `fraction` de la gourde ; `nil`
    /// si ce niveau est déjà atteint.
    static func amountToReach(fraction: Double, drunkMl: Double, capacityMl: Double) -> Double? {
        let delta = (fraction * capacityMl - drunkMl).rounded()
        return delta >= 1 ? delta : nil
    }
}
