import SwiftUI

/// A circular gauge showing how much of the monthly income is already
/// committed to fixed expenses, with the remaining amount in the center.
struct BudgetRing: View {
    var spentFraction: Double          // 0...1
    var remaining: Double
    var isOverBudget: Bool

    private var ringColor: Color {
        if isOverBudget { return .moneyDanger }
        if spentFraction > 0.8 { return .moneyOut }
        return .appAccent
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 18)

            Circle()
                .trim(from: 0, to: max(0.001, min(spentFraction, 1)))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: spentFraction)

            VStack(spacing: 2) {
                Text("Reste à vivre")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Money.string(remaining))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(isOverBudget ? Color.moneyDanger : Color.moneyGood)
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
