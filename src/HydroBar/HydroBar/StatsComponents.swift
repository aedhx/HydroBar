//
//  StatsComponents.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import Charts

// MARK: - KPICardView
struct KPICardView: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icône et Titre en haut
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(Theme.Font.caption)
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(Theme.Font.captionMedium)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Valeur en grand et gras au centre
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Theme.Font.kpiValue)
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(Theme.Font.controlMedium)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            // strokeBorder : le trait reste dans la tuile, sur la marge commune.
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - StatsSection

/// Une section des statistiques : son titre, puis son contenu. Le même écart
/// entre les deux partout — chaque section réglait le sien, et chaque bloc sa
/// marge.
struct StatsSection<Content: View>: View {
    private let title: Text
    private let content: Content

    init(_ title: Text, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.title) {
            title
                .font(Theme.Font.bodyEmphasis)
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - StatsEmptyState

/// Bloc sans données : une icône et une phrase centrées, dans un cadre de la
/// largeur des autres blocs. C'était une phrase seule, avec son propre retrait.
struct StatsEmptyState: View {
    let systemImage: String
    let message: Text

    var body: some View {
        VStack(spacing: Theme.Spacing.title) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            message
                .font(Theme.Font.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.tile)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            // Pointillés, comme les cases hors période de la heatmap : « rien
            // ici pour l'instant ».
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Color.secondary.opacity(0.3),
                              style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}

// MARK: - Bulle de valeur

extension View {
    /// Bulle affichée sur un graphique pour le jour ou l'heure pointés.
    func statsTooltip() -> some View {
        padding(6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
    }
}

// MARK: - StatsHeaderView
struct StatsHeaderView: View {
    @ObservedObject var manager: HydrationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Theme.Spacing.tile),
            GridItem(.flexible(), spacing: Theme.Spacing.tile)
        ], spacing: Theme.Spacing.tile) {
            // Carte 1: Moyenne
            let avgFormatted = formatValue(manager.dailyAverage)
            KPICardView(
                title: String(localized: "Average", comment: "KPI card title for daily average"),
                value: avgFormatted.value,
                unit: avgFormatted.unit,
                icon: "chart.line.uptrend.xyaxis"
            )
            .transition(.scale.combined(with: .opacity))
            
            // Carte 2: Total Hebdo
            let totalFormatted = formatValue(manager.weeklyTotal)
            KPICardView(
                title: String(localized: "Weekly Total", comment: "KPI card title for weekly total"),
                value: totalFormatted.value,
                unit: totalFormatted.unit,
                icon: "drop.fill"
            )
            .transition(.scale.combined(with: .opacity))
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.1), value: manager.dailyAverage)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.15), value: manager.weeklyTotal)
    }
    
    /// Toujours dans l'unité choisie. L'ancienne version basculait en litres
    /// au-delà de 1 000 ml quelle que soit l'unité : un utilisateur en onces voyait
    /// son total hebdomadaire — toujours supérieur à un litre — affiché en litres.
    private func formatValue(_ ml: Double) -> (value: String, unit: String) {
        let unit = manager.selectedUnit
        return (unit.formattedNumber(ml: ml), unit.symbol)
    }
}

// MARK: - WeeklyChartView
struct WeeklyChartView: View {
    @ObservedObject var manager: HydrationManager
    @State private var selectedDay: HistoryEntry?
    
    /// Dernière graduation au plus haut. L'axe montait à 200 % pour une seule
    /// journée très arrosée : la ligne d'objectif tombait au milieu, et la
    /// moitié du graphique ne servait qu'à cette barre. Au-delà, la barre sort
    /// du cadre, coupée net ; la quantité exacte reste dans la bulle.
    private static let maximumAxisTick = 1.5
    /// Air au-dessus de la dernière graduation : son trait et son libellé
    /// tiennent dans le cadre au lieu de déborder sur le titre.
    private static let axisHeadroom = 0.1
    /// Hauteur du repère d'un jour vide, en part de la hauteur du graphique.
    private static let stubShare = 0.03

