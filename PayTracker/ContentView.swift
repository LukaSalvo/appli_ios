import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TrackerView()
                .tabItem { Label("Suivi", systemImage: "timer") }

            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.pie.fill") }

            HistoryView()
                .tabItem { Label("Heures", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
        }
        .tint(.appAccent)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self], inMemory: true)
}
