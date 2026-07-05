import WidgetKit
import SwiftUI

// MARK: - Shared Constants

private let appGroupID = "group.com.screendrift.shared"

private struct WidgetDailyLog: Codable {
    let id: UUID
    let date: Date
    var minutes: Int
}

private extension Int {
    var formattedDuration: String {
        let h = self / 60
        let m = self % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

// MARK: - Timeline Entry

struct ScreenDriftEntry: TimelineEntry {
    let date: Date
    let usedMinutes: Int
    let targetMinutes: Int

    var remainingMinutes: Int { max(0, targetMinutes - usedMinutes) }
    var countdownEndDate: Date { date.addingTimeInterval(TimeInterval(remainingMinutes * 60)) }

    /// 0→1 as usage increases (used for the ring arc)
    var usedFraction: Double {
        guard targetMinutes > 0 else { return 0 }
        return min(1.0, Double(usedMinutes) / Double(targetMinutes))
    }

    /// 1→0 as time runs out (used for the draining progress bar)
    var remainingFraction: Double {
        guard targetMinutes > 0 else { return 0 }
        return max(0.0, 1.0 - usedFraction)
    }

    var progressFraction: Double { usedFraction }   // kept for ring backward compat

    var isOverTarget: Bool { usedMinutes > targetMinutes }

    var progressColor: Color {
        if isOverTarget { return .red }
        if usedFraction >= 0.8 { return .orange }
        return .green
    }

    static var placeholder: ScreenDriftEntry {
        ScreenDriftEntry(date: Date(), usedMinutes: 150, targetMinutes: 240)
    }
}

// MARK: - Provider

struct ScreenDriftProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScreenDriftEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (ScreenDriftEntry) -> Void) {
        completion(context.isPreview ? .placeholder : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScreenDriftEntry>) -> Void) {
        let entry = makeEntry()
        // Refresh every 15 minutes with real DeviceActivity data — no simulated increments
        // so the widget and app always show the same value.
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry() -> ScreenDriftEntry {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let saved = defaults.integer(forKey: "targetMinutes")
        let target = saved > 0 ? saved : 240

        let autoMinutes = defaults.integer(forKey: "autoTodayMinutes")
        var used = autoMinutes

        if used == 0,
           let data = defaults.data(forKey: "logs"),
           let logs = try? JSONDecoder().decode([WidgetDailyLog].self, from: data) {
            used = logs.first { Calendar.current.isDateInToday($0.date) }?.minutes ?? 0
        }

        return ScreenDriftEntry(date: Date(), usedMinutes: used, targetMinutes: target)
    }
}

// MARK: - Helpers

private func overtimeView(entry: ScreenDriftEntry, fontSize: CGFloat) -> some View {
    let overtimeSeconds = TimeInterval((entry.usedMinutes - entry.targetMinutes) * 60)
    let overtimeStart = entry.date.addingTimeInterval(-overtimeSeconds)
    return VStack(spacing: 1) {
        Text("+")
            .font(.system(size: fontSize * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(.red)
        Text(timerInterval: overtimeStart...overtimeStart.addingTimeInterval(86400),
             countsDown: false)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.red)
            .minimumScaleFactor(0.5)
        Text("over limit")
            .font(.system(size: fontSize * 0.55, weight: .medium))
            .foregroundStyle(.red.opacity(0.7))
    }
}

// MARK: - Style 1: Ring (Small)

struct RingSmallView: View {
    let entry: ScreenDriftEntry

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(entry.progressFraction, 1.0))
                    .stroke(entry.progressColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    if entry.isOverTarget {
                        overtimeView(entry: entry, fontSize: 11)
                    } else {
                        Text(timerInterval: entry.date...entry.countdownEndDate, countsDown: true)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(entry.progressColor)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.center)
                        Text("left")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(4)
            }
            .frame(width: 90, height: 90)

            Text("Screen Drift")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(8)
    }
}

// MARK: - Style 1: Ring (Medium)

struct RingMediumView: View {
    let entry: ScreenDriftEntry

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: entry.progressFraction)
                    .stroke(entry.progressColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    if entry.isOverTarget {
                        overtimeView(entry: entry, fontSize: 13)
                    } else {
                        Text(timerInterval: entry.date...entry.countdownEndDate, countsDown: true)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(entry.progressColor)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.center)
                        Text("remaining")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(6)
            }
            .frame(width: 90, height: 90)

            VStack(alignment: .leading, spacing: 8) {
                Text("Screen Drift")
                    .font(.headline)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 4) {
                    statRow(dot: entry.progressColor,
                            label: "Used", value: entry.usedMinutes.formattedDuration)
                    statRow(dot: .blue,
                            label: "Target", value: entry.targetMinutes.formattedDuration)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.1))
                        Capsule()
                            .fill(entry.progressColor)
                            .frame(width: geo.size.width * entry.remainingFraction)
                    }
                }
                .frame(height: 5)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private func statRow(dot: Color, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(label + ":").font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.bold())
        }
    }
}