    private var weeklyData: [HistoryEntry] {
        // Les données sont déjà triées par date croissante dans getLast7DaysHistoryData()
        manager.getLast7DaysHistoryData()
    }

    /// Part de l'objectif portée par la barre, et lue par VoiceOver : limitée
    /// à 200 %, comme avant.
    private func fraction(for entry: HistoryEntry) -> Double {
        entry.targetMl > 0 ? min(entry.amountMl / entry.targetMl, 2.0) : 0
    }

    /// Jusqu'où l'axe doit monter : ce que la semaine demande, par pas de
    /// 25 %, entre 100 % (la ligne d'objectif est toujours là) et 150 %.
    private func axisExtent(for data: [HistoryEntry]) -> Double {
        let peak = data.map(fraction(for:)).max() ?? 0
        let needed = (max(peak, 1) / 0.25).rounded(.up) * 0.25
        return min(needed, Self.maximumAxisTick)
    }

    var body: some View {
        let data = weeklyData
        let extent = axisExtent(for: data)
        let top = extent + Self.axisHeadroom

        Chart {
            // Barres pour chaque jour
            ForEach(data) { entry in
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Percentage", fraction(for: entry))
                )
                .foregroundStyle(entry.amountMl >= entry.targetMl ? Theme.goal : Theme.water)
                .cornerRadius(4, style: .continuous)
                .opacity(selectedDay?.id == entry.id ? 1.0 : 0.8)

                // Un jour sans prise garde un repère : la semaine se lit comme
                // sept emplacements, pas comme une barre isolée. Décoratif,
                // donc masqué à VoiceOver, qui lit toujours la barre ci-dessus.
                if entry.amountMl <= 0 {
                    BarMark(
                        x: .value("Day", entry.date, unit: .day),
                        yStart: .value("Percentage", 0),
                        yEnd: .value("Percentage", top * Self.stubShare)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .cornerRadius(2, style: .continuous)
                    .accessibilityHidden(true)
                }
            }

            // L'objectif en pointillés, comme sur la vue de l'année.
            RuleMark(y: .value("Goal", 1.0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.secondary)
                .accessibilityHidden(true)
        }
        .chartYScale(domain: 0...top)
        // Une barre plus haute que l'axe est coupée au bord du graphique.
        .chartPlotStyle { $0.clipped() }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                // Centré sous la barre : le libellé partait du bord gauche de
                // la journée.
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        let isToday = Calendar.current.isDateInToday(date)
                        Text(shortDayName(for: date))
                            .font(isToday ? Theme.Font.footnoteEmphasis : Theme.Font.footnote)
                            .foregroundStyle(isToday ? Color.primary : Color.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            // À droite, comme les graphiques du système : le tracé part de la
            // marge commune au lieu d'être repoussé par la largeur de « 100% ».
            AxisMarks(position: .trailing, values: Array(stride(from: 0.0, through: extent, by: 0.5))) { value in
                let isGoal = value.as(Double.self) == 1.0
                // À 100 %, c'est la ligne d'objectif qui fait foi.
                AxisGridLine().foregroundStyle(Color.secondary.opacity(isGoal ? 0 : 0.2))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text("\(Int(doubleValue * 100))%")
                            .font(Theme.Font.footnote)
                    }
                }
            }
        }
        .frame(height: 140)
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                // Trouver la barre la plus proche au survol
                                let location = gesture.location
                                if let date = chartProxy.value(atX: location.x, as: Date.self) {
                                    selectedDay = data.first { entry in
                                        Calendar.current.isDate(entry.date, inSameDayAs: date)
                                    }
                                }
                            }
                            .onEnded { _ in
                                // Garder la sélection même après le relâchement
                            }
                    )
            }
        }
        .overlay(alignment: .topTrailing) {
            if let selected = selectedDay {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(manager.displayValue(for: selected.amountMl))
                        .font(Theme.Font.calloutEmphasis)
                        .foregroundColor(.primary)
                    Text(dayLabel(for: selected.date))
                        .font(Theme.Font.footnote)
                        .foregroundColor(.secondary)
                }
                .statsTooltip()
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    /// Libellé du jour sélectionné, dans la langue de l'utilisateur.
    /// Forcé en français auparavant, quelle que soit la langue de l'app.
    private func dayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return String(localized: "Today", comment: "Label for today's date")
        }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    /// Abréviation du jour sur l'axe (« Mo », « lu », « Mo »…), fournie par le
    /// système pour chaque langue. L'ancienne version écrivait les noms à la main
    /// en français et en anglais seulement, et tronquait « Today » à deux lettres
    /// (« TO », « AU ») pour le jour courant.
    private func shortDayName(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.short))
    }
}

