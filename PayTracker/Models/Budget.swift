import Foundation

/// Configuration for meal vouchers ("tickets restaurant").
/// The employer pays a share of each ticket's face value — that share is
/// effectively free purchasing power, so we count it as a benefit.
struct MealTicketConfig {
    var isEnabled: Bool
    var faceValue: Double        // e.g. 9.00 € per ticket
    var employerSharePct: Double // e.g. 60 → employer pays 60 %
    var daysWorked: Int          // one ticket per worked day

    /// Value of the employer's contribution over the month.
    var employerBenefit: Double {
        guard isEnabled else { return 0 }
        return faceValue * (employerSharePct / 100) * Double(daysWorked)
    }

    /// What the employee pays out of pocket for their share of the tickets.
    var employeeCost: Double {
        guard isEnabled else { return 0 }
        return faceValue * (1 - employerSharePct / 100) * Double(daysWorked)
    }

    /// Total face value of tickets received.
    var totalFaceValue: Double {
        guard isEnabled else { return 0 }
        return faceValue * Double(daysWorked)
    }
}

/// A month's financial picture: what comes in vs. everything going out —
/// both the recurring fixed costs and the variable spending logged this month.
struct BudgetSummary {
    var salaryIncome: Double
    var mealTicketBenefit: Double
    var totalExpenses: Double          // recurring fixed costs
    var variableExpenses: Double = 0   // one-off spending logged this month

    var totalIncome: Double { salaryIncome + mealTicketBenefit }

    /// Everything leaving the account this month.
    var totalSpending: Double { totalExpenses + variableExpenses }

    var remaining: Double { totalIncome - totalSpending }

    /// Share of income already spent (0...1), used by the budget ring.
    var spentFraction: Double {
        guard totalIncome > 0 else { return 0 }
        return min(max(totalSpending / totalIncome, 0), 1)
    }
}
