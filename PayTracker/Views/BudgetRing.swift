import SwiftUI

/// A thin circular gauge showing how much of the monthly income is already
/// committed to fixed expenses, with the remaining amount glowing in the center.
struct BudgetRing: View {
    var spentFraction: Double          // 0...1
    var remaining: Double
    var isOverBudget: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var ringColor: Color {
        if isOverBudget { return .moneyDanger }
        if spentFraction > 0.8 { return .gold }
        return .appAccent
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appTrack, lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0.001, min(spentFraction, 1)))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(colorScheme == .dark ? 0.7 : 0.25), radius: 8)
                .animation(.spring(duration: 0.6), value: spentFraction)

            VStack(spacing: 4) {
                Text("Reste à vivre").eyebrow()
                Text(Money.string(remaining))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(isOverBudget ? Color.moneyDanger : Color.appTextPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("\(Int((spentFraction * 100).rounded())) % dépensé")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
    }
}

#Preview {
    BudgetRing(spentFraction: 0.62, remaining: 684, isOverBudget: false)
        .padding()
}
