//
//  ProgressRingView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI

struct ProgressRingView: View {
    @ObservedObject var manager: HydrationManager
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard manager.targetMl > 0 else { return 0 }
        return manager.currentMl / manager.targetMl
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    private var displayProgress: Double {
        return min(progress, 1.0)
    }

    private var ringGradient: AngularGradient {
        progress >= 1.0
            ? AngularGradient(
                colors: [.green, .mint],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
            : AngularGradient(
                colors: [Color(red: 0.2, green: 0.5, blue: 1.0), .cyan],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
    }

    var body: some View {
        ZStack {
            // Cercle de fond gris
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 12)

            // Cercle de progression avec gradient
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

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
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = displayProgress
            }
        }
        .onChange(of: displayProgress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                animatedProgress = newValue
            }
        }
    }
}

#Preview {
    ProgressRingView(manager: HydrationManager.shared)
        .padding()
}
