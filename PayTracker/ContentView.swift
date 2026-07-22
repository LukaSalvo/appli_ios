import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TrackerView()
                .tabItem { Label("Suivi", systemImage: "clock.fill") }

            HistoryView()
                .tabItem { Label("Historique", systemImage: "list.bullet") }

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkSession.self, Benefit.self], inMemory: true)
}
