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
        let current = AppGroupStore.read()
        let updated = HydrationSnapshot(
            currentMl: current.currentMl + amountMl,
            targetMl: current.targetMl,
            unit: current.unit,
            lastUpdated: Date(),
            weekHistory: current.weekHistory
        )
        AppGroupStore.write(updated)
        AppGroupStore.addPendingDelta(amountMl)
        return .result()
    }
}

