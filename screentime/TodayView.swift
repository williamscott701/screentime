import SwiftUI

struct TodayView: View {
    @EnvironmentObject var manager: ScreenTimeManager
    @State private var showTargetSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    targetCard
                    progressSection
                    statsRow
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // Reserved for focus / app-blocking configuration
                    } label: {
                        Image(systemName: "scope")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                switch manager.authorizationStatus {
                case .notDetermined:
                    manager.requestAuthorization()
                case .approved:
                    manager.loadScreenTimeData()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Subviews

    private var targetCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatHours(manager.dailyTargetHours))
                    .font(.title2)
                    .bold()
            }
            Spacer()
            Button {
                showTargetSheet = true
            } label: {
                Label("Change", systemImage: "pencil")
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(.systemBackground))
                    .clipShape(Capsule())
            }
            .tint(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showTargetSheet) {
            TargetPickerView()
                .environmentObject(manager)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 18)
                    .frame(width: 220, height: 220)

                if manager.isLoading || manager.authorizationStatus != .approved {
                    loadingContent
                } else {
                    filledRing
                }
            }

            if manager.isLoading || manager.authorizationStatus != .approved {
                Text("Checking your screen time...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var loadingContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var filledRing: some View {
        let progress = manager.dailyTargetSeconds > 0
            ? min(manager.todayUsage / manager.dailyTargetSeconds, 1.0)
            : 0.0
        let ringColor: Color = progress >= 1.0 ? .red : .blue

        return ZStack {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(formatDuration(manager.todayUsage))
                    .font(.largeTitle)
                    .bold()
                Text("of \(formatHours(manager.dailyTargetHours))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "hourglass.bottomhalf.filled",
                iconColor: .green,
                value: manager.isLoading ? "-" : formatDuration(manager.todayUsage),
                label: "Used"
            )
            statCard(
                icon: "target",
                iconColor: .blue,
                value: formatHours(manager.dailyTargetHours),
                label: "Target"
            )
        }
    }

    private func statCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.title3)
                .bold()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Formatters

    private func formatHours(_ hours: Double) -> String {
        hours == hours.rounded() ? "\(Int(hours))h" : String(format: "%.1fh", hours)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }
}
