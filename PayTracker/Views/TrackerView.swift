import SwiftUI
import SwiftData

struct TrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hourlyRate") private var hourlyRate: Double = 11.65

    @Query(filter: #Predicate<WorkSession> { $0.endDate == nil })
    private var activeSessions: [WorkSession]

    @Query(sort: \Benefit.createdAt) private var benefits: [Benefit]

    private var activeSession: WorkSession? { activeSessions.first }

    private var enabledPerHourTotal: Double {
        benefits.filter { $0.isEnabled && $0.type == .perHour }.reduce(0) { $0 + $1.amount }
    }

    private var enabledFixedTotal: Double {
        benefits.filter { $0.isEnabled && $0.type == .perShift }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let session = activeSession {
                    liveCard(for: session)

                    Button(role: .destructive) {
                        stopSession(session)
                    } label: {
                        Label("Terminer la session", systemImage: "stop.circle.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .padding(.horizontal)

                    Spacer()
                } else {
                    Spacer()
                    ContentUnavailableView(
                        "Aucune session en cours",
                        systemImage: "clock",
                        description: Text("Démarrez une session pour suivre votre paie en temps réel.")
                    )

                    Button {
                        startSession()
                    } label: {
                        Label("Démarrer", systemImage: "play.circle.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    Spacer()
                }
            }
            .padding(.top)
            .navigationTitle("Suivi de paie")
        }
    }

    @ViewBuilder
    private func liveCard(for session: WorkSession) -> some View {
        TimelineView(.periodic(from: session.startDate, by: 1)) { context in
            let elapsed = session.duration(asOf: context.date)
            let total = session.totalPay(asOf: context.date)

            VStack(spacing: 16) {
                Text(formattedDuration(elapsed))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(total, format: .currency(code: "EUR"))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                    .animation(.default, value: total)

                VStack(spacing: 8) {
                    LabeledContent("Taux horaire") {
                        Text(session.hourlyRateSnapshot, format: .currency(code: "EUR"))
                    }
                    if session.perHourBenefitsSnapshot > 0 {
                        LabeledContent("Avantages / heure") {
                            Text(session.perHourBenefitsSnapshot, format: .currency(code: "EUR"))
                        }
                    }
                    if session.fixedBenefitsSnapshot > 0 {
                        LabeledContent("Avantages fixes") {
                            Text(session.fixedBenefitsSnapshot, format: .currency(code: "EUR"))
                        }
                    }
                }
                .font(.subheadline)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
        }
    }

    private func startSession() {
        let session = WorkSession(
            startDate: Date(),
            hourlyRateSnapshot: hourlyRate,
            perHourBenefitsSnapshot: enabledPerHourTotal,
            fixedBenefitsSnapshot: enabledFixedTotal
        )
        modelContext.insert(session)
    }

    private func stopSession(_ session: WorkSession) {
        session.endDate = Date()
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    TrackerView()
        .modelContainer(for: [WorkSession.self, Benefit.self], inMemory: true)
}
