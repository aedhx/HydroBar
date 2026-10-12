//
//  TodayLogView.swift
//  HydroBar
//
//  Journal du jour (roadmap F17) : ce qui a été enregistré aujourd'hui, avec la
//  possibilité de retirer une prise sans toucher aux autres. Avant, les seules
//  corrections possibles étaient l'annulation de la dernière prise et le reset
//  de toute la journée.
//

import SwiftUI

struct TodayLogView: View {
    @ObservedObject var manager: HydrationManager

    /// Replié par défaut : le popover reste centré sur l'anneau et les presets.
    @AppStorage("todayLogExpanded") private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAddingPastDrink = false

    var body: some View {
        let events = manager.todayEvents

        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(Theme.Font.footnoteEmphasis)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(String(format: String(localized: "Today's log (%lld)",
                                               comment: "Disclosure title for today's intake list; %lld is the number of entries"),
                                events.count))
                        .font(Theme.Font.calloutMedium)
                    Spacer()
                }
                .foregroundColor(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Shows or hides the list of today's entries",
                                    comment: "VoiceOver hint for the today's log disclosure"))

            if isExpanded {
                if events.isEmpty {
                    Text("Nothing logged yet today.", comment: "Empty state of today's log")
                        .font(Theme.Font.callout)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            // Une prise ajoutée glisse en tête, une prise
                            // supprimée se replie (v2.2).
                            ForEach(events) { event in
                                row(for: event)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .animation(Theme.motion(Theme.Motion.snappy, reduceMotion: reduceMotion),
                                   value: events.map(\.id))
                    }
                    .frame(maxHeight: 150)
                }

                if isAddingPastDrink {
                    PastDrinkForm(manager: manager) { isAddingPastDrink = false }
                } else {
                    Button {
                        isAddingPastDrink = true
                    } label: {
                        Label(String(localized: "Add an Earlier Drink…", comment: "Button to log a drink at a past date or time"),
                              systemImage: "clock.arrow.circlepath")
                            .font(Theme.Font.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    private func row(for event: IntakeEvent) -> some View {
        HStack(spacing: 10) {
            Group {
                if event.isAggregate {
                    // Total repris de la v1 : il n'a pas d'heure réelle.
                    Text("Earlier", comment: "Time label for a total imported from the previous version")
                } else {
                    Text(event.date.formatted(date: .omitted, time: .shortened))
                }
            }
            .font(Theme.Font.mono)
            .foregroundColor(.secondary)
            .frame(width: 64, alignment: .leading)

            Text(verbatim: "+" + manager.displayValue(for: event.amountMl))
                .font(Theme.Font.bodyMedium)

            Spacer()

            Button {
                manager.removeEvent(id: event.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(Theme.Font.body)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Remove this entry (⌘Z to undo)",
                         comment: "Tooltip of the delete button in today's log"))
            .accessibilityLabel(Text("Remove entry", comment: "VoiceOver label of the delete button in today's log"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(6)
    }
}
