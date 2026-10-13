//
//  HydrationSettingsPage.swift
//  HydroBar
//
//  Page « Hydratation » des réglages : objectif quotidien, objectif par jour
//  de la semaine, presets et mode gourde.
//

import SwiftUI

struct HydrationSettingsPage: View {
    @ObservedObject var manager: HydrationManager

    var body: some View {
        SettingsPage {
            goalSection
            weekdayGoalsSection
            presetsSection
            bottleSection
        }
    }

    // MARK: - Objectif

    private var goalSection: some View {
        Section {
            LabeledContent {
                AmountField(manager: manager, valueMl: manager.defaultTargetMl, rangeMl: HydrationLimits.goal) {
                    manager.targetMl = $0
                }
            } label: {
                Text("Your daily goal", comment: "Onboarding step title")
            }
        }
    }

    // MARK: - Objectif par jour de la semaine

    /// Jours dans l'ordre de la locale (lundi d'abord en France).
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private var weekdayGoalsSection: some View {
        Section {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                weekdayRow(weekday)
            }
        } header: {
            Text("Goal by day of the week", comment: "Settings section title for per-weekday goals")
        } footer: {
            SettingsFooter(Text("Higher on sports days, lower on weekends. Days without their own goal use the daily goal.",
                                comment: "Explanation of per-weekday goals"))
        }
    }

    private func weekdayRow(_ weekday: Int) -> some View {
        let override = manager.weekdayGoals.overrides[weekday]
        let name = Calendar.current.weekdaySymbols[weekday - 1].capitalized
        return LabeledContent {
            HStack(spacing: 12) {
                if let override {
                    AmountField(manager: manager, valueMl: override, rangeMl: HydrationLimits.goal) { goal in
                        var goals = manager.weekdayGoals
                        goals.overrides[weekday] = goal
                        manager.weekdayGoals = goals
                    }
                }
                Toggle(isOn: Binding(
                    get: { override != nil },
                    set: { enabled in
                        var goals = manager.weekdayGoals
                        goals.overrides[weekday] = enabled ? manager.defaultTargetMl : nil
                        manager.weekdayGoals = goals
                    }
                )) {
                    Text(verbatim: name)
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            // La hauteur du champ, qu'il soit là ou non : les sept lignes
            // gardent la même.
            .frame(height: 22)
            .centeredOnRowLabel()
        } label: {
            Text(verbatim: name)
        }
    }

    // MARK: - Presets

    private var presetsSection: some View {
        Section {
            ForEach(Array(manager.presetsMl.enumerated()), id: \.offset) { index, preset in
                LabeledContent {
                    AmountField(manager: manager, valueMl: preset, rangeMl: HydrationLimits.single) {
                        updatePreset(at: index, ml: $0)
                    }
                } label: {
                    Label {
                        Text(verbatim: HotkeyAction.preset(index).localizedName)
                    } icon: {
                        // Même largeur pour les trois pictogrammes : les
                        // libellés restent alignés.
                        Image(systemName: iconForPreset(at: index))
                            .frame(width: 20)
                    }
                }
            }
        } header: {
            Text("Your usual glasses", comment: "Onboarding step title")
        } footer: {
            SettingsFooter(Text("One click on a preset logs it. Set them to the glasses and bottles you actually use.",
                                comment: "Onboarding step subtitle"))
        }
    }

    private func updatePreset(at index: Int, ml: Double) {
        var presets = manager.presetsMl
        guard presets.indices.contains(index) else { return }
        presets[index] = ml
        manager.presetsMl = presets
    }

    private func iconForPreset(at index: Int) -> String {
        switch index {
        case 0:  return "cup.and.saucer.fill"   // petit verre
        case 1:  return "mug.fill"              // verre moyen
        case 2:  return "wineglass.fill"        // grand verre
        default: return "drop.fill"
        }
    }

    // MARK: - Mode gourde

    private var bottleSection: some View {
        Section {
            Toggle(isOn: Binding(get: { manager.bottleModeEnabled },
                                 set: { manager.bottleModeEnabled = $0 })) {
                Text("Bottle mode", comment: "Toggle: bottle mode")
                Text("Drink from a bottle? Log how much of it you've had — a quarter, half, three quarters — and HydroBar records the difference.",
                     comment: "Explanation of bottle mode")
            }

            if manager.bottleModeEnabled {
                LabeledContent {
                    AmountField(manager: manager, valueMl: manager.bottleCapacityMl, rangeMl: Bottle.capacityRange) {
                        manager.bottleCapacityMl = $0
                    }
                } label: {
                    Text("Bottle size", comment: "Bottle mode: capacity label")
                }
            }
        }
    }
}
