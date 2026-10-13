//
//  SettingsPreviews.swift
//  HydroBar
//
//  Aperçus en tête des pages de réglages : ce que règle la page, montré avec
//  les vues de l'app elle-même, et mis à jour à chaque changement. Ils ne
//  disent rien que les réglages ne disent déjà : VoiceOver les ignore.
//

import SwiftUI
import AppKit

// MARK: - Général : la barre des menus

/// Un bout de barre des menus, avec l'icône de HydroBar telle qu'elle est
/// réglée : anneau ou pourcentage, monochrome ou en couleur.
struct MenuBarPreview: View {
    @ObservedObject var manager: HydrationManager

    private var progress: Double {
        manager.targetMl > 0 ? manager.currentMl / manager.targetMl : 0
    }

    var body: some View {
        HStack(spacing: 14) {
            Spacer(minLength: 0)

            icon
                .padding(.horizontal, 7)
                .frame(minWidth: 32, minHeight: 22)
                .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Image(systemName: "switch.2")
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                    .monospacedDigit()
            }
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .modifier(GlassSurface(cornerRadius: Theme.Radius.control))
        .accessibilityHidden(true)
    }

    /// Les mêmes rendus que l'icône réelle (AppDelegate.updateStatusItem).
    @ViewBuilder
    private var icon: some View {
        if manager.coloredMenuBarIcon {
            MenuBarIconView(manager: manager)
                .fixedSize()
        } else {
            switch manager.menuBarIconStyle {
            case .pieRing:
                Image(nsImage: MenuBarIconRenderer.ring(progress: progress, showBadge: manager.showReminderBadge))
                    .renderingMode(.template)
            case .percentage:
                Image(nsImage: MenuBarIconRenderer.percentage(Int(progress * 100), showBadge: manager.showReminderBadge))
                    .renderingMode(.template)
            }
        }
    }
}

// MARK: - Rappels : la journée

/// Géométrie de la frise d'une journée, en fractions de 24 h. Pur : couvert
/// par DayTimelineTests.
enum DayTimeline {

    struct Layout: Equatable {
        /// Plage active.
        var band: ClosedRange<Double>
        /// Un rappel à chaque cadence écoulée depuis le début de la plage.
        var reminders: [Double]
        var lastCall: Double?
    }

    /// - Returns: `nil` pour une plage invalide (vide ou à cheval sur minuit),
    ///   que le planificateur refuse lui aussi.
    static func layout(startHour: Int, endHour: Int, intervalMinutes: Int,
                       remindersEnabled: Bool, lastCallEnabled: Bool) -> Layout? {
        guard (0..<24).contains(startHour), (1...24).contains(endHour), startHour < endHour else { return nil }
        let day = 24.0 * 60
        let start = Double(startHour * 60)
        let end = Double(endHour * 60)

        var lastCall: Double?
        if remindersEnabled, lastCallEnabled {
            let minute = end - ReminderContent.lastCallLead / 60
            if minute > start { lastCall = minute }
        }

        var reminders: [Double] = []
        if remindersEnabled, intervalMinutes > 0 {
            var minute = start + Double(intervalMinutes)
            while minute < end {
                // Pas deux notifications à quelques minutes d'écart : le
                // dernier appel remplace un rappel trop proche.
                if lastCall.map({ abs($0 - minute) >= 20 }) ?? true {
                    reminders.append(minute / day)
                }
                minute += Double(intervalMinutes)
            }
        }
        return Layout(band: (start / day)...(end / day), reminders: reminders, lastCall: lastCall.map { $0 / day })
    }
}

/// La journée sur 24 heures : la plage active en bleu, un trait par rappel à
/// la cadence choisie, un point pour le dernier appel. Avec les jours off, une
/// seconde frise montre ce qu'ils changent.
struct SchedulePreview: View {
    @ObservedObject var manager: HydrationManager

    private static let barHeight: CGFloat = 16
    private static let barSpacing: CGFloat = 7

    var body: some View {
        let plan = manager.dayPlan
        HStack(alignment: .top, spacing: 10) {
            // Avec les jours off, chaque frise porte le nom de sa journée ;
            // celle d'aujourd'hui est en gras.
            if plan.enabled {
                VStack(alignment: .trailing, spacing: Self.barSpacing) {
                    kindLabel(Text("Work Day", comment: "Day type"), isToday: manager.todayKind == .work)
                    kindLabel(Text("Day Off", comment: "Day type"), isToday: manager.todayKind == .off)
                }
            }

            VStack(spacing: Self.barSpacing) {
                DayTimelineBar(layout: DayTimeline.layout(
                    startHour: manager.activeHoursStart, endHour: manager.activeHoursEnd,
                    intervalMinutes: manager.reminderIntervalMinutes,
                    remindersEnabled: manager.notificationsEnabled,
                    lastCallEnabled: manager.lastCallEnabled))
                    .frame(height: Self.barHeight)
                if plan.enabled {
                    DayTimelineBar(layout: DayTimeline.layout(
                        startHour: plan.offStartHour, endHour: plan.offEndHour,
                        intervalMinutes: plan.offIntervalMinutes,
                        remindersEnabled: manager.notificationsEnabled && plan.offRemindersEnabled,
                        lastCallEnabled: manager.lastCallEnabled))
                        .frame(height: Self.barHeight)
                }
                HourScale()
            }
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }

    private func kindLabel(_ text: Text, isToday: Bool) -> some View {
        text
            .font(isToday ? Theme.Font.captionMedium : Theme.Font.caption)
            .foregroundStyle(isToday ? .primary : .secondary)
            .lineLimit(1)
            .fixedSize()
            .frame(height: Self.barHeight)
    }
}

struct DayTimelineBar: View {
    let layout: DayTimeline.Layout?

    var body: some View {
        Canvas { context, size in
            let radius = size.height / 2
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: radius),
                         with: .color(Theme.track))
            guard let layout else { return }

            let band = CGRect(x: layout.band.lowerBound * size.width, y: 0,
                              width: (layout.band.upperBound - layout.band.lowerBound) * size.width,
                              height: size.height)
            context.fill(Path(roundedRect: band, cornerRadius: radius),
                         with: .linearGradient(Gradient(colors: [Theme.water, Theme.waterLight]),
                                               startPoint: CGPoint(x: band.minX, y: 0),
                                               endPoint: CGPoint(x: band.maxX, y: 0)))

            for reminder in layout.reminders {
                let tick = CGRect(x: reminder * size.width - 0.75, y: 3.5, width: 1.5, height: size.height - 7)
                context.fill(Path(roundedRect: tick, cornerRadius: 0.75), with: .color(.white.opacity(0.9)))
            }

            // Une forme à part, pas seulement une couleur : le dernier appel
            // se distingue des rappels même en niveaux de gris.
            if let lastCall = layout.lastCall {
                let diameter = size.height - 4
                let dot = CGRect(x: lastCall * size.width - diameter / 2, y: 2, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: dot), with: .color(.white))
                context.fill(Path(ellipseIn: dot.insetBy(dx: 2, dy: 2)), with: .color(Theme.warning))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Repères horaires sous les frises : minuit, 6 h, midi, 18 h.
private struct HourScale: View {
    private static let hours = [0, 6, 12, 18]

    var body: some View {
        GeometryReader { geometry in
            ForEach(Self.hours, id: \.self) { hour in
                Text(verbatim: Self.label(hour))
                    .font(Theme.Font.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(x: CGFloat(hour) / 24 * geometry.size.width)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 12)
    }

    private static func label(_ hour: Int) -> String {
        guard let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) else {
            return "\(hour)"
        }
        return date.formatted(.dateTime.hour())
    }
}
