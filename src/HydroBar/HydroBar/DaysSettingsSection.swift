//
//  DaysSettingsSection.swift
//  HydroBar
//
//  Carte « Jours off » de la page Rappels : un interrupteur, et sous lui,
//  quand il est allumé, tout ce qui distingue un jour off — journée en cours,
//  jours de la semaine, plage, rappels, objectif, congés, automatisation.
//

import SwiftUI
import AppKit

struct DaysSettingsSection: View {
    @ObservedObject var manager: HydrationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var leaveStart = Date()
    @State private var leaveEnd = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var editingLeave = false
    @State private var showsAutomation = false

    private var plan: DayPlan { manager.dayPlan }

    var body: some View {
        SettingsCard {
            Toggle(isOn: Binding(get: { plan.enabled },
                                 set: { enabled in update { $0.enabled = enabled } })) {
                Text("Different settings on days off", comment: "Toggle: enable day profiles")
                // Allumé, les lignes qui suivent le disent d'elles-mêmes.
                if !plan.enabled {
                    Text("Your usual settings describe a work day. Days off can start later, remind you less often and have their own goal.",
                         comment: "Explanation of days off")
                }
            }

            if plan.enabled {
                todayRow
                weekdaysRow
                hoursRow
                remindersRow
                ownGoalRow
                leaveRows
                automationRow
            }
        }
        .animation(Theme.motion(Theme.Motion.quick, reduceMotion: reduceMotion), value: plan.enabled)
    }

    private func update(_ change: (inout DayPlan) -> Void) {
        var plan = manager.dayPlan
        change(&plan)
        manager.dayPlan = plan
    }

    // MARK: Aujourd'hui

    private var todayLabel: Text {
        Text("Today", comment: "Settings row: today's day type")
    }

    private var todayRow: some View {
        LabeledContent {
            Picker(selection: Binding(get: { manager.todayKind },
                                      set: { manager.setTodayKind($0) })) {
                Text("Work Day", comment: "Day type").tag(DayKind.work)
                Text("Day Off", comment: "Day type").tag(DayKind.off)
            } label: {
                todayLabel
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .disabled(manager.todayKindSetByFocus)
        } label: {
            todayLabel
            if manager.todayKindSetByFocus {
                Text("Set by your current Focus.", comment: "Day type chosen by a macOS Focus")
            }
        }
        .help(Text("Only for today. Tomorrow follows your week again.",
                   comment: "Explanation of today's day type override"))
    }

    // MARK: Semaine

    /// Jours dans l'ordre de la locale (lundi d'abord en France).
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private var weekdaysRow: some View {
        LabeledContent {
            HStack(spacing: 4) {
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    weekdayToggle(weekday)
                }
            }
        } label: {
            Text("My days off", comment: "Settings row: weekdays that are days off")
        }
    }

    private func weekdayToggle(_ weekday: Int) -> some View {
        let isOff = plan.offWeekdays.contains(weekday)
        let calendar = Calendar.current
        return Toggle(isOn: Binding(
            get: { isOff },
            set: { off in
                update { plan in
                    if off { plan.offWeekdays.insert(weekday) } else { plan.offWeekdays.remove(weekday) }
                }
            }
        )) {
            Text(verbatim: calendar.shortWeekdaySymbols[weekday - 1])
        }
        .toggleStyle(.button)
        .accessibilityLabel(Text(verbatim: calendar.weekdaySymbols[weekday - 1]))
        .accessibilityValue(isOff
                            ? Text("Day Off", comment: "Day type")
                            : Text("Work Day", comment: "Day type"))
    }

    // MARK: Plage, rappels, objectif

    private var hoursRow: some View {
        LabeledContent {
            HourRangePicker(
                start: Binding(
                    get: { plan.offStartHour },
                    set: { start in
                        update { plan in
                            plan.offStartHour = start
                            // Jamais à cheval sur minuit, comme la plage habituelle.
                            if plan.offEndHour <= start { plan.offEndHour = min(start + 1, 24) }
                        }
                    }
                ),
                end: Binding(get: { plan.offEndHour },
                             set: { end in update { $0.offEndHour = end } })
            )
        } label: {
            Text("Active hours", comment: "Days off: active hours label")
        }
    }

    private var remindersLabel: Text {
        Text("Reminders on days off", comment: "Toggle: reminders on days off")
    }

