//
//  HydroBarApp.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import UserNotifications
import AppKit

@main
struct HydroBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Configurer la langue de l'application
        let manager = HydrationManager.shared
        if manager.appLanguage != "system" {
            UserDefaults.standard.set([manager.appLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
        
        // Configurer le delegate pour les notifications
        UNUserNotificationCenter.current().delegate = appDelegate
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - MenuBarIconView
struct MenuBarIconView: View {
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
        // Pour le pie ring, limiter visuellement à 100% mais permettre le dépassement
        return min(progress, 1.0)
    }
    
    private var isGoalReached: Bool {
        progress >= 1.0
    }
    
    var body: some View {
        ZStack {
            // Couche 1 : L'icône principale
            Group {
                switch manager.menuBarIconStyle {
                case .pieRing:
                    pieRingView
                case .percentage:
                    percentageView
                }
            }
            
            // Couche 2 : Pastille rouge si badge actif
            if manager.showReminderBadge {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -4)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var pieRingView: some View {
        GeometryReader { geometry in
            ZStack {
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2 - 0.5
                
                // Camembert - cercle de fond complet (gris)
                Circle()
                    .fill(Color(white: 0.5, opacity: 0.2))
                
                // Bordure visible quand progress est 0 pour améliorer la visibilité
                if displayProgress == 0 {
                    Circle()
                        .stroke(Color(white: 0.6, opacity: 0.4), lineWidth: 1.5)
                }
                
                // Camembert - partie remplie avec Path
                if displayProgress > 0 {
                    Path { path in
                        // Commencer au centre
                        path.move(to: center)
                        
                        // Ligne vers le haut (0°)
                        path.addLine(to: CGPoint(x: center.x, y: center.y - radius))
                        
                        // Arc de cercle pour la partie remplie
                        let endAngle = displayProgress * 360 - 90
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(endAngle),
                            clockwise: false
                        )
                        
                        // Retour au centre pour fermer le camembert
                        path.closeSubpath()
                    }
                    .fill(isGoalReached ? Color.green : Color.blue)
                }
            }
        }
        .frame(width: 18, height: 18)
    }
    
    private var percentageView: some View {
        Text("\(percentage)%")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(isGoalReached ? Color(red: 0.2, green: 0.8, blue: 0.2) : Color(red: 0.2, green: 0.5, blue: 1.0))
            .monospacedDigit()
            .frame(minWidth: 45, alignment: .center)
            .padding(.horizontal, 2)
    }
}

// MARK: - AppDelegate pour gérer les notifications et le status bar
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var hostingController: NSHostingController<MenuBarIconView>?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Demander l'autorisation pour les notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Erreur lors de la demande d'autorisation: \(error)")
            }
        }
        
        // Initialiser le gestionnaire de raccourcis globaux
        _ = GlobalHotkeyManager.shared
        
        // Charger les raccourcis sauvegardés
        loadSavedShortcuts()
        
        // Créer le status item
        setupStatusBar()
    }
    
    func setupStatusBar() {
        // La longueur sera ajustée dans updateStatusBarIcon selon le style
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else { return }
        
        // Configurer le bouton pour un meilleur alignement
        button.imagePosition = .imageOnly
        button.imageHugsTitle = true
        
        // Créer la vue SwiftUI pour l'icône avec un hosting controller
        updateStatusBarIcon()
        
        // Gérer les clics
        button.action = #selector(statusBarButtonClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Créer le popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        
        let mainViewController = NSHostingController(rootView: MainView())
        mainViewController.view.setFrameSize(NSSize(width: 320, height: 400))
        popover?.contentViewController = mainViewController
        
        // Configurer le responder pour Cmd+Z
        setupUndoSupport()
        
        // Mettre à jour l'icône périodiquement
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatusBarIcon()
        }
    }
    
    func updateStatusBarIcon() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let button = self.statusItem?.button else { return }
            
            let manager = HydrationManager.shared
            
            if manager.menuBarIconStyle == .percentage {
                // Mode pourcentage : utiliser NSImage pour un rendu plus fiable
                // Retirer les vues SwiftUI
                button.subviews.forEach { $0.removeFromSuperview() }
                self.hostingController = nil
                
                // Utiliser une longueur variable pour le texte
                self.statusItem?.length = NSStatusItem.variableLength
                
                let percentage = Int((manager.currentMl / manager.targetMl) * 100)
                let isGoalReached = manager.currentMl >= manager.targetMl
                
                if let image = self.createPercentageImage(percentage: percentage, isGoalReached: isGoalReached, showBadge: manager.showReminderBadge) {
                    button.image = image
                    button.imagePosition = .imageLeading
                    button.title = ""
                }
            } else {
                // Mode pie ring : utiliser SwiftUI avec longueur fixe pour centrage
                button.image = nil
                button.title = ""
                
                // Utiliser une longueur fixe pour garantir un centrage correct
                self.statusItem?.length = 24
                
                // Retirer les anciennes vues
                button.subviews.forEach { $0.removeFromSuperview() }
                
                self.hostingController = NSHostingController(rootView: MenuBarIconView(manager: manager))
                
                let iconSize: CGFloat = 18
                let buttonFrame = button.bounds
                
                // Centrer la vue dans le bouton (le bouton a une hauteur standard de ~22px)
                let xOffset = max(0, (buttonFrame.width - iconSize) / 2)
                let yOffset = max(0, (buttonFrame.height - iconSize) / 2)
                
                self.hostingController?.view.frame = NSRect(x: xOffset, y: yOffset, width: iconSize, height: iconSize)
                self.hostingController?.view.wantsLayer = true
                self.hostingController?.view.layer?.backgroundColor = NSColor.clear.cgColor
                
                if let hostingView = self.hostingController?.view {
                    button.addSubview(hostingView)
                }
            }
        }
    }
    
    private func createPercentageImage(percentage: Int, isGoalReached: Bool, showBadge: Bool) -> NSImage? {
        let text = "\(percentage)%"
        let fontSize: CGFloat = 12
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        
        // Couleur selon si l'objectif est atteint
        let color = isGoalReached ? NSColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0) : NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
        
        // Calculer la taille du texte
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        
        // Créer l'image avec un peu de padding
        let padding: CGFloat = 4
        let badgeSize: CGFloat = 6
        let badgeOffset: CGFloat = 4
        let imageSize = NSSize(width: textSize.width + padding * 2, height: 22)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        
        // Fond transparent
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: imageSize).fill()
        
        // Dessiner le texte centré verticalement
        let textRect = NSRect(
            x: padding,
            y: (imageSize.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attributedString.draw(in: textRect)
        
        // Dessiner la pastille rouge si nécessaire
        if showBadge {
            let badgeRect = NSRect(
                x: imageSize.width - badgeSize - badgeOffset,
                y: imageSize.height - badgeSize - badgeOffset,
                width: badgeSize,
                height: badgeSize
            )
            NSColor.red.setFill()
            NSBezierPath(ovalIn: badgeRect).fill()
        }
        
        image.unlockFocus()
        
        // Configurer l'image pour qu'elle soit bien rendue dans la barre de menu
        image.isTemplate = false
        image.cacheMode = .never
        
        return image
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Clic droit : afficher le menu contextuel
            showContextMenu(for: sender)
        } else {
            // Clic gauche : ouvrir/fermer le popover
            togglePopover(for: sender)
        }
    }
    
    func togglePopover(for sender: NSStatusBarButton) {
        guard let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Calculer le rectangle relatif centré sur le bouton
            let buttonBounds = sender.bounds
            let centerX = buttonBounds.midX
            let centerRect = NSRect(
                x: centerX - 1,
                y: buttonBounds.minY,
                width: 2,
                height: buttonBounds.height
            )
            popover.show(relativeTo: centerRect, of: sender, preferredEdge: .minY)
        }
    }
    
    func updatePopoverSize(height: CGFloat) {
        guard let popover = popover,
              let viewController = popover.contentViewController else { return }
        
        let newSize = NSSize(width: 320, height: height)
        popover.contentSize = newSize
        viewController.view.setFrameSize(newSize)
    }
    
    /// Charge les raccourcis sauvegardés depuis UserDefaults
    private func loadSavedShortcuts() {
        let manager = GlobalHotkeyManager.shared
        let hydrationManager = HydrationManager.shared
        
        // Charger les raccourcis pour chaque preset
        for index in 0..<hydrationManager.presetsMl.count {
            let key = "shortcut_preset_\(index)"
            if let data = UserDefaults.standard.data(forKey: key),
               let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
                // Réenregistrer le raccourci
                manager.registerShortcut(
                    for: index,
                    keyCode: shortcut.keyCode,
                    modifiers: shortcut.modifiers
                )
            }
        }
    }
    
    private static let repositoryURL = URL(string: "https://github.com/aedhx/HydroBar")!
    
    private var currentAppVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
    
    func showContextMenu(for sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        // Version tout en haut (affichage seul)
        let versionItem = NSMenuItem(title: String(localized: "Version", comment: "Context menu label for app version") + " \(currentAppVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Ajouter 25cl / 250ml
        let addWaterItem = NSMenuItem(title: String(localized: "Add 25cl / 250ml", comment: "Menu item to add water"), action: #selector(addWater), keyEquivalent: "")
        addWaterItem.target = self
        menu.addItem(addWaterItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Sous-menu : Raccourcis clavier configurés
        let shortcutsTitle = String(localized: "Keyboard Shortcuts", comment: "Context menu submenu for configured shortcuts")
        let shortcutsItem = NSMenuItem(title: shortcutsTitle, action: nil, keyEquivalent: "")
        let shortcutsSubmenu = NSMenu()
        let presetCount = HydrationManager.shared.presetsMl.count
        for index in 0..<presetCount {
            let key = "shortcut_preset_\(index)"
            let presetLabel = String(format: String(localized: "Preset %lld", comment: "Preset label with index"), index + 1)
            let displayText: String
            if let data = UserDefaults.standard.data(forKey: key),
               let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
                displayText = "\(presetLabel): \(shortcut.displayString)"
            } else {
                displayText = "\(presetLabel): —"
            }
            let item = NSMenuItem(title: displayText, action: nil, keyEquivalent: "")
            item.isEnabled = false
            shortcutsSubmenu.addItem(item)
        }
        shortcutsItem.submenu = shortcutsSubmenu
        menu.addItem(shortcutsItem)
        
        // À propos
        let aboutItem = NSMenuItem(title: String(localized: "About", comment: "Menu item for about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // Ouvrir le dépôt (sources)
        let repoItem = NSMenuItem(title: String(localized: "View Repository", comment: "Menu item to open GitHub repository"), action: #selector(openRepository), keyEquivalent: "")
        repoItem.target = self
        menu.addItem(repoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quitter
        let quitItem = NSMenuItem(title: String(localized: "Quit", comment: "Menu item to quit app"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    
    @objc func addWater() {
        HydrationManager.shared.addWater(amount: 250.0)
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = String(localized: "HydroBar", comment: "App name")
        let versionText = String(format: String(localized: "Hydration tracking app for macOS\nVersion %@\n\nMade by Antoine Deshoux - https://adx.cool", comment: "About dialog text"), currentAppVersion)
        alert.informativeText = versionText
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK", comment: "OK button"))
        alert.runModal()
    }
    
    @objc func openRepository() {
        NSWorkspace.shared.open(Self.repositoryURL)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func setupUndoSupport() {
        // Créer ou mettre à jour le menu Edit avec Undo
        DispatchQueue.main.async { [weak self] in
            guard let mainMenu = NSApp.mainMenu else { return }
            
            // Chercher le menu Edit existant ou en créer un nouveau
            let editMenu: NSMenu
            let editMenuTitle = String(localized: "Edit", comment: "Edit menu title")
            if let existingEditItem = mainMenu.items.first(where: { $0.title == "Edit" || $0.title == "Édition" || $0.title == editMenuTitle }),
               let existingMenu = existingEditItem.submenu {
                editMenu = existingMenu
            } else {
                editMenu = NSMenu(title: editMenuTitle)
                let editMenuItem = NSMenuItem(title: editMenuTitle, action: nil, keyEquivalent: "")
                editMenuItem.submenu = editMenu
                mainMenu.addItem(editMenuItem)
            }
            
            // Ajouter ou mettre à jour l'item Undo
            if let existingUndo = editMenu.items.first(where: { $0.action == #selector(self?.performUndo) }) {
                existingUndo.isEnabled = HydrationManager.shared.canUndo
            } else {
                let undoItem = NSMenuItem(title: String(localized: "Undo", comment: "Undo menu item"), action: #selector(self?.performUndo), keyEquivalent: "z")
                undoItem.target = self
                undoItem.isEnabled = HydrationManager.shared.canUndo
                editMenu.insertItem(undoItem, at: 0)
            }
        }
    }
    
    @objc func performUndo() {
        let success = HydrationManager.shared.undo()
        if success {
            // Mettre à jour l'état du menu
            setupUndoSupport()
        }
    }
    
    // Gérer les actions de notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "DRINK_ACTION" {
            // Ajouter le premier preset
            let manager = HydrationManager.shared
            if !manager.presetsMl.isEmpty {
                manager.addWater(amount: manager.presetsMl[0])
            }
        }
        
        completionHandler()
    }
    
    // Afficher les notifications même quand l'app est au premier plan
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
