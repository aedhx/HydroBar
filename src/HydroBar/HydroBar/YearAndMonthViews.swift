//
//  YearAndMonthViews.swift
//  HydroBar
//
//  Vue sur l'année (moyenne quotidienne de chaque mois) et bilan du mois,
//  partageable en image. Possibles depuis que l'historique n'est plus tronqué
//  à 30 jours.
//

import SwiftUI
import Charts
import AppKit

// MARK: - Année

struct YearChartView: View {
    @ObservedObject var manager: HydrationManager

    var body: some View {
        let months = manager.monthlySummaries
        let goal = manager.selectedUnit.fromMl(manager.defaultTargetMl)

        if months.allSatisfy({ $0.trackedDays == 0 }) {
            Text("Your year will fill in as you log.", comment: "Year chart empty state")
                .font(Theme.Font.callout)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            Chart {
                ForEach(months) { month in
                    BarMark(
                        x: .value("Month", month.month, unit: .month),
                        y: .value("Average", manager.selectedUnit.fromMl(month.averageMl))
                    )
                    .foregroundStyle(month.averageMl >= manager.defaultTargetMl ? Theme.goal : Theme.water)
                    .cornerRadius(3)
                }
                // L'objectif en pointillés : chaque barre se lit par rapport à lui.
                RuleMark(y: .value("Goal", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.secondary)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.month(.narrow)))
                                .font(Theme.Font.footnote)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                }
            }
            .frame(height: 110)
            .padding(.horizontal, 16)
            .accessibilityElement()
            .accessibilityLabel(Text("Average daily intake for each of the last 12 months",
                                     comment: "VoiceOver label of the year chart"))
        }
    }
}

// MARK: - Bilan du mois

struct MonthlyRecapView: View {
    @ObservedObject var manager: HydrationManager

    var body: some View {
        if let month = manager.monthlySummaries.last, month.trackedDays > 0 {
            let card = MonthlyRecapCard(summary: month,
                                        streak: manager.currentStreak,
                                        format: manager.displayValue(for:))
            VStack(alignment: .leading, spacing: 8) {
                card
                    .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    if let image = render(card) {
                        ShareLink(item: Image(nsImage: image),
                                  preview: SharePreview(String(localized: "My month with HydroBar",
                                                               comment: "Share preview title of the monthly recap"),
                                                        image: Image(nsImage: image))) {
                            Label(String(localized: "Share", comment: "Share the monthly recap image"),
                                  systemImage: "square.and.arrow.up")
                        }
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.writeObjects([image])
                        } label: {
                            Label(String(localized: "Copy Image", comment: "Copy the monthly recap image"),
                                  systemImage: "doc.on.doc")
                        }
                    }
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
        }
    }

    /// Rendu en image, à deux fois la résolution pour un partage net.
    @MainActor
    private func render(_ card: MonthlyRecapCard) -> NSImage? {
        let renderer = ImageRenderer(content: card.frame(width: 300))
        renderer.scale = 2
        return renderer.nsImage
    }
}

/// La carte elle-même : pensée pour être partagée, donc lisible seule.
struct MonthlyRecapCard: View {
    let summary: HydrationStats.MonthSummary
    let streak: Int
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("HydroBar", systemImage: "drop.fill")
                    .font(Theme.Font.calloutEmphasis)
                Spacer()
                Text(summary.month.formatted(.dateTime.month(.wide).year()))
                    .font(Theme.Font.calloutMedium)
            }
            .opacity(0.9)

            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: format(summary.averageMl))
                    .font(Theme.Font.kpiValue)
                Text("a day on average", comment: "Monthly recap: under the average amount")
                    .font(Theme.Font.caption)
                    .opacity(0.85)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: String(localized: "Goal reached %lld of %lld days",
                                           comment: "Monthly recap; goal days out of tracked days"),
                            summary.goalDays, summary.trackedDays))
                if let best = summary.bestDay {
                    Text(String(format: String(localized: "Best day: %@, %@",
                                               comment: "Monthly recap; %1$@ is a date, %2$@ an amount"),
                                best.date.formatted(.dateTime.day().month(.abbreviated)),
                                format(best.amountMl)))
                }
                if streak > 1 {
                    Text(String(format: String(localized: "Current streak: %lld days.",
                                               comment: "Weekly summary streak; %lld is the streak length"),
                                streak))
                }
            }
            .font(Theme.Font.callout)
        }
        .foregroundColor(.white)
        .padding(16)
        .background(
            LinearGradient(colors: [Theme.water, Theme.waterLight],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}
