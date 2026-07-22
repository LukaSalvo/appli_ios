import SwiftUI

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue

    private var appearanceMode: AppearanceMode { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }

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
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .preferredColorScheme(appearanceMode.colorScheme)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self], inMemory: true)
}
