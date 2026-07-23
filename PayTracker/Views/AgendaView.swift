import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// A calendar of worked/school days with earnings per day, week, month and
/// year, plus import from an .ics file or from Apple Calendar.
struct AgendaView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<WorkSession> { $0.endDate != nil },
           sort: \WorkSession.startDate)
    private var sessions: [WorkSession]

    @Query(sort: \Benefit.createdAt) private var benefits: [Benefit]

    @AppStorage("hourlyRate") private var hourlyRate: Double = 11.65
    @AppStorage("schoolDaysPaid") private var schoolDaysPaid: Bool = true

    @State private var period: StatsPeriod = .month
    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingFileImporter = false
    @State private var isImporting = false
    @State private var importMessage: String?

    private let calendar = Calendar.current
    private var stats: WorkStats { WorkStats(sessions: sessions) }

    private var enabledPerHour: Double {
        benefits.filter { $0.isEnabled && $0.type == .perHour }.reduce(0) { $0 + $1.amount }
    }
    private var enabledFixed: Double {
        benefits.filter { $0.isEnabled && $0.type == .perShift }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    earningsCard
                    calendarCard
                    importCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Agenda")
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: icsTypes) { result in
                if case .success(let url) = result { importICS(url) }
            }
        }
    }

    // MARK: - Earnings per period

    private var earningsCard: some View {
        Card(hero: true) {
            VStack(spacing: 12) {
                Picker("Période", selection: $period) {
                    ForEach(StatsPeriod.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Text(Money.string(stats.earnings(period)))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient.moneyText)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: period)

                Text("gagné · \(formatHours(stats.hours(period))) travaillées")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Month calendar

    private var calendarCard: some View {
        Card {
            VStack(spacing: 12) {
                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                }
                .buttonStyle(.borderless)

                HStack {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(monthGrid.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(date)
                        } else {
                            Color.clear.frame(minHeight: 42)
                        }
                    }
                }

                HStack(spacing: 16) {
                    legend(.entreprise)
                    legend(.ecole)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let earned = stats.earnings(onDay: date)
        let kind = stats.kind(onDay: date)
        let isToday = calendar.isDateInToday(date)
        return VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
            if earned > 0 {
                Text("\(Int(earned.rounded()))€")
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Color.clear.frame(height: 11)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .background((kindColor(kind) ?? .clear).opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isToday ? Color.appAccent : .clear, lineWidth: 1.5)
        )
    }

    private func legend(_ kind: SessionKind) -> some View {
        HStack(spacing: 6) {
            Circle().fill(kindColor(kind) ?? .secondary).frame(width: 9, height: 9)
            Text(kind.rawValue)
        }
    }

    // MARK: - Import

    private var importCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Importer un emploi du temps", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(Color.appAccent)

                Text("Importez votre calendrier alternance : l'app détecte les jours d'école et d'entreprise et remplit l'agenda.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Toggle("Jours d'école payés", isOn: $schoolDaysPaid)
                    .font(.subheadline)

                Button {
                    showingFileImporter = true
                } label: {
                    Label("Importer un fichier (.ics)", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.appAccent)

                Button {
                    importFromAppleCalendar()
                } label: {
                    Label("Synchroniser Apple Calendrier", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.appAccent)

                if isImporting {
                    HStack(spacing: 8) { ProgressView(); Text("Import en cours…").font(.caption) }
                } else if let importMessage {
                    Text(importMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func importICS(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let text = (try? String(contentsOf: url, encoding: .utf8))
            ?? (try? String(contentsOf: url, encoding: .isoLatin1))
        guard let text else {
            importMessage = "Impossible de lire le fichier."
            return
        }
        handle(ICSParser.parse(text))
    }

    private func importFromAppleCalendar() {
        #if canImport(EventKit)
        isImporting = true
        Task {
            let events = await EventKitService.fetchEvents()
            handle(events)
        }
        #else
        importMessage = "Calendrier Apple indisponible sur cet appareil."
        #endif
    }

    private func handle(_ events: [ImportedEvent]) {
        guard !events.isEmpty else {
            isImporting = false
            importMessage = "Aucun événement trouvé."
            return
        }
        isImporting = true
        let existing = Set(sessions.map { calendar.startOfDay(for: $0.startDate) })
        Task {
            let created = await CalendarImporter.makeSessions(
                from: events,
                hourlyRate: hourlyRate,
                perHour: enabledPerHour,
                fixed: enabledFixed,
                schoolPaid: schoolDaysPaid,
                useAI: true,
                existingDays: existing
            )
            await MainActor.run {
                for session in created { modelContext.insert(session) }
                isImporting = false
                importMessage = created.isEmpty
                    ? "Rien de nouveau à importer."
                    : "\(created.count) journée(s) importée(s)."
            }
        }
    }

    // MARK: - Helpers

    private var icsTypes: [UTType] {
        var types: [UTType] = [.data]
        if let ics = UTType(filenameExtension: "ics") { types.insert(ics, at: 0) }
        return types
    }

    private func kindColor(_ kind: SessionKind?) -> Color? {
        switch kind {
        case .entreprise: return .appAccent
        case .ecole: return .gold
        case .autre: return .secondary
        case nil: return nil
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = d
        }
    }

    /// Weekday header symbols, ordered from the locale's first weekday.
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = .current
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? ["D", "L", "M", "M", "J", "V", "S"]
        guard symbols.count == 7 else { return symbols }
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Cells for the displayed month, with leading blanks for alignment.
    private var monthGrid: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = calendar.startOfDay(for: interval.start)
        let weekday = calendar.component(.weekday, from: firstDay)
        let leading = (weekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        var day = firstDay
        while day < interval.end {
            cells.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? interval.end
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}

#Preview {
    AgendaView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self, VariableExpense.self], inMemory: true)
}
