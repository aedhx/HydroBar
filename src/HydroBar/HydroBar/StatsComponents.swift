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
        .animation(.easeOut(duration: 0.3).delay(0.1), value: manager.dailyAverage)
        .animation(.easeOut(duration: 0.3).delay(0.15), value: manager.weeklyTotal)
    }
    
    private func formatValue(_ ml: Double) -> (value: String, unit: String) {
        // Si la valeur en ml est >= 1000, afficher en litres
        if ml >= 1000 {
            let liters = ml / 1000.0
            return (String(format: "%.1f", liters), "L")
        } else {
            // Convertir vers l'unité choisie
            let convertedValue = manager.selectedUnit.fromMl(ml)
            
            // Formatage selon la valeur
            let valueString: String
            if convertedValue.truncatingRemainder(dividingBy: 1) == 0 {
                valueString = String(format: "%.0f", convertedValue)
            } else {
                valueString = String(format: "%.1f", convertedValue)
            }
            
            return (valueString, manager.selectedUnit.rawValue)
        }
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
        if #available(macOS 13.0, *) {
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
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(shortDayName(for: date))
                                .font(.system(size: 10))
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
        } else {
            Text("Chart not available\n(macOS 13+ required)", comment: "Message when chart is not available")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 200)
        }
    }
    
    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateStart = calendar.startOfDay(for: date)
        
        if calendar.isDate(dateStart, inSameDayAs: today) {
            return String(localized: "Today", comment: "Label for today's date")
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMM"
        return formatter.string(from: date).capitalized
    }
    
    private func shortDayName(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateStart = calendar.startOfDay(for: date)
        
        // Si c'est aujourd'hui, afficher "Aj" (2 lettres)
        if calendar.isDate(dateStart, inSameDayAs: today) {
            // Utiliser "Aj" pour "Aujourd'hui" ou les 2 premières lettres de "Today"
            let todayText = String(localized: "Today", comment: "Label for today's date")
            if todayText.count >= 2 {
                return String(todayText.prefix(2)).uppercased()
            }
            return "Aj"
        }
        
        // Obtenir le numéro du jour de la semaine (1 = dimanche, 2 = lundi, etc.)
        let weekday = calendar.component(.weekday, from: date)
        
        // Mapping selon la locale (français par défaut)
        let locale = Locale.current
        let isFrench = locale.language.languageCode?.identifier == "fr" || locale.identifier.hasPrefix("fr")
        
        let dayNames: [String]
        if isFrench {
            // Français : lu, ma, me, je, ve, sa, di
            dayNames = ["di", "lu", "ma", "me", "je", "ve", "sa"]
        } else {
            // Anglais : Su, Mo, Tu, We, Th, Fr, Sa
            dayNames = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        }
        
        // weekday: 1 = dimanche, 2 = lundi, ..., 7 = samedi
        let index = (weekday - 1) % 7
        return dayNames[index]
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
            // Titre
            Text("Consistency (30 days)", comment: "Title for 30-day consistency heatmap")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            
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
                    heatmapCell(for: entry, colorScheme: colorScheme)
                }
            }
            .padding(.horizontal, 20)
            
            // Légende
            HStack(spacing: 12) {
                Text("Less", comment: "Legend label for less activity")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                // Exemples de couleurs
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(colorScheme == .dark ? Color(white: 0.1, opacity: 1.0) : Color(white: 0.85, opacity: 1.0))
                        .frame(width: 12, height: 12)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 12, height: 12)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .cornerRadius(3)
                        .shadow(color: .green.opacity(0.5), radius: 2)
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
    
    private func heatmapCell(for entry: HistoryEntry, colorScheme: ColorScheme) -> some View {
        let percentage = entry.targetMl > 0 ? (entry.amountMl / entry.targetMl) : 0
        let color = colorForPercentage(percentage, colorScheme: colorScheme)
        let hasGlow = percentage >= 1.5
        
        return Rectangle()
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(4)
            .shadow(color: hasGlow ? .green.opacity(0.5) : .clear, radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 0.5)
            )
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
