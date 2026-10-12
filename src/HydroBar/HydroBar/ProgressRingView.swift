//
//  ProgressRingView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import AppKit

struct ProgressRingView: View {
    @ObservedObject var manager: HydrationManager
    /// Progression affichée, au-delà de 1 pour le second tour.
    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Célébration de l'objectif (v2.2)
    @State private var celebrations = 0
    @State private var burstVisible = false
    @State private var burstExpanded = false
    /// Incrémenté quand l'utilisateur passe en retard : le repère pulse.
    @State private var behindPulses = 0

    private let diameter: CGFloat = 180
    private let lineWidth: CGFloat = 12

    private var progress: Double {
        guard manager.targetMl > 0 else { return 0 }
        return manager.currentMl / manager.targetMl
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    /// Jusqu'à deux tours : au-delà de 200 %, l'anneau reste plein.
    private var displayProgress: Double {
        min(progress, 2.0)
    }

    private var isBehind: Bool { manager.paceDeficitMl != nil }

    private func gradient(_ colors: [Color]) -> AngularGradient {
        AngularGradient(colors: colors, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: lineWidth)

            // Premier tour
            Circle()
                .trim(from: 0, to: min(animatedProgress, 1))
                .stroke(progress >= 1 ? gradient([Theme.goal, Theme.goalLight]) : gradient([Theme.water, Theme.waterLight]),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Second tour au-delà de 100 %, plus foncé, comme les anneaux
            // d'Activité. Avant, l'anneau restait plein : 130 % ressemblait à 100 %.
            if animatedProgress > 1 {
                Circle()
                    .trim(from: 0, to: min(animatedProgress - 1, 1))
                    .stroke(gradient([Theme.goalLight, Theme.goal]),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .black.opacity(0.25), radius: 2)
            }

            // Repère d'allure : « où devrais-je en être à cette heure-ci ? »
            // Sans lui, 15 % à 9 h du matin se lit comme un échec alors que tout va bien.
            if let expected = manager.expectedProgress {
                paceMarker(at: expected)
            }

            if burstVisible { burst }

            // Texte au centre
            VStack(spacing: 4) {
                // Objectif atteint : une coche, pas seulement le passage au vert.
                // Bleu et vert sont les deux couleurs les plus confondues en
                // deutéranopie (roadmap F7).
                if progress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.goal)
                        .symbolEffect(.bounce, value: celebrations)
                        .transition(.scale.combined(with: .opacity))
                }

                // Les chiffres roulent au lieu de sauter.
                Text("\(percentage)%")
                    .font(Theme.Font.ringValue)
                    .foregroundColor(.primary)
                    .contentTransition(.numericText(value: Double(percentage)))

                Text("\(manager.displayValue(for: manager.currentMl)) / \(manager.displayValue(for: manager.targetMl))")
                    .font(Theme.Font.ringCaption)
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText(value: manager.currentMl))

                if manager.expectedProgress != nil {
                    paceCaption
                }
            }
            .animation(Theme.motion(Theme.Motion.snappy, reduceMotion: reduceMotion), value: percentage)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(manager.progressAccessibilitySummary)
        // « Réduire les animations » : l'anneau se place sans balayage.
        .onAppear {
            withAnimation(Theme.motion(.easeOut(duration: 0.8), reduceMotion: reduceMotion)) {
                animatedProgress = displayProgress
            }
        }
        .onChange(of: displayProgress) { oldValue, newValue in
            withAnimation(Theme.motion(Theme.Motion.ring, reduceMotion: reduceMotion)) {
                animatedProgress = newValue
            }
            if oldValue < 1, newValue >= 1 { celebrate() }
        }
        .onChange(of: isBehind) { _, behind in
            if behind { behindPulses += 1 }
        }
    }

    // MARK: - Objectif atteint

    /// Coche qui rebondit, couronne de gouttes, retour haptique du trackpad.
    /// Une seule fois par franchissement.
    private func celebrate() {
        celebrations += 1
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        guard !reduceMotion else { return }

        burstExpanded = false
        burstVisible = true
        withAnimation(.easeOut(duration: 0.9)) { burstExpanded = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { burstVisible = false }
    }

    private var burst: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                let angle = Double(index) / 16 * 2 * .pi
                let radius = (diameter / 2) + (burstExpanded ? 26 : 0)
                Circle()
                    .fill(Theme.goalLight)
                    .frame(width: index.isMultiple(of: 2) ? 6 : 4, height: index.isMultiple(of: 2) ? 6 : 4)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                    .opacity(burstExpanded ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Repère d'allure

    /// Graduation traversant la bande de l'anneau à la position attendue.
    /// C'est une **forme** distincte, pas une nuance de couleur : le repère reste
    /// lisible en cas de daltonisme, comme en niveaux de gris.
    /// En passant en retard, il pulse trois fois puis s'immobilise : l'œil le
    /// remarque une fois, sans animation permanente.
    private func paceMarker(at expected: Double) -> some View {
        Capsule()
            .fill(Color.primary.opacity(0.55))
            .frame(width: 3, height: lineWidth + 8)
            .phaseAnimator(reduceMotion ? [false] : [false, true, false, true, false, true, false],
                           trigger: behindPulses) { marker, phase in
                marker
                    .scaleEffect(x: phase ? 1.6 : 1, y: phase ? 1.25 : 1)
                    .opacity(phase ? 1 : 0.85)
            } animation: { _ in
                .easeInOut(duration: 0.3)
            }
            .offset(y: -(diameter - lineWidth) / 2)
            .rotationEffect(.degrees(expected * 360))
    }

    private var paceCaption: some View {
        Group {
            if let deficit = manager.paceDeficitMl {
                Text(String(format: String(localized: "%@ behind",
                                           comment: "Pace caption when the user is behind schedule"),
                            manager.displayValue(for: deficit)))
                    .foregroundColor(Theme.warning)
            } else {
                Text("On track", comment: "Pace caption when the user is on schedule")
                    .foregroundColor(.secondary)
            }
        }
        .font(Theme.Font.ringFootnote)
    }
}

#Preview {
    ProgressRingView(manager: HydrationManager.shared)
        .padding()
}
