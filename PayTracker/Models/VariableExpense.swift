import Foundation
import SwiftData

/// A one-off spend that happens during the month (groceries, a night out, a
/// train ticket…). Unlike a fixed `Expense`, it is dated so the budget can
/// count only what was actually spent in the current month — turning the
/// "reste à vivre" ring from a theoretical figure into a live one.
@Model
final class VariableExpense {
    var name: String
    var amount: Double
    var date: Date
    var categoryRawValue: String

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    init(name: String, amount: Double, date: Date = .now, category: ExpenseCategory = .other) {
        self.name = name
        self.amount = amount
        self.date = date
        self.categoryRawValue = category.rawValue
    }
}
