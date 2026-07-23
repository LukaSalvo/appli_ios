import SwiftUI
import SwiftData

/// Manage the one-off spending logged for the current month.
struct VariableExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VariableExpense.date, order: .reverse) private var allExpenses: [VariableExpense]

    @State private var showingAdd = false

    /// Only the spends dated within the current calendar month.
    private var monthExpenses: [VariableExpense] {
        let cal = Calendar.current
        guard let month = cal.dateInterval(of: .month, for: .now) else { return [] }
        return allExpenses.filter { month.contains($0.date) }
    }

    private var total: Double { monthExpenses.reduce(0) { $0 + $1.amount } }

    var body: some View {
        List {
            if !monthExpenses.isEmpty {
                Section {
                    HStack {
                        Text("Dépensé ce mois").fontWeight(.semibold)
                        Spacer()
                        Text(Money.string(total))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.moneyOut)
                            .monospacedDigit()
                    }
                }
            }

            Section {
                if monthExpenses.isEmpty {
                    ContentUnavailableView(
                        "Aucune dépense ce mois",
                        systemImage: "cart",
                        description: Text("Ajoutez vos achats du quotidien pour voir ce qu'il vous reste vraiment.")
                    )
                } else {
                    ForEach(monthExpenses) { expense in
                        HStack {
                            Image(systemName: expense.category.systemImage)
                                .foregroundStyle(Color.appAccent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(expense.name)
                                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.string(expense.amount))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Dépenses du mois")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddVariableExpenseView()
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(monthExpenses[index]) }
    }
}

#Preview {
    NavigationStack { VariableExpensesView() }
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self, VariableExpense.self], inMemory: true)
}
