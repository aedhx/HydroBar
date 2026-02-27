// AppGroupStore.swift
// Target Membership: HydroBar (main app) AND HydroBarWidget (widget extension)
// Foundation only — no AppKit, no SwiftUI, no HydrationManager

import Foundation

// MARK: - Shared Snapshot Structs
// These are minimal Codable value types — no dependency on HydrationManager or AppKit.
// The widget reads these; HydrationManager writes them.

struct HydrationSnapshot: Codable {
    let currentMl: Double
    let targetMl: Double
    let unit: String          // AppUnit.rawValue — "cl", "L", or "oz"
    let lastUpdated: Date
    let weekHistory: [HistoryEntrySnapshot]

    var progress: Double { min(currentMl / max(targetMl, 1.0), 1.0) }

    // Placeholder for widget gallery preview
    static let placeholder = HydrationSnapshot(
        currentMl: 1200,
        targetMl: 2000,
        unit: "cl",
        lastUpdated: Date(),
        weekHistory: []
    )
}

struct HistoryEntrySnapshot: Codable {
    let date: Date
    let amountMl: Double
    let targetMl: Double
    var isComplete: Bool { amountMl >= targetMl }
}

// MARK: - App Group Store

struct AppGroupStore {
    static let suiteName = "group.com.adxcool.HydroBar"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Keys
    private enum Key {
        static let snapshot = "widget_snapshot_v1"
    }

    // MARK: - Write (called by main app only)
    /// Atomically writes the complete hydration snapshot to the shared container.
    /// Called from HydrationManager.syncToAppGroup() after every state mutation.
    static func write(_ snapshot: HydrationSnapshot) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(encoded, forKey: Key.snapshot)
    }

    // MARK: - Read (called by widget TimelineProvider)
    /// Returns the latest snapshot written by the main app.
    /// Returns HydrationSnapshot.placeholder if no data has been written yet.
    static func read() -> HydrationSnapshot {
        guard let data = defaults.data(forKey: Key.snapshot),
              let snapshot = try? JSONDecoder().decode(HydrationSnapshot.self, from: data)
        else {
            return .placeholder
        }
        return snapshot
    }
}
