import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.createdAt) private var expenses: [Expense]

    @State private var showingAdd = false

    private var total: Double { expenses.reduce(0) { $0 + $1.amount } }

    var body: some View {
        List {
            if !expenses.isEmpty {
                Section {
                    HStack {
                        Text("Total mensuel").fontWeight(.semibold)
                        Spacer()
                        Text(Money.string(total))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.moneyOut)
                            .monospacedDigit()
                    }
                }
            }

            Section {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "Aucune dépense fixe",
                        systemImage: "tray",
                        description: Text("Ajoutez vos charges récurrentes : loyer, abonnements, transport…")
                    )
                } else {
                    ForEach(expenses) { expense in
                        HStack {
                            Image(systemName: expense.category.systemImage)
                                .foregroundStyle(Color.appAccent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(expense.name)
                                Text(expense.category.rawValue)
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
        .navigationTitle("Dépenses fixes")
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
            AddExpenseView()
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(expenses[index]) }
    }
}

#Preview {
    NavigationStack { ExpensesView() }
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self], inMemory: true)
}
