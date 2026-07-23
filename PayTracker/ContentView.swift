import SwiftUI

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @State private var selectedTab = 0

    private var appearanceMode: AppearanceMode { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }

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
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .preferredColorScheme(appearanceMode.colorScheme)
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
