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
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Valeur en grand et gras au centre
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - StatsHeaderView
struct StatsHeaderView: View {
    @ObservedObject var manager: HydrationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
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
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 4)
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
    
    private var weeklyData: [HistoryEntry] {
        // Les données sont déjà triées par date croissante dans getLast7DaysHistoryData()
        manager.getLast7DaysHistoryData()
    }
    
    var body: some View {
        Chart {
            // Barres pour chaque jour
            ForEach(weeklyData) { entry in
                let percentage = entry.targetMl > 0 ? min((entry.amountMl / entry.targetMl), 2.0) : 0 // Limiter à 200% pour l'affichage
                
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Percentage", percentage)
                )
                .foregroundStyle(entry.amountMl >= entry.targetMl ? Color.green : Color.blue)
                .cornerRadius(4, style: .continuous)
                .opacity(selectedDay?.id == entry.id ? 1.0 : 0.8)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(shortDayName(for: date))
                            .font(.system(size: 10,
                                          weight: Calendar.current.isDateInToday(date) ? .bold : .regular))
                    }
                }
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text("\(Int(doubleValue * 100))%")
                            .font(.system(size: 10))
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
                                    selectedDay = weeklyData.first { entry in
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
        .padding(.horizontal, 16)
        .overlay(alignment: .topTrailing) {
            if let selected = selectedDay {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(manager.displayValue(for: selected.amountMl))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(dayLabel(for: selected.date))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(.trailing, 20)
                .padding(.top, 8)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Grille Heatmap
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                // Ajouter des cellules vides au début si nécessaire pour aligner avec le jour de la semaine
                let calendar = Calendar.current
                if let firstDate = monthlyData.first?.date {
                    let weekday = calendar.component(.weekday, from: firstDate)
                    // Convertir weekday (1=Dimanche, 2=Lundi...) vers index 0-6 (Lundi=0)
                    let firstWeekday = calendar.firstWeekday // Généralement 1 (Dimanche) ou 2 (Lundi)
                    let weekdayIndex = (weekday - firstWeekday + 7) % 7
                    
                    // Cellules vides pour l'alignement
                    ForEach(0..<weekdayIndex, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                
                // Cellules pour chaque jour
                ForEach(monthlyData) { entry in
                    heatmapCell(for: entry, manager: manager, colorScheme: colorScheme)
                }
            }
            .padding(.horizontal, 20)
            
            // Légende
            HStack(spacing: 12) {
                Text("Less", comment: "Legend label for less activity")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                // Échantillons tirés de colorForPercentage, comme les cellules :
                // la légende affichait auparavant d'autres opacités (0,3 / 0,6)
                // que les cellules qu'elle était censée expliquer (0,4 / 0,7).
                HStack(spacing: 4) {
                    ForEach([0.0, 0.25, 0.75, 1.0, 1.5], id: \.self) { sample in
                        Rectangle()
                            .fill(colorForPercentage(sample, colorScheme: colorScheme))
                            .frame(width: 12, height: 12)
                            .cornerRadius(3)
                            .shadow(color: sample >= 1.5 ? .green.opacity(0.5) : .clear, radius: 2)
                    }
                }
                
                Text("More", comment: "Legend label for more activity")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 4)
        }
    }
    
    private func heatmapCell(for entry: HistoryEntry, manager: HydrationManager, colorScheme: ColorScheme) -> some View {
        let percentage = entry.targetMl > 0 ? (entry.amountMl / entry.targetMl) : 0
        let color = colorForPercentage(percentage, colorScheme: colorScheme)
        let hasGlow = percentage >= 1.5
        let tooltipText = heatmapTooltipText(for: entry, manager: manager)
        
        return Rectangle()
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(4)
            .shadow(color: hasGlow ? .green.opacity(0.5) : .clear, radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 0.5)
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
            return Color.green.opacity(0.4)
        } else if percentage < 1.0 {
            // 50-99% : vert moyen
            return Color.green.opacity(0.7)
        } else if percentage < 1.5 {
            // 100%+ : vert vif
            return Color.green
        } else {
            // 150%+ : vert vif avec glow
            return Color.green
        }
    }
}

#Preview {
    VStack {
        StatsHeaderView(manager: HydrationManager.shared)
        WeeklyChartView(manager: HydrationManager.shared)
        MonthlyHeatmapView(manager: HydrationManager.shared)
    }
    .padding()
    .background(Color.black)
}
