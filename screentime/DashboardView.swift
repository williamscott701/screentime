import SwiftUI
import FamilyControls

struct DashboardView: View {
    @Environment(ScreenDriftStore.self) var store
    @Environment(\.openURL) private var openURL
    @State private var showManualLog = false
    @State private var showTargetSheet = false

    // MARK: - Computed

    private var progressColor: Color {
        if store.isOverTarget { return .red }
        if store.progressFraction >= 0.8 { return .orange }
        return .green
    }

    private var statusMessage: (text: String, color: Color) {
        guard store.todayMinutes > 0 else {
            return (store.isAuthorized
                    ? "No usage logged yet today"
                    : "Authorize to track usage automatically",
                    .secondary)
        }
        if store.isOverTarget {
            let over = store.todayMinutes - store.targetMinutes
            return ("You're \(over.formattedDuration) over your limit today", .red)
        }
        if store.progressFraction < 0.5 { return ("You're doing great — well within your limit!", .green) }
        if store.progressFraction < 0.8 { return ("On track. Keep it up!", .primary) }
        return ("Approaching your limit. Consider a break.", .orange)
    }

    private var suggestionAvg: Int? { store.weeklyAverage ?? store.last3DaysAverage }
    private var suggestionLabel: String { store.weeklyAverage != nil ? "7-day avg" : "3-day avg" }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !store.isAuthorized {
                        authorizationCard
                    }

                    targetSection

