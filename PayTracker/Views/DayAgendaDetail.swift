import SwiftUI
import SwiftData

/// Everything about one calendar day: the work session logged that day (with
/// a shortcut to add/edit it) and the notes/rendez-vous attached to it.
struct DayAgendaDetail: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var sessionsThatDay: [WorkSession]
    @Query private var notes: [DayNote]

    @State private var editingSession: WorkSession?
    @State private var showingAddSession = false
    @State private var noteText = ""
    @State private var isAppointment = false
    @State private var appointmentTime = Date()

    init(date: Date) {
        self.date = date
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _sessionsThatDay = Query(
            filter: #Predicate<WorkSession> { $0.startDate >= start && $0.startDate < end },
            sort: \WorkSession.startDate
        )
        _notes = Query(filter: #Predicate<DayNote> { $0.day == start }, sort: \DayNote.createdAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sessionsSection
            Divider()
            notesSection
        }
        .sheet(item: $editingSession) { session in
            AddSessionView(session: session)
        }
        .sheet(isPresented: $showingAddSession) {
            AddSessionView(defaultDay: date)
        }
    }

    // MARK: - Session

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sessionsThatDay.isEmpty {
                Text("Aucune session ce jour.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessionsThatDay) { session in
                    sessionRow(session)
                }
            }
            Button {
                showingAddSession = true
            } label: {
                Label("Ajouter une session", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func sessionRow(_ session: WorkSession) -> some View {
        Button {
            editingSession = session
        } label: {
            HStack {
                Image(systemName: session.kind.systemImage)
                    .foregroundStyle(session.kind == .ecole ? Color.gold : Color.appAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeRange(session))
                        .font(.subheadline.weight(.semibold))
                    Text("\(formatHours(session.duration() / 3600)) · \(Money.string(session.totalPay()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func timeRange(_ session: WorkSession) -> String {
        let start = session.startDate.formatted(.dateTime.hour().minute())
        guard let end = session.endDate else { return "\(start) – en cours" }
        return "\(start) – \(end.formatted(.dateTime.hour().minute()))"
    }

    // MARK: - Notes & rendez-vous

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes & rendez-vous").font(.headline)

            if notes.isEmpty {
                Text("Rien de noté pour ce jour.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { note in
                    noteRow(note)
                }
            }

            TextField("Note ou rendez-vous", text: $noteText)
                .textFieldStyle(.roundedBorder)

            Toggle("Avec une heure (rendez-vous)", isOn: $isAppointment)
                .font(.subheadline)

            if isAppointment {
                DatePicker("Heure", selection: $appointmentTime, displayedComponents: .hourAndMinute)
                    .font(.subheadline)
            }

            Button(action: addNote) {
                Label("Ajouter", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func noteRow(_ note: DayNote) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: note.isAppointment ? "clock.fill" : "note.text")
                .foregroundStyle(note.isAppointment ? Color.gold : Color.appAccent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                if let time = note.time {
                    Text(time.formatted(.dateTime.hour().minute()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(note.text).font(.subheadline)
            }
            Spacer()
            Button {
                modelContext.delete(note)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private func addNote() {
        let text = noteText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let time = isAppointment ? combine(day: date, time: appointmentTime) : nil
        modelContext.insert(DayNote(day: date, text: text, time: time))
        noteText = ""
        isAppointment = false
    }

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

#Preview {
    DayAgendaDetail(date: .now)
        .padding()
        .modelContainer(for: [WorkSession.self, Benefit.self, DayNote.self], inMemory: true)
}
