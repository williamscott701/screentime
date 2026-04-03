import SwiftUI

struct LogTimeView: View {
    @Environment(ScreenDriftStore.self) var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHours = 0
    @State private var selectedMinutes = 0

    private var totalMinutes: Int { selectedHours * 60 + selectedMinutes }

    private var comparison: (text: String, color: Color)? {
        guard totalMinutes > 0 else { return nil }
        let diff = totalMinutes - store.targetMinutes
        if diff == 0 { return ("Exactly at your target", .orange) }
        if diff > 0  { return ("\(diff.formattedDuration) over your target", .red) }
        return ("\((-diff).formattedDuration) under your target", .green)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // How-to hint
                HStack(spacing: 6) {
                    Image(systemName: "iphone")
                        .foregroundStyle(.blue)
                    Text("Settings → Screen Time → see your total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
                .padding(.top, 24)

                // Large time display
                Text(totalMinutes > 0 ? totalMinutes.formattedDuration : "–")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(totalMinutes > 0 ? .primary : .secondary)
                    .padding(.top, 28)
                    .animation(.easeInOut(duration: 0.15), value: totalMinutes)

                // Comparison badge
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

                // Wheel pickers
                HStack(spacing: 0) {
                    Picker("Hours", selection: $selectedHours) {
                        ForEach(0..<24) { h in
                            Text("\(h) hr").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Minutes", selection: $selectedMinutes) {
                        ForEach(0..<12) { i in
                            Text("\(i * 5) min").tag(i * 5)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)

                Spacer()

                // Save button
                Button {
                    store.logToday(minutes: totalMinutes)
                    dismiss()
                } label: {
                    Text("Save")
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
            }
            .navigationTitle("Log Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                let existing = store.todayMinutes
                if existing > 0 {
                    selectedHours = existing / 60
                    selectedMinutes = (existing % 60 / 5) * 5
                }
            }
        }
    }
}

#Preview {
    LogTimeView()
        .environment(ScreenDriftStore())
}
