//
//  RemindersSettingsPage.swift
//  HydroBar
//
//  Page « Rappels » des réglages : rappels, pause et Concentration, plage
//  active, puis les jours off (DaysSettingsSection), qui sont un autre
//  horaire pour les mêmes réglages.
//

import SwiftUI
import AppKit

struct RemindersSettingsPage: View {
    @ObservedObject var manager: HydrationManager
    @ObservedObject private var focusMonitor = FocusModeMonitor.shared
    /// Le système a refusé les notifications à l'activation des rappels.
    @State private var notificationsDenied = false

    var body: some View {
        SettingsPage {
            remindersSection
            if manager.notificationsEnabled {
                optionsSection
                quietSection
            }
            activeHoursSection
            DaysSettingsSection(manager: manager)
        }
    }

    // MARK: - Rappels

    private var remindersSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { manager.notificationsEnabled },
                set: { newValue in
                    // Le didSet de notificationsEnabled programme ou
                    // annule les rappels.
                    manager.setRemindersEnabled(newValue) { granted in
                        notificationsDenied = newValue && !granted
                    }
                }
            )) {
                Text("Enable reminders", comment: "Toggle label to enable reminders")
            }

            // Refus visible et rattrapable, au lieu d'un interrupteur qui
            // revient en arrière sans explication.
            if notificationsDenied {
                SettingsLink(title: Text("Notifications are turned off for HydroBar in System Settings.",
                                         comment: "Shown when the user enables reminders but notifications are denied"),
                             isWarning: true,
                             action: { manager.openNotificationSettings() })
            }

            if manager.notificationsEnabled {
                LabeledContent {
                    intervalControls
                } label: {
                    intervalLabel
                }
            }
        }
    }

    private var intervalLabel: Text {
        Text("Remind me", comment: "Reminder interval label")
    }

    private var intervalControls: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Picker(selection: Binding(
                get: { manager.notificationInterval },
                set: { newValue in
                    manager.notificationInterval = newValue
                    manager.scheduleNotifications()
                }
            )) {
                ForEach(NotificationInterval.allCases, id: \.self) { interval in
                    Text(interval.localizedString).tag(interval)
                }
            } label: {
                intervalLabel
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            if manager.notificationInterval == .custom {
                ValidatedNumberField(
                    value: Double(manager.reminderIntervalMinutes),
                    range: Double(HydrationLimits.reminderMinutes.lowerBound)...Double(HydrationLimits.reminderMinutes.upperBound),
                    format: { NumberInput.fieldText($0, fractionDigits: 0...0) },
                    alignment: .trailing,
                    fieldWidth: SettingsLayout.amountFieldWidth,
                    suffix: String(localized: "minutes", comment: "Unit label for custom notification minutes"),
                    onCommit: { minutes in
                        manager.customNotificationMinutes = Int(minutes.rounded())
                        manager.scheduleNotifications()
                    }
                )
            }
        }
    }

    // MARK: - Rappels intelligents (F6)

    private var optionsSection: some View {
        Section {
            Toggle(isOn: Binding(get: { manager.adaptiveReminders },
                                 set: { manager.adaptiveReminders = $0 })) {
                Text("Adapt to my pace", comment: "Toggle: remind more often when behind schedule")
                Text("Reminders follow your active hours, stop once your goal is reached, and come a bit more often when you're behind.",
                     comment: "Explanation of how reminders are scheduled")
            }

            Toggle(isOn: Binding(get: { manager.weeklySummaryEnabled },
                                 set: { manager.weeklySummaryEnabled = $0 })) {
                Text("Weekly summary", comment: "Toggle: weekly summary notification")
            }

            Toggle(isOn: Binding(get: { manager.lastCallEnabled },
                                 set: { manager.lastCallEnabled = $0 })) {
                Text("Last call", comment: "Toggle: last call notification")
                Text("One hour before your day ends, if your goal isn't reached yet.",
                     comment: "Explanation of the last call notification")
            }

            Toggle(isOn: Binding(get: { manager.holdRemindersDuringCalls },
                                 set: { manager.holdRemindersDuringCalls = $0 })) {
                Text("Hold during calls", comment: "Toggle: no reminders during calls")
                Text("While an app uses your microphone or camera, reminders wait for the call to end.",
                     comment: "Explanation of holding reminders during calls")
            }
        }
    }

    // MARK: - Pause, Ne pas déranger, Concentration

    private var quietSection: some View {
        Section {
            snoozeRow

            // Le réglage manuel reste modifiable quand la synchro
            // Concentration est active : les deux se cumulent.
            // Le changement reprogramme les rappels (didSet).
            Toggle(isOn: Binding(get: { manager.doNotDisturb },
                                 set: { manager.doNotDisturb = $0 })) {
                Text("Do Not Disturb Mode", comment: "Toggle label for Do Not Disturb mode")
                if manager.focusModeAutoSync && manager.focusIsActive && !manager.doNotDisturb {
                    Text("A Focus is on: reminders appear as a badge.",
                         comment: "Shown when a macOS Focus currently silences reminders")
                }
            }

            focusRows
        }
    }

    /// L'état de la pause est toujours visible et annulable : c'est ce qui
    /// manque au mode Ne pas déranger, qu'on oublie de désactiver.
    @ViewBuilder
    private var snoozeRow: some View {
        if let until = manager.remindersSnoozedUntil {
            LabeledContent {
                Button(String(localized: "Resume", comment: "Button to end the reminders pause")) {
                    manager.resumeReminders()
                }
            } label: {
                Text(String(format: String(localized: "Paused until %@",
                                           comment: "Reminders snooze status; %@ is a time"),
                            until.formatted(date: .omitted, time: .shortened)))
            }
        } else {
            LabeledContent {
                Menu {
                    ForEach(SnoozeOption.allCases) { option in
                        Button(option.title) { manager.snoozeReminders(option) }
                    }
                } label: {
                    Text("Pause…", comment: "Snooze menu button")
                }
                .fixedSize()
            } label: {
                Text("Pause reminders", comment: "Label of the snooze menu in settings")
            }
        }
    }

    /// Synchronisation Focus Mode. L'ancien interrupteur activait le réglage sans
    /// jamais demander l'autorisation : il restait allumé alors que la
    /// fonctionnalité ne pouvait pas fonctionner. Chaque cas d'échec est désormais
    /// affiché — voir l'en-tête de FocusModeMonitor.swift.
    @ViewBuilder
    private var focusRows: some View {
        // La synchro par INFocusStatusCenter demande la capability
        // Communication Notifications, absente de la build App Store : le
        // filtre de Concentration ci-dessous fait mieux, sans autorisation.
        #if !APP_STORE
        Toggle(isOn: Binding(
            get: { manager.focusModeAutoSync },
            set: { newValue in
                // L'autorisation est demandée ici, pas au lancement :
                // une invite système n'a de sens qu'au moment où
                // l'utilisateur réclame la fonctionnalité.
                if newValue {
                    focusMonitor.enableAutoSync()
                } else {
                    focusMonitor.disableAutoSync()
                }
            }
        )) {
            Text("Sync with Focus Mode", comment: "Toggle label to sync with macOS Focus Mode")
            switch focusMonitor.availability {
            case .unavailable:
                Text("Focus status is unreadable. Check that HydroBar is allowed to send notifications — the Focus status also needs it.",
                     comment: "Focus Mode status unreadable despite authorization")
                    .foregroundStyle(Theme.warning)
            case .authorized, .notRequested:
                if manager.focusModeAutoSync {
                    Text("Do Not Disturb mode automatically follows macOS Focus Mode",
                         comment: "Explanation text for Focus Mode sync")
                }
            case .denied:
                EmptyView()
            }
        }

        if focusMonitor.availability == .denied {
            SettingsLink(title: Text("Access denied — grant it under Privacy & Security › Focus",
                                     comment: "Focus Mode authorization denied"),
                         isWarning: true,
                         action: { focusMonitor.openFocusPrivacySettings() })
        }
        #endif

        // Alternative sans autorisation ni capability : le filtre de
        // Concentration, réglé mode par mode dans Réglages Système.
        VStack(alignment: .leading, spacing: 4) {
            SettingsLink(title: Text("Choose per Focus in System Settings › Focus › Focus Filters",
                                     comment: "Link to configure the HydroBar Focus filter"),
                         action: openFocusSettings)
            if manager.focusFilterQuiet {
                Text("A Focus filter is showing reminders as a badge.",
                     comment: "Shown while the HydroBar Focus filter is active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func openFocusSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Plage active

    private var activeHoursSection: some View {
        Section {
            LabeledContent {
                HourRangePicker(
                    start: Binding(
                        get: { manager.activeHoursStart },
                        set: { newValue in
                            manager.activeHoursStart = newValue
                            // La plage ne doit jamais passer minuit : la journée est
                            // remise à zéro à 0 h, une plage à cheval porterait sur
                            // deux journées de données différentes.
                            if manager.activeHoursEnd <= newValue {
                                manager.activeHoursEnd = min(newValue + 1, 24)
                            }
                        }
                    ),
                    end: Binding(get: { manager.activeHoursEnd },
                                 set: { manager.activeHoursEnd = $0 })
                )
            } label: {
                Text("Active hours", comment: "Settings row: active hours")
            }
        } footer: {
            SettingsFooter(Text("Used by the pace marker on the ring: it shows where you should be at this time of day.",
                                comment: "Explanation for the active hours setting"))
        }
    }
}
