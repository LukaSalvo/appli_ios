import SwiftUI
import SwiftData

/// Quickly log a one-off spend for the month (with a date and a category).
struct AddVariableExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var amount: Double = 0
    @State private var category: ExpenseCategory = .food
    @State private var date: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Dépense") {
                    TextField("Nom (ex : Courses, Resto, Essence)", text: $name)
                    TextField("Montant", value: $amount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Catégorie") {
                    Picker("Catégorie", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.systemImage).tag(cat)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Nouvelle dépense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        modelContext.insert(
                            VariableExpense(name: name, amount: amount, date: date, category: category)
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || amount <= 0)
                }
            }
        }
    }
}

#Preview {
    AddVariableExpenseView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self, VariableExpense.self], inMemory: true)
}
