import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<WorkSession> { $0.endDate != nil },
        sort: \WorkSession.startDate,
        order: .reverse
    )
    private var pastSessions: [WorkSession]

    @Environment(\.modelContext) private var modelContext
    @State private var period: StatsPeriod = .week
    @State private var sessionToDelete: WorkSession?

    private var stats: WorkStats { WorkStats(sessions: pastSessions) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hoursCard
                    chartCard
                    sessionsCard
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Heures & historique")
            .confirmationDialog(
                "Supprimer cette session ?",
                isPresented: Binding(
                    get: { sessionToDelete != nil },
                    set: { if !$0 { sessionToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: sessionToDelete
            ) { session in
                Button("Supprimer", role: .destructive) {
                    Haptics.impact(.rigid)
                    modelContext.delete(session)
                    sessionToDelete = nil
                }
                Button("Annuler", role: .cancel) { sessionToDelete = nil }
            } message: { session in
                Text("\(session.startDate.formatted(date: .abbreviated, time: .omitted)) · \(formatHours(session.duration() / 3600))")
            }
        }
    }

    // MARK: - Hours breakdown

    private var hoursCard: some View {
        Card(hero: true) {
            VStack(spacing: 14) {
                Picker("Période", selection: $period) {
                    ForEach(StatsPeriod.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HeroAmountText(value: formatHours(stats.hours(period)), size: 46)
                    .animation(.snappy, value: period)

                Text(periodSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    metric(icon: "number", label: "Sessions", value: "\(stats.sessionCount(period))")
                    Divider().frame(height: 34)
                    metric(icon: "eurosign.circle", label: "Gagné",
                           value: Money.string(stats.earnings(period)), tint: .moneyGood)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var chartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Heures cette semaine", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(Color.appAccent)
                WeekBarChart(data: stats.currentWeek, isToday: stats.isToday)
            }
        }
    }

    private var sessionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Sessions récentes", systemImage: "list.bullet")
                    .font(.headline)
                if pastSessions.isEmpty {
                    Text("Aucune session terminée pour le moment.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    let recent = Array(pastSessions.prefix(12))
                    ForEach(Array(recent.enumerated()), id: \.offset) { index, session in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(session.startDate, style: .date)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(Money.string(session.totalPay()))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.moneyGood)
                                        .monospacedDigit()
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                    Text(formatHours(session.duration() / 3600))
                                    Text("·")
                                    Text(timeRange(session))
                                    if session.breakDuration > 0 {
                                        Text("·")
                                        Image(systemName: "pause.circle")
                                        Text(formatHours(session.breakDuration / 3600))
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Button {
                                sessionToDelete = session
                            } label: {
                                Image(systemName: "trash")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .padding(6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Supprimer la session")
                        }
                        .padding(.vertical, 4)
                        if index < recent.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var periodSubtitle: String {
        switch period {
        case .day: return "travaillées aujourd'hui"
        case .week: return "travaillées cette semaine"
        case .month: return "travaillées ce mois-ci"
        }
    }

    private func metric(icon: String, label: String, value: String, tint: Color = .primary) -> some View {
        VStack(spacing: 3) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func timeRange(_ session: WorkSession) -> String {
        let start = session.startDate.formatted(date: .omitted, time: .shortened)
        let end = session.endDate?.formatted(date: .omitted, time: .shortened) ?? "—"
        return "\(start) – \(end)"
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self], inMemory: true)
}
