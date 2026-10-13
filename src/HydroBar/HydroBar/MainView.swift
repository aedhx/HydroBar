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
    /// Niveau d'eau dans le bouton pendant l'appui, de 0 à 1.
    var fillFraction: CGFloat = 0
    var onPress: () -> Void
    var onRelease: () -> Void

    func makeNSView(context: Context) -> HoldButtonNSView {
        let view = HoldButtonNSView()
        view.label = label
        view.onPress = onPress
        view.onRelease = onRelease
        return view
    }

    func updateNSView(_ nsView: HoldButtonNSView, context: Context) {
        nsView.label = label
        nsView.onPress = onPress
        nsView.onRelease = onRelease
        nsView.isHolding = isHolding
        nsView.fillFraction = fillFraction
        nsView.needsDisplay = true
    }
}

class HoldButtonNSView: NSView {
    var label: String = ""
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var isHolding: Bool = false
    var fillFraction: CGFloat = 0

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onPress?()
    }

    override func mouseUp(with event: NSEvent) {
        onRelease?()
    }

    // MARK: Accessibilité (F7)
    // Une NSView dessinée à la main est invisible pour VoiceOver. Elle se
    // présente comme un bouton ; un « appui » VoiceOver équivaut à maintenir
    // une seconde, un appui long n'ayant pas d'équivalent au clavier.

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { label }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.onRelease?()
        }
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: Theme.Radius.control, yRadius: Theme.Radius.control)
        Theme.NS.water.setFill()
        path.fill()

        // Pendant l'appui, le bouton se remplit comme un verre (v2) : on voit
        // combien on a versé, et quand relâcher.
        if isHolding, fillFraction > 0 {
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            let level = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height * min(fillFraction, 1))
            NSColor.systemCyan.withAlphaComponent(0.85).setFill()
            NSBezierPath(rect: level).fill()
            NSGraphicsContext.restoreGraphicsState()
        }

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

/// Fond des boutons de preset : Liquid Glass sur macOS 26, teinté d'eau et
/// réactif au survol ; le fond actuel sur les versions précédentes.
struct PresetSurface: ViewModifier {
    func body(content: Content) -> some View {
        // glassEffect n'existe qu'à partir du SDK 26 (Xcode 26, Swift 6.2) : avec
        // un Xcode plus ancien, seul le fond classique est compilé.
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(Theme.water.opacity(0.25)).interactive(),
                                in: .rect(cornerRadius: Theme.Radius.control))
        } else {
            classic(content)
        }
        #else
        classic(content)
        #endif
    }

    private func classic(_ content: Content) -> some View {
        content
            .background(Theme.presetFill)
            .cornerRadius(Theme.Radius.control)
    }
}

enum ViewType {
    case main
    case statistics
    case settings
}

