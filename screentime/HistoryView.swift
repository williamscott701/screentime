import SwiftUI
import Charts
import DeviceActivity
import FamilyControls

// Context shared with the report extension (same raw string)
extension DeviceActivityReport.Context {
    static let totalActivity = Self("totalActivity")
}

struct HistoryView: View {
    @Environment(ScreenDriftStore.self) var store
    @Environment(\.openURL) private var openURL
    // Start the chart scrolled so the last 7 days are visible
    @State private var chartScrollDate: Date = Calendar.current.date(
        byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()
    @State private var isSyncing = false

    /// Last 30 days filter so we pull in a full month of historical Screen Time data.
    private static func last7DaysFilter() -> DeviceActivityFilter {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -29, to: Date())!)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: end)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    screenTimeSection
                    chartCard
                    summaryRow
                    logListSection
                }
                .padding()
            }
            .navigationTitle("History")
            .onAppear {
                // Refresh App Groups data when this tab appears (triggers extension)
                store.refreshFromAppGroups()
            }
        }
    }

    // MARK: - Screen Time Section (always shown, adapts to auth state)

    private var screenTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Screen Time").font(.headline)
                Spacer()
                syncBadge
            }

            if store.isAuthorized {
                // Apple's privacy-preserving report. When rendered, the extension's
                // makeConfiguration() runs and writes daily data to App Groups.
                DeviceActivityReport(.totalActivity, filter: Self.last7DaysFilter())
                    .frame(minHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .task {
                        isSyncing = true
                        // Extension runs async — wait for it to write dailyMinutes
                        try? await Task.sleep(for: .seconds(4))
                        store.refreshFromAppGroups()
                        isSyncing = false
                    }
            } else {
                permissionWarning
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var syncBadge: some View {
        if !store.isAuthorized {
            let isDenied = store.authorizationStatus == .denied
            Label(isDenied ? "Access Denied" : "No Access",
                  systemImage: isDenied ? "xmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.caption.bold())
                .foregroundStyle(.red)
        } else if isSyncing {
            HStack(spacing: 5) {
                ProgressView().scaleEffect(0.75)
                Text("Syncing…").font(.caption.bold()).foregroundStyle(.orange)
            }
        } else if let updated = store.autoLastUpdated {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                Text("Updated \(updated, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "clock").font(.caption).foregroundStyle(.secondary)
                Text("Waiting for data").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var permissionWarning: some View {
        let isDenied = store.authorizationStatus == .denied
        let color: Color = isDenied ? .red : .orange
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isDenied ? "xmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(color)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isDenied ? "Screen Time Access Denied" : "Permission Required")
                        .font(.subheadline.bold())
                    Text(isDenied
                         ? "Go to Settings → Privacy & Security → Screen Time and allow Screen Drift."
                         : "Grant access so Screen Drift can read your daily usage history from iOS Screen Time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                if isDenied {
                    if let url = URL(string: "app-settings:") { openURL(url) }
                } else {
                    Task { await store.requestAuthorization() }
                }
            } label: {
                Text(isDenied ? "Open Settings" : "Grant Access")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Chart (our custom chart using archived log data)

    private var last30Days: [(date: Date, minutes: Int)] {
        let calendar = Calendar.current
        return (0..<30).compactMap { daysAgo -> (Date, Int)? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { return nil }
            let mins = store.logs.first { calendar.isDate($0.date, inSameDayAs: date) }?.minutes ?? 0
            return (date, mins)
        }.reversed()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily Usage")
                    .font(.headline)
                Spacer()
                if isSyncing {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.7)
                        Text("Loading…").font(.caption2).foregroundStyle(.orange)
                    }
                } else {
                    Text("← scroll")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            let maxY = max(store.targetMinutes, last30Days.map(\.minutes).max() ?? 0, 60)

            Chart {
                RuleMark(y: .value("Target", store.targetMinutes))
                    .foregroundStyle(Color.accentColor.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Target")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }

                ForEach(last30Days, id: \.date) { item in
                    BarMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(barColor(for: item.minutes))
                    .cornerRadius(6)
                }
            }
            .chartYScale(domain: 0...maxY)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.narrow).day(), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let mins = value.as(Int.self) {
                            Text(mins == 0 ? "0" : "\(mins / 60)h")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 7 * 24 * 60 * 60)
            .chartScrollPosition(x: $chartScrollDate)
            .frame(height: 200)

            HStack(spacing: 16) {
                legendDot(color: .accentColor, label: "Within target")
                legendDot(color: .red, label: "Over target")
                legendDot(color: Color(.systemGray4), label: "No data")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func barColor(for minutes: Int) -> Color {
        if minutes == 0 { return Color(.systemGray4) }
        return minutes > store.targetMinutes ? .red.opacity(0.8) : .accentColor.opacity(0.85)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(label)
        }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 12) {
            if let avg7 = store.weeklyAverage {
                summaryCard(label: "7-day Avg", value: avg7.formattedDuration, icon: "calendar", color: .purple)
            }
            if let avg3 = store.last3DaysAverage {
                summaryCard(label: "3-day Avg", value: avg3.formattedDuration, icon: "clock", color: .orange)
            }
            if let suggested = store.suggestedTarget {
                summaryCard(label: "Suggested", value: suggested.formattedDuration, icon: "lightbulb.fill", color: .yellow)
            }
        }
    }

    private func summaryCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(.headline.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Log List

    private var logListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Log")
                    .font(.headline)
                Spacer()
                if store.isAuthorized {
                    Text("Auto-tracked")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            if store.logs.isEmpty {
                emptyState
            } else {
                ForEach(store.logs) { log in
                    logRow(log)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No data yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(store.isAuthorized
                 ? "Data will appear here after your first full day of tracking."
                 : "Grant access on the Today tab to start auto-tracking.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func logRow(_ log: DailyLog) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.subheadline.bold())
                Text(log.date, format: .dateTime.year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(log.minutes.formattedDuration)
                    .font(.headline)
                    .foregroundStyle(log.minutes > store.targetMinutes ? .red : .primary)

                HStack(spacing: 3) {
                    Image(systemName: log.minutes > store.targetMinutes ? "arrow.up" : "checkmark")
                        .font(.caption2)
                    Text(log.minutes > store.targetMinutes ? "Over target" : "Within target")
                        .font(.caption)
                }
                .foregroundStyle(log.minutes > store.targetMinutes ? .red : .green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button(role: .destructive) {
                store.deleteLog(log)
            } label: {
                Label("Delete Entry", systemImage: "trash")
            }
        }
    }
}

#Preview {
    HistoryView()
        .environment(ScreenDriftStore())
}
