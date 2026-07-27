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
///
/// The file is user-picked but externally authored — a school's export, a link
/// someone sent, a subscribed calendar. It is therefore parsed defensively:
/// bounded in size before it is even read (see ``Limits/maxFileBytes``), capped
/// in event count, with titles sanitised and durations clamped, so a hostile or
/// simply broken file cannot exhaust memory or flood the agenda.
enum ICSParser {

    enum Limits {
        /// A year of a school timetable is a few hundred kilobytes.
        static let maxFileBytes = 4 * 1024 * 1024
        /// Enough for several years of daily events; beyond this the rest is dropped.
        static let maxEvents = 5_000
        /// An event longer than a day says more about the file than the day.
        static let maxEventDuration: TimeInterval = 24 * 3600
    }

    static func parse(_ text: String) -> [ImportedEvent] {
        let lines = unfold(text).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var events: [ImportedEvent] = []
        var inEvent = false
        var summary = ""
        var start: Date?
        var end: Date?

        for raw in lines {
            guard events.count < Limits.maxEvents else { break }
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            switch true {
            case line == "BEGIN:VEVENT":
                inEvent = true; summary = ""; start = nil; end = nil
            case line == "END:VEVENT":
                if let s = start, Sanitize.isPlausible(s) {
                    events.append(makeEvent(title: summary, start: s, end: end))
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

    /// Builds an event with a display-safe title and a sane duration.
    static func makeEvent(title: String, start: Date, end: Date?) -> ImportedEvent {
        let safeTitle = Sanitize.text(title, fallback: "Événement", maxLength: Sanitize.maxTitleLength)
        var finish = end ?? start.addingTimeInterval(3600)
        // An end before the start, or a multi-week "event", would otherwise be
        // taken at face value and billed as worked time.
        if finish <= start { finish = start.addingTimeInterval(3600) }
        let maxFinish = start.addingTimeInterval(Limits.maxEventDuration)
        if finish > maxFinish { finish = maxFinish }
        return ImportedEvent(title: safeTitle, start: start, end: finish)
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

    enum Limits {
        /// A single import may not create more days than this — roughly four
        /// years of work. It bounds both the write burst and the undo.
        static let maxSessions = 1_500
        /// How many distinct titles are worth asking the on-device model about.
        /// Past this the keyword heuristic decides on its own, which keeps a
        /// file full of unique titles from turning into thousands of inferences.
        static let maxAIClassifications = 200
    }

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
        var aiCalls = 0
        for title in Set(events.map(\.title)) {
            var kind = ScheduleClassifier.heuristic(title)
            #if canImport(FoundationModels)
            if kind == .autre, useAI, aiCalls < Limits.maxAIClassifications,
               #available(iOS 26.0, *) {
                aiCalls += 1
                if let ai = await AIScheduleClassifier.classify(title) { kind = ai }
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
            guard sessions.count < Limits.maxSessions else { break }
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
                // The rates come from settings, but an imported day is written
                // straight to the store — keep them in range at the boundary.
                hourlyRateSnapshot: paid ? Sanitize.rate(hourlyRate) : 0,
                perHourBenefitsSnapshot: paid ? Sanitize.rate(perHour) : 0,
                fixedBenefitsSnapshot: paid ? Sanitize.amount(fixed) : 0,
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
        let rawEnd = events.map(\.end).max() ?? day
        // Several back-to-back events can still add up past midnight; a single
        // logged day never exceeds 24 h.
        let end = min(rawEnd, start.addingTimeInterval(ICSParser.Limits.maxEventDuration))
        if end.timeIntervalSince(start) >= 3600 { return (start, end) }
        let s = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? start
        let e = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day) ?? end
        return (s, e)
    }
}
