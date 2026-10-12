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

    private let diameter: CGFloat = 180
    private let lineWidth: CGFloat = 12

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
                .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)

            // Cercle de progression avec gradient
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Repère d'allure : « où devrais-je en être à cette heure-ci ? »
            // Sans lui, 15 % à 9 h du matin se lit comme un échec alors que tout va bien.
            if let expected = manager.expectedProgress {
                paceMarker(at: expected)
            }

            // Texte au centre
            VStack(spacing: 4) {
                Text("\(percentage)%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("\(manager.displayValue(for: manager.currentMl)) / \(manager.displayValue(for: manager.targetMl))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                if manager.expectedProgress != nil {
                    paceCaption
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
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

    // MARK: - Repère d'allure

    /// Graduation traversant la bande de l'anneau à la position attendue.
    /// C'est une **forme** distincte, pas une nuance de couleur : le repère reste
    /// lisible en cas de daltonisme, comme en niveaux de gris.
    private func paceMarker(at expected: Double) -> some View {
        Capsule()
            .fill(Color.primary.opacity(0.55))
            .frame(width: 3, height: lineWidth + 8)
            .offset(y: -(diameter - lineWidth) / 2)
            .rotationEffect(.degrees(expected * 360))
    }

    private var paceCaption: some View {
        Group {
            if let deficit = manager.paceDeficitMl {
                Text(String(format: String(localized: "%@ behind",
                                           comment: "Pace caption when the user is behind schedule"),
                            manager.displayValue(for: deficit)))
                    .foregroundColor(.orange)
            } else {
                Text("On track", comment: "Pace caption when the user is on schedule")
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
    }

    // MARK: - Accessibilité

    /// L'anneau, la graduation et les deux lignes de texte forment une seule
    /// information : VoiceOver l'annonce d'un bloc plutôt qu'en quatre fragments.
    private var accessibilityDescription: String {
        let base = String(
            format: String(localized: "Hydration: %lld percent, %@ of %@",
                           comment: "VoiceOver description of the progress ring"),
            percentage,
            manager.displayValue(for: manager.currentMl),
            manager.displayValue(for: manager.targetMl)
        )
        guard manager.expectedProgress != nil else { return base }

        if let deficit = manager.paceDeficitMl {
            let behind = String(format: String(localized: "%@ behind",
                                               comment: "Pace caption when the user is behind schedule"),
                                manager.displayValue(for: deficit))
            return "\(base). \(behind)"
        }
        return "\(base). " + String(localized: "On track", comment: "Pace caption when the user is on schedule")
    }
}

#Preview {
    ProgressRingView(manager: HydrationManager.shared)
        .padding()
}
