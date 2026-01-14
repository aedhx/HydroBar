//
//  MainView.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import AppKit

enum ViewType {
    case main
    case statistics
    case settings
}

// PreferenceKey pour communiquer la taille du contenu au parent
struct ContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct MainView: View {
    @StateObject private var manager = HydrationManager.shared
    @State private var isHolding = false
    @State private var holdTimer: Timer?
    @State private var currentView: ViewType = .main
    
    var body: some View {
        VStack(spacing: 0) {
            // Header avec fond pour meilleure visibilité
            HStack {
                // Bouton Stats (gauche) - Toggle entre stats et main
                Button(action: {
                    if currentView == .statistics {
                        currentView = .main
                    } else {
                        currentView = .statistics
                    }
                }) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundColor(currentView == .statistics ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Titre
                Text(titleForCurrentView)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Bouton Réglages (droite) - Toggle entre settings et main
                Button(action: {
                    if currentView == .settings {
                        currentView = .main
                    } else {
                        currentView = .settings
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(currentView == .settings ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Corps - Affichage conditionnel selon la vue
            Group {
                switch currentView {
                case .main:
                    MainContentView(manager: manager, isHolding: $isHolding, holdTimer: $holdTimer)
                case .statistics:
                    StatisticsView(manager: manager, currentView: $currentView)
                case .settings:
                    SettingsView(manager: manager, currentView: $currentView)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ContentSizeKey.self, value: geometry.size)
                }
            )
            .onChange(of: currentView) { _, _ in
                // Forcer une mise à jour de la taille quand on change de vue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // La taille sera mise à jour automatiquement par le PreferenceKey
                }
            }
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onPreferenceChange(ContentSizeKey.self) { size in
            // Mettre à jour la taille du popover quand le contenu change
            updatePopoverSize(contentHeight: size.height)
        }
        .onDisappear {
            stopHolding()
        }
    }
    
    private func startHolding() {
        isHolding = true
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if isHolding {
                manager.addWater(amount: 5.0)
                // Haptic feedback
                let haptic = NSHapticFeedbackManager.defaultPerformer
                haptic.perform(.generic, performanceTime: .default)
            }
        }
    }
    
    private func stopHolding() {
        isHolding = false
        holdTimer?.invalidate()
        holdTimer = nil
    }
    
    private var titleForCurrentView: String {
        switch currentView {
        case .main:
            return String(localized: "Today", comment: "Title for today's view")
        case .statistics:
            return String(localized: "Statistics", comment: "Title for statistics view")
        case .settings:
            return String(localized: "Settings", comment: "Title for settings view")
        }
    }
    
    private func updatePopoverSize(contentHeight: CGFloat) {
        // Ignorer si la taille est zéro (pas encore mesurée)
        guard contentHeight > 0 else { return }
        
        // Header height: ~48px (padding + divider)
        let headerHeight: CGFloat = 48
        let totalHeight = contentHeight + headerHeight
        
        // Limiter la hauteur entre min et max
        let minHeight: CGFloat = 350
        let maxHeight: CGFloat = 700
        let finalHeight = min(max(totalHeight, minHeight), maxHeight)
        
        // Mettre à jour le popover via AppDelegate
        DispatchQueue.main.async {
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.updatePopoverSize(height: finalHeight)
            }
        }
    }
}

// MARK: - MainContentView
struct MainContentView: View {
    @ObservedObject var manager: HydrationManager
    @Binding var isHolding: Bool
    @Binding var holdTimer: Timer?
    @State private var holdStartAmount: Double = 0.0
    @State private var holdTotalAmount: Double = 0.0
    
    var body: some View {
        VStack(spacing: 24) {
            // Jauge circulaire
            ProgressRingView(manager: manager)
                .padding(.top, 20)
            
            // Grille Presets
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(manager.presetsMl, id: \.self) { preset in
                    Button(action: {
                        manager.addWater(amount: preset)
                    }) {
                        Text(manager.displayValue(for: preset))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            
            // Bouton Hold-to-Add
            Button(action: {}) {
                Text("Hold to Add", comment: "Button label for hold-to-add water")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHolding {
                            startHolding()
                        }
                    }
                    .onEnded { _ in
                        stopHolding()
                    }
            )
            .padding(.horizontal, 20)
            
            // Footer - Reset
            Button(action: {
                manager.resetDay()
            }) {
                Label(String(localized: "Reset my day", comment: "Button to reset daily progress"), systemImage: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .padding(.vertical, 16)
        .onDisappear {
            stopHolding()
        }
    }
    
    private func startHolding() {
        isHolding = true
        holdStartAmount = manager.currentMl
        holdTotalAmount = 0.0
        
        // Calculer la quantité d'une gorgée selon l'unité sélectionnée
        // Une gorgée = ~25ml = ~2.5cl
        let gulpAmountMl: Double = 25.0 // ~25ml par gorgée
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if isHolding {
                // Ajouter une gorgée sans enregistrer dans undo (on le fera en groupe à la fin)
                manager.addWater(amount: gulpAmountMl, skipUndo: true)
                holdTotalAmount += gulpAmountMl
                // Haptic feedback
                let haptic = NSHapticFeedbackManager.defaultPerformer
                haptic.perform(.generic, performanceTime: .default)
            }
        }
    }
    
    private func stopHolding() {
        isHolding = false
        holdTimer?.invalidate()
        holdTimer = nil
        
        // Si on a ajouté de l'eau pendant le hold, regrouper les actions undo
        // en une seule action pour que undo retire tout le groupe
        if holdTotalAmount > 0 {
            // Ajouter une action groupée dans le stack undo
            manager.undoStack.append((amount: holdTotalAmount, timestamp: Date()))
            
            // Limiter la taille du stack
            if manager.undoStack.count > 50 {
                manager.undoStack.removeFirst()
            }
        }
    }
}

#Preview {
    MainView()
        .padding()
        .background(Color.black)
}
