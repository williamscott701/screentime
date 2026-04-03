import SwiftUI
import Charts
import DeviceActivity

// Context shared with the report extension (same raw string)
extension DeviceActivityReport.Context {
    static let totalActivity = Self("totalActivity")
}

struct HistoryView: View {
    @Environment(ScreenDriftStore.self) var store
    @State private var reportFilter = Self.todayFilter()

    private static func todayFilter() -> DeviceActivityFilter {
        let today = Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
        return DeviceActivityFilter(segment: .daily(during: today))
    }

    private static func weekFilter() -> DeviceActivityFilter {
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now) ?? DateInterval()
        return DeviceActivityFilter(segment: .daily(during: week))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if store.isAuthorized {
                        autoReportSection
                    }

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

    // MARK: - Auto Report (DeviceActivityReport embedded view)

    private var autoReportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week's Breakdown")
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text("Live")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }

            // Apple's built-in report — rendered by the DeviceActivity report extension.
            // When this view renders, the extension's makeConfiguration() runs and
            // writes updated data to App Groups.
            DeviceActivityReport(.totalActivity, filter: Self.weekFilter())
                .frame(minHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Chart (our custom chart using archived log data)

    private var last7Days: [(date: Date, minutes: Int)] {
        let calendar = Calendar.current
        return (0..<7).compactMap { daysAgo -> (Date, Int)? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { return nil }
            let mins = store.logs.first { calendar.isDate($0.date, inSameDayAs: date) }?.minutes ?? 0
            return (date, mins)
        }.reversed()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(store.isAuthorized ? "Your 7-day Trend" : "Last 7 Days")
                    .font(.headline)
                Spacer()
                if !store.isAuthorized {
                    Text("Manual data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let maxY = max(store.targetMinutes, last7Days.map(\.minutes).max() ?? 0, 60)

            Chart {
                RuleMark(y: .value("Target", store.targetMinutes))
                    .foregroundStyle(Color.accentColor.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Target")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }

                ForEach(last7Days, id: \.date) { item in
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
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
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