struct MainView: View {
    @ObservedObject private var manager = HydrationManager.shared
    @ObservedObject private var navigation = AppNavigation.shared
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
                        .font(Theme.Font.control)
                        .foregroundColor(currentView == .statistics ? Theme.water : .secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Titre
                Text(titleForCurrentView)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Bouton Réglages (droite) : ouvre la fenêtre de réglages (v2).
                Button(action: { SettingsWindowController.shared.show() }) {
                    Image(systemName: "gearshape.fill")
                        .font(Theme.Font.control)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Settings", comment: "Title for settings view"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            Divider()

            // Corps - Affichage conditionnel selon la vue
            Group {
                switch currentView {
                case .main, .settings:
                    // Les réglages ont leur fenêtre : le popover n'affiche
                    // jamais `.settings`.
                    MainContentView(manager: manager)
                case .statistics:
                    // Défilante : avec la vue sur l'année et le bilan du mois, les
                    // statistiques dépassent la hauteur maximale du popover.
                    StatisticsScrollView(manager: manager, currentView: $currentView)
                        .frame(maxHeight: 620)
                }
            }
            // Hauteur idéale = hauteur du contenu : le popover s'y ajuste seul
            // (sizingOptions dans l'AppDelegate).
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onChange(of: navigation.pendingRequest) { _, request in
            // Vue demandée par un deep link `hydrobar://open/...`.
            if let request, request.view != .settings { currentView = request.view }
        }
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
}

// MARK: - MainContentView
struct MainContentView: View {
    @ObservedObject var manager: HydrationManager
    @State private var isHolding = false
    @State private var holdTimer: Timer?

    /// Quantité ajoutée à chaque tick pendant l'appui. 25 ml toutes les 50 ms
    /// faisaient 500 ml par seconde : deux secondes d'inattention ajoutaient un
    /// litre. 10 ml donnent 200 ml/s, et le total s'affiche en direct sur le
    /// bouton (cf. AUDIT § P2-3).
    private static let gulpMl: Double = 10
    private static let tickInterval: TimeInterval = 0.05

    /// Libellé du bouton : son rôle au repos, le total ajouté pendant l'appui.
    private var holdButtonLabel: String {
        isHolding
            ? "+" + manager.displayValue(for: manager.holdTotalMl)
            : String(localized: "Hold to Add", comment: "Button to add water continuously while pressed")
    }

    var body: some View {
        VStack(spacing: 24) {
            // Jauge circulaire
            ProgressRingView(manager: manager)
                .padding(.top, 20)

            // Type de journée, quand les jours off ont leurs propres réglages.
            if manager.dayPlan.enabled {
                DayKindChip(manager: manager)
                    .padding(.top, -12)
            }
            
            // Mode gourde
            if manager.bottleModeEnabled {
                BottleView(manager: manager)
                    .padding(.horizontal, 20)
            }

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
                        Text(verbatim: manager.displayValue(for: preset))
                            .font(Theme.Font.bodyMedium)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .modifier(PresetSurface())
                    }
                    .buttonStyle(.plain)
                    // « Ajouter 25 cl » plutôt que « 25 cl » seul.
                    .accessibilityLabel(String(format: String(localized: "Add %@", comment: "Context menu item; %@ is an amount"),
                                               manager.displayValue(for: preset)))
                }
            }
            .padding(.horizontal, 20)
            
            PresetSuggestionBanner(manager: manager)
                .padding(.horizontal, 20)

            // Bouton Hold-to-Add
            HoldButton(
                label: holdButtonLabel,
                isHolding: isHolding,
                // Plein à 750 ml : la taille d'une grande bouteille.
                fillFraction: CGFloat(min(manager.holdTotalMl / 750, 1)),
                onPress: { if !isHolding { startHolding() } },
                onRelease: { stopHolding() }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .padding(.horizontal, 20)

            // Journal du jour (F17)
            TodayLogView(manager: manager)
                .padding(.horizontal, 20)

            // Footer - Reset
            Button(action: {
                manager.resetDay()
            }) {
                Label(String(localized: "Reset my day", comment: "Button to reset daily progress"), systemImage: "arrow.counterclockwise")
                    .font(Theme.Font.caption)
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
        manager.beginHoldSession()
        // Une fois au début de l'appui, et non plus à chaque tick : rendre la
        // fenêtre active parcourait la liste des fenêtres 20 fois par seconde.
        NSApplication.shared.windows.first(where: { $0.isVisible })?.makeKey()

        holdTimer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { _ in
            guard isHolding else { return }
            manager.addHeldWater(Self.gulpMl)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }

    /// Une seule entrée d'annulation pour tout l'appui, une seule écriture :
    /// c'est `endHoldSession()` qui s'en charge. La vue modifiait auparavant la
    /// pile d'annulation du manager elle-même (cf. AUDIT § P1-3).
    private func stopHolding() {
        guard isHolding else { return }
        isHolding = false
        holdTimer?.invalidate()
        holdTimer = nil
        manager.endHoldSession()
    }
}

#Preview {
    MainView()
        .padding()
        .background(Color.black)
}

/// « Jour off · 10:00–22:00 » : le type de la journée et sa plage active, en
/// un coup d'œil. Un menu permet de changer pour aujourd'hui seulement.
struct DayKindChip: View {
    @ObservedObject var manager: HydrationManager

    var body: some View {
        let rules = manager.todayRules
        let isOff = rules.kind == .off
        Menu {
            Picker(String(localized: "Today", comment: "Popover: today's day type menu title"),
                   selection: Binding(get: { manager.todayKind }, set: { manager.setTodayKind($0) })) {
                Text("Work Day", comment: "Day type").tag(DayKind.work)
                Text("Day Off", comment: "Day type").tag(DayKind.off)
            }
            .pickerStyle(.inline)
            .disabled(manager.todayKindSetByFocus)
        } label: {
            Label {
                Text(verbatim: summary(rules))
            } icon: {
                Image(systemName: isOff ? "sun.max" : "briefcase")
            }
            .font(Theme.Font.caption)
            .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text(verbatim: summary(rules)))
    }

    private func summary(_ rules: DayRules) -> String {
        let kind = rules.kind == .off
            ? String(localized: "Day Off", comment: "Day type")
            : String(localized: "Work Day", comment: "Day type")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .hour, value: rules.startHour, to: today),
              let end = calendar.date(byAdding: .hour, value: rules.endHour, to: today)
        else { return kind }
        let style = Date.FormatStyle.dateTime.hour().minute()
        return "\(kind) · \(start.formatted(style))–\(end.formatted(style))"
    }
}
