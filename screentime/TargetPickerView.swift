import SwiftUI

struct TargetPickerView: View {
    @EnvironmentObject var manager: ScreenTimeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text(formatHours(manager.dailyTargetHours))
                    .font(.system(size: 72, weight: .bold))
                    .monospacedDigit()

                VStack(spacing: 8) {
                    Slider(value: $manager.dailyTargetHours, in: 0.5...12, step: 0.5)
                    HStack {
                        Text("30m").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("12h").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Text("Set your daily screen time target")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Daily Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }

    private func formatHours(_ hours: Double) -> String {
        hours == hours.rounded() ? "\(Int(hours))h" : String(format: "%.1fh", hours)
    }
}
