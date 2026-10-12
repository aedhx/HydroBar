// AddWaterControl.swift
// Target Membership: HydroBarWidget ONLY
//
// Bouton du Centre de contrôle (macOS 26, roadmap F10) : ajoute le premier
// preset sans ouvrir HydroBar. Il passe par le même intent que les boutons du
// widget, donc par la même synchronisation avec l'app (delta en attente +
// notification Darwin).

import WidgetKit
import SwiftUI
import AppIntents

@available(macOS 26.0, *)
struct AddWaterControl: ControlWidget {
    static let kind = "com.adxcool.HydroBar.AddWaterControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            let snapshot = AppGroupStore.read()
            let amount = snapshot.widgetPresetsMl.first ?? HydrationSnapshot.defaultPresetsMl[0]
            let unit = AppUnit(rawValue: snapshot.unit) ?? .cl
            ControlWidgetButton(action: AddWaterIntent(amountMl: amount)) {
                Label("+" + unit.format(ml: amount), systemImage: "drop.fill")
            }
        }
        .displayName("Add Water")
        .description("Log your first HydroBar preset.")
    }
}
