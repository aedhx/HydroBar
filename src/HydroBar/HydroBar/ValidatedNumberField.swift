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
    /// Valeur courante, dans l'unité affichée. `nil` : champ vide, permis
    /// seulement avec `onClear`.
    let value: Double?
    /// Bornes acceptées, dans l'unité affichée.
    let range: ClosedRange<Double>
    /// Mise en forme de la valeur dans le champ.
    let format: (Double) -> String
    var alignment: TextAlignment = .leading
    /// Largeur du champ seul. Les bornes rappelées en cas de refus gardent
    /// alors leur propre largeur, au lieu de se replier sous un champ étroit.
    var fieldWidth: CGFloat?
    /// Unité affichée à droite du champ.
    var suffix: String?
    /// Sans bordure : le champ se fond dans ce qui le porte (grand chiffre de
    /// l'objectif, touche de preset), sur un fond qui s'entoure de bleu
    /// pendant la saisie.
    var isBordered = true
    /// Texte grisé d'un champ vide : la valeur qui s'applique sans saisie.
    var placeholder: String?
    /// Appelée quand le champ est vidé. Sans elle, un champ vidé revient à sa
    /// valeur.
    var onClear: (() -> Void)?
    /// Le refus est signalé ailleurs (plusieurs champs étroits côte à côte) :
    /// le champ n'affiche pas lui-même les bornes.
    var rejection: Binding<Bool>?
    let onCommit: (Double) -> Void

    @State private var text = ""
    @State private var rejected = false
    @FocusState private var isFocused: Bool

    private var currentText: String { value.map(format) ?? "" }

    var body: some View {
        VStack(alignment: alignment == .trailing ? .trailing : .leading, spacing: 2) {
            HStack(spacing: 6) {
                styledField
                    .multilineTextAlignment(alignment)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commit() }
                    }
                    .onAppear { text = currentText }
                    .onChange(of: value) { _, _ in
                        // Ne pas écraser ce que l'utilisateur est en train de taper.
                        if !isFocused { text = currentText }
                    }
                    .frame(width: fieldWidth)

                if let suffix {
                    Text(verbatim: suffix)
                        .foregroundStyle(.secondary)
                }
            }

            if rejected, rejection == nil {
                Text(Self.boundsHint(range: range, format: format))
                    .font(Theme.Font.footnote)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: fieldWidth != nil, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var styledField: some View {
        let field = TextField("", text: $text, prompt: placeholder.map { Text(verbatim: $0) })
        if isBordered {
            field.textFieldStyle(.roundedBorder)
        } else {
            let well = RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
            field
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(well.fill(Color.primary.opacity(0.07)))
                .overlay(well.strokeBorder(Theme.water, lineWidth: isFocused ? 2 : 0))
        }
    }

    static func boundsHint(range: ClosedRange<Double>, format: (Double) -> String) -> String {
        String(format: String(localized: "Between %@ and %@",
                              comment: "Validation hint for a numeric field; %@ are the bounds"),
               format(range.lowerBound), format(range.upperBound))
    }

    private func setRejected(_ value: Bool) {
        rejected = value
        rejection?.wrappedValue = value
    }

    private func commit() {
        // Entrer puis sortir d'un champ sans le modifier ne doit rien écrire :
        // une valeur arrondie à l'affichage (6,76 oz) serait sinon réécrite et
        // dériverait un peu plus à chaque passage.
        guard text != currentText else {
            setRejected(false)
            return
        }
        let isEmpty = text.trimmingCharacters(in: .whitespaces).isEmpty
        if isEmpty, let onClear {
            setRejected(false)
            text = ""
            onClear()
            return
        }
        guard let parsed = NumberInput.parse(text), range.contains(parsed) else {
            setRejected(!isEmpty)
            text = currentText
            return
        }
        setRejected(false)
        onCommit(parsed)
        text = format(parsed)
    }
}
