// ScreenDriftReportExtension.swift
//
// ============================================================
// HOW TO ADD THE REPORT EXTENSION:
//
// 1. In Xcode: File → New → Target → "Device Activity Report Extension"
//    - Product Name: ScreenDriftReport
//
// 2. Delete Xcode's generated placeholder file in the new group,
//    then drag THIS file into that group.
//
// 3. Add these capabilities to the ScreenDriftReport target:
//    - App Groups → add: group.com.screendrift.shared
//    (The main app needs the same App Group + Family Controls capability)
//
// 4. Add "Family Controls" capability to the MAIN app target too:
//    Select "screentime" target → Signing & Capabilities
//    → + Capability → Family Controls
//
// How it works:
//   Every time the app shows a DeviceActivityReport view (History tab),
//   this extension's makeConfiguration() is called with the real usage data.
//   It writes today's total minutes to the shared App Group, which the main
//   app's ScreenDriftStore reads to power the remaining-time ring.
// ============================================================

import DeviceActivity
import SwiftUI

private let appGroupID = "group.com.screendrift.shared"

// Must match the context defined in HistoryView.swift
extension DeviceActivityReport.Context {
    static let totalActivity = Self("totalActivity")
}

// MARK: - Extension Entry Point

@main
struct ScreenDriftReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityScene()
    }
}

// MARK: - Report Scene

struct TotalActivityScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    typealias Configuration = TotalUsageModel

    /// Runs every time the host app refreshes the DeviceActivityReport view.
    /// Iterates the raw activity data, totals today's usage, and persists
    /// it to the shared App Group so the main app can read it.
    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> TotalUsageModel {
        var totalDuration: TimeInterval = 0
        var appBreakdown: [AppUsageItem] = []

        for await activityData in data {
            for await segment in activityData.activitySegments {
                totalDuration += segment.totalActivityDuration

                // Collect per-app breakdown for the rendered view
                for await app in segment.applications {
                    let mins = Int(app.totalActivityDuration / 60)
                    guard mins > 0 else { continue }
                    appBreakdown.append(AppUsageItem(
                        token: app.application,
                        minutes: mins
                    ))
                }
            }
        }

        let totalMinutes = Int(totalDuration / 60)

        // Write to shared App Group so the main app can read today's total
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(totalMinutes, forKey: "autoTodayMinutes")
        defaults?.set(Date().timeIntervalSinceReferenceDate, forKey: "autoLastUpdated")

        return TotalUsageModel(
            totalMinutes: totalMinutes,
            apps: appBreakdown.sorted { $0.minutes > $1.minutes }.prefix(5).map { $0 }
        )
    }

    var content: (TotalUsageModel) -> some View {
        { model in TotalUsageView(model: model) }
    }
}

// MARK: - Models

struct TotalUsageModel {
    let totalMinutes: Int
    let apps: [AppUsageItem]
}

struct AppUsageItem {
    let token: ApplicationToken
    let minutes: Int
}

// MARK: - Rendered View (shown inside the DeviceActivityReport in HistoryView)

struct TotalUsageView: View {
    let model: TotalUsageModel

    var body: some View {
        VStack(spacing: 16) {
            // Total
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Usage")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(model.totalMinutes.extensionFormattedDuration)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }
                Spacer()
            }

            if !model.apps.isEmpty {
                Divider()

                // Top apps
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Apps")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    ForEach(model.apps.indices, id: \.self) { i in
                        let app = model.apps[i]
                        HStack {
                            Label {
                                Text("App \(i + 1)")
                                    .font(.subheadline)
                            } icon: {
                                // ApplicationToken renders via Apple's privacy-preserving UI
                                // Use a generic placeholder here; the real icon renders in the extension
                                Image(systemName: "app.fill")
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            Text(app.minutes.extensionFormattedDuration)
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

private extension Int {
    var extensionFormattedDuration: String {
        let h = self / 60
        let m = self % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}
