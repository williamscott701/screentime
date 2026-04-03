// ScreenDriftWidget.swift
//
// ============================================================
// HOW TO ADD THE WIDGET:
//
// 1. In Xcode: File → New → Target → Widget Extension
//    - Product Name: ScreenDriftWidgetExtension
//    - Uncheck "Include Configuration App Intent"
//
// 2. Delete the placeholder Swift files Xcode generates
//    in the new ScreenDriftWidgetExtension group, then drag
//    THIS file into that group.
//
// 3. Add App Groups to BOTH targets:
//    - Select "screentime" target → Signing & Capabilities
//      → + Capability → App Groups → add:
//        group.com.screendrift.shared
//    - Repeat for "ScreenDriftWidgetExtension" target
//
// 4. Build & run. Long-press home screen → Edit → + widget
//    → search "Screen Drift".
// ============================================================

import WidgetKit
import SwiftUI

// MARK: - Shared Constants

private let appGroupID = "group.com.screendrift.shared"

// MARK: - Local model (mirrors DailyLog exactly for Codable compatibility)

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

    var progressFraction: Double {
        guard targetMinutes > 0 else { return 0 }
        return min(1.0, Double(usedMinutes) / Double(targetMinutes))
    }

    var isOverTarget: Bool { usedMinutes > targetMinutes }

    var progressColor: Color {
        if isOverTarget { return .red }
        if progressFraction >= 0.8 { return .orange }
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
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry() -> ScreenDriftEntry {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let saved = defaults.integer(forKey: "targetMinutes")
        let target = saved > 0 ? saved : 240

        var used = 0
        if let data = defaults.data(forKey: "logs"),
           let logs = try? JSONDecoder().decode([WidgetDailyLog].self, from: data) {
            used = logs.first { Calendar.current.isDateInToday($0.date) }?.minutes ?? 0
        }

        return ScreenDriftEntry(date: Date(), usedMinutes: used, targetMinutes: target)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: ScreenDriftEntry

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: entry.progressFraction)
                    .stroke(entry.progressColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(entry.isOverTarget ? "OVER" : entry.remainingMinutes.formattedDuration)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(entry.isOverTarget ? .red : .primary)
                    if !entry.isOverTarget {
                        Text("left")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 76, height: 76)

            Text("Screen Drift")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: ScreenDriftEntry

    var body: some View {
        HStack(spacing: 20) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: entry.progressFraction)
                    .stroke(entry.progressColor,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(entry.isOverTarget ? "OVER" : entry.remainingMinutes.formattedDuration)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(entry.isOverTarget ? .red : .primary)
                    Text(entry.isOverTarget ? "limit" : "remaining")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            // Stats
            VStack(alignment: .leading, spacing: 10) {
                Text("Screen Drift")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 5) {
                    widgetStat(label: "Used", value: entry.usedMinutes.formattedDuration,
                               color: entry.progressColor)
                    widgetStat(label: "Target", value: entry.targetMinutes.formattedDuration,
                               color: .accentColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(entry.progressColor)
                            .frame(width: geo.size.width * entry.progressFraction)
                    }
                }
                .frame(height: 6)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
    }

    private func widgetStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label + ":").font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.bold())
        }
    }
}

// MARK: - Entry View

struct ScreenDriftWidgetEntryView: View {
    let entry: ScreenDriftEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

@main
struct ScreenDriftWidget: Widget {
    let kind = "ScreenDriftWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScreenDriftProvider()) { entry in
            ScreenDriftWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Screen Drift")
        .description("See your remaining screen time at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