                    if store.targetMinutes > 0 {
                        progressRingSection

                        Text(statusMessage.text)
                            .font(.subheadline)
                            .foregroundStyle(statusMessage.color)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        statsRow
                        infoSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Today")
            .toolbar {
                if store.streak >= 2 {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").foregroundStyle(.orange)
                            Text("\(store.streak)").font(.subheadline.bold())
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showManualLog = true } label: {
                        Image(systemName: "pencil.circle").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showManualLog) {
            LogTimeView().environment(store)
        }
        .sheet(isPresented: $showTargetSheet) {
            SetTargetView().environment(store)
        }
        .onAppear { store.refreshFromAppGroups() }
    }

    // MARK: - Authorization Card

    private var authorizationCard: some View {
        let isDenied = store.authorizationStatus == .denied
        let color: Color = isDenied ? .orange : .blue
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isDenied ? "exclamationmark.shield.fill" : "lock.shield.fill")
                    .foregroundStyle(color)
                    .font(.title3)
                Text(isDenied ? "Access Denied" : "Enable Auto-Tracking")
                    .font(.headline)
            }
            Text(isDenied
                 ? "Screen Drift needs Family Controls access. Go to Settings → Screen Time to re-enable it."
                 : "Allow access so Screen Drift can read your daily screen time automatically — no manual logging needed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                if isDenied {
                    if let url = URL(string: "app-settings:") { openURL(url) }
                } else {
                    Task { await store.requestAuthorization() }
                }
            } label: {
                Label(isDenied ? "Open Settings" : "Grant Access",
                      systemImage: isDenied ? "gear" : "checkmark.shield.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Target Section (main feature)

    private var targetSection: some View {
        VStack(spacing: 12) {
            // Suggestion card — shown when history data exists and suggestion differs from current target
            if let avg = suggestionAvg, let suggested = store.suggestedTarget,
               suggested != store.targetMinutes {
                suggestionCard(suggested: suggested, avg: avg)
            }

            // Current target row — shown when a target is already set
            if store.targetMinutes > 0 {
                currentTargetCard
            } else if suggestionAvg == nil {
                // No history and no target yet
                setTargetPromptCard
            }
        }
    }

    private func suggestionCard(suggested: Int, avg: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text("Suggested Target").font(.headline)
                Spacer()
            }
            Text("Your \(suggestionLabel) is **\(avg.formattedDuration)**. Reducing by 20% gives **\(suggested.formattedDuration)** — a realistic daily goal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    store.targetMinutes = suggested
                    store.save()
                } label: {
                    Label("Set \(suggested.formattedDuration)", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button { showTargetSheet = true } label: {
                    Text("Set Manually")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
    }

    private var currentTargetCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(store.targetMinutes.formattedDuration)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            Spacer()
            Button { showTargetSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                    Text("Change")
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
                .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var setTargetPromptCard: some View {
        Button { showTargetSheet = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Daily Target").font(.headline)
                    Text("Choose your screen time goal to get started")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Progress Ring

    private var progressRingSection: some View {
        ZStack {
            Circle().stroke(Color(.systemGray5), lineWidth: 22)
            Circle()
                .trim(from: 0, to: store.progressFraction)
                .stroke(progressColor, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: store.progressFraction)
            VStack(spacing: 4) {
                if store.isOverTarget {
                    let over = store.todayMinutes - store.targetMinutes
                    Text("+\(over.formattedDuration)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                    Text("over limit").font(.subheadline).foregroundStyle(.secondary)
                } else if store.todayMinutes == 0 {
                    Image(systemName: store.isAuthorized ? "checkmark.circle" : "lock")
                        .font(.system(size: 40)).foregroundStyle(.secondary)
                    Text(store.isAuthorized ? "0m used" : "Not tracking")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(store.remainingMinutes.formattedDuration)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("remaining today").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 230, height: 230)
        .padding(.top, 8)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(title: "Used",
                     value: store.todayMinutes > 0 ? store.todayMinutes.formattedDuration : "–",
                     icon: "hourglass", color: progressColor)
            statCard(title: "Remaining",
                     value: store.isOverTarget ? "0m" : store.remainingMinutes.formattedDuration,
                     icon: "timer", color: store.isOverTarget ? .red : progressColor)
            statCard(title: "Target", value: store.targetMinutes.formattedDuration,
                     icon: "target", color: .blue)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            Text(value).font(.headline.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 10) {
            if store.isAuthorized, let updated = store.autoLastUpdated {
                InfoCard(icon: "checkmark.circle.fill", color: .green,
                         title: "Auto-tracking active",
                         description: "Usage updated \(updated.formatted(.relative(presentation: .named))). Data refreshes each time you open the app.")
            } else if !store.isAuthorized {
                InfoCard(icon: "info.circle.fill", color: .blue,
                         title: "How auto-tracking works",
                         description: "After you grant access, Screen Drift reads your total daily screen time directly from iOS — no manual logging. Your data stays on your device.")
            }
            if store.isOverTarget {
                InfoCard(icon: "moon.fill", color: .indigo,
                         title: "Over your limit — try this",
                         description: "Enable a Focus mode, put your phone face-down, or leave it in another room. 30 min less per day = 3.5 hrs saved per week.")
            } else if store.progressFraction >= 0.8 && store.todayMinutes > 0 {
                InfoCard(icon: "hand.raised.fill", color: .orange,
                         title: "Approaching your limit",
                         description: "You're close. Try setting your phone aside and doing something offline for a while.")
            }
            if store.streak >= 3 {
                InfoCard(icon: "flame.fill", color: .orange,
                         title: "\(store.streak)-day streak!",
                         description: "You've stayed within your target for \(store.streak) days in a row. Keep the momentum going!")
            }
        }
    }
}

// MARK: - InfoCard

struct InfoCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).font(.title3).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - SetTargetView

struct SetTargetView: View {
    @Environment(ScreenDriftStore.self) var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHours = 4
    @State private var selectedMins = 0

    private let minuteSteps = [0, 15, 30, 45]
    private var totalMinutes: Int { selectedHours * 60 + selectedMins }
    private var hasChanged: Bool { totalMinutes != store.targetMinutes }

    private var comparison: (text: String, color: Color)? {
        guard let suggested = store.suggestedTarget, totalMinutes > 0 else { return nil }
        let diff = totalMinutes - suggested
        if diff == 0 { return ("Matches suggestion", .green) }
        if diff > 0  { return ("\(diff.formattedDuration) above suggestion", .orange) }
        return ("\((-diff).formattedDuration) below suggestion", .blue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(totalMinutes > 0 ? totalMinutes.formattedDuration : "–")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(totalMinutes > 0 ? .primary : .secondary)
                    .padding(.top, 28)
                    .animation(.easeInOut(duration: 0.15), value: totalMinutes)

                if let comp = comparison {
                    Text(comp.text)
                        .font(.subheadline.bold())
                        .foregroundStyle(comp.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(comp.color.opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.top, 10)
                        .transition(.opacity)
                        .animation(.easeInOut, value: totalMinutes)
                } else {
                    Spacer().frame(height: 38)
                }

                HStack(spacing: 0) {
                    Picker("Hours", selection: $selectedHours) {
                        ForEach(0..<25) { Text("\($0)h").tag($0) }
                    }
                    .pickerStyle(.wheel).frame(maxWidth: .infinity)

                    Picker("Minutes", selection: $selectedMins) {
                        ForEach(minuteSteps, id: \.self) { Text("\($0)m").tag($0) }
                    }
                    .pickerStyle(.wheel).frame(maxWidth: .infinity)
                }
                .padding(.top, 4)

                Spacer()

                // Save button only appears when value has changed
                if hasChanged {
                    Button {
                        store.targetMinutes = totalMinutes
                        store.save()
                        dismiss()
                    } label: {
                        Text("Set Target")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(totalMinutes > 0 ? Color.accentColor : Color(.systemGray4))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(totalMinutes == 0)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: hasChanged)
                }
            }
            .navigationTitle("Daily Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                selectedHours = store.targetMinutes / 60
                let mins = store.targetMinutes % 60
                selectedMins = minuteSteps.min(by: { abs($0 - mins) < abs($1 - mins) }) ?? 0
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(ScreenDriftStore())
}