// MARK: - Minimal countdown block (reused across sizes)

private func minimalCountdown(entry: ScreenDriftEntry, fontSize: CGFloat) -> some View {
    Group {
        if entry.isOverTarget {
            let overtimeSeconds = TimeInterval((entry.usedMinutes - entry.targetMinutes) * 60)
            let overtimeStart = entry.date.addingTimeInterval(-overtimeSeconds)
            VStack(spacing: 2) {
                Text(timerInterval: overtimeStart...overtimeStart.addingTimeInterval(86400),
                     countsDown: false)
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.red)
                    .minimumScaleFactor(0.4)
                    .multilineTextAlignment(.center)
                Text("over limit")
                    .font(.system(size: fontSize * 0.28, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.7))
            }
        } else {
            VStack(spacing: 2) {
                Text(timerInterval: entry.date...entry.countdownEndDate, countsDown: true)
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(entry.progressColor)
                    .minimumScaleFactor(0.4)
                    .multilineTextAlignment(.center)
                Text("remaining")
                    .font(.system(size: fontSize * 0.28, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func progressBar(entry: ScreenDriftEntry, height: CGFloat = 4) -> some View {
    GeometryReader { geo in
        ZStack(alignment: .leading) {
            Capsule().fill(Color.primary.opacity(0.08))
            Capsule()
                .fill(entry.progressColor)
                .frame(width: geo.size.width * entry.remainingFraction)
        }
    }
    .frame(height: height)
}

// MARK: - Style 2: Minimal (Small)

struct MinimalSmallView: View {
    let entry: ScreenDriftEntry

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            minimalCountdown(entry: entry, fontSize: 30)
            Spacer()
            progressBar(entry: entry, height: 4)
        }
        .padding(14)
    }
}

// MARK: - Style 2: Minimal (Medium) — rectangle

struct MinimalMediumView: View {
    let entry: ScreenDriftEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left: big countdown
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.isOverTarget ? "OVER LIMIT" : "REMAINING")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                minimalCountdown(entry: entry, fontSize: 36)

                progressBar(entry: entry, height: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(width: 1)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)

            // Right: stats
            VStack(alignment: .trailing, spacing: 8) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("USED").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                    Text(entry.usedMinutes.formattedDuration).font(.system(size: 14, weight: .bold))
                        .foregroundStyle(entry.progressColor)
                }
                VStack(alignment: .trailing, spacing: 1) {
                    Text("TARGET").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                    Text(entry.targetMinutes.formattedDuration).font(.system(size: 14, weight: .bold))
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Style 2: Minimal (Large)

struct MinimalLargeView: View {
    let entry: ScreenDriftEntry

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(entry.isOverTarget ? "OVER LIMIT" : "REMAINING TODAY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            Spacer().frame(height: 8)
            minimalCountdown(entry: entry, fontSize: 64)
            Spacer()
            progressBar(entry: entry, height: 6)
                .padding(.bottom, 12)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("USED").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                    Text(entry.usedMinutes.formattedDuration).font(.system(size: 15, weight: .bold))
                        .foregroundStyle(entry.progressColor)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("SCREEN DRIFT").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                    Text("\(Int(entry.remainingFraction * 100))%")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(entry.progressColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TARGET").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                    Text(entry.targetMinutes.formattedDuration).font(.system(size: 15, weight: .bold))
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Ring Widget (small + medium)

struct ScreenDriftRingWidgetEntryView: View {
    let entry: ScreenDriftEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            RingSmallView(entry: entry)
        default:
            RingMediumView(entry: entry)
        }
    }
}

struct ScreenDriftRingWidget: Widget {
    let kind = "ScreenDriftRingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScreenDriftProvider()) { entry in
            ScreenDriftRingWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Screen Drift — Ring")
        .description("Progress ring with live countdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Minimal Widget (small + large)

struct ScreenDriftMinimalWidgetEntryView: View {
    let entry: ScreenDriftEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            MinimalSmallView(entry: entry)
        case .systemMedium:
            MinimalMediumView(entry: entry)
        default:
            MinimalLargeView(entry: entry)
        }
    }
}

struct ScreenDriftMinimalWidget: Widget {
    let kind = "ScreenDriftMinimalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScreenDriftProvider()) { entry in
            ScreenDriftMinimalWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Screen Drift — Minimal")
        .description("Big bold countdown with no distractions.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
