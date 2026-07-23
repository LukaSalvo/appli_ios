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

    @State private var naturalText: String = ""
    @State private var isParsing: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Ex : 25€ resto hier", text: $naturalText)
                            .submitLabel(.done)
                            .onSubmit { runSmartParse() }
                        Button(action: runSmartParse) {
                            if isParsing {
                                ProgressView()
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(naturalText.trimmingCharacters(in: .whitespaces).isEmpty || isParsing)
                    }
                } header: {
                    Text("Saisie rapide")
                } footer: {
                    Text(smartFooter)
                }

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

    private var smartFooter: String {
        if ExpenseTextParser.isOnDeviceModelAvailable {
            return "Analysé par l'IA d'Apple, directement sur votre iPhone — rien n'est envoyé en ligne."
        }
        return "Reconnaît le montant, la catégorie et la date. L'analyse est améliorée par l'IA d'Apple sur iPhone compatible (iOS 26)."
    }

    private func runSmartParse() {
        let text = naturalText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isParsing else { return }
        isParsing = true
        Task {
            let parsed = await ExpenseTextParser.parse(text)
            await MainActor.run {
                if parsed.amount > 0 { amount = parsed.amount }
                name = parsed.name
                category = parsed.category
                date = parsed.date
                isParsing = false
            }
        }
    }
}

#Preview {
    AddVariableExpenseView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self, VariableExpense.self], inMemory: true)
}
