import SwiftUI

struct TotalActivityView: View {
    let model: TotalUsageModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Last 30 Days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(model.totalMinutes.formattedDuration)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
            }
            Spacer()
            Image(systemName: "iphone")
                .font(.system(size: 36))
                .foregroundStyle(.blue)
        }
        .padding()
    }
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
