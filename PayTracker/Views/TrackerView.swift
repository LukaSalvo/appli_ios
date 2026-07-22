import SwiftUI
import SwiftData

struct TrackerView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("payMode") private var payModeRaw: String = PayMode.hourly.rawValue
    @AppStorage("hourlyRate") private var hourlyRate: Double = 11.65
    @AppStorage("monthlySalary") private var monthlySalary: Double = 1800

    @Query(filter: #Predicate<WorkSession> { $0.endDate == nil })
    private var activeSessions: [WorkSession]

    @Query(sort: \Benefit.createdAt) private var benefits: [Benefit]

    private var payMode: PayMode { PayMode(rawValue: payModeRaw) ?? .hourly }
    private var activeSession: WorkSession? { activeSessions.first }

    private var enabledPerHourTotal: Double {
        benefits.filter { $0.isEnabled && $0.type == .perHour }.reduce(0) { $0 + $1.amount }
    }
    private var enabledFixedTotal: Double {
        benefits.filter { $0.isEnabled && $0.type == .perShift }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if payMode == .hourly {
                        hourlyContent
                    } else {
                        monthlyContent
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Suivi de paie")
        }
    }

    // MARK: - Hourly

    @ViewBuilder
    private var hourlyContent: some View {
        if let session = activeSession {
            liveCard(for: session)
            Button(role: .destructive) {
                session.endDate = Date()
            } label: {
                Label("Terminer la session", systemImage: "stop.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.moneyDanger)
            .controlSize(.large)
        } else {
            Card {
                VStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Aucune session en cours")
                        .font(.headline)
                    Text("Démarrez une session pour suivre votre paie seconde par seconde.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Button {
                startSession()
            } label: {
                Label("Démarrer", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccent)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private func liveCard(for session: WorkSession) -> some View {
        TimelineView(.periodic(from: session.startDate, by: 1)) { context in
            let elapsed = session.duration(asOf: context.date)
            let total = session.totalPay(asOf: context.date)

            Card {
                VStack(spacing: 14) {
                    Label("En cours", systemImage: "circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color.appAccent)
                        .labelStyle(.titleAndIcon)
                        .imageScale(.small)

                    Text(formattedDuration(elapsed))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(Money.string(total))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.moneyGood)
                        .contentTransition(.numericText())
                        .animation(.default, value: total)

                    VStack(spacing: 8) {
                        row("Taux horaire", Money.string(session.hourlyRateSnapshot))
                        if session.perHourBenefitsSnapshot > 0 {
                            row("Avantages / heure", Money.string(session.perHourBenefitsSnapshot))
                        }
                        if session.fixedBenefitsSnapshot > 0 {
                            row("Avantages fixes", Money.string(session.fixedBenefitsSnapshot))
                        }
                    }
                    .font(.subheadline)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Monthly

    @ViewBuilder
    private var monthlyContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let fraction = monthElapsedFraction(now: context.date)
            let earned = monthlySalary * fraction

            Card {
                VStack(spacing: 14) {
                    Text(monthTitle(context.date))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(Money.string(earned))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.moneyGood)
                        .contentTransition(.numericText())
                        .animation(.default, value: earned)

                    Text("gagné ce mois-ci")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ProgressView(value: fraction)
                        .tint(.appAccent)
                        .padding(.vertical, 4)

                    VStack(spacing: 8) {
                        row("Salaire mensuel net", Money.string(monthlySalary))
                        row("Mois écoulé", "\(Int((fraction * 100).rounded())) %")
                        row("Reste à venir", Money.string(monthlySalary - earned))
                    }
                    .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
            }
        }

        Card {
            Label {
                Text("Rendez-vous dans l'onglet **Budget** pour voir ce qu'il vous reste après vos dépenses fixes.")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "chart.pie.fill").foregroundStyle(Color.appAccent)
            }
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
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

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let s = Int(interval)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private func monthTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}

#Preview {
    TrackerView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self], inMemory: true)
}
