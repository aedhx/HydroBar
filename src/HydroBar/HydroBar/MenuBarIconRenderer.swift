//
//  MenuBarIconRenderer.swift
//  HydroBar
//
//  Icônes « template » de la barre de menu : monochromes, teintées par macOS
//  selon la barre (claire, sombre, Liquid Glass). L'icône était bleue ou verte,
//  ce qui détonne sur une barre teintée et se lit mal sur fond clair ; la
//  couleur reste disponible en option.
//
//  Une image template n'a qu'une couleur : seule l'opacité distingue la piste,
//  la progression et la pastille. La pastille est découpée dans l'anneau pour
//  rester lisible sans le rouge.
//

import AppKit

enum MenuBarIconRenderer {

    private static let size = NSSize(width: 18, height: 18)

    /// Anneau qui se remplit ; coche au centre une fois l'objectif atteint.
    static func ring(progress: Double, showBadge: Bool) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 6.6
            let lineWidth: CGFloat = 2.2

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            NSColor.black.withAlphaComponent(0.3).setStroke()
            track.stroke()

            let fraction = min(max(progress, 0), 1)
            if fraction > 0 {
                // Sens horaire depuis midi, comme l'anneau du popover.
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius,
                              startAngle: 90, endAngle: 90 - CGFloat(fraction) * 360, clockwise: true)
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                NSColor.black.setStroke()
                arc.stroke()
            }

            if progress >= 1 {
                let check = NSBezierPath()
                check.move(to: NSPoint(x: center.x - 2.8, y: center.y + 0.1))
                check.line(to: NSPoint(x: center.x - 0.8, y: center.y - 1.9))
                check.line(to: NSPoint(x: center.x + 3.0, y: center.y + 2.2))
                check.lineWidth = 1.6
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                NSColor.black.setStroke()
                check.stroke()
            }

            if showBadge { drawBadge(in: rect) }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Pourcentage en texte.
    static func percentage(_ value: Int, showBadge: Bool) -> NSImage {
        let text = "\(value)%" as NSString
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textSize = text.size(withAttributes: attributes)
        let imageSize = NSSize(width: ceil(textSize.width) + 8, height: 18)

        let image = NSImage(size: imageSize, flipped: false) { rect in
            text.draw(at: NSPoint(x: 4, y: (rect.height - textSize.height) / 2), withAttributes: attributes)
            if showBadge { drawBadge(in: rect) }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Pastille en haut à droite, détourée pour se détacher de ce qu'elle couvre.
    private static func drawBadge(in rect: NSRect) {
        let diameter: CGFloat = 6
        let badge = NSRect(x: rect.maxX - diameter, y: rect.maxY - diameter, width: diameter, height: diameter)
        guard let context = NSGraphicsContext.current else { return }

        context.compositingOperation = .clear
        NSBezierPath(ovalIn: badge.insetBy(dx: -1.2, dy: -1.2)).fill()
        context.compositingOperation = .sourceOver
        NSColor.black.setFill()
        NSBezierPath(ovalIn: badge).fill()
    }
}
