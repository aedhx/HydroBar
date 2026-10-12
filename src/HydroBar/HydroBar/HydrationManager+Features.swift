//
//  HydrationManager+Features.swift
//  HydroBar
//
//  Mode gourde et preset suggéré : la logique vit ici, les réglages
//  (@AppStorage) restent dans la classe.
//

import Foundation

extension HydrationManager {

    // MARK: - Mode gourde

    var currentBottle: Int {
        bottleDayKey == IntakeLog.dayKey(for: Date(), calendar: .current) ? bottleNumber : 1
    }

    /// Quantité déjà bue dans la gourde en cours.
    var bottleDrunkMl: Double {
        Bottle.drunkMl(events: log.events, bottle: currentBottle, on: Date(), calendar: .current)
    }

    /// Enregistre ce qui manque pour que la gourde soit à `fraction`.
    func setBottleLevel(_ fraction: Double) {
        guard let amount = Bottle.amountToReach(fraction: fraction, drunkMl: bottleDrunkMl,
                                                capacityMl: bottleCapacityMl) else { return }
        addWater(amount: amount, bottle: currentBottle)
    }

    func startNewBottle() {
        objectWillChange.send()
        let next = currentBottle + 1
        bottleDayKey = IntakeLog.dayKey(for: Date(), calendar: .current)
        bottleNumber = next
    }

    // MARK: - Preset suggéré

    private var dismissedSuggestions: Set<Double> {
        Set(dismissedSuggestionsRaw.split(separator: ",").compactMap { Double($0) })
    }

    var presetSuggestion: (amountMl: Double, replacingIndex: Int)? {
        PresetSuggestion.suggest(events: log.events, presets: presetsMl, now: Date(),
                                 dismissed: dismissedSuggestions)
    }

    func acceptPresetSuggestion() {
        guard let suggestion = presetSuggestion else { return }
        var presets = presetsMl
        presets[suggestion.replacingIndex] = suggestion.amountMl
        presetsMl = presets
    }

    func dismissPresetSuggestion() {
        guard let suggestion = presetSuggestion else { return }
        objectWillChange.send()
        let values = dismissedSuggestions.union([suggestion.amountMl])
        dismissedSuggestionsRaw = values.map { String(Int($0)) }.joined(separator: ",")
    }
}