// MARK: - MonthlyHeatmapView
struct MonthlyHeatmapView: View {
    @ObservedObject var manager: HydrationManager
    @Environment(\.colorScheme) var colorScheme
    
    private var monthlyData: [HistoryEntry] {
        manager.getLast30DaysData()
    }
    
    private static let columns = 7

    /// Les 30 jours rangés en semaines : une colonne par jour de la semaine, la
    /// première étant le premier jour de la semaine de l'utilisateur. `nil`
    /// pour une case hors période — avant le premier des 30 jours, ou après
    /// aujourd'hui.
    private var weekRows: [[HistoryEntry?]] {
        let calendar = Calendar.current
        let entries = monthlyData
        guard let firstDate = entries.first?.date else { return [] }

        // weekday : 1 = dimanche ; firstWeekday : 1 (dimanche) ou 2 (lundi) le plus souvent.
        let weekday = calendar.component(.weekday, from: firstDate)
        let leading = (weekday - calendar.firstWeekday + Self.columns) % Self.columns

        var slots: [HistoryEntry?] = Array(repeating: nil, count: leading)
        slots.append(contentsOf: entries)
        let trailing = (Self.columns - slots.count % Self.columns) % Self.columns
        slots.append(contentsOf: Array(repeating: nil, count: trailing))

        return stride(from: 0, to: slots.count, by: Self.columns).map {
            Array(slots[$0..<$0 + Self.columns])
        }
    }

