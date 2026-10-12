//
//  HydroBarApp.swift
//  HydroBar
//
//  Created by Antoine DX on 13/01/2026.
//

import SwiftUI
import UserNotifications
import AppKit
import Combine

@main
struct HydroBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Avant de créer le manager, qui produit déjà des textes localisés.
        HydrationManager.applyLanguagePreference(
            UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        )
        
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
                    .fill(isGoalReached ? Theme.goal : Theme.water)
                }

                // Bordure toujours visible pour ancrer l'icône sur fond transparent
                Circle()
                    .stroke(Color(white: 0.5, opacity: 0.35), lineWidth: 1)
            }
        }
        .frame(width: 18, height: 18)
    }
    
    private var percentageView: some View {
        Text("\(percentage)%")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(isGoalReached ? Theme.goal : Theme.water)
            .monospacedDigit()
            .frame(minWidth: 45, alignment: .center)
            .padding(.horizontal, 2)
    }
}

// MARK: - AppDelegate pour gérer les notifications et le status bar
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, DeepLinkPresenting {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var hostingController: NSHostingController<MenuBarIconView>?

    /// L'icône se met à jour quand l'état change, et seulement alors. Remplace un
    /// minuteur à 2 Hz qui reconstruisait un NSHostingController complet à chaque
    /// tick, 24 h/24, pour une valeur qui change quelques dizaines de fois par
    /// jour (cf. AUDIT § P2-1).
    private var iconSubscription: AnyCancellable?

    /// Style actuellement monté dans le bouton : la vue SwiftUI n'est
    /// reconstruite que lorsqu'il change.
    private var renderedIconStyle: MenuBarIconStyle?
    
    // MARK: - Deep links (hydrobar://)

    /// Le presenter est branché avant la fin du lancement : l'app peut être démarrée
    /// *par* une URL, et AppKit délivre alors l'URL très tôt.
    func applicationWillFinishLaunching(_ notification: Notification) {
        DeepLinkRouter.shared.presenter = self
    }

    /// Unique point d'entrée des `hydrobar://`. On ne pose volontairement PAS de
    /// handler Apple Event `GURL` en plus : AppKit en installe déjà un qui appelle
    /// cette méthode, et en ajouter un second risque de délivrer l'URL deux fois —
    /// donc d'ajouter l'eau en double. Les URLs arrivées avant que la barre de menu
    /// n'existe sont mises en attente par le routeur jusqu'à `markReady()`.
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { DeepLinkRouter.shared.handle($0) }
    }

    /// L'écriture de l'historique est différée d'une demi-seconde : on la vide à
    /// la fermeture pour qu'un délai ne coûte jamais une donnée.
    func applicationWillTerminate(_ notification: Notification) {
        HydrationManager.shared.flushPendingWrites()
    }

    /// Raccourci global « Open HydroBar » (F20).
    func togglePopoverFromShortcut() {
        guard let button = statusItem?.button else { return }
        NSApp.activate()
        togglePopover(for: button)
    }

    func presentPopover(showing view: ViewType) {
        AppNavigation.shared.requestView(view)
        guard let button = statusItem?.button, let popover = popover else { return }
        NSApp.activate()
        if !popover.isShown {
            togglePopover(for: button)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // L'autorisation des notifications n'est plus demandée ici, au premier
        // lancement, mais quand l'utilisateur active les rappels (onboarding ou
        // réglages). On vérifie seulement qu'elle n'a pas été retirée depuis.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .denied else { return }
            DispatchQueue.main.async {
                HydrationManager.shared.notificationsEnabled = false
            }
        }

        // Initialiser le gestionnaire de raccourcis globaux
        _ = GlobalHotkeyManager.shared
        
        // Charger les raccourcis sauvegardés
        loadSavedShortcuts()
        
        // Créer le status item
        setupStatusBar()

        // La barre de menu existe : les deep links reçus pendant le lancement
        // peuvent maintenant être traités.
        DeepLinkRouter.shared.markReady()

        OnboardingWindowController.shared.showIfNeeded()
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
        
        // objectWillChange est émis AVANT la mutation : receive(on:) diffère la
        // lecture au tour de boucle suivant, quand la nouvelle valeur est en place.
        iconSubscription = HydrationManager.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusBarIcon() }
    }
    
    func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        let manager = HydrationManager.shared

        // VoiceOver et info-bulle : l'icône seule n'annonçait rien d'exploitable.
        let summary = manager.progressAccessibilitySummary
        button.setAccessibilityLabel("HydroBar")
        button.setAccessibilityValue(summary)
        button.toolTip = summary + "\n" + String(localized: "Option-click to log your first preset.",
                                                 comment: "Menu bar icon tooltip hint")

        let target = manager.targetMl
        let progress = target > 0 ? manager.currentMl / target : 0

        // Icône monochrome par défaut (v2.2) : une image template, teintée par
        // macOS. Redessinée à chaque changement, ce qui ne coûte presque rien.
        if !manager.coloredMenuBarIcon {
            if hostingController != nil {
                button.subviews.forEach { $0.removeFromSuperview() }
                hostingController = nil
            }
            renderedIconStyle = nil
            button.title = ""
            button.imagePosition = .imageOnly
            switch manager.menuBarIconStyle {
            case .pieRing:
                statusItem?.length = NSStatusItem.squareLength
                button.image = MenuBarIconRenderer.ring(progress: progress, showBadge: manager.showReminderBadge)
            case .percentage:
                statusItem?.length = NSStatusItem.variableLength
                button.image = MenuBarIconRenderer.percentage(Int(progress * 100), showBadge: manager.showReminderBadge)
            }
            return
        }

        switch manager.menuBarIconStyle {
        case .percentage:
            if renderedIconStyle != .percentage {
                button.subviews.forEach { $0.removeFromSuperview() }
                hostingController = nil
                statusItem?.length = NSStatusItem.variableLength
                button.imagePosition = .imageLeading
                button.title = ""
            }
            // Une image texte coûte peu : elle est redessinée à chaque changement.
            let percentage = target > 0 ? Int((manager.currentMl / target) * 100) : 0
            let isGoalReached = target > 0 && manager.currentMl >= target
            button.image = createPercentageImage(percentage: percentage,
                                                 isGoalReached: isGoalReached,
                                                 showBadge: manager.showReminderBadge)

        case .pieRing:
            // La vue SwiftUI observe le manager elle-même : il suffit de la monter
            // une fois, elle se redessine ensuite seule.
            guard renderedIconStyle != .pieRing else { break }
            button.image = nil
            button.title = ""
            statusItem?.length = 24
            button.subviews.forEach { $0.removeFromSuperview() }

            let controller = NSHostingController(rootView: MenuBarIconView(manager: manager))
            let hostingView = controller.view
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(hostingView)

            // Centré par contraintes, pas par un cadre calculé. Les dimensions du
            // bouton ne sont pas toujours définitives au moment du montage :
            // l'ancien minuteur corrigeait un mauvais centrage au tick suivant ;
            // monté une seule fois, un cadre calculé trop tôt resterait faux.
            let iconSize: CGFloat = 18
            NSLayoutConstraint.activate([
                hostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                hostingView.widthAnchor.constraint(equalToConstant: iconSize),
                hostingView.heightAnchor.constraint(equalToConstant: iconSize),
            ])
            hostingController = controller
        }
        renderedIconStyle = manager.menuBarIconStyle
    }

    private func createPercentageImage(percentage: Int, isGoalReached: Bool, showBadge: Bool) -> NSImage? {
        let text = "\(percentage)%"
        let fontSize: CGFloat = 12
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        
        // Couleur selon si l'objectif est atteint
        let color = isGoalReached ? Theme.NS.goal : Theme.NS.water
        
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
        } else if event.modifierFlags.contains(.option) {
            // ⌥-clic : premier preset, sans ouvrir le popover (F14).
            let manager = HydrationManager.shared
            if let first = manager.presetsMl.first {
                manager.addWater(amount: first)
                NSSound(named: "Pop")?.play()
            }
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
        let hotkeys = GlobalHotkeyManager.shared
        let presetActions = HydrationManager.shared.presetsMl.indices.map { HotkeyAction.preset($0) }
        for action in presetActions + HotkeyAction.general {
            hotkeys.registerSavedShortcut(for: action)
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
        
        // Un élément par preset réel. L'ancien « Add 25cl / 250ml » ajoutait une
        // quantité codée en dur, quels que soient les presets de l'utilisateur.
        let manager = HydrationManager.shared
        for (index, preset) in manager.presetsMl.enumerated() {
            let title = String(format: String(localized: "Add %@", comment: "Context menu item; %@ is an amount"),
                               manager.displayValue(for: preset))
            let item = NSMenuItem(title: title, action: #selector(addPresetFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            menu.addItem(item)
        }

        let undoItem = NSMenuItem(title: String(localized: "Undo", comment: "Undo menu item"),
                                  action: #selector(performUndo), keyEquivalent: "")
        undoItem.target = self
        undoItem.isEnabled = manager.canUndo
        menu.addItem(undoItem)

        menu.addItem(NSMenuItem.separator())

        // Pause des rappels (F19)
        if manager.notificationsEnabled {
            if let until = manager.remindersSnoozedUntil {
                let title = String(format: String(localized: "Resume Reminders (paused until %@)",
                                                  comment: "Context menu item; %@ is a time"),
                                   until.formatted(date: .omitted, time: .shortened))
                let resumeItem = NSMenuItem(title: title, action: #selector(resumeReminders), keyEquivalent: "")
                resumeItem.target = self
                menu.addItem(resumeItem)
            } else {
                let pauseItem = NSMenuItem(title: String(localized: "Pause Reminders", comment: "Context menu submenu"),
                                           action: nil, keyEquivalent: "")
                let pauseMenu = NSMenu()
                for option in SnoozeOption.allCases {
                    let item = NSMenuItem(title: option.title, action: #selector(snoozeFromMenu(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = option.rawValue
                    pauseMenu.addItem(item)
                }
                pauseItem.submenu = pauseMenu
                menu.addItem(pauseItem)
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        // Sous-menu : Raccourcis clavier configurés
        let shortcutsTitle = String(localized: "Keyboard Shortcuts", comment: "Context menu submenu for configured shortcuts")
        let shortcutsItem = NSMenuItem(title: shortcutsTitle, action: nil, keyEquivalent: "")
        let shortcutsSubmenu = NSMenu()
        let presetActions = HydrationManager.shared.presetsMl.indices.map { HotkeyAction.preset($0) }
        for action in presetActions + HotkeyAction.general {
            let displayText: String
            if let data = UserDefaults.standard.data(forKey: action.defaultsKey),
               let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
                displayText = "\(action.localizedName): \(shortcut.displayString)"
            } else {
                displayText = "\(action.localizedName): —"
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
    
    @objc func addPresetFromMenu(_ sender: NSMenuItem) {
        let manager = HydrationManager.shared
        guard manager.presetsMl.indices.contains(sender.tag) else { return }
        manager.addWater(amount: manager.presetsMl[sender.tag])
    }

    @objc func snoozeFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let option = SnoozeOption(rawValue: raw) else { return }
        HydrationManager.shared.snoozeReminders(option)
    }

    @objc func resumeReminders() {
        HydrationManager.shared.resumeReminders()
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
        let manager = HydrationManager.shared
        switch response.actionIdentifier {
        case "DRINK_ACTION":
            // Ajouter le premier preset
            if let first = manager.presetsMl.first {
                manager.addWater(amount: first)
            }
        case "SNOOZE_ACTION":
            manager.snoozeReminders(.oneHour)
        default:
            break
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
