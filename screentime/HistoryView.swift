import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var manager: ScreenTimeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    weekBreakdownCard
                    trendChartCard
                    dailyLogSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("History")
        }
    }

    // MARK: - This Week's Breakdown

    private var weekBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("This Week's Breakdown")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Live")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
            .padding()

            Color.clear.frame(height: 40)
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 7-day Trend Chart

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your 7-day Trend")
                    .font(.headline)
                Spacer()
                Text("Target")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            Chart {
                // One bar per day; use a tiny height for no-data days so the
                // category still appears on the X axis.
                ForEach(manager.weeklyData) { day in
                    BarMark(
                        x: .value("Day", day.dayAbbreviation),
                        y: .value("Hours", day.hasData ? day.durationHours : 0.05)
                    )
                    .foregroundStyle(barColor(for: day))
                    .cornerRadius(4)
                }

                // Dashed target line
                RuleMark(y: .value("Target", manager.dailyTargetHours))
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
            }
            .chartYAxis {
                AxisMarks(values: .stride(by: 1)) { value in
                    AxisGridLine()
                    if let h = value.as(Int.self) {
                        AxisValueLabel { Text("\(h)h") }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel() }
            }
            .frame(height: 200)

            // Legend
            HStack(spacing: 16) {
                legendDot(color: .blue, label: "Within target")
                legendDot(color: .red, label: "Over target")
                legendDot(color: Color(.systemGray4), label: "No data")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func barColor(for day: DailyUsage) -> Color {
        guard day.hasData else { return Color(.systemGray4) }
        return day.isOverTarget ? .red : .blue
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Daily Log

    private var dailyLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Log")
                    .font(.title2)
                    .bold()
                Spacer()
                Text("Auto-tracked")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }

            let logDays = manager.weeklyData.filter { $0.hasData }.reversed()
            if logDays.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(logDays)) { day in
                    dailyLogRow(day: day)
                    Divider()
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func dailyLogRow(day: DailyUsage) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.date, style: .date)
                    .font(.subheadline)
                    .bold()
                Text(formatDuration(day.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: day.isOverTarget ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(day.isOverTarget ? .red : .green)
        }
        .padding(.vertical, 2)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }
}
