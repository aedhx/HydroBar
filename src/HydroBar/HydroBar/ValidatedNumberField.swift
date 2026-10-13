//
//  ValidatedNumberField.swift
//  HydroBar
//
//  Saisie numérique des réglages, validée et bornée.
//

import SwiftUI

/// Lecture et mise en forme des nombres saisis dans les réglages.
///
/// `NumberFormatter` seul ne suffit pas : selon la locale, « 1,000 » vaut mille
/// (anglais) ou un (français), et « 1.5 » vaut un et demi (anglais) ou quinze
/// (allemand, où le point groupe les milliers). La règle retenue est explicite :
///
/// 1. le séparateur décimal de la locale est toujours décimal ;
/// 2. l'autre séparateur (`,` ↔ `.`) est décimal s'il apparaît une seule fois et
///    est suivi d'un ou deux chiffres — un francophone qui tape « 1.5 » veut dire
///    1,5 — et un séparateur de milliers sinon (« 1,000 » en français = mille).
///
/// Fonction pure, couverte par NumberInputTests.
enum NumberInput {
    static func parse(_ text: String, locale: Locale = .current) -> Double? {
        // Espaces ordinaires, insécables et fines insécables (groupement français).
        var raw = text.filter { !$0.isWhitespace && $0 != "\u{00A0}" && $0 != "\u{202F}" }
        guard !raw.isEmpty else { return nil }

        let decimal = locale.decimalSeparator ?? "."
        let other = decimal == "," ? "." : ","

        if raw.contains(decimal) {
            // L'autre séparateur ne peut alors être qu'un groupement.
            raw = raw.replacingOccurrences(of: other, with: "")
            raw = raw.replacingOccurrences(of: decimal, with: ".")
        } else if raw.components(separatedBy: other).count == 2,
                  let tail = raw.components(separatedBy: other).last,
                  (1...2).contains(tail.count) {
            raw = raw.replacingOccurrences(of: other, with: ".")
        } else {
            raw = raw.replacingOccurrences(of: other, with: "")
        }

        guard let value = Double(raw), value.isFinite else { return nil }
        return value
    }

    /// Mise en forme pour un champ de saisie : séparateur décimal de la locale,
    /// sans groupement des milliers, pour que ce qui est affiché se relise tel quel.
    static func fieldText(_ value: Double, fractionDigits: ClosedRange<Int>, locale: Locale = .current) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(fractionDigits))
                .grouping(.never)
                .locale(locale)
        )
    }
}

/// Champ numérique validé.
///
/// La valeur n'est appliquée qu'à la validation — touche Entrée ou perte du
/// focus — et seulement si elle est dans les bornes. Sinon le champ revient à la
/// dernière valeur valide et indique les bornes acceptées.
///
/// Les champs qu'il remplace écrivaient à **chaque frappe**, sans aucune borne.
/// Deux plantages en découlaient : un objectif de 0 (taper « 0 » comme premier
/// caractère de « 0,5 L », cf. AUDIT § P0-2) et un intervalle de rappel de
/// 0 minute, refusé par le système pour un déclencheur répétitif.
struct ValidatedNumberField: View {
    /// Valeur courante, dans l'unité affichée.
    let value: Double
    /// Bornes acceptées, dans l'unité affichée.
    let range: ClosedRange<Double>
    /// Mise en forme de la valeur dans le champ.
    let format: (Double) -> String
    var alignment: TextAlignment = .leading
    let onCommit: (Double) -> Void

    @State private var text = ""
    @State private var rejected = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(alignment)
                .focused($isFocused)
                .onSubmit(commit)
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
                .onAppear { text = format(value) }
                .onChange(of: value) { _, newValue in
                    // Ne pas écraser ce que l'utilisateur est en train de taper.
                    if !isFocused { text = format(newValue) }
                }

            if rejected {
                Text(String(format: String(localized: "Between %@ and %@",
                                           comment: "Validation hint for a numeric field; %@ are the bounds"),
                            format(range.lowerBound), format(range.upperBound)))
                    .font(Theme.Font.footnote)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func commit() {
        // Entrer puis sortir d'un champ sans le modifier ne doit rien écrire :
        // une valeur arrondie à l'affichage (6,76 oz) serait sinon réécrite et
        // dériverait un peu plus à chaque passage.
        guard text != format(value) else {
            rejected = false
            return
        }
        guard let parsed = NumberInput.parse(text), range.contains(parsed) else {
            rejected = !text.trimmingCharacters(in: .whitespaces).isEmpty
            text = format(value)
            return
        }
        rejected = false
        onCommit(parsed)
        text = format(parsed)
    }
}
