import Foundation
import SwiftUI
import Observation
import FamilyControls

// MARK: - Data Model

struct DailyLog: Codable, Identifiable {
    let id: UUID
    let date: Date
    var minutes: Int

    init(id: UUID = UUID(), date: Date = Date(), minutes: Int) {
        self.id = id
        self.date = date
        self.minutes = minutes
    }
}

extension Int {
    /// Formats minutes as "Xh Ym", "Xh", or "Ym"
    var formattedDuration: String {
        let h = self / 60
        let m = self % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

// MARK: - Store

@Observable
class ScreenDriftStore {
    static let appGroupID = "group.com.screendrift.shared"

    // Persisted via App Groups
    var logs: [DailyLog] = []
    var targetMinutes: Int = 240

    // Auto-populated by the DeviceActivity report extension
    // The extension writes this key when it processes today's data
    var autoTodayMinutes: Int = 0
    var autoLastUpdated: Date?

    // FamilyControls authorization state
    var authorizationStatus: AuthorizationStatus = .notDetermined

    private let defaults: UserDefaults

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        load()
        refreshFromAppGroups()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        // Check current status first
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        guard authorizationStatus != .approved else { return }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    // MARK: - App Groups sync (written by DeviceActivity report extension)

    /// Call this when the app becomes active or the report view loads.
    func refreshFromAppGroups() {
        let newMinutes = defaults.integer(forKey: "autoTodayMinutes")
        if newMinutes > 0 {
            autoTodayMinutes = newMinutes
            if let ts = defaults.object(forKey: "autoLastUpdated") as? Double {
                autoLastUpdated = Date(timeIntervalSinceReferenceDate: ts)
            }
            archiveTodayIfNeeded(minutes: newMinutes)
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    /// Archives today's auto-read value into the logs array for history + suggestion calculations.
    private func archiveTodayIfNeeded(minutes: Int) {
        guard minutes > 0 else { return }
        if let index = logs.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            if logs[index].minutes != minutes {
                logs[index].minutes = minutes
                save()
            }
        } else {
            logs.insert(DailyLog(date: Date(), minutes: minutes), at: 0)
            logs = Array(logs.prefix(90))
            save()
        }
    }

    // MARK: - Persistence

    private func load() {
        let saved = defaults.integer(forKey: "targetMinutes")
        targetMinutes = saved > 0 ? saved : 240

        if let data = defaults.data(forKey: "logs"),
           let decoded = try? JSONDecoder().decode([DailyLog].self, from: data) {
            logs = decoded.sorted { $0.date > $1.date }
        }
    }

    func save() {
        defaults.set(targetMinutes, forKey: "targetMinutes")
        if let encoded = try? JSONEncoder().encode(logs) {
            defaults.set(encoded, forKey: "logs")
        }
    }

    // MARK: - Today

    /// Today's usage: prefers auto-read from DeviceActivity, falls back to manual log
    var todayMinutes: Int {
        if autoTodayMinutes > 0 { return autoTodayMinutes }
        return todayLog?.minutes ?? 0
    }

    var todayLog: DailyLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }

    var remainingMinutes: Int { max(0, targetMinutes - todayMinutes) }

    var progressFraction: Double {
        guard targetMinutes > 0 else { return 0 }
        return min(1.0, Double(todayMinutes) / Double(targetMinutes))
    }

    var isOverTarget: Bool { todayMinutes > targetMinutes }

    // MARK: - History & Averages

    var last3DaysLogs: [DailyLog] { recentLogs(within: 1...3) }

    var last3DaysAverage: Int? {
        let days = last3DaysLogs
        guard !days.isEmpty else { return nil }
        return days.reduce(0) { $0 + $1.minutes } / days.count
    }

    /// 20% less than weekly average (falls back to 3-day) — achievable, not drastic
    var suggestedTarget: Int? {
        guard let avg = weeklyAverage ?? last3DaysAverage else { return nil }
        return max(30, Int(Double(avg) * 0.8))
    }

    var weeklyAverage: Int? {
        let days = recentLogs(within: 1...7)
        guard !days.isEmpty else { return nil }
        return days.reduce(0) { $0 + $1.minutes } / days.count
    }

    var streak: Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        var count = 0

        if todayMinutes > 0 && todayMinutes <= targetMinutes {
            count += 1
        }

        var daysAgo = 1
        while true {
            guard let checkDate = calendar.date(byAdding: .day, value: -daysAgo, to: todayStart) else { break }
            let dayLog = logs.first { calendar.isDate($0.date, inSameDayAs: checkDate) }
            guard let log = dayLog, log.minutes > 0, log.minutes <= targetMinutes else { break }
            count += 1
            daysAgo += 1
        }
        return count
    }

    // MARK: - Manual log (fallback / override when not authorized)

    func logToday(minutes: Int) {
        if let index = logs.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            logs[index].minutes = minutes
        } else {
            logs.insert(DailyLog(date: Date(), minutes: minutes), at: 0)
        }
        logs = Array(logs.prefix(90))
        save()
    }

    func deleteLog(_ log: DailyLog) {
        logs.removeAll { $0.id == log.id }
        save()
    }

    // MARK: - Private

    private func recentLogs(within range: ClosedRange<Int>) -> [DailyLog] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return logs.filter { log in
            let logStart = calendar.startOfDay(for: log.date)
            let diff = calendar.dateComponents([.day], from: logStart, to: todayStart).day ?? 0
            return range.contains(diff)
        }
    }
}
