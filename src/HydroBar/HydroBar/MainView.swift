//
//  MainView.swift
//  HydroBar
// 
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import AppKit

// MARK: - HoldButton (NSViewRepresentable)
// Detects mouseDown/mouseUp directly — reliable in menu bar popovers
// where SwiftUI gestures can be swallowed by the window event chain.
struct HoldButton: NSViewRepresentable {
    var label: String
    var isHolding: Bool
    var onPress: () -> Void
    var onRelease: () -> Void

    func makeNSView(context: Context) -> HoldButtonNSView {
        let view = HoldButtonNSView()
        view.onPress = onPress
        view.onRelease = onRelease
        return view
    }

    func updateNSView(_ nsView: HoldButtonNSView, context: Context) {
        nsView.onPress = onPress
        nsView.onRelease = onRelease
        nsView.isHolding = isHolding
        nsView.needsDisplay = true
    }
}

class HoldButtonNSView: NSView {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var isHolding: Bool = false

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onPress?()
    }

    override func mouseUp(with event: NSEvent) {
        onRelease?()
    }

    override func draw(_ dirtyRect: NSRect) {
        let color = isHolding ? NSColor.systemBlue.withAlphaComponent(0.75) : NSColor.systemBlue
        let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        color.setFill()
        path.fill()

        let label = "Hold to Add"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (label as NSString).size(withAttributes: attrs)
        let rect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        (label as NSString).draw(in: rect, withAttributes: attrs)
    }
}

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
            
            // Bannière widget (one-shot, vue principale uniquement)
            if currentView == .main {
                WidgetPromoBanner()
            }

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
                DispatchQueue.main.async {
                    NSApplication.shared.windows.first(where: { $0.isVisible })?.makeKey()
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
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

// MARK: - WidgetPromoBanner

struct WidgetPromoBanner: View {
    @AppStorage("widgetPromoDismissed") private var dismissed = false

    var body: some View {
        if !dismissed {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Widget available", comment: "Widget promo banner title")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Right-click desktop → Edit Widgets", comment: "Widget promo banner subtitle")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { dismissed = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.07))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.blue.opacity(0.12)), alignment: .bottom)
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
            HoldButton(
                label: "Hold to Add",
                isHolding: isHolding,
                onPress: { if !isHolding { startHolding() } },
                onRelease: { stopHolding() }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 40)
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
                DispatchQueue.main.async {
                    NSApplication.shared.windows.first(where: { $0.isVisible })?.makeKey()
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
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
