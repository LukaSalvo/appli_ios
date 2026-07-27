import Foundation
import SwiftData

/// A recurring monthly expense that stays roughly the same every month
/// (rent, subscriptions, phone bill, gym…).
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case housing = "Logement"
    case subscriptions = "Abonnements"
    case transport = "Transport"
    case food = "Alimentation"
    case insurance = "Assurances"
    case other = "Autre"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .housing: return "house.fill"
        case .subscriptions: return "sparkles.tv.fill"
        case .transport: return "tram.fill"
        case .food: return "cart.fill"
        case .insurance: return "shield.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

@Model
final class Expense {
    var name: String
    var amount: Double
    var categoryRawValue: String
    var createdAt: Date

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    /// Values are normalised here rather than at each call site: an expense is
    /// created from a form, from a natural-language parse, from an imported
    /// backup and from the on-device model, and every one of those paths must
    /// end up with a display-safe name and a finite, in-range amount.
    init(name: String, amount: Double, category: ExpenseCategory = .other) {
        self.name = Sanitize.text(name, fallback: category.rawValue)
        self.amount = Sanitize.amount(amount)
        self.categoryRawValue = category.rawValue
        self.createdAt = Date()
    }
}
