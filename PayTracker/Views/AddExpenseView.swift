import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var amount: Double = 0
    @State private var category: ExpenseCategory = .housing

    var body: some View {
        NavigationStack {
            Form {
                Section("Dépense") {
                    TextField("Nom (ex : Loyer, Netflix, Forfait mobile)", text: $name)
                    TextField("Montant / mois", value: $amount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
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
                        modelContext.insert(Expense(name: name, amount: amount, category: category))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || amount <= 0)
                }
            }
        }
    }
}

#Preview {
    AddExpenseView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self], inMemory: true)
}
