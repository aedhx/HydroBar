// HydroBarWidget.swift
// Target Membership: HydroBarWidget ONLY

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct HydrationEntry: TimelineEntry {
    let date: Date
    let snapshot: HydrationSnapshot
}

// MARK: - Timeline Provider

struct HydroBarTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> HydrationEntry {
        HydrationEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HydrationEntry) -> Void) {
        completion(HydrationEntry(date: Date(), snapshot: AppGroupStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        let entry = HydrationEntry(date: Date(), snapshot: AppGroupStore.read())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Ring Component

struct HydroRing: View {
    let progress: Double   // rawProgress, uncapped — color logic; stroke clamped to 1.0
    let lineWidth: CGFloat

    private var ringColor: Color {
        if progress <= 0 { return Color(white: 0.78) }
        return progress >= 1.0 ? .green : .blue
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(white: 0.85), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1.0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Helpers

private func formatMl(_ ml: Double, unit: String) -> String {
    switch unit {
    case "cl":
        let val = ml / 10
        return val.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(val)) cl"
            : String(format: "%.1f cl", val)
    case "L":
        return String(format: "%.2f L", ml / 1000)
    case "oz":
        return String(format: "%.0f oz", ml / 29.5735)
    default:
        let val = ml / 10
        return val.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(val)) cl"
            : String(format: "%.1f cl", val)
    }
}

/// Green intensity matching the app's monthly heatmap style.
/// 0 → gray, >0–50% → light green, 50–100% → medium green, 100%+ → full green
private func heatmapColor(amountMl: Double, targetMl: Double) -> Color {
    guard amountMl > 0, targetMl > 0 else { return Color(white: 0.85) }
    let ratio = min(amountMl / targetMl, 1.0)
    return Color.green.opacity(0.2 + ratio * 0.8)
}

// MARK: - Preset button presets (ml)

private let presets: [Double] = [200, 500, 750]

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: HydrationEntry

    private var pct: Int { Int(entry.snapshot.rawProgress * 100) }
    private var unit: String { entry.snapshot.unit }

    var body: some View {
        VStack(spacing: 8) {
            // Ring — smaller lineWidth so the percentage fits without the subtitle
            ZStack {
                HydroRing(progress: entry.snapshot.rawProgress, lineWidth: 9)
                Text("\(pct)%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Preset buttons
            HStack(spacing: 4) {
                ForEach(presets, id: \.self) { ml in
                    Button(intent: AddWaterIntent(amountMl: ml)) {
                        Text("+\(formatMl(ml, unit: unit))")
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(.fill.secondary, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: HydrationEntry

    private var unit: String { entry.snapshot.unit }

    private var paddedHistory: [HistoryEntrySnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { offset -> HistoryEntrySnapshot in
            let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today)!
            let existing = entry.snapshot.weekHistory.first {
                calendar.isDate($0.date, inSameDayAs: date)
            }
            return existing ?? HistoryEntrySnapshot(date: date, amountMl: 0, targetMl: entry.snapshot.targetMl)
        }
    }

    private func dayInitial(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date).uppercased()
    }

    var body: some View {
        HStack(spacing: 16) {
            // Mini ring
            ZStack {
                HydroRing(progress: entry.snapshot.rawProgress, lineWidth: 8)
                VStack(spacing: 1) {
                    Text("\(min(Int(entry.snapshot.rawProgress * 100), 100))%")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(formatMl(entry.snapshot.currentMl, unit: unit))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 78, height: 78)

            // Right column: heatmap + buttons
            VStack(alignment: .leading, spacing: 8) {
                // 7-day heatmap (app style: green intensity)
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        ForEach(paddedHistory, id: \.date) { day in
                            Text(dayInitial(day.date))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    HStack(spacing: 0) {
                        ForEach(paddedHistory, id: \.date) { day in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(heatmapColor(amountMl: day.amountMl, targetMl: day.targetMl))
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .padding(2)
                        }
                    }
                }

                // Preset buttons
                HStack(spacing: 5) {
                    ForEach(presets, id: \.self) { ml in
                        Button(intent: AddWaterIntent(amountMl: ml)) {
                            Text("+\(formatMl(ml, unit: unit))")
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(.fill.secondary, in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Entry View (router)

struct HydroBarWidgetEntryView: View {
    let entry: HydrationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct HydroBarWidget: Widget {
    let kind = "HydroBarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HydroBarTimelineProvider()) { entry in
            HydroBarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("HydroBar")
        .description("Track your daily hydration.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle Entry Point

@main
struct HydroBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        HydroBarWidget()
    }
}

// MARK: - Previews

#Preview("Small – in progress", as: .systemSmall) {
    HydroBarWidget()
} timeline: {
    HydrationEntry(date: .now, snapshot: .placeholder)
}

#Preview("Small – goal reached", as: .systemSmall) {
    HydroBarWidget()
} timeline: {
    HydrationEntry(date: .now, snapshot: HydrationSnapshot(
        currentMl: 5000, targetMl: 2000, unit: "cl",
        lastUpdated: .now, weekHistory: []
    ))
}

#Preview("Medium", as: .systemMedium) {
    HydroBarWidget()
} timeline: {
    HydrationEntry(date: .now, snapshot: .placeholder)
}
