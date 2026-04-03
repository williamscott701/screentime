import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: ScreenTimeManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily Target") {
                    HStack {
                        Text("Target")
                        Spacer()
                        Text(formatHours(manager.dailyTargetHours))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $manager.dailyTargetHours, in: 0.5...12, step: 0.5)
                }

                Section("Screen Time Access") {
                    HStack {
                        Text("Authorization")
                        Spacer()
                        Text(statusLabel)
                            .foregroundStyle(statusColor)
                    }

                    if manager.authorizationStatus != .approved {
                        Button("Request Authorization") {
                            manager.requestAuthorization()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var statusLabel: String {
        switch manager.authorizationStatus {
        case .approved:       return "Approved"
        case .denied:         return "Denied"
        case .notDetermined:  return "Not Set"
        @unknown default:     return "Unknown"
        }
    }

    private var statusColor: Color {
        switch manager.authorizationStatus {
        case .approved:       return .green
        case .denied:         return .red
        default:              return .secondary
        }
    }

    private func formatHours(_ hours: Double) -> String {
        hours == hours.rounded() ? "\(Int(hours))h" : String(format: "%.1fh", hours)
    }
}
