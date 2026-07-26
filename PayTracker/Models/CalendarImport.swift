import Foundation

/// A calendar event coming from an .ics file or from Apple Calendar.
struct ImportedEvent {
    var title: String
    var start: Date
    var end: Date
}

// MARK: - ICS parsing

/// Minimal iCalendar (.ics) parser: pulls SUMMARY / DTSTART / DTEND out of each
/// VEVENT. Good enough for a school/company timetable export.
enum ICSParser {
    static func parse(_ text: String) -> [ImportedEvent] {
        let lines = unfold(text).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var events: [ImportedEvent] = []
        var inEvent = false
        var summary = ""
        var start: Date?
        var end: Date?

        for raw in lines {
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            switch true {
            case line == "BEGIN:VEVENT":
                inEvent = true; summary = ""; start = nil; end = nil
            case line == "END:VEVENT":
                if let s = start {
                    events.append(ImportedEvent(
                        title: summary.isEmpty ? "Événement" : summary,
                        start: s,
                        end: end ?? s.addingTimeInterval(3600)
                    ))
                }
                inEvent = false
            case inEvent:
                if let v = value(of: "SUMMARY", in: line) { summary = unescape(v) }
                else if line.hasPrefix("DTSTART") { start = parseDate(line) }
                else if line.hasPrefix("DTEND") { end = parseDate(line) }
            default:
                break
            }
        }
        return events
    }

    /// RFC 5545 line unfolding (a CRLF followed by space/tab is a continuation).
    private static func unfold(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
    }

    private static func value(of key: String, in line: String) -> String? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let name = line[..<colon].split(separator: ";").first.map(String.init) ?? String(line[..<colon])
        guard name == key else { return nil }
        return String(line[line.index(after: colon)...])
    }

    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func parseDate(_ line: String) -> Date? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let params = String(line[..<colon])
        let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if params.contains("VALUE=DATE") || value.count == 8 {
            formatter.dateFormat = "yyyyMMdd"
            formatter.timeZone = .current
            return formatter.date(from: value)
        }
        if value.hasSuffix("Z") {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
        } else {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
            formatter.timeZone = .current // TZID approximated as local time
        }
        return formatter.date(from: value)
    }
}

// MARK: - Classification

/// Decides whether an event is a school day, a company day, or neither —
/// from keywords. The AI classifier refines the "autre" cases when available.
enum ScheduleClassifier {
    static func heuristic(_ title: String) -> SessionKind {
        let t = title.lowercased()
        let school = ["cours", "td", "tp", "amphi", "école", "ecole", "universit",
                      "fac", "exam", "partiel", "soutenance", "licence", "master",
                      "bts", "semestre", "module", "promo", "campus", "lecture"]
        if school.contains(where: { t.contains($0) }) { return .ecole }
        let work = ["entreprise", "mission", "travail", "boulot", "réunion",
                    "reunion", "client", "bureau", "atelier", "chantier", "poste"]
        if work.contains(where: { t.contains($0) }) { return .entreprise }
        return .autre
    }
}

// MARK: - Import orchestration

enum CalendarImporter {
    /// Build one work session per day from the imported events. Days are
    /// classified school/company; school days are filled 8 h–17 h (as an
    /// alternance day), company days use the events' actual span.
    ///
    /// - schoolPaid: when false, school days are recorded with a 0 rate so they
    ///   appear on the agenda without adding to earnings.
    /// - existingDays: days already having a session, skipped to avoid dupes.
    static func makeSessions(
        from events: [ImportedEvent],
        hourlyRate: Double,
        perHour: Double,
        fixed: Double,
        schoolPaid: Bool,
        useAI: Bool,
        existingDays: Set<Date>,
        importedCalendar: ImportedCalendar? = nil
    ) async -> [WorkSession] {
        let calendar = Calendar.current

        // Classify each distinct title once.
        var kindByTitle: [String: SessionKind] = [:]
        for title in Set(events.map(\.title)) {
            var kind = ScheduleClassifier.heuristic(title)
            #if canImport(FoundationModels)
            if kind == .autre, useAI, #available(iOS 26.0, *),
               let ai = await AIScheduleClassifier.classify(title) {
                kind = ai
            }
            #endif
            kindByTitle[title] = kind
        }

        // Group events by calendar day.
        var byDay: [Date: [ImportedEvent]] = [:]
        for event in events {
            byDay[calendar.startOfDay(for: event.start), default: []].append(event)
        }

        var sessions: [WorkSession] = []
        for (day, dayEvents) in byDay {
            guard !existingDays.contains(day) else { continue }

            let kinds = dayEvents.map { kindByTitle[$0.title] ?? .autre }
            let dayKind: SessionKind
            if kinds.contains(.ecole) { dayKind = .ecole }
            else if kinds.contains(.entreprise) { dayKind = .entreprise }
            else { continue } // only "autre" events → skip the day

            let (start, end) = span(for: dayKind, day: day, events: dayEvents, calendar: calendar)
            let paid = dayKind != .ecole || schoolPaid
            let session = WorkSession(
                startDate: start,
                endDate: end,
                hourlyRateSnapshot: paid ? hourlyRate : 0,
                perHourBenefitsSnapshot: paid ? perHour : 0,
                fixedBenefitsSnapshot: paid ? fixed : 0,
                kind: dayKind,
                importedCalendar: importedCalendar
            )
            sessions.append(session)
        }
        return sessions.sorted { $0.startDate < $1.startDate }
    }

    private static func span(
        for kind: SessionKind, day: Date, events: [ImportedEvent], calendar: Calendar
    ) -> (Date, Date) {
        // A school day is a standard 8 h–17 h day, as requested.
        if kind == .ecole {
            let s = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? day
            let e = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day) ?? day
            return (s, e)
        }
        // A company day uses the events' real span, with an 8 h–17 h fallback.
        let start = events.map(\.start).min() ?? day
        let end = events.map(\.end).max() ?? day
        if end.timeIntervalSince(start) >= 3600 { return (start, end) }
        let s = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? start
        let e = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day) ?? end
        return (s, e)
    }
}
