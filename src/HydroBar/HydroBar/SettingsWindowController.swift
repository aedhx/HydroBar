//
//  SettingsWindowController.swift
//  HydroBar
//
//  Fenêtre de réglages (v2). Les réglages s'affichaient dans le popover de
//  320 px, douze sections empilées. Ils ont désormais une vraie fenêtre, à
//  onglets de barre d'outils, comme les réglages de Safari ou de Mail : une
//  icône par page, le titre de la fenêtre qui suit la page, la hauteur aussi.
//
//  Gérée à la main plutôt que par la scène `Settings` de SwiftUI : pour une app
//  de barre de menu, l'ouvrir par programme n'est pas fiable sur macOS 14+, où
//  le sélecteur `showSettingsWindow:` ne fonctionne plus. Cette fenêtre-ci
//  s'ouvre de partout : popover, menu contextuel (⌘,), deep link.
//

import AppKit
import SwiftUI

final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        (NSApp.delegate as? AppDelegate)?.closePopover()

        // La source de vérité du lancement au démarrage est le système :
        // l'utilisateur a pu le changer dans Réglages Système entre-temps.
        LaunchAtLoginManager.shared.refresh()

        if window == nil {
            window = Self.makeWindow(manager: .shared)
        }
        // App de barre de menu : sans activation, la fenêtre s'ouvre derrière
        // l'application au premier plan.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    static func makeWindow(manager: HydrationManager) -> NSWindow {
        let tabs = SettingsTabViewController(manager: manager)
        let window = NSWindow(contentViewController: tabs)
        // Contenu pleine hauteur et barre de titre transparente : le matériau
        // de la fenêtre passe aussi sous les onglets.
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false

        tabs.fitWindowToSelectedPage(animated: false)
        // Comme dans Safari ou Mail : pas de « Texte seulement » au clic droit.
        window.toolbar?.allowsDisplayModeCustomization = false
        window.setFrameAutosaveName("HydroBarSettings")
        if !window.setFrameUsingName("HydroBarSettings") { window.center() }
        // Seule la position enregistrée compte : la taille est celle de la
        // page affichée.
        tabs.fitWindowToSelectedPage(animated: false)
        return window
    }
}

// MARK: - Onglets

/// Les quatre pages, en onglets de barre d'outils. La fenêtre prend la
/// hauteur de la page affichée ; une page plus haute que `maxPageHeight`
/// défile.
final class SettingsTabViewController: NSTabViewController {
    private static let selectionKey = "settingsTab"
    private static let maxPageHeight: CGFloat = 680

    init(manager: HydrationManager) {
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        // Pas de fondu entre deux pages : c'est la fenêtre qui s'anime.
        transitionOptions = []

        for tab in SettingsTab.allCases {
            let page = SettingsPageController(tab: tab, manager: manager)
            page.onContentHeightChange = { [weak self, weak page] in
                guard let self, let page, page === self.selectedPage else { return }
                self.fitWindowToSelectedPage(animated: true)
            }
            let item = NSTabViewItem(viewController: page)
            item.image = NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: nil)
            addTabViewItem(item)
        }

        // Onglet affiché, retrouvé à la réouverture de la fenêtre.
        let stored = SettingsTab(storedValue: UserDefaults.standard.string(forKey: Self.selectionKey))
        selectedTabViewItemIndex = SettingsTab.allCases.firstIndex(of: stored) ?? 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SettingsTabViewController se crée par init(manager:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Le verre : le bureau et les fenêtres de derrière transparaissent,
        // floutés, sous toute la fenêtre. `.sidebar` est le matériau des
        // barres latérales du système : translucide, et prévu pour porter du
        // texte, en clair comme en sombre. `.active` : la fenêtre ne devient
        // pas opaque quand elle perd le focus.
        let glass = NSVisualEffectView(frame: view.bounds)
        glass.material = .sidebar
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.autoresizingMask = [.width, .height]
        view.addSubview(glass, positioned: .below, relativeTo: nil)
        // Sans cela, la vue à onglets peint le fond de fenêtre par-dessus.
        tabView.drawsBackground = false
    }

    private var selectedPage: SettingsPageController? {
        guard tabViewItems.indices.contains(selectedTabViewItemIndex) else { return nil }
        return tabViewItems[selectedTabViewItemIndex].viewController as? SettingsPageController
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let page = selectedPage else { return }
        UserDefaults.standard.set(page.tab.rawValue, forKey: Self.selectionKey)
        fitWindowToSelectedPage(animated: true)
    }

    /// Donne à la fenêtre la hauteur de la page affichée. Le coin haut gauche
    /// ne bouge pas : la fenêtre grandit vers le bas.
    func fitWindowToSelectedPage(animated: Bool) {
        guard let window = view.window, let page = selectedPage else { return }

        window.layoutIfNeeded()
        // Barre de titre et barre d'outils, que le contenu pleine hauteur
        // englobe.
        let chrome = window.frame.height - window.contentLayoutRect.height
        let screen = (window.screen ?? NSScreen.main)?.visibleFrame
        let available = (screen?.height ?? .greatestFiniteMagnitude) - chrome
        let height = min(page.contentHeight, Self.maxPageHeight, available) + chrome

        var frame = window.frame
        frame.origin.y += frame.height - height
        frame.size = NSSize(width: SettingsLayout.pageWidth, height: height)
        // Une page plus haute ne doit pas pousser le bas de la fenêtre hors
        // de l'écran.
        if let screen, frame.minY < screen.minY {
            frame.origin.y = screen.minY
        }
        guard frame != window.frame else { return }

        if animated && window.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }
    }
}

// MARK: - Page

/// Une page : sa vue SwiftUI, calée sous la barre d'outils. Le contenu de la
/// fenêtre passe sous la barre, transparente, pour que le matériau y soit
/// continu ; la page, elle, s'arrête dessous, sinon ses lignes défileraient
/// derrière les onglets.
final class SettingsPageController: NSViewController {
    let tab: SettingsTab
    /// La hauteur du contenu a changé : une option a ajouté ou retiré des lignes.
    var onContentHeightChange: (() -> Void)?

    private let hosting: NSHostingController<AnyView>
    private var reportedHeight: CGFloat?

    init(tab: SettingsTab, manager: HydrationManager) {
        self.tab = tab
        let metrics = SettingsPageMetrics()
        hosting = NSHostingController(rootView: AnyView(
            tab.page(manager: manager).environment(\.settingsPageMetrics, metrics)
        ))
        // Aucune contrainte de taille : c'est la fenêtre qui prend la hauteur
        // de la page, et une page plus haute qu'elle doit pouvoir défiler.
        hosting.sizingOptions = []
        super.init(nibName: nil, bundle: nil)
        // NSTabViewController en fait le libellé de l'onglet et le titre de
        // la fenêtre.
        title = tab.title
        addChild(hosting)
        metrics.onContentHeightChange = { [weak self] height in
            guard let self, height != self.reportedHeight else { return }
            self.reportedHeight = height
            self.onContentHeightChange?()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SettingsPageController se crée par init(tab:manager:)")
    }

    override func loadView() {
        let container = NSView()
        let page = hosting.view
        page.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(page)
        NSLayoutConstraint.activate([
            page.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            page.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            page.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view = container
    }

    /// Hauteur du contenu de la page, sans limite : au-delà de celle de la
    /// fenêtre, la page défile. Tant que la page n'a pas été affichée, c'est
    /// la taille idéale de sa vue.
    var contentHeight: CGFloat {
        reportedHeight ?? hosting.view.fittingSize.height
    }
}
