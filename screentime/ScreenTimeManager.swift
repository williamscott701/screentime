import Foundation
import FamilyControls
import SwiftUI

struct DailyUsage: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval  // seconds; 0 = no data
    let target: TimeInterval    // seconds

    var hasData: Bool { duration > 0 }
    var isOverTarget: Bool { hasData && duration > target }
    var durationHours: Double { duration / 3600 }

    var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var todayUsage: TimeInterval = 0
    @Published var weeklyData: [DailyUsage] = []
    @Published var dailyTargetHours: Double {
        didSet { UserDefaults.standard.set(dailyTargetHours, forKey: "dailyTargetHours") }
    }

    private let authCenter = AuthorizationCenter.shared

    var dailyTargetSeconds: TimeInterval { dailyTargetHours * 3600 }

    private init() {
        let saved = UserDefaults.standard.double(forKey: "dailyTargetHours")
        dailyTargetHours = saved > 0 ? saved : 4.0
        buildWeeklyPlaceholders()
        authorizationStatus = authCenter.authorizationStatus
        if authorizationStatus == .approved {
            loadScreenTimeData()
        }
    }

    func requestAuthorization() {
        Task {
            do {
                try await authCenter.requestAuthorization(for: .individual)
                authorizationStatus = authCenter.authorizationStatus
                // FIX: Trigger data load immediately after authorization is granted.
                // Without this call the UI stays stuck in the "Loading..." state forever.
                if authorizationStatus == .approved {
                    loadScreenTimeData()
                }
            } catch {
                isLoading = false
            }
        }
    }

    func loadScreenTimeData() {
        guard authorizationStatus == .approved else { return }
        isLoading = true
        Task {
            await fetchUsageData()
            isLoading = false
        }
    }

    // MARK: - Private

    private func buildWeeklyPlaceholders() {
        let calendar = Calendar.current
        let today = Date()
        weeklyData = (0..<7).reversed().compactMap { offset -> DailyUsage? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyUsage(date: date, duration: 0, target: dailyTargetSeconds)
        }
    }

    private func fetchUsageData() async {
        // Screen time data is delivered via a DeviceActivityReport App Extension.
        // That extension calls back into the main app with per-app usage totals.
        // Here we reset to empty placeholders; the extension populates real values.
        buildWeeklyPlaceholders()
        todayUsage = 0
    }
}
