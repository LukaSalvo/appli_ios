import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @State private var selectedTab = 0

    private var appearanceMode: AppearanceMode { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }

    @Environment(\.scenePhase) private var scenePhase

    // Completed sessions drive the daily 18:00 recap notification.
    @Query(filter: #Predicate<WorkSession> { $0.endDate != nil })
    private var completedSessions: [WorkSession]

    @AppStorage("dailySummaryEnabled") private var dailySummaryEnabled: Bool = true
    @AppStorage("weeklyContractHours") private var weeklyContractHours: Double = 35

    var body: some View {
        TabView(selection: $selectedTab) {
            AIAssistantView()
                .tabItem { Label("IA", systemImage: "sparkles") }
                .tag(0)

            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.pie.fill") }
                .tag(1)

            AgendaView()
                .tabItem { Label("Agenda", systemImage: "calendar") }
                .tag(2)

            // Live pay tracking now lives at the top of the "Heures" hub.
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
            // Deep link from the Home Screen widget → open the live pay tracker
            // (now hosted in the "Heures" tab).
            if url.scheme == "paytracker" { selectedTab = 3 }
        }
        // Keep the 18:00 recap's figures fresh: on launch, when returning to the
        // foreground, when the setting changes, and whenever a session changes.
        .onAppear(perform: refreshDailySummary)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDailySummary() }
        }
        .onChange(of: dailySummaryEnabled) { _, _ in refreshDailySummary() }
        .onChange(of: weeklyContractHours) { _, _ in refreshDailySummary() }
        .onChange(of: sessionsDigest) { _, _ in refreshDailySummary() }
    }

    /// A cheap fingerprint that changes when a session is added, removed, or its
    /// hours are edited — used to re-arm the recap while the app is open.
    private var sessionsDigest: String {
        completedSessions
            .map { "\($0.startDate.timeIntervalSince1970)-\($0.endDate?.timeIntervalSince1970 ?? 0)-\($0.breakDuration)" }
            .joined(separator: "|")
    }

    private func refreshDailySummary() {
        let stats = WorkStats(sessions: completedSessions)
        DailySummaryNotification.refresh(
            enabled: dailySummaryEnabled,
            hoursToday: stats.hoursOnDay(Date()),
            earningsToday: stats.earnings(onDay: Date()),
            weeklyHours: stats.weeklyTotal,
            weeklyTarget: weeklyContractHours
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self, VariableExpense.self], inMemory: true)
}
