//
//  PresetSuggestionBanner.swift
//  HydroBar
//
//  « Vous ajoutez souvent 33 cl : en faire un preset ? » — proposé quand une
//  quantité revient au moins cinq fois en 30 jours sans correspondre à aucun
//  preset. Elle remplace le preset le moins utilisé. Un refus est retenu.
//

import SwiftUI

struct PresetSuggestionBanner: View {
    @ObservedObject var manager: HydrationManager

    var body: some View {
        if let suggestion = manager.presetSuggestion,
           manager.presetsMl.indices.contains(suggestion.replacingIndex) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(String(format: String(localized: "You often log %@. Make it a preset?",
                                               comment: "Preset suggestion; %@ is an amount"),
                                manager.displayValue(for: suggestion.amountMl)))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundColor(Theme.water)
                }
                .font(Theme.Font.callout)

                HStack(spacing: 8) {
                    Button(String(format: String(localized: "Replace %@", comment: "Preset suggestion: replace this preset; %@ is an amount"),
                                  manager.displayValue(for: manager.presetsMl[suggestion.replacingIndex]))) {
                        manager.acceptPresetSuggestion()
                    }
                    Button(String(localized: "No Thanks", comment: "Preset suggestion: dismiss")) {
                        manager.dismissPresetSuggestion()
                    }
                }
                .controlSize(.small)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.presetFill)
            .cornerRadius(Theme.Radius.control)
            .transition(.opacity)
        }
    }
}
