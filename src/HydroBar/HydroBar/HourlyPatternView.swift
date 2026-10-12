//
//  HourlyPatternView.swift
//  HydroBar
//
//  « Quand je bois » : moyenne par heure sur 30 jours, et le plus long creux
//  de la plage active. Impossible avant le journal d'événements (F5), qui
//  enregistre l'heure de chaque prise.
//

import SwiftUI
import Charts

struct HourlyPatternView: View {
    @ObservedObject var manager: HydrationManager
    @State private var hoveredHour: Int?

    /// En dessous, la moyenne ne dit encore rien.
    private static let minimumDays = 3
    private static let windowDays = 30

    private var pattern: (averages: [Double], dayCount: Int) {
        HydrationStats.hourlyAverages(events: manager.log.events,
                                      days: Self.windowDays,
                                      today: Date())
    }

    var body: some View {
        let data = pattern

        VStack(alignment: .leading, spacing: 8) {
            if data.dayCount < Self.minimumDays {
                Text("Log a few days to see when you drink.",
                     comment: "Hourly pattern empty state")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                insight(for: data.averages)
                chart(for: data.averages)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Phrase de synthèse

    @ViewBuilder
    private func insight(for averages: [Double]) -> some View {
        if let stretch = HydrationStats.quietestStretch(averages: averages,
                                                        activeStartHour: manager.activeHoursStart,
                                                        activeEndHour: manager.activeHoursEnd) {
            Label {
                Text(String(format: String(localized: "Your longest dry spell: %@ – %@.",
                                           comment: "Hourly pattern insight; %@ are times of day"),
                            hourLabel(stretch.start), hourLabel(stretch.end)))
            } icon: {
                Image(systemName: "hourglass")
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
    }

    // MARK: Graphique

    private func chart(for averages: [Double]) -> some View {
        Chart {
            ForEach(0..<24, id: \.self) { hour in
                BarMark(
                    x: .value("Hour", hour),
                    y: .value("Average", manager.selectedUnit.fromMl(averages[hour]))
                )
                .foregroundStyle(Color.blue.opacity(hoveredHour == nil || hoveredHour == hour ? 0.85 : 0.4))
                .cornerRadius(2)
            }
        }
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { value in
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text(hourLabel(hour)).font(.system(size: 10))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            if let hour = proxy.value(atX: location.x, as: Int.self) {
                                hoveredHour = min(max(hour, 0), 23)
                            }
                        case .ended:
                            hoveredHour = nil
                        }
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            if let hour = hoveredHour {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: manager.displayValue(for: averages[hour]))
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(format: String(localized: "on average around %@",
                                               comment: "Hourly pattern tooltip; %@ is a time of day"),
                                hourLabel(hour)))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(6)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
            }
        }
        .frame(height: 110)
        .accessibilityElement()
        .accessibilityLabel(Text("Average intake by hour of the day",
                                 comment: "VoiceOver label of the hourly pattern chart"))
        .accessibilityValue(Text(accessibilitySummary(averages)))
    }

    // MARK: Utilitaires

    private func hourLabel(_ hour: Int) -> String {
        let normalized = hour % 24
        guard let date = Calendar.current.date(bySettingHour: normalized, minute: 0, second: 0, of: Date()) else {
            return String(format: "%02d:00", normalized)
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// VoiceOver ne lit pas les barres : on lui donne l'heure de pointe.
    private func accessibilitySummary(_ averages: [Double]) -> String {
        guard let peak = averages.indices.max(by: { averages[$0] < averages[$1] }), averages[peak] > 0 else { return "" }
        return String(format: String(localized: "Most around %@.", comment: "VoiceOver: hour of peak intake"),
                      hourLabel(peak))
    }
}
