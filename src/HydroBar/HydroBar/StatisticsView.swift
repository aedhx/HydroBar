//
//  StatisticsView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import Charts
import AppKit

// MARK: - StatisticsScrollView

/// Les statistiques dans leur zone défilante, avec la marge du popover.
///
/// Quand les barres de défilement sont toujours visibles (réglage système, ou
/// souris branchée), la barre prend une quinzaine de points à droite du contenu
/// au lieu de flotter par-dessus : la marge de droite faisait 35 pt, celle de
/// gauche 20. La marge de droite est donc réduite de ce que la barre occupe.
/// La barre vit dans la marge, jamais sur le contenu, et les blocs restent à
/// égale distance des deux bords du popover dans les deux cas.
struct StatisticsScrollView: View {
    @ObservedObject var manager: HydrationManager
    @Binding var currentView: ViewType

    /// Largeur de la zone défilante, et largeur qu'elle laisse à son contenu.
    @State private var viewportWidth: CGFloat = 0
    @State private var contentWidth: CGFloat = 0

    /// Ce que la barre de défilement retire au contenu : 0 quand elle flotte.
    private var scrollerGutter: CGFloat {
        guard viewportWidth > 0, contentWidth > 0 else {
            // Avant la première mesure, ce qu'AppKit annonce : la marge est
            // juste dès la première image.
            return NSScroller.preferredScrollerStyle == .legacy
                ? NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
                : 0
        }
        return max(viewportWidth - contentWidth, 0)
    }

    var body: some View {
        ScrollView {
            StatisticsView(manager: manager, currentView: $currentView)
                .padding(.leading, Theme.Spacing.inset)
                .padding(.trailing, max(Theme.Spacing.inset - scrollerGutter, 0))
                .padding(.vertical, Theme.Spacing.inset)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { contentWidth = $0 }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { viewportWidth = $0 }
    }
}

// MARK: - StatisticsView

/// Le contenu des statistiques, sans marge : c'est `StatisticsScrollView` qui
/// la pose, une fois, pour tous les blocs.
struct StatisticsView: View {
    @ObservedObject var manager: HydrationManager
    @Binding var currentView: ViewType

    private var streak: Int {
        manager.currentStreak
    }

    /// Le bilan n'existe qu'à partir du premier jour noté du mois. Sans lui,
    /// la section se réduisait à son titre, collé à la section suivante.
    private var hasMonthlyRecap: Bool {
        (manager.monthlySummaries.last?.trackedDays ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.section) {
            // KPIs Header
            StatsHeaderView(manager: manager)

            // Section Cette Semaine
            StatsSection(Text("This Week", comment: "Section title for weekly statistics")) {
                WeeklyChartView(manager: manager)
            }

            // Section Quand je bois (par heure, 30 jours)
            StatsSection(Text("When You Drink (30 days)", comment: "Title for the hourly intake pattern chart")) {
                HourlyPatternView(manager: manager)
            }

            // Section Activité Mensuelle
            StatsSection(Text("Consistency (30 days)", comment: "Title for 30-day consistency heatmap")) {
                MonthlyHeatmapView(manager: manager)
            }

            // Section Ce mois-ci : bilan partageable
            if hasMonthlyRecap {
                StatsSection(Text("This Month", comment: "Title for the monthly recap section")) {
                    MonthlyRecapView(manager: manager)
                }
            }

            // Section Année : moyenne quotidienne de chaque mois
            StatsSection(Text("Your Year", comment: "Title for the 12-month chart")) {
                YearChartView(manager: manager)
            }

            // Section Streak (mise en valeur)
            VStack(spacing: 4) {
                Text(String(format: String(localized: "Current streak: %lld days 🔥", comment: "Current streak display with number of days"), streak))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                if streak > 3 {
                    Text("You're unstoppable!", comment: "Motivational message for long streaks")
                        .font(Theme.Font.captionMedium)
                        .foregroundColor(Theme.goal)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, Theme.Spacing.tile)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.goal.opacity(0.1),
                                Theme.water.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                // strokeBorder : le trait reste à l'intérieur du bloc, sur la
                // même ligne que les autres (stroke débordait de 0,75 pt).
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        streak > 3 ? Theme.goal.opacity(0.3) : Theme.water.opacity(0.2),
                        lineWidth: 1.5
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    StatisticsScrollView(manager: HydrationManager.shared, currentView: .constant(.statistics))
        .frame(width: 320, height: 620)
        .background(Color.black)
}
