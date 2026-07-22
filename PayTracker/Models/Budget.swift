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

/// A month's financial picture: what comes in vs. the fixed costs going out.
struct BudgetSummary {
    var salaryIncome: Double
    var mealTicketBenefit: Double
    var totalExpenses: Double

    var totalIncome: Double { salaryIncome + mealTicketBenefit }
    var remaining: Double { totalIncome - totalExpenses }

    /// Share of income already committed to fixed expenses (0...1).
    var spentFraction: Double {
        guard totalIncome > 0 else { return 0 }
        return min(max(totalExpenses / totalIncome, 0), 1)
    }
}
