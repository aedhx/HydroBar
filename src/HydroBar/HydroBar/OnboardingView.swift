//
//  OnboardingView.swift
//  HydroBar
//
//  Premier lancement (roadmap F8). Avant, l'app apparaissait dans la barre de
//  menu avec un objectif de 2 000 ml et des presets arbitraires, sans
//  explication, et demandait d'emblée l'autorisation des notifications.
//
//  Trois écrans : objectif (avec la suggestion de F21), presets, rappels. C'est
//  au troisième, et seulement si l'utilisateur active les rappels, que
//  l'autorisation des notifications est demandée.
//

import SwiftUI
import AppKit

// MARK: - Fenêtre

final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private static let completedKey = "hasCompletedOnboarding"
    private var window: NSWindow?

    var isCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.completedKey) }
    }

    /// Au premier lancement seulement. Un utilisateur de la v1 a déjà réglé son
    /// app : on ne lui impose pas l'accueil.
    func showIfNeeded() {
        guard !isCompleted else { return }
        let defaults = UserDefaults.standard
        let isExistingUser = !HydrationManager.shared.log.events.isEmpty
            || defaults.object(forKey: "targetMl") != nil
            || defaults.object(forKey: "presetsMl") != nil
        if isExistingUser {
            isCompleted = true
            return
        }
        show()
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingView(manager: .shared) { [weak self] in self?.finish() }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = String(localized: "Welcome to HydroBar", comment: "Onboarding window title")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish() {
        isCompleted = true
        window?.close()
        window = nil
    }
}

// MARK: - Vue

struct OnboardingView: View {
    @ObservedObject var manager: HydrationManager
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    let onFinish: () -> Void

    @State private var step = 0
    @State private var weightText = ""
    @State private var remindersDenied = false

    private let stepCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                switch step {
                case 0: goalStep
                case 1: presetsStep
                default: remindersStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .padding(24)
        .frame(width: 440, height: 400)
    }

    // MARK: Étape 1 — objectif

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(title: String(localized: "Your daily goal", comment: "Onboarding step title"),
                   subtitle: String(localized: "HydroBar shows your progress toward it all day, right in the menu bar.",
                                    comment: "Onboarding step subtitle"))

            Picker("", selection: Binding(get: { manager.selectedUnit }, set: { manager.selectedUnit = $0 })) {
                ForEach(AppUnit.allCases, id: \.self) { unit in
                    Text(verbatim: unit.pickerLabel).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ValidatedNumberField(
                    value: manager.selectedUnit.fromMl(manager.defaultTargetMl),
                    range: displayRange(HydrationLimits.goal),
                    format: formatForInput,
                    onCommit: { manager.targetMl = manager.mlValue(from: $0) }
                )
                .frame(width: 120)
                Text(verbatim: manager.selectedUnit.symbol)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Suggestion (F21)
            Text("Not sure? Get a suggestion from your weight.",
                 comment: "Onboarding: goal suggestion prompt")
                .font(Theme.Font.calloutMedium)
            HStack(spacing: 8) {
                TextField("", text: $weightText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text(verbatim: GoalSuggestion.prefersPounds() ? "lb" : "kg")
                    .foregroundColor(.secondary)
                if let suggestion = suggestedGoal {
                    Button(String(format: String(localized: "Use %@", comment: "Onboarding: apply the suggested goal; %@ is an amount"),
                                  manager.displayValue(for: suggestion))) {
                        manager.targetMl = suggestion
                    }
                }
            }
            Text("About 30 ml per kilogram. A starting point, not medical advice: activity, heat and diet change your needs. Your weight is not saved.",
                 comment: "Onboarding: goal suggestion disclaimer")
                .font(Theme.Font.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var suggestedGoal: Double? {
        guard let value = NumberInput.parse(weightText) else { return nil }
        let kilograms = GoalSuggestion.prefersPounds() ? GoalSuggestion.kilograms(fromPounds: value) : value
        return GoalSuggestion.goalMl(forWeightKg: kilograms)
    }

    // MARK: Étape 2 — presets

    private var presetsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(title: String(localized: "Your usual glasses", comment: "Onboarding step title"),
                   subtitle: String(localized: "One click on a preset logs it. Set them to the glasses and bottles you actually use.",
                                    comment: "Onboarding step subtitle"))

            HStack(spacing: 12) {
                ForEach(Array(manager.presetsMl.enumerated()), id: \.offset) { index, preset in
                    VStack(spacing: 4) {
                        ValidatedNumberField(
                            value: manager.selectedUnit.fromMl(preset),
                            range: displayRange(HydrationLimits.single),
                            format: formatForInput,
                            alignment: .center,
                            onCommit: { updatePreset(at: index, displayValue: $0) }
                        )
                        Text(String(format: String(localized: "Preset %lld", comment: "Preset label with index"), index + 1))
                            .font(Theme.Font.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Label {
                Text("You can give each preset a global keyboard shortcut in Settings.",
                     comment: "Onboarding: hint about keyboard shortcuts")
            } icon: {
                Image(systemName: "keyboard")
            }
            .font(Theme.Font.callout)
            .foregroundColor(.secondary)
        }
    }

    // MARK: Étape 3 — rappels

    private var remindersStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(title: String(localized: "Reminders", comment: "Onboarding step title"),
                   subtitle: String(localized: "HydroBar can remind you to drink when you haven't logged anything for a while. macOS will ask for your permission.",
                                    comment: "Onboarding step subtitle"))

            Toggle(String(localized: "Enable reminders", comment: "Toggle label to enable reminders"),
                   isOn: Binding(
                    get: { manager.notificationsEnabled },
                    set: { newValue in
                        manager.setRemindersEnabled(newValue) { granted in
                            remindersDenied = newValue && !granted
                        }
                    }))
                .toggleStyle(.switch)

            if remindersDenied {
                Button(String(localized: "Notifications are turned off for HydroBar in System Settings.",
                              comment: "Shown when the user enables reminders but notifications are denied")) {
                    manager.openNotificationSettings()
                }
                .buttonStyle(.link)
                .font(Theme.Font.caption)
            }

            Toggle(String(localized: "Launch at login", comment: "Toggle label for launching the app at login"),
                   isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) }))
                .toggleStyle(.switch)
        }
        .onAppear { launchAtLogin.refresh() }
    }

    // MARK: Pied de page

    private var footer: some View {
        HStack {
            // Indicateur d'étape
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(String(format: String(localized: "Step %lld of %lld", comment: "Onboarding progress for VoiceOver"),
                                            step + 1, stepCount)))

            Spacer()

            if step > 0 {
                Button(String(localized: "Back", comment: "Onboarding navigation")) { step -= 1 }
            }
            if step < stepCount - 1 {
                Button(String(localized: "Next", comment: "Onboarding navigation")) { step += 1 }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(String(localized: "Done", comment: "Onboarding navigation")) { onFinish() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: Utilitaires

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Text(subtitle)
                .font(Theme.Font.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func displayRange(_ mlRange: ClosedRange<Double>) -> ClosedRange<Double> {
        let unit = manager.selectedUnit
        return unit.fromMl(mlRange.lowerBound)...unit.fromMl(mlRange.upperBound)
    }

    private func formatForInput(_ value: Double) -> String {
        NumberInput.fieldText(value, fractionDigits: manager.selectedUnit.inputFractionDigits)
    }

    private func updatePreset(at index: Int, displayValue: Double) {
        var presets = manager.presetsMl
        guard presets.indices.contains(index) else { return }
        presets[index] = manager.mlValue(from: displayValue)
        manager.presetsMl = presets
    }
}
