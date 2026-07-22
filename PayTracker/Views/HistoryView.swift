import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<WorkSession> { $0.endDate != nil },
        sort: \WorkSession.startDate,
        order: .reverse
    )
    private var pastSessions: [WorkSession]

    private var weekTotal: Double {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return pastSessions
            .filter { $0.startDate >= weekStart }
            .reduce(0) { $0 + $1.totalPay() }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Total cette semaine") {
                        Text(weekTotal, format: .currency(code: "EUR"))
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
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
                                    Text(session.totalPay(), format: .currency(code: "EUR"))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.green)
                                }
                                Text(sessionTimeRange(session))
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

    private func sessionTimeRange(_ session: WorkSession) -> String {
        let start = session.startDate.formatted(date: .omitted, time: .shortened)
        let end = session.endDate?.formatted(date: .omitted, time: .shortened) ?? "—"
        return "\(start) - \(end)"
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [WorkSession.self, Benefit.self], inMemory: true)
}
