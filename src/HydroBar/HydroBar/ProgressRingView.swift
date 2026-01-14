//
//  ProgressRingView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI

struct ProgressRingView: View {
    @ObservedObject var manager: HydrationManager
    
    private var progress: Double {
        guard manager.targetMl > 0 else { return 0 }
        // Permettre le pourcentage au-delà de 100%
        return manager.currentMl / manager.targetMl
    }
    
    private var percentage: Int {
        Int(progress * 100)
    }
    
    private var displayProgress: Double {
        // Pour l'affichage du cercle, on limite à 1.0 (100%) visuellement
        // mais le pourcentage peut dépasser 100%
        return min(progress, 1.0)
    }
    
    var body: some View {
        ZStack {
            // Cercle de fond gris
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 12)
            
            // Cercle de progression
            Circle()
                .trim(from: 0, to: displayProgress)
                .stroke(
                    progress >= 1.0 ? Color.green : Color.blue,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: displayProgress)
            
            // Texte au centre
            VStack(spacing: 4) {
                Text("\(percentage)%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(manager.displayValue(for: manager.currentMl)) / \(manager.displayValue(for: manager.targetMl))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 180, height: 180)
    }
}

#Preview {
    ProgressRingView(manager: HydrationManager.shared)
        .padding()
}
