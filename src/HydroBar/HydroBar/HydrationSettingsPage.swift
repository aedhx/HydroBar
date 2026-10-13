//
//  HydrationSettingsPage.swift
//  HydroBar
//
//  Page « Hydratation » des réglages : l'objectif quotidien à côté de l'anneau
//  du jour, les presets édités sur leurs touches, l'objectif par jour de la
//  semaine et le mode gourde.
//

import SwiftUI

struct HydrationSettingsPage: View {
    @ObservedObject var manager: HydrationManager
    /// Un des objectifs par jour vient d'être refusé : les bornes s'affichent
    /// une fois, sous la rangée.
    @State private var weekdayGoalRejected = false

    var body: some View {
        SettingsPage {
            goalCard
            presetsCard
            weekdayGoalsCard
            bottleCard
        }
    }

    // MARK: - Objectif

    /// L'anneau du popover, à la progression du jour, et l'objectif en grand.
    private var goalCard: some View {
        SettingsCard {
            HStack(spacing: 22) {
                VStack(spacing: 5) {
                    ProgressRingView(manager: manager, diameter: 88, lineWidth: 9, isMiniature: true)
                    Text(verbatim: "\(manager.displayValue(for: manager.currentMl)) / \(manager.displayValue(for: manager.targetMl))")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    goalLabel
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        AmountField(manager: manager, valueMl: manager.defaultTargetMl, rangeMl: HydrationLimits.goal,
                                    fieldWidth: 104, showsUnit: false, isBordered: false) {
                            manager.targetMl = $0
                        }
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .accessibilityLabel(goalLabel)

                        Text(verbatim: manager.selectedUnit.symbol)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
        }
    }

    private var goalLabel: Text {
        Text("Your daily goal", comment: "Onboarding step title")
    }

    // MARK: - Presets

    /// Les trois touches du popover, éditées sur place.
    private var presetsCard: some View {
        SettingsCard(title: Text("Your usual glasses", comment: "Onboarding step title"),
                     footer: Text("One click on a preset logs it. Set them to the glasses and bottles you actually use.",
                                  comment: "Onboarding step subtitle")) {
            HStack(spacing: 12) {
                ForEach(Array(manager.presetsMl.enumerated()), id: \.offset) { index, preset in
                    AmountField(manager: manager, valueMl: preset, rangeMl: HydrationLimits.single,
                                fieldWidth: 54, isBordered: false) {
                        updatePreset(at: index, ml: $0)
                    }
                    .font(Theme.Font.bodyMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .modifier(PresetSurface())
                    .accessibilityLabel(Text(verbatim: HotkeyAction.preset(index).localizedName))
                }
            }
            .padding(.vertical, 5)
        }
    }

    private func updatePreset(at index: Int, ml: Double) {
        var presets = manager.presetsMl
        guard presets.indices.contains(index) else { return }
        presets[index] = ml
        manager.presetsMl = presets
    }

    // MARK: - Objectif par jour de la semaine

    /// Jours dans l'ordre de la locale (lundi d'abord en France).
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    /// Une colonne par jour. Un champ vide suit l'objectif quotidien, rappelé
    /// en grisé ; une valeur donne au jour son propre objectif.
    private var weekdayGoalsCard: some View {
        let unit = manager.selectedUnit
        let range = unit.fromMl(HydrationLimits.goal.lowerBound)...unit.fromMl(HydrationLimits.goal.upperBound)
        let format: (Double) -> String = { NumberInput.fieldText($0, fractionDigits: unit.inputFractionDigits) }

        return SettingsCard(title: Text("Goal by day of the week", comment: "Settings section title for per-weekday goals"),
                            footer: Text("Higher on sports days, lower on weekends. Days without their own goal use the daily goal.",
                                         comment: "Explanation of per-weekday goals")) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(orderedWeekdays, id: \.self) { weekday in
                        VStack(spacing: 4) {
                            Text(verbatim: Calendar.current.shortWeekdaySymbols[weekday - 1])
                                .font(Theme.Font.caption)
                                .foregroundStyle(.secondary)
                            ValidatedNumberField(
                                value: manager.weekdayGoals.overrides[weekday].map(unit.fromMl),
                                range: range,
                                format: format,
                                alignment: .center,
                                placeholder: format(unit.fromMl(manager.defaultTargetMl)),
                                onClear: { setWeekdayGoal(nil, on: weekday) },
                                rejection: $weekdayGoalRejected,
                                onCommit: { setWeekdayGoal(manager.mlValue(from: $0), on: weekday) }
                            )
                            .accessibilityLabel(Text(verbatim: Calendar.current.weekdaySymbols[weekday - 1]))
                        }
                    }
                    Text(verbatim: unit.symbol)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 3)
                }

                if weekdayGoalRejected {
                    Text(ValidatedNumberField.boundsHint(range: range, format: format))
                        .font(Theme.Font.footnote)
                        .foregroundStyle(Theme.warning)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func setWeekdayGoal(_ goal: Double?, on weekday: Int) {
        var goals = manager.weekdayGoals
        goals.overrides[weekday] = goal
        manager.weekdayGoals = goals
    }

    // MARK: - Mode gourde

    private var bottleCard: some View {
        SettingsCard {
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
