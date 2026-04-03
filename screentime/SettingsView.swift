import SwiftUI

struct SettingsView: View {
    @Environment(ScreenDriftStore.self) var store
    @Environment(\.openURL) private var openURL

    private let supportEmail = "support@screendrift.app"

    var body: some View {
        NavigationStack {
            List {
                tipsSection
                supportSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        Section("Tips for Reducing Screen Time") {
            TipRow(icon: "moon.fill", color: .indigo,
                   title: "Set Downtime",
                   description: "In Settings → Screen Time → Downtime, schedule offline hours during sleep or meals so apps lock automatically.")
            TipRow(icon: "app.badge.fill", color: .red,
                   title: "Use App Limits",
                   description: "Cap time on specific categories like Social or Entertainment directly in Settings → Screen Time → App Limits.")
            TipRow(icon: "bell.slash.fill", color: .gray,
                   title: "Silence Notifications",
                   description: "Focus modes let you silence distracting apps during work, sleep, or family time. Find them in Control Center.")
            TipRow(icon: "figure.walk", color: .green,
                   title: "Replace the Habit Loop",
                   description: "When you reach for your phone, try a short walk, stretch, or glass of water instead. Small swaps compound over time.")
            TipRow(icon: "circle.lefthalf.filled", color: .blue,
                   title: "Try Greyscale Mode",
                   description: "Settings → Accessibility → Display & Text Size → Colour Filters → Greyscale makes the screen far less visually appealing.")
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section("Support") {
            SupportRow(icon: "ladybug.fill", color: .red, title: "Report a Bug") {
                openMail(subject: "Bug Report — Screen Drift App")
            }
            SupportRow(icon: "lightbulb.fill", color: .yellow, title: "Request a Feature") {
                openMail(subject: "Feature Request — Screen Drift App")
            }
            SupportRow(icon: "star.fill", color: .orange, title: "Rate the App") {
                openMail(subject: "App Review — Screen Drift App")
            }
            SupportRow(icon: "envelope.fill", color: .blue, title: "General Feedback") {
                openMail(subject: "Feedback — Screen Drift App")
            }
        }
    }

    private func openMail(subject: String) {
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        if let url = URL(string: "mailto:\(supportEmail)?subject=\(encoded)") {
            openURL(url)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Data stored")
                Spacer()
                Text("On device only").foregroundStyle(.secondary)
            }
            HStack {
                Text("Logs kept for")
                Spacer()
                Text("90 days").foregroundStyle(.secondary)
            }
            HStack {
                Text("Suggestion method")
                Spacer()
                Text("7-day avg × 80%").foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - TipRow

struct TipRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SupportRow

struct SupportRow: View {
    let icon: String
    let color: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(color).frame(width: 24)
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    SettingsView()
        .environment(ScreenDriftStore())
}
