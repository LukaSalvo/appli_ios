import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The four zoom levels of the agenda calendar.
enum AgendaViewMode: String, CaseIterable, Identifiable {
    case day = "Jour"
    case week = "Semaine"
    case month = "Mois"
    case year = "Année"
    var id: String { rawValue }
}

/// A calendar of worked/school days with earnings per day, week, month and
/// year, day notes/rendez-vous, plus import from an .ics file or from Apple
/// Calendar (with the ability to undo an import).
struct AgendaView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<WorkSession> { $0.endDate != nil },
           sort: \WorkSession.startDate)
    private var sessions: [WorkSession]

    @Query(sort: \Benefit.createdAt) private var benefits: [Benefit]
    @Query private var dayNotes: [DayNote]
    @Query(sort: \ImportedCalendar.importedAt, order: .reverse)
    private var importedCalendars: [ImportedCalendar]

    @AppStorage("hourlyRate") private var hourlyRate: Double = 11.65
    @AppStorage("schoolDaysPaid") private var schoolDaysPaid: Bool = true

    @State private var viewMode: AgendaViewMode = .month
    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingFileImporter = false
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var calendarPendingDelete: ImportedCalendar?
    /// Kept separate from the calendar's own zoom level so switching the
    /// earnings period doesn't jump the calendar around, and vice versa.
    @State private var statsPeriod: StatsPeriod = .month

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
                    if !importedCalendars.isEmpty {
                        importedCalendarsCard
                    }
                    importCard
                }
                .padding()
            }
            .background(Color.appBackground)
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
                Picker("Période", selection: $statsPeriod) {
                    ForEach(StatsPeriod.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HeroAmountText(value: Money.string(stats.earnings(statsPeriod)), size: 40)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: statsPeriod)

                Text("gagné · \(formatHours(stats.hours(statsPeriod))) travaillées")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Calendar (day / week / month / year)

    private var calendarCard: some View {
        Card {
            VStack(spacing: 12) {
                Picker("Vue", selection: $viewMode) {
                    ForEach(AgendaViewMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(periodTitle).font(.headline)
                    Spacer()
                    Button { shift(1) } label: { Image(systemName: "chevron.right") }
                }
                .buttonStyle(.borderless)

                switch viewMode {
                case .day:
                    DayAgendaDetail(date: selectedDate)
                case .week:
                    weekContent
                case .month:
                    monthContent
                    HStack(spacing: 16) {
                        legend(.entreprise)
                        legend(.ecole)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                case .year:
                    yearContent
                }
            }
        }
    }

    private var periodTitle: String {
        switch viewMode {
        case .day:
            return selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
        case .week:
            guard let first = weekDays.first, let last = weekDays.last else { return "" }
            return "\(first.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))"
        case .month:
            return displayedMonth.formatted(.dateTime.month(.wide).year())
        case .year:
            return displayedMonth.formatted(.dateTime.year())
        }
    }

    private func shift(_ delta: Int) {
        switch viewMode {
        case .day:
            if let d = calendar.date(byAdding: .day, value: delta, to: selectedDate) { selectedDate = d }
        case .week:
            if let d = calendar.date(byAdding: .day, value: delta * 7, to: selectedDate) { selectedDate = d }
        case .month:
            if let d = calendar.date(byAdding: .month, value: delta, to: displayedMonth) { displayedMonth = d }
        case .year:
            if let d = calendar.date(byAdding: .year, value: delta, to: displayedMonth) { displayedMonth = d }
        }
    }

    // MARK: - Month grid

    private var monthContent: some View {
        VStack(spacing: 12) {
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
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let earned = stats.earnings(onDay: date)
        let kind = stats.kind(onDay: date)
        let isToday = calendar.isDateInToday(date)
        let hasNotes = dayNotes.contains { calendar.isDate($0.day, inSameDayAs: date) }
        return Button {
            selectedDate = date
            viewMode = .day
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(.primary)
                if earned > 0 {
                    Text("\(Int(earned.rounded()))€")
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear.frame(height: 11)
                }
                Circle()
                    .fill(hasNotes ? Color.gold : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background((kindColor(kind) ?? .clear).opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isToday ? Color.appAccent : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func legend(_ kind: SessionKind) -> some View {
        HStack(spacing: 6) {
            Circle().fill(kindColor(kind) ?? .secondary).frame(width: 9, height: 9)
            Text(kind.rawValue)
        }
    }

    // MARK: - Week list

    private var weekDays: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        var days: [Date] = []
        var day = calendar.startOfDay(for: week.start)
        for _ in 0..<7 {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 3600)
        }
        return days
    }

    private var weekContent: some View {
        VStack(spacing: 4) {
            ForEach(weekDays, id: \.self) { day in
                weekDayRow(day)
            }
        }
    }

    private func weekDayRow(_ day: Date) -> some View {
        let earned = stats.earnings(onDay: day)
        let hrs = stats.hoursOnDay(day)
        let kind = stats.kind(onDay: day)
        let hasNotes = dayNotes.contains { calendar.isDate($0.day, inSameDayAs: day) }
        let isToday = calendar.isDateInToday(day)
        return Button {
            selectedDate = day
            viewMode = .day
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(calendar.component(.day, from: day))")
                        .font(.subheadline.weight(isToday ? .bold : .regular))
                }
                .frame(width: 40, alignment: .leading)

                Circle().fill(kindColor(kind) ?? .clear).frame(width: 8, height: 8)

                if hasNotes {
                    Image(systemName: "note.text").font(.caption2).foregroundStyle(.secondary)
                }

                Spacer()

                if hrs > 0 {
                    Text(formatHours(hrs))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(earned > 0 ? Money.string(earned) : "—")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 72, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Year grid

    private var yearMonths: [Date] {
        let year = calendar.component(.year, from: displayedMonth)
        return (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
    }

    private var yearContent: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(yearMonths, id: \.self) { month in
                yearMonthCell(month)
            }
        }
    }

    private func yearMonthCell(_ month: Date) -> some View {
        let monthStats = WorkStats(sessions: sessions, now: month)
        let earned = monthStats.earnings(.month)
        let hrs = monthStats.hours(.month)
        let isCurrentMonth = calendar.isDate(month, equalTo: .now, toGranularity: .month)
        return Button {
            displayedMonth = month
            viewMode = .month
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(month.formatted(.dateTime.month(.wide)))
                    .font(.subheadline.weight(.semibold))
                if earned > 0 {
                    Text(Money.string(earned)).font(.caption).foregroundStyle(.secondary)
                    Text(formatHours(hrs)).font(.caption2).foregroundStyle(.tertiary)
                } else {
                    Text("—").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isCurrentMonth ? Color.appAccent : Color.appHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Imported calendars

    private var importedCalendarsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Calendriers importés", systemImage: "calendar.badge.clock")
                    .font(.headline)
                    .foregroundStyle(Color.appAccent)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(importedCalendars) { imported in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(imported.name).font(.subheadline.weight(.semibold))
                                Text("\(imported.sessions.count) jour(s) · importé le \(imported.importedAt.formatted(.dateTime.day().month().year()))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                calendarPendingDelete = imported
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(Color.moneyDanger)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Supprimer ce calendrier importé ?",
            isPresented: Binding(
                get: { calendarPendingDelete != nil },
                set: { if !$0 { calendarPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Supprimer les \(calendarPendingDelete?.sessions.count ?? 0) journée(s)", role: .destructive) {
                if let imported = calendarPendingDelete {
                    modelContext.delete(imported)
                }
                calendarPendingDelete = nil
            }
            Button("Annuler", role: .cancel) { calendarPendingDelete = nil }
        } message: {
            Text("Les journées importées par « \(calendarPendingDelete?.name ?? "") » seront retirées de votre agenda. Cette action est irréversible.")
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
        handle(ICSParser.parse(text), sourceName: url.deletingPathExtension().lastPathComponent)
    }

    private func importFromAppleCalendar() {
        #if canImport(EventKit)
        isImporting = true
        Task {
            let events = await EventKitService.fetchEvents()
            handle(events, sourceName: "Apple Calendrier")
        }
        #else
        importMessage = "Calendrier Apple indisponible sur cet appareil."
        #endif
    }

    private func handle(_ events: [ImportedEvent], sourceName: String) {
        guard !events.isEmpty else {
            isImporting = false
            importMessage = "Aucun événement trouvé."
            return
        }
        isImporting = true
        let existing = Set(sessions.map { calendar.startOfDay(for: $0.startDate) })
        Task {
            let calendarImport = ImportedCalendar(name: sourceName)
            let created = await CalendarImporter.makeSessions(
                from: events,
                hourlyRate: hourlyRate,
                perHour: enabledPerHour,
                fixed: enabledFixed,
                schoolPaid: schoolDaysPaid,
                useAI: true,
                existingDays: existing,
                importedCalendar: calendarImport
            )
            await MainActor.run {
                if created.isEmpty {
                    importMessage = "Rien de nouveau à importer."
                } else {
                    modelContext.insert(calendarImport)
                    for session in created { modelContext.insert(session) }
                    importMessage = "\(created.count) journée(s) importée(s)."
                }
                isImporting = false
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
        .modelContainer(for: [
            WorkSession.self, Benefit.self, Expense.self, VariableExpense.self,
            ImportedCalendar.self, DayNote.self
        ], inMemory: true)
}
