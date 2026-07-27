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
    @AppStorage("hideAmountsOnLockScreen") private var hideAmountsOnLockScreen: Bool = false

    // Face ID / Touch ID gate in front of the financial data.
    @StateObject private var appLock = AppLock()
    @AppStorage(AppLock.enabledKey) private var appLockEnabled: Bool = false

    /// Hide everything while locked, and also while the app is not frontmost so
    /// the app-switcher snapshot never captures any figure.
    private var isCovered: Bool {
        appLock.isLocked || (appLockEnabled && scenePhase != .active)
    }

    var body: some View {
        ZStack {
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
            .environmentObject(appLock)

            if isCovered {
                if appLock.isLocked {
                    AppLockView(lock: appLock)
                } else {
                    PrivacyShadeView()
                }
            }
        }
        // The store failed to open and the app fell back to memory — say so
        // rather than letting the user log a day that vanishes on relaunch.
        .safeAreaInset(edge: .top) {
            if AppModelContainer.isUsingMemoryFallback && !isCovered {
                Label("Stockage indisponible : les données saisies ne seront pas conservées.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.moneyDanger)
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .onOpenURL { url in
            // Deep link from the Home Screen widget → open the live pay tracker
            // (now hosted in the "Heures" tab). Only our own scheme is honoured,
            // and it may not bypass the lock.
            guard url.scheme == "paytracker", !appLock.isLocked else { return }
            selectedTab = 3
        }
        // Keep the 18:00 recap's figures fresh: on launch, when returning to the
        // foreground, when the setting changes, and whenever a session changes.
        .onAppear(perform: refreshDailySummary)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                refreshDailySummary()
                if appLock.isLocked { Task { await appLock.unlock() } }
            case .background:
                // Re-arm the lock as soon as the app leaves the foreground.
                appLock.lock()
            default:
                break
            }
        }
        .onChange(of: dailySummaryEnabled) { _, _ in refreshDailySummary() }
        .onChange(of: weeklyContractHours) { _, _ in refreshDailySummary() }
        .onChange(of: hideAmountsOnLockScreen) { _, _ in refreshDailySummary() }
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
            hideAmounts: hideAmountsOnLockScreen,
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
