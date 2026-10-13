//
//  BottleView.swift
//  HydroBar
//
//  Mode gourde dans le popover : la gourde se remplit à l'écran au fil des
//  niveaux notés (un quart, la moitié, trois quarts, finie).
//

import SwiftUI

struct BottleView: View {
    @ObservedObject var manager: HydrationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var drunk: Double { manager.bottleDrunkMl }
    private var capacity: Double { max(manager.bottleCapacityMl, 1) }
    private var fraction: Double { min(drunk / capacity, 1) }
    private var isFinished: Bool { fraction >= 0.999 }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            bottle
                .frame(width: 34, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(statusText)
                    .font(Theme.Font.calloutMedium)
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText(value: drunk))

                if isFinished {
                    Button {
                        manager.startNewBottle()
                    } label: {
                        Label(String(localized: "New Bottle", comment: "Bottle mode: start a new bottle"),
                              systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                } else {
                    HStack(spacing: 6) {
                        ForEach(Bottle.marks, id: \.self) { mark in
                            markButton(mark)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.presetFill)
        .cornerRadius(Theme.Radius.control)
        .animation(Theme.motion(Theme.Motion.ring, reduceMotion: reduceMotion), value: fraction)
    }

    private var statusText: String {
        if isFinished {
            return String(localized: "Bottle finished. Well done!", comment: "Bottle mode status when the bottle is empty")
        }
        return String(format: String(localized: "%@ left in your bottle", comment: "Bottle mode status; %@ is an amount"),
                      manager.displayValue(for: max(capacity - drunk, 0)))
    }

    // MARK: Boutons de niveau

    private func markButton(_ mark: Double) -> some View {
        let reached = fraction >= mark - 0.001
        return Button {
            manager.setBottleLevel(mark)
        } label: {
            Text(verbatim: label(for: mark))
                .font(Theme.Font.calloutEmphasis)
                .frame(minWidth: 28)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.row)
                        .fill(reached ? Theme.water.opacity(0.25) : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .disabled(reached)
        .accessibilityLabel(accessibilityLabel(for: mark))
    }

    private func label(for mark: Double) -> String {
        switch mark {
        case 0.25: return "¼"
        case 0.5: return "½"
        case 0.75: return "¾"
        default: return String(localized: "Done", comment: "Onboarding navigation")
        }
    }

    private func accessibilityLabel(for mark: Double) -> String {
        mark >= 1
            ? String(localized: "Bottle finished", comment: "VoiceOver: mark the bottle as finished")
            : String(format: String(localized: "%lld percent of the bottle drunk", comment: "VoiceOver: bottle level; %lld is a percentage"),
                     Int(mark * 100))
    }

    // MARK: Dessin

    /// L'eau restante descend à mesure qu'on boit : la gourde se vide.
    private var bottle: some View {
        ZStack(alignment: .bottom) {
            BottleShape()
                .fill(Color.primary.opacity(0.06))
            Rectangle()
                .fill(LinearGradient(colors: [Theme.waterLight, Theme.water], startPoint: .top, endPoint: .bottom))
                .frame(height: 64 * 0.82 * (1 - fraction))
                .mask(alignment: .bottom) { BottleShape().frame(height: 64) }
            BottleShape()
                .stroke(Color.primary.opacity(0.35), lineWidth: 1.5)
        }
    }
}

/// Silhouette de gourde : un corps arrondi et un goulot.
private struct BottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let neckWidth = rect.width * 0.42
        let neckHeight = rect.height * 0.18
        let neck = CGRect(x: rect.midX - neckWidth / 2, y: rect.minY, width: neckWidth, height: neckHeight)
        path.addRoundedRect(in: neck, cornerSize: CGSize(width: 3, height: 3))
        let body = CGRect(x: rect.minX, y: rect.minY + neckHeight - 2, width: rect.width, height: rect.height - neckHeight + 2)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: rect.width * 0.3, height: rect.width * 0.3))
        return path
    }
}
