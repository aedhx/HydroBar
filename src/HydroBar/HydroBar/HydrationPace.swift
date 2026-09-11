//
//  HydrationPace.swift
//  HydroBar
//
//  Calcul de l'allure attendue : « où devrais-je en être à cette heure-ci ? ».
//  Logique pure, sans UserDefaults ni UI — testable sans lancer l'app.
//

import Foundation

enum HydrationPace {

    static let defaultStartHour = 8
    static let defaultEndHour = 22

    /// Heures proposées dans les réglages. 24 = minuit, borne de fin uniquement.
    static let selectableStartHours = Array(0...23)
    static let selectableEndHours = Array(1...24)

    /// Fraction de l'objectif qu'on devrait avoir atteinte à `date`, au prorata de la
    /// plage horaire active.
    ///
    /// - Returns: `nil` **avant** le début de la plage (pas de repère : rien n'est
    ///   encore attendu) ou si la plage est invalide ; `1.0` après la fin.
    ///
    /// Les plages qui passent minuit (22 h → 6 h) ne sont volontairement pas gérées :
    /// la journée d'hydratation est remise à zéro à minuit, une plage à cheval
    /// porterait donc sur deux journées de données différentes. L'UI empêche de la
    /// saisir, cette fonction la rejette.
    static func expectedFraction(at date: Date,
                                 startHour: Int,
                                 endHour: Int,
                                 calendar: Calendar = .current) -> Double? {
        guard selectableStartHours.contains(startHour),
              selectableEndHours.contains(endHour),
              startHour < endHour
        else { return nil }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }

        let nowMinutes = Double(hour * 60 + minute)
        let startMinutes = Double(startHour * 60)
        let endMinutes = Double(endHour * 60)

        guard nowMinutes >= startMinutes else { return nil }
        guard nowMinutes < endMinutes else { return 1.0 }

        return (nowMinutes - startMinutes) / (endMinutes - startMinutes)
    }

    /// Quantité manquante, en ml, pour être « dans les temps ».
    /// - Returns: `nil` hors plage active, si l'objectif est nul, ou si rien ne manque.
    static func deficitMl(currentMl: Double,
                          targetMl: Double,
                          expectedFraction: Double?) -> Double? {
        guard let expectedFraction, targetMl > 0 else { return nil }
        let deficit = expectedFraction * targetMl - currentMl
        return deficit > 0 ? deficit : nil
    }
}
