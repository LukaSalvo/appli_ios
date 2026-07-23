import SwiftUI
import SwiftData

/// Manually log a worked day from an arrival time, a departure time and a
/// break duration — the worked hours and estimated pay update live.
/// Pass an existing session to edit it instead of creating a new one.
struct AddSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hourlyRate") private var hourlyRate: Double = 11.65
    @Query(sort: \Benefit.createdAt) private var benefits: [Benefit]

    /// The session being edited, or `nil` when logging a brand-new day.
    private let editing: WorkSession?

    @State private var day: Date
    @State private var arrival: Date
    @State private var departure: Date
    @State private var breakMinutes: Int

    @State private var naturalText: String = ""
    @State private var isParsing: Bool = false

    init(session: WorkSession? = nil) {
        self.editing = session
        if let s = session {
            let cal = Calendar.current
            _day = State(initialValue: cal.startOfDay(for: s.startDate))
            _arrival = State(initialValue: s.startDate)
            _departure = State(initialValue: s.endDate ?? s.startDate)
            _breakMinutes = State(initialValue: Int(s.breakDuration / 60))
        } else {
            _day = State(initialValue: .now)
            _arrival = State(initialValue: defaultTime(hour: 9))
            _departure = State(initialValue: defaultTime(hour: 17))
            _breakMinutes = State(initialValue: 60)
        }
    }

    private var enabledPerHour: Double {
        benefits.filter { $0.isEnabled && $0.type == .perHour }.reduce(0) { $0 + $1.amount }
    }
    private var enabledFixed: Double {
        benefits.filter { $0.isEnabled && $0.type == .perShift }.reduce(0) { $0 + $1.amount }
    }

    private var startDate: Date { combine(day: day, time: arrival) }
    private var endDate: Date {
        var end = combine(day: day, time: departure)
        if end <= startDate { end.addTimeInterval(24 * 3600) } // crosses midnight
        return end
    }
    private var workedSeconds: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate) - Double(breakMinutes) * 60)
    }
    private var estimatedPay: Double {
        workedSeconds / 3600 * (hourlyRate + enabledPerHour) + enabledFixed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Ex : 9h-17h, 1h de pause hier", text: $naturalText)
                            .submitLabel(.done)
                            .onSubmit { runSmartParse() }
                        Button(action: runSmartParse) {
                            if isParsing {
                                ProgressView()
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(naturalText.trimmingCharacters(in: .whitespaces).isEmpty || isParsing)
                    }
                } header: {
                    Text("Saisie rapide")
                } footer: {
                    Text(smartFooter)
                }

                Section("Journée") {
                    DatePicker("Date", selection: $day, displayedComponents: .date)
                }

                Section("Horaires") {
                    DatePicker("Heure d'arrivée", selection: $arrival, displayedComponents: .hourAndMinute)
                    DatePicker("Heure de départ", selection: $departure, displayedComponents: .hourAndMinute)
                    Picker("Pause", selection: $breakMinutes) {
                        ForEach(breakOptions, id: \.self) { m in
                            Text(breakLabel(m)).tag(m)
                        }
                    }
                }

                Section {
                    summaryRow("Heures travaillées", formatHours(workedSeconds / 3600),
                               tint: .appAccent, big: true)
                    summaryRow("Amplitude", formatHours(endDate.timeIntervalSince(startDate) / 3600))
                    summaryRow("Pause déduite", breakLabel(breakMinutes))
                    summaryRow("Paie estimée", Money.string(estimatedPay), tint: .moneyGood)
                } header: {
                    Text("Récapitulatif")
                } footer: {
                    Text("Basé sur votre taux (\(Money.string(hourlyRate))/h) et vos avantages actifs.")
                }
            }
            .navigationTitle(editing == nil ? "Saisir mes heures" : "Modifier la session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                        .disabled(workedSeconds <= 0)
                }
            }
        }
    }

    private func save() {
        if let session = editing {
            // Edit in place; keep the rate/benefit snapshot as it was recorded.
            session.startDate = startDate
            session.endDate = endDate
            session.breakDuration = Double(breakMinutes) * 60
        } else {
            let session = WorkSession(
                startDate: startDate,
                endDate: endDate,
                breakDuration: Double(breakMinutes) * 60,
                hourlyRateSnapshot: hourlyRate,
                perHourBenefitsSnapshot: enabledPerHour,
                fixedBenefitsSnapshot: enabledFixed
            )
            modelContext.insert(session)
        }
        dismiss()
    }

    // MARK: - Smart entry

    private var smartFooter: String {
        if ExpenseTextParser.isOnDeviceModelAvailable {
            return "Analysé par l'IA d'Apple, directement sur votre iPhone — rien n'est envoyé en ligne."
        }
        return "Reconnaît les horaires et la pause. L'analyse est améliorée par l'IA d'Apple sur iPhone compatible (iOS 26)."
    }

    private func runSmartParse() {
        let text = naturalText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isParsing else { return }
        isParsing = true
        Task {
            let parsed = await SessionTextParser.parse(text)
            await MainActor.run {
                day = parsed.day
                arrival = parsed.arrival
                departure = parsed.departure
                breakMinutes = parsed.breakMinutes
                isParsing = false
            }
        }
    }

    // MARK: - UI helpers

    private func summaryRow(_ label: String, _ value: String, tint: Color = .primary, big: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(big ? .title3.weight(.bold) : .body.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }

    private var breakOptions: [Int] {
        let base = [0, 15, 20, 30, 45, 60, 90, 120]
        // A session edited from a live one may carry a break not in the presets.
        return base.contains(breakMinutes) ? base : (base + [breakMinutes]).sorted()
    }

    private func breakLabel(_ minutes: Int) -> String {
        if minutes == 0 { return "Aucune" }
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m)"
    }

    // MARK: - Date helpers

    private func combine(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: day)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day
        c.hour = t.hour; c.minute = t.minute
        return cal.date(from: c) ?? day
    }
}

private func defaultTime(hour: Int) -> Date {
    Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
}

#Preview {
    AddSessionView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self], inMemory: true)
}
