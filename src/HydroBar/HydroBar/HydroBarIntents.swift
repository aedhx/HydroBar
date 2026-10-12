//
//  HydroBarIntents.swift
//  HydroBar
//
//  App Intents (roadmap F2) : HydroBar dans Raccourcis, Spotlight et Siri.
//  Complément des deep links : un schéma d'URL ne renvoie rien, un intent
//  renvoie une valeur et une phrase.
//
//  Les intents s'exécutent dans le processus de l'app et passent par le même
//  `HydrationManager` et les mêmes bornes (`HydrationLimits`) que l'interface
//  et les deep links : un seul chemin d'écriture. Le widget garde son propre
//  intent, qui ne peut pas parler directement à l'app.
//

import AppIntents
import Foundation

// MARK: - Unité

enum IntentVolumeUnit: String, AppEnum {
    case milliliters
    case centiliters
    case liters
    case usFluidOunces
    case ukFluidOunces

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Unit"

    static let caseDisplayRepresentations: [IntentVolumeUnit: DisplayRepresentation] = [
        .milliliters: "ml",
        .centiliters: "cl",
        .liters: "L",
        .usFluidOunces: "US fl oz",
        .ukFluidOunces: "UK fl oz",
    ]

    var appUnit: AppUnit {
        switch self {
        case .milliliters:   return .ml
        case .centiliters:   return .cl
        case .liters:        return .liter
        case .usFluidOunces: return .oz
        case .ukFluidOunces: return .ozUK
        }
    }
}

// MARK: - Erreurs

enum HydroBarIntentError: Error, CustomLocalizedStringResourceConvertible {
    case amountOutOfRange
    case presetNotFound
    case nothingToUndo

    // Mêmes textes que les erreurs de deep links : déjà traduits.
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .amountOutOfRange: return "Invalid or out-of-range amount."
        case .presetNotFound:   return "This preset does not exist."
        case .nothingToUndo:    return "Nothing to undo."
        }
    }
}

// MARK: - Résumé partagé

@MainActor
private func todaySummary(_ manager: HydrationManager) -> String {
    let percent = manager.targetMl > 0 ? Int((manager.currentMl / manager.targetMl * 100).rounded()) : 0
    return String(format: String(localized: "Today: %@ of %@ (%lld%%).",
                                 comment: "Intent result; amounts and percentage of the daily goal"),
                  manager.displayValue(for: manager.currentMl),
                  manager.displayValue(for: manager.targetMl),
                  percent)
}

// MARK: - Ajouter une quantité

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Adds a drink to today's total in HydroBar.")
    static let openAppWhenRun = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Unit", default: .milliliters)
    var unit: IntentVolumeUnit

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) \(\.$unit) of water")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let ml = unit.appUnit.toMl(amount)
        guard ml.isFinite, HydrationLimits.single.contains(ml) else {
            throw HydroBarIntentError.amountOutOfRange
        }
        let manager = HydrationManager.shared
        manager.addWater(amount: ml)
        return .result(value: manager.currentMl, dialog: "\(todaySummary(manager))")
    }
}

// MARK: - Ajouter un preset

struct LogPresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Preset"
    static let description = IntentDescription("Adds one of your HydroBar presets, numbered from 1 as in the app.")
    static let openAppWhenRun = false

    @Parameter(title: "Preset Number", default: 1)
    var preset: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Log preset \(\.$preset)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let manager = HydrationManager.shared
        let presets = manager.presetsMl
        guard presets.indices.contains(preset - 1) else {
            throw HydroBarIntentError.presetNotFound
        }
        manager.addWater(amount: presets[preset - 1])
        return .result(value: manager.currentMl, dialog: "\(todaySummary(manager))")
    }
}

// MARK: - État du jour

struct GetHydrationStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Hydration Status"
    static let description = IntentDescription("Returns how much you have drunk today, in milliliters.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let manager = HydrationManager.shared
        return .result(value: manager.currentMl, dialog: "\(todaySummary(manager))")
    }
}

// MARK: - Annuler

struct UndoLastDrinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Undo Last Drink"
    static let description = IntentDescription("Undoes the last change made in HydroBar.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = HydrationManager.shared
        guard manager.undo() else { throw HydroBarIntentError.nothingToUndo }
        return .result(dialog: "\(todaySummary(manager))")
    }
}

// MARK: - Objectif

/// Pas de confirmation, contrairement à `hydrobar://set-goal` : un raccourci
/// est écrit par l'utilisateur lui-même, une URL peut venir de n'importe
/// quelle page web. Les bornes, elles, sont les mêmes.
struct SetDailyGoalIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Daily Goal"
    static let description = IntentDescription("Changes your daily hydration goal in HydroBar.")
    static let openAppWhenRun = false

    @Parameter(title: "Goal")
    var amount: Double

    @Parameter(title: "Unit", default: .milliliters)
    var unit: IntentVolumeUnit

    static var parameterSummary: some ParameterSummary {
        Summary("Set daily goal to \(\.$amount) \(\.$unit)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ml = unit.appUnit.toMl(amount)
        guard ml.isFinite, HydrationLimits.goal.contains(ml) else {
            throw HydroBarIntentError.amountOutOfRange
        }
        let manager = HydrationManager.shared
        manager.targetMl = ml
        return .result(dialog: "\(todaySummary(manager))")
    }
}

// MARK: - Raccourcis proposés

struct HydroBarShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogPresetIntent(),
            phrases: [
                "Log a drink in \(.applicationName)",
                "Add water in \(.applicationName)",
            ],
            shortTitle: "Log a Preset",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: GetHydrationStatusIntent(),
            phrases: [
                "How much have I drunk in \(.applicationName)",
                "\(.applicationName) status",
            ],
            shortTitle: "Hydration Status",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: UndoLastDrinkIntent(),
            phrases: ["Undo last drink in \(.applicationName)"],
            shortTitle: "Undo Last Drink",
            systemImageName: "arrow.uturn.backward"
        )
    }
}
