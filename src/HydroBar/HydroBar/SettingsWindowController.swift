//
//  SettingsWindowController.swift
//  HydroBar
//
//  Fenêtre de réglages (v2). Les réglages s'affichaient dans le popover de
//  320 px, douze sections empilées. Ils ont désormais une vraie fenêtre, à
//  onglets.
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

        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(manager: .shared))
            let window = NSWindow(contentViewController: controller)
            window.title = String(localized: "HydroBar Settings", comment: "Settings window title")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("HydroBarSettings")
            if !window.setFrameUsingName("HydroBarSettings") { window.center() }
            self.window = window
        }
        // App de barre de menu : sans activation, la fenêtre s'ouvre derrière
        // l'application au premier plan.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
