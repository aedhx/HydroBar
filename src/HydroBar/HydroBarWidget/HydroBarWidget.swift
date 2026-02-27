// HydroBarWidget.swift
// Target Membership: HydroBarWidget ONLY

import WidgetKit
import SwiftUI

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
        let snapshot = AppGroupStore.read()
        let entry = HydrationEntry(date: Date(), snapshot: snapshot)
        // .never: widget refreshes only when HydrationManager calls WidgetCenter.reloadTimelines()
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Placeholder Widget View
// Temporary stub view — replaced with real UI in Phase 2
struct HydroBarWidgetEntryView: View {
    let entry: HydrationEntry

    var body: some View {
        VStack {
            Text("\(Int(entry.snapshot.progress * 100))%")
                .font(.largeTitle.bold())
            Text("of \(Int(entry.snapshot.targetMl)) ml")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle Entry Point
@main
struct HydroBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        HydroBarWidget()
    }
}
