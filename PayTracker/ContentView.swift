import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TrackerView()
                .tabItem { Label("Suivi", systemImage: "timer") }
                .tag(0)

            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.pie.fill") }
                .tag(1)

            AgendaView()
                .tabItem { Label("Agenda", systemImage: "calendar") }
                .tag(2)

            HistoryView()
                .tabItem { Label("Heures", systemImage: "chart.bar.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(.appAccent)
        .onOpenURL { url in
            // Deep link from the Home Screen widget → open the pay tracker.
            if url.scheme == "paytracker" { selectedTab = 0 }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self, VariableExpense.self], inMemory: true)
}