    var body: some View {
        let weeks = weekRows

        VStack(alignment: .leading, spacing: Theme.Spacing.title) {
            // Grille : sept colonnes de même largeur, d'un bord à l'autre, les
            // cases carrées s'ajustant à la largeur disponible.
            VStack(spacing: Theme.Spacing.cell) {
                // Jours de la semaine : sans eux, rien ne disait que les
                // colonnes en étaient, et la dernière ligne, incomplète,
                // semblait orpheline.
                HStack(spacing: Theme.Spacing.cell) {
                    ForEach(0..<Self.columns, id: \.self) { column in
                        Text(verbatim: weekdayLabel(forColumn: column, in: weeks))
                            .font(Theme.Font.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)

                ForEach(weeks.indices, id: \.self) { row in
                    HStack(spacing: Theme.Spacing.cell) {
                        ForEach(0..<Self.columns, id: \.self) { column in
                            if let entry = weeks[row][column] {
                                heatmapCell(for: entry, manager: manager, colorScheme: colorScheme)
                            } else {
                                placeholderCell
                            }
                        }
                    }
                }
            }

            // Légende, calée sur le bord droit de la grille.
            HStack(spacing: Theme.Spacing.title) {
                Text("Less", comment: "Legend label for less activity")
                    .font(Theme.Font.footnote)
                    .foregroundColor(.secondary)

                // Échantillons tirés de colorForPercentage, comme les cellules :
                // la légende affichait auparavant d'autres opacités (0,3 / 0,6)
                // que les cellules qu'elle était censée expliquer (0,4 / 0,7).
                HStack(spacing: 4) {
                    ForEach([0.0, 0.25, 0.75, 1.0, 1.5], id: \.self) { sample in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForPercentage(sample, colorScheme: colorScheme))
                            .frame(width: 12, height: 12)
                            .shadow(color: sample >= 1.5 ? Theme.goal.opacity(0.5) : .clear, radius: 2)
                    }
                }

                Text("More", comment: "Legend label for more activity")
                    .font(Theme.Font.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// Abréviation du jour d'une colonne, dans le même format que l'axe du
    /// graphique de la semaine. Lue sur un des jours de la colonne : 30 jours
    /// couvrent toujours les sept.
    private func weekdayLabel(forColumn column: Int, in weeks: [[HistoryEntry?]]) -> String {
        guard let date = weeks.lazy.compactMap({ $0[column] }).first?.date else { return "" }
        return date.formatted(.dateTime.weekday(.short))
    }

    /// Case hors période : un contour en pointillés, pour que la grille reste
    /// un rectangle complet sans faire passer ces jours pour des jours sans eau.
    private var placeholderCell: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.row)
            .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }

    private func heatmapCell(for entry: HistoryEntry, manager: HydrationManager, colorScheme: ColorScheme) -> some View {
        let percentage = entry.targetMl > 0 ? (entry.amountMl / entry.targetMl) : 0
        let color = colorForPercentage(percentage, colorScheme: colorScheme)
        let hasGlow = percentage >= 1.5
        let tooltipText = heatmapTooltipText(for: entry, manager: manager)

        return RoundedRectangle(cornerRadius: Theme.Radius.row)
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: hasGlow ? Theme.goal.opacity(0.5) : .clear, radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.row)
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 0.5)
            )
            .help(tooltipText)
    }
    
    private func heatmapTooltipText(for entry: HistoryEntry, manager: HydrationManager) -> String {
        // FormatStyle met son formateur en cache : l'ancien code instanciait un
        // DateFormatter par cellule, soit 30 à chaque rendu de la heatmap.
        let dateString = entry.date.formatted(date: .abbreviated, time: .omitted)
        
        if entry.amountMl <= 0 {
            return String(format: String(localized: "No activity on %@", comment: "Heatmap tooltip when no hydration"), dateString)
        }
        
        let amountStr = manager.displayValue(for: entry.amountMl)
        let targetStr = manager.displayValue(for: entry.targetMl)
        let percentage = entry.targetMl > 0 ? Int(round((entry.amountMl / entry.targetMl) * 100)) : 0
        
        return String(format: String(localized: "%@ / %@ (%lld%% of goal) on %@", comment: "Heatmap tooltip with amount and date"), amountStr, targetStr, percentage, dateString)
    }
    
    private func colorForPercentage(_ percentage: Double, colorScheme: ColorScheme) -> Color {
        if percentage == 0 {
            // Mode clair : gris clair visible, mode sombre : gris très sombre
            return colorScheme == .dark 
                ? Color(white: 0.1, opacity: 1.0) 
                : Color(white: 0.85, opacity: 1.0)
        } else if percentage < 0.5 {
            // 1-49% : vert clair
            return Theme.goal.opacity(0.4)
        } else if percentage < 1.0 {
            // 50-99% : vert moyen
            return Theme.goal.opacity(0.7)
        } else if percentage < 1.5 {
            // 100%+ : vert vif
            return Theme.goal
        } else {
            // 150%+ : vert vif avec glow
            return Theme.goal
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.section) {
        StatsHeaderView(manager: HydrationManager.shared)
        WeeklyChartView(manager: HydrationManager.shared)
        MonthlyHeatmapView(manager: HydrationManager.shared)
    }
    .padding(Theme.Spacing.inset)
    .frame(width: 320)
    .background(Color.black)
}
