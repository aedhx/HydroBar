//
//  GoalSuggestion.swift
//  HydroBar
//
//  Suggestion d'objectif à partir du poids (roadmap F21). Rien n'aidait à
//  choisir 2 000 ml plutôt que 3 000 : l'objectif par défaut restait souvent en
//  place à vie, même franchement inadapté.
//
//  Base simple et explicable : ~30 ml par kilo. Ce n'est pas une
//  recommandation médicale — les besoins réels dépendent de l'activité, du
//  climat et de l'alimentation —, et l'interface le dit. Le poids sert au
//  calcul puis n'est stocké nulle part.
//

import Foundation

enum GoalSuggestion {
    static let millilitersPerKilogram = 30.0
    static let kilogramsPerPound = 0.45359237
    /// Au-delà, la saisie est plus probablement une erreur qu'un poids.
    static let plausibleWeightKg: ClosedRange<Double> = 25...300

    /// Objectif suggéré, arrondi aux 50 ml et borné comme toute saisie
    /// d'objectif ; `nil` pour un poids invraisemblable.
    static func goalMl(forWeightKg weight: Double) -> Double? {
        guard weight.isFinite, plausibleWeightKg.contains(weight) else { return nil }
        let rounded = (weight * millilitersPerKilogram / 50).rounded() * 50
        return min(max(rounded, HydrationLimits.goal.lowerBound), HydrationLimits.goal.upperBound)
    }

    static func kilograms(fromPounds pounds: Double) -> Double {
        pounds * kilogramsPerPound
    }

    /// Les livres là où le système métrique n'est pas l'usage.
    static func prefersPounds(locale: Locale = .current) -> Bool {
        locale.measurementSystem == .us
    }
}
