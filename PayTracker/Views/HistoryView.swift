import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<WorkSession> { $0.endDate != nil },
        sort: \WorkSession.startDate,
        order: .reverse
    )
    private var pastSessions: [WorkSession]

    private func total(since start: Date) -> Double {
        pastSessions.filter { $0.startDate >= start }.reduce(0) { $0 + $1.totalPay() }
    }

    private var weekTotal: Double {
        let cal = Calendar.current
        guard let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return total(since: start)
    }

    private var monthTotal: Double {
        let cal = Calendar.current
        guard let start = cal.dateInterval(of: .month, for: .now)?.start else { return 0 }
        return total(since: start)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryRow("Cette semaine", weekTotal)
                    summaryRow("Ce mois-ci", monthTotal)
                }

                Section("Sessions passées") {
                    if pastSessions.isEmpty {
                        Text("Aucune session terminée pour le moment.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pastSessions) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(session.startDate, style: .date)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(Money.string(session.totalPay()))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.moneyGood)
                                        .monospacedDigit()
                                }
                                Text(timeRange(session))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Historique")
        }
    }

    private func summaryRow(_ label: String, _ value: Double) -> some View {
        LabeledContent(label) {
            Text(Money.string(value))
                .font(.headline)
                .foregroundStyle(Color.moneyGood)
                .monospacedDigit()
        }
    }

    private func timeRange(_ session: WorkSession) -> String {
        let start = session.startDate.formatted(date: .omitted, time: .shortened)
        let end = session.endDate?.formatted(date: .omitted, time: .shortened) ?? "—"
        return "\(start) - \(end)"
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self], inMemory: true)
}
