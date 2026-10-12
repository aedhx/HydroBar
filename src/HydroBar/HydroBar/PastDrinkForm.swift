//
//  PastDrinkForm.swift
//  HydroBar
//
//  Ajout d'une prise oubliée, à une date et une heure passées. Formulaire en
//  ligne dans le journal du jour : une feuille modale s'accorde mal d'un
//  popover de barre de menu.
//

import SwiftUI

struct PastDrinkForm: View {
    @ObservedObject var manager: HydrationManager
    let onDone: () -> Void

    @State private var date = Date().addingTimeInterval(-3600)
    /// Lu au moment d'ajouter, pas à la validation du champ : sur macOS, un
    /// clic sur un bouton ne retire pas le focus du champ, et la valeur tapée
    /// serait ignorée.
    @State private var amountText = ""
    @State private var isInvalid = false

    /// Un an en arrière suffit : au-delà, c'est une restauration (F4).
    private var allowedDates: ClosedRange<Date> {
        Date().addingTimeInterval(-365 * 86_400)...Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(String(localized: "When", comment: "Past drink form: date and time"),
                       selection: $date, in: allowedDates)
                .datePickerStyle(.compact)
                .font(.system(size: 12))

            HStack(spacing: 8) {
                Text("Amount", comment: "Past drink form: amount")
                    .font(.system(size: 12))
                TextField("", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onSubmit(add)
                Text(verbatim: manager.selectedUnit.symbol)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }

            if isInvalid {
                Text(String(format: String(localized: "Between %@ and %@",
                                           comment: "Validation hint for a numeric field; %@ are the bounds"),
                            manager.displayValue(for: HydrationLimits.single.lowerBound),
                            manager.displayValue(for: HydrationLimits.single.upperBound)))
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }

            HStack {
                Spacer()
                Button(String(localized: "Cancel", comment: "Cancel button")) { onDone() }
                Button(String(localized: "Add", comment: "Past drink form: confirm"), action: add)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(6)
        .onAppear {
            let preset = manager.presetsMl.first ?? 250
            amountText = NumberInput.fieldText(manager.selectedUnit.fromMl(preset),
                                               fractionDigits: manager.selectedUnit.inputFractionDigits)
        }
    }

    private func add() {
        guard let value = NumberInput.parse(amountText) else {
            isInvalid = true
            return
        }
        let ml = manager.mlValue(from: value)
        guard HydrationLimits.single.contains(ml) else {
            isInvalid = true
            return
        }
        manager.addPastDrink(amount: ml, at: min(date, Date()))
        onDone()
    }
}
