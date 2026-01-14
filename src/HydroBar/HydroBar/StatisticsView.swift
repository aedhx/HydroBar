//
//  StatisticsView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @ObservedObject var manager: HydrationManager
    @Binding var currentView: ViewType
    
    private var streak: Int {
        manager.currentStreak
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // KPIs Header
            StatsHeaderView(manager: manager)
                .padding(.top, 4)
            
            // Section Cette Semaine
            VStack(alignment: .leading, spacing: 10) {
                Text("This Week", comment: "Section title for weekly statistics")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                
                WeeklyChartView(manager: manager)
            }
            
            // Section Activité Mensuelle
            VStack(alignment: .leading, spacing: 10) {
                Text("Monthly Activity", comment: "Section title for monthly activity")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                
                MonthlyHeatmapView(manager: manager)
            }
            
            // Section Streak (mise en valeur)
            VStack(spacing: 4) {
                Text(String(format: String(localized: "Current streak: %lld days 🔥", comment: "Current streak display with number of days"), streak))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                if streak > 3 {
                    Text("You're unstoppable!", comment: "Motivational message for long streaks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.1),
                                Color.blue.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        streak > 3 ? Color.green.opacity(0.3) : Color.blue.opacity(0.2),
                        lineWidth: 1.5
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    StatisticsView(manager: HydrationManager.shared, currentView: .constant(.statistics))
        .padding()
        .background(Color.black)
}
