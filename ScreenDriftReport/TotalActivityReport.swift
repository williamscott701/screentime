import DeviceActivity
import ExtensionKit
import SwiftUI

private let appGroupID = "group.com.screendrift.shared"

// Must match the context string in HistoryView.swift exactly
extension DeviceActivityReport.Context {
    static let totalActivity = Self("totalActivity")
}

struct TotalUsageModel {
    let totalMinutes: Int
}

nonisolated struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    nonisolated(unsafe) let content: (TotalUsageModel) -> TotalActivityView

    // nonisolated so this struct can be constructed from ScreenDriftReport.body
    // which must be nonisolated to satisfy DeviceActivityReportExtension.
    nonisolated init(content: @escaping (TotalUsageModel) -> TotalActivityView) {
        self.content = content
    }

    nonisolated func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> TotalUsageModel {
        // Collect per-day durations keyed by ISO date string (e.g. "2025-04-03")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone.current

        var dailyDurations: [String: TimeInterval] = [:]

        for await activityData in data {
            for await segment in activityData.activitySegments {
                let dayKey = formatter.string(from: segment.dateInterval.start)
                dailyDurations[dayKey, default: 0] += segment.totalActivityDuration
            }
        }

        // Identify today's key and extract today's total separately
        let todayKey = formatter.string(from: Calendar.current.startOfDay(for: Date()))
        let todayMinutes = Int((dailyDurations[todayKey] ?? 0) / 60)
        let totalMinutes = Int(dailyDurations.values.reduce(0, +) / 60)

        // Convert to per-day Int dictionary for App Groups
        let dailyMinutes = Dictionary(uniqueKeysWithValues: dailyDurations.map {
            ($0.key, Int($0.value / 60))
        })

        let defaults = UserDefaults(suiteName: appGroupID)
        // Write today-only value (used by widget and dashboard ring)
        defaults?.set(todayMinutes, forKey: "autoTodayMinutes")
        defaults?.set(Date().timeIntervalSinceReferenceDate, forKey: "autoLastUpdated")
        // Write full daily breakdown (used by History chart)
        if let encoded = try? JSONEncoder().encode(dailyMinutes) {
            defaults?.set(encoded, forKey: "dailyMinutes")
        }
        // Flush to disk so the main app can read immediately
        defaults?.synchronize()

        return TotalUsageModel(totalMinutes: totalMinutes)
    }
}
