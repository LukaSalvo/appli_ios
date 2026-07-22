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

    init(name: String, amount: Double, category: ExpenseCategory = .other) {
        self.name = name
        self.amount = amount
        self.categoryRawValue = category.rawValue
        self.createdAt = Date()
    }
}