    /// L'interrupteur et, allumé, la cadence à sa gauche.
    private var remindersRow: some View {
        LabeledContent {
            HStack(spacing: 10) {
                if plan.offRemindersEnabled {
                    Picker(selection: Binding(get: { plan.offIntervalMinutes },
                                              set: { minutes in update { $0.offIntervalMinutes = minutes } })) {
                        ForEach(DayPlan.selectableIntervals, id: \.self) { minutes in
                            Text(verbatim: intervalLabel(minutes)).tag(minutes)
                        }
                    } label: {
                        Text("Remind me", comment: "Reminder interval label")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Toggle(isOn: Binding(get: { plan.offRemindersEnabled },
                                     set: { enabled in update { $0.offRemindersEnabled = enabled } })) {
                    remindersLabel
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
        } label: {
            remindersLabel
        }
    }

    private var ownGoalLabel: Text {
        Text("Own goal", comment: "Toggle: a different goal on days off")
    }

    private var ownGoalRow: some View {
        LabeledContent {
            HStack(spacing: 10) {
                if let goal = plan.offGoalMl {
                    AmountField(manager: manager, valueMl: goal, rangeMl: HydrationLimits.goal) { goal in
                        update { $0.offGoalMl = goal }
                    }
                }
                Toggle(isOn: Binding(
                    get: { plan.offGoalMl != nil },
                    set: { enabled in update { $0.offGoalMl = enabled ? manager.defaultTargetMl : nil } }
                )) {
                    ownGoalLabel
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
        } label: {
            ownGoalLabel
        }
        .help(Text("Without its own goal, a day off uses your goal for that day of the week.",
                   comment: "Explanation of the days off goal"))
    }

    // MARK: Congés

    @ViewBuilder
    private var leaveRows: some View {
        if let end = plan.leaveEndDate(after: Date(), calendar: .current), !editingLeave {
            LabeledContent {
                Button(String(localized: "End", comment: "Button: end the leave period")) {
                    update { $0.clearLeave() }
                }
            } label: {
                Label(String(format: String(localized: "Days off until %@",
                                            comment: "Leave period status; %@ is a date"),
                             end.formatted(.dateTime.weekday(.wide).day().month(.wide))),
                      systemImage: "beach.umbrella")
            }
        } else if editingLeave {
            HStack(spacing: 10) {
                DatePicker(String(localized: "From", comment: "Leave period start"),
                           selection: $leaveStart, displayedComponents: .date)
                DatePicker(String(localized: "To", comment: "Leave period end"),
                           selection: $leaveEnd, in: leaveStart..., displayedComponents: .date)
                Spacer(minLength: 0)
                Button(String(localized: "Cancel", comment: "Cancel button")) { editingLeave = false }
                Button(String(localized: "Save", comment: "Save the leave period")) {
                    update { $0.setLeave(from: leaveStart, to: leaveEnd, calendar: .current) }
                    editingLeave = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .datePickerStyle(.field)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            LabeledContent {
                Button(String(localized: "Add Time Off…", comment: "Button: add a leave period")) {
                    leaveStart = Date()
                    leaveEnd = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
                    editingLeave = true
                }
            } label: {
                Text("Time off", comment: "Settings row: leave period")
            }
            .help(Text("Every day of your time off follows your day-off settings.",
                       comment: "Explanation of the leave period"))
        }
    }

    // MARK: Automatique

    /// Replié par défaut : c'est une explication et un raccourci vers
    /// Réglages Système, pas un réglage de HydroBar.
    private var automationRow: some View {
        DisclosureGroup(isExpanded: $showsAutomation.animation(Theme.motion(Theme.Motion.quick, reduceMotion: reduceMotion))) {
            VStack(alignment: .leading, spacing: 8) {
                Text("A Focus can choose the day type: add the HydroBar filter to your Work Focus. The Shortcuts app can also set it with “Set Today's Day Type”.",
                     comment: "Explanation of the automatic day type")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(String(localized: "Open Focus Settings…", comment: "Button opening macOS Focus settings")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        } label: {
            Text("Automatic", comment: "Settings row: automatic day type")
        }
    }

    // MARK: Formats

    private func intervalLabel(_ minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.allowedUnits = [.hour, .minute]
        let duration = formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
        return String(format: String(localized: "Every %@", comment: "Reminder interval; %@ is a duration"), duration)
    }
}
