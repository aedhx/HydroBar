//
//  DaysSettingsSection.swift
//  HydroBar
//
//  Onglet « Jours » des réglages : jours off, journée en cours, congés.
//

import SwiftUI
import AppKit

struct DaysSettingsSection: View {
    @ObservedObject var manager: HydrationManager

    @State private var leaveStart = Date()
    @State private var leaveEnd = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var editingLeave = false

    private var plan: DayPlan { manager.dayPlan }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            enableSection
            if plan.enabled {
                todaySection
                weekdaysSection
                offDaySection
                leaveSection
                automationSection
            }
        }
    }

    private func update(_ change: (inout DayPlan) -> Void) {
        var plan = manager.dayPlan
        change(&plan)
        manager.dayPlan = plan
    }

    private func sectionTitle(_ title: Text) -> some View {
        title
            .font(Theme.Font.sectionTitle)
            .foregroundColor(.secondary)
    }

    private func caption(_ text: Text) -> some View {
        text
            .font(Theme.Font.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Activation

    private var enableSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(Text("DAYS OFF", comment: "Settings section title for days off"))
            Toggle(isOn: Binding(get: { plan.enabled },
                                 set: { enabled in update { $0.enabled = enabled } })) {
                Text("Different settings on days off", comment: "Toggle: enable day profiles")
                    .font(Theme.Font.body)
            }
            .toggleStyle(.switch)
            caption(Text("Your usual settings describe a work day. Days off can start later, remind you less often and have their own goal.",
                         comment: "Explanation of days off"))
        }
    }

    // MARK: Aujourd'hui

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(Text("TODAY", comment: "Settings section title: today's day type"))
            Picker("", selection: Binding(get: { manager.todayKind },
                                          set: { manager.setTodayKind($0) })) {
                Text("Work Day", comment: "Day type").tag(DayKind.work)
                Text("Day Off", comment: "Day type").tag(DayKind.off)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .disabled(manager.todayKindSetByFocus)

            if manager.todayKindSetByFocus {
                caption(Text("Set by your current Focus.", comment: "Day type chosen by a macOS Focus"))
            } else {
                caption(Text("Only for today. Tomorrow follows your week again.",
                             comment: "Explanation of today's day type override"))
            }
        }
    }

    // MARK: Semaine

    /// Jours dans l'ordre de la locale (lundi d'abord en France).
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private var weekdaysSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(Text("MY DAYS OFF", comment: "Settings section title: weekdays that are days off"))
            HStack(spacing: 6) {
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    weekdayChip(weekday)
                }
            }
        }
    }

    private func weekdayChip(_ weekday: Int) -> some View {
        let isOff = plan.offWeekdays.contains(weekday)
        let calendar = Calendar.current
        return Button {
            update { plan in
                if isOff { plan.offWeekdays.remove(weekday) } else { plan.offWeekdays.insert(weekday) }
            }
        } label: {
            Text(verbatim: calendar.shortWeekdaySymbols[weekday - 1])
                .font(Theme.Font.calloutMedium)
                .frame(width: 40, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.row)
                        .fill(isOff ? Theme.water.opacity(0.25) : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: calendar.weekdaySymbols[weekday - 1]))
        .accessibilityValue(isOff
                            ? Text("Day Off", comment: "Day type")
                            : Text("Work Day", comment: "Day type"))
        .accessibilityAddTraits(isOff ? .isSelected : [])
    }

    // MARK: Réglages des jours off

    private var offDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(Text("ON DAYS OFF", comment: "Settings section title: settings used on days off"))

            HStack(spacing: 8) {
                Text("Active hours", comment: "Days off: active hours label")
                    .font(Theme.Font.body)
                    .frame(width: 120, alignment: .leading)
                Picker("", selection: Binding(
                    get: { plan.offStartHour },
                    set: { start in
                        update { plan in
                            plan.offStartHour = start
                            // Jamais à cheval sur minuit, comme la plage habituelle.
                            if plan.offEndHour <= start { plan.offEndHour = min(start + 1, 24) }
                        }
                    }
                )) {
                    ForEach(HydrationPace.selectableStartHours, id: \.self) { hour in
                        Text(verbatim: hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 90)
                Text("to", comment: "Separator between start and end hour")
                    .font(Theme.Font.callout)
                    .foregroundColor(.secondary)
                Picker("", selection: Binding(get: { plan.offEndHour },
                                              set: { end in update { $0.offEndHour = end } })) {
                    ForEach(HydrationPace.selectableEndHours.filter { $0 > plan.offStartHour }, id: \.self) { hour in
                        Text(verbatim: hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 90)
            }

            Toggle(isOn: Binding(get: { plan.offRemindersEnabled },
                                 set: { enabled in update { $0.offRemindersEnabled = enabled } })) {
                Text("Reminders on days off", comment: "Toggle: reminders on days off")
                    .font(Theme.Font.body)
            }
            .toggleStyle(.switch)

            if plan.offRemindersEnabled {
                HStack(spacing: 8) {
                    Text("Remind me", comment: "Days off: reminder interval label")
                        .font(Theme.Font.body)
                        .frame(width: 120, alignment: .leading)
                    Picker("", selection: Binding(get: { plan.offIntervalMinutes },
                                                  set: { minutes in update { $0.offIntervalMinutes = minutes } })) {
                        ForEach(DayPlan.selectableIntervals, id: \.self) { minutes in
                            Text(verbatim: intervalLabel(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 160)
                }
            }

            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { plan.offGoalMl != nil },
                    set: { enabled in update { $0.offGoalMl = enabled ? manager.defaultTargetMl : nil } }
                )) {
                    Text("Own goal", comment: "Toggle: a different goal on days off")
                        .font(Theme.Font.body)
                        .frame(width: 100, alignment: .leading)
                }
                .toggleStyle(.checkbox)

                if let goal = plan.offGoalMl {
                    ValidatedNumberField(
                        value: manager.selectedUnit.fromMl(goal),
                        range: goalRange,
                        format: { NumberInput.fieldText($0, fractionDigits: manager.selectedUnit.inputFractionDigits) },
                        onCommit: { value in update { $0.offGoalMl = manager.mlValue(from: value) } }
                    )
                    .frame(width: 90)
                    Text(verbatim: manager.selectedUnit.symbol)
                        .font(Theme.Font.caption)
                        .foregroundColor(.secondary)
                }
            }
            caption(Text("Without its own goal, a day off uses your goal for that day of the week.",
                         comment: "Explanation of the days off goal"))
        }
    }

    /// Bornes de l'objectif, dans l'unité affichée.
    private var goalRange: ClosedRange<Double> {
        let unit = manager.selectedUnit
        return unit.fromMl(HydrationLimits.goal.lowerBound)...unit.fromMl(HydrationLimits.goal.upperBound)
    }

    // MARK: Congés

    @ViewBuilder
    private var leaveSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(Text("TIME OFF", comment: "Settings section title: leave period"))

            if let end = plan.leaveEndDate(after: Date(), calendar: .current), !editingLeave {
                HStack {
                    Image(systemName: "beach.umbrella")
                        .foregroundColor(.secondary)
                    Text(String(format: String(localized: "Days off until %@",
                                               comment: "Leave period status; %@ is a date"),
                                end.formatted(.dateTime.weekday(.wide).day().month(.wide))))
                        .font(Theme.Font.body)
                    Spacer()
                    Button(String(localized: "End", comment: "Button: end the leave period")) {
                        update { $0.clearLeave() }
                    }
                    .controlSize(.small)
                }
            } else if editingLeave {
                HStack(spacing: 8) {
                    DatePicker(String(localized: "From", comment: "Leave period start"),
                               selection: $leaveStart, displayedComponents: .date)
                    DatePicker(String(localized: "To", comment: "Leave period end"),
                               selection: $leaveEnd, in: leaveStart..., displayedComponents: .date)
                }
                .datePickerStyle(.field)
                HStack {
                    Button(String(localized: "Cancel", comment: "Cancel button")) { editingLeave = false }
                    Button(String(localized: "Save", comment: "Save the leave period")) {
                        update { $0.setLeave(from: leaveStart, to: leaveEnd, calendar: .current) }
                        editingLeave = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .controlSize(.small)
            } else {
                Button {
                    leaveStart = Date()
                    leaveEnd = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
                    editingLeave = true
                } label: {
                    Label(String(localized: "Add Time Off…", comment: "Button: add a leave period"),
                          systemImage: "beach.umbrella")
                }
                .controlSize(.small)
            }
            caption(Text("Every day of your time off follows your day-off settings.",
                         comment: "Explanation of the leave period"))
        }
    }

    // MARK: Automatique

    private var automationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(Text("AUTOMATIC", comment: "Settings section title: automatic day type"))
            caption(Text("A Focus can choose the day type: add the HydroBar filter to your Work Focus. The Shortcuts app can also set it with “Set Today's Day Type”.",
                         comment: "Explanation of the automatic day type"))
            Button(String(localized: "Open Focus Settings…", comment: "Button opening macOS Focus settings")) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
    }

    // MARK: Formats

    /// Heure formatée selon la locale (« 8 AM » ou « 08:00 »).
    private func hourLabel(_ hour: Int) -> String {
        let normalized = hour == 24 ? 0 : hour
        guard let date = Calendar.current.date(bySettingHour: normalized, minute: 0, second: 0, of: Date()) else {
            return String(format: "%02d:00", normalized)
        }
        return date.formatted(.dateTime.hour().minute())
    }

    private func intervalLabel(_ minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.allowedUnits = [.hour, .minute]
        let duration = formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
        return String(format: String(localized: "Every %@", comment: "Reminder interval; %@ is a duration"), duration)
    }
}
