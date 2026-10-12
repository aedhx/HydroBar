// AddWaterIntent.swift
// Target Membership: HydroBarWidget ONLY

import AppIntents
import Foundation

struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Water"
    static var description = IntentDescription("Add water from the HydroBar widget")

    @Parameter(title: "Amount (ml)")
    var amountMl: Double

    init() { self.amountMl = 0 }
    init(amountMl: Double) { self.amountMl = amountMl }

    func perform() async throws -> some IntentResult {
        guard amountMl > 0 else { return .result() }
        let now = Date()
        // asOf : un verre ajouté après minuit ne s'additionne pas au total d'hier.
        let current = AppGroupStore.read().asOf(now)
        let updated = HydrationSnapshot(
            currentMl: current.currentMl + amountMl,
            targetMl: current.targetMl,
            unit: current.unit,
            lastUpdated: now,
            weekHistory: current.weekHistory,
            presetsMl: current.presetsMl
        )
        AppGroupStore.write(updated)
        AppGroupStore.addPendingDelta(amountMl)
        AppGroupStore.postWidgetDidAddWater()
        return .result()
    }
}

