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
    case daysOffDisabled

    // Mêmes textes que les erreurs de deep links : déjà traduits.
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .amountOutOfRange: return "Invalid or out-of-range amount."
        case .presetNotFound:   return "This preset does not exist."
        case .nothingToUndo:    return "Nothing to undo."
        case .daysOffDisabled:  return "Turn on Days Off in HydroBar's settings first."
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

// MARK: - Filtre de Concentration

/// Filtre de Concentration : dans Réglages Système › Concentration, chaque mode
/// peut passer les rappels de HydroBar en pastille dans la barre de menu.
///
/// Plus fiable que la synchronisation par `INFocusStatusCenter`, qui demande la
/// capability Communication Notifications et une autorisation dédiée : ici,
/// c'est le système qui appelle l'app à l'activation et à la désactivation.
/// À la désactivation, les paramètres arrivent vides (`nil`) — d'où le
/// paramètre optionnel.
struct HydroBarFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "HydroBar Reminders"
    static let description: IntentDescription? = IntentDescription("Show HydroBar reminders as a menu bar badge instead of notifications during this Focus.")

    @Parameter(title: "Reminders as a Badge")
    var remindersAsBadge: Bool?

    /// Une Concentration « Travail » programmée sait déjà quand on travaille :
    /// elle peut décider du type de journée.
    @Parameter(title: "Day Type")
    var dayType: IntentDayType?

    var displayRepresentation: DisplayRepresentation {
        let reminders: LocalizedStringResource = remindersAsBadge == true ? "Reminders as a badge" : "Reminders unchanged"
        switch dayType {
        case .work: return DisplayRepresentation(title: reminders, subtitle: "Work Day")
        case .off: return DisplayRepresentation(title: reminders, subtitle: "Day Off")
        case nil: return DisplayRepresentation(title: reminders)
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Concentration désactivée : le système rappelle le filtre sans valeur.
        let manager = HydrationManager.shared
        manager.setFocusFilterQuiet(remindersAsBadge ?? false)
        manager.setFocusDayKind(dayType?.dayKind)
        return .result()
    }
}

// MARK: - Type de journée

enum IntentDayType: String, AppEnum {
    case work
    case off

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Day Type"

    static let caseDisplayRepresentations: [IntentDayType: DisplayRepresentation] = [
        .work: "Work Day",
        .off: "Day Off",
    ]

    var dayKind: DayKind {
        switch self {
        case .work: return .work
        case .off: return .off
        }
    }
}

/// Pour une automatisation : « jour off » quand le Mac se connecte au Wi-Fi de
/// la maison un jour de semaine, par exemple.
struct SetDayTypeIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Today's Day Type"
    static let description = IntentDescription("Makes today a work day or a day off in HydroBar. Days off use their own hours, reminders and goal.")
    static let openAppWhenRun = false

    @Parameter(title: "Day Type")
    var dayType: IntentDayType

    static var parameterSummary: some ParameterSummary {
        Summary("Make today a \(\.$dayType)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = HydrationManager.shared
        guard manager.dayPlan.enabled else { throw HydroBarIntentError.daysOffDisabled }
        manager.setTodayKind(dayType.dayKind)
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
