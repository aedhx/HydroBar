//
//  IntakeToast.swift
//  HydroBar
//
//  Étiquette « +20 cl » sous l'icône de la barre de menu, quand une prise est
//  ajoutée sans que le popover soit ouvert : raccourci global, ⌥-clic, App
//  Intents, widget, deep link. Avant, seul un son la confirmait — et rien du
//  tout pour les ajouts silencieux.
//

import AppKit
import SwiftUI

final class IntakeToastController {

    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    /// Affiche l'étiquette sous `button` pendant un peu plus d'une seconde.
    func show(_ text: String, below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let host = NSHostingView(rootView: ToastLabel(text: text))
        host.frame.size = host.fittingSize
        panel.contentView = host
        panel.setContentSize(host.fittingSize)

        // Centrée sous l'icône, un peu sous la barre de menu.
        let anchor = buttonWindow.frame
        let origin = NSPoint(x: anchor.midX - host.fittingSize.width / 2,
                             y: anchor.minY - host.fittingSize.height - 6)
        panel.setFrameOrigin(origin)

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = reduceMotion ? 1 : 0
        panel.orderFrontRegardless()
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 1
            }
        }

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide(animated: !reduceMotion) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3, execute: work)
    }

    private func hide(animated: Bool) {
        guard let panel else { return }
        guard animated else { panel.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        return panel
    }
}

private struct ToastLabel: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Theme.Font.bodyEmphasis)
            .monospacedDigit()
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.water))
            .padding(2)
    }
}
