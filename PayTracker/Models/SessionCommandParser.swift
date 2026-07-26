import Foundation

/// Turns a natural-language order into a structured ``SessionCommand``.
///
/// Just like ``SessionTextParser`` it uses Apple's on-device model when it is
/// available (iOS 26+ on a compatible iPhone) and otherwise falls back to a
/// heuristic that works everywhere — including iOS 17 and in CI, where the
/// Foundation Models SDK isn't present.
///
/// Unlike ``SessionTextParser`` (which only ever *adds* a day), this parser
/// also understands *modify* and *delete* orders about a **past** day, which is
/// what powers the conversational assistant.
enum SessionCommandParser {

    static func parse(_ text: String) async -> SessionCommand {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let ai = await AISessionCommandParser.parse(text) {
            return ai
        }
        #endif
        return heuristicParse(text)
    }

    /// Whether the on-device model can be used right now (device + OS support).
    static var isOnDeviceModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AISessionCommandParser.isAvailable
        }
        #endif
        return false
    }

    // MARK: - Heuristic fallback

    static func heuristicParse(_ text: String) -> SessionCommand {
        let lower = text.lowercased()
        let resolvedDay = detectDay(in: text)
        let times = SessionTextParser.detectTimes(in: text)
        let breakMin = detectBreakMinutes(in: lower)

        switch detectIntent(in: lower) {
        case .delete:
            return SessionCommand(
                intent: .delete, day: resolvedDay.date, hasExplicitDay: resolvedDay.explicit,
                arrival: nil, departure: nil, breakMinutes: nil, rawText: text
            )

        case .modify:
            let slots = classifyTimes(times, day: resolvedDay.date, text: lower)
            return SessionCommand(
                intent: .modify, day: resolvedDay.date, hasExplicitDay: resolvedDay.explicit,
                arrival: slots.arrival, departure: slots.departure,
                breakMinutes: mentionsBreak(lower) ? breakMin : nil,
                rawText: text
            )

        case .add:
            let arrival = times.count >= 1 ? time(times[0], on: resolvedDay.date)
                                           : defaultTime(hour: 9, on: resolvedDay.date)
            let departure = times.count >= 2 ? time(times[1], on: resolvedDay.date)
                                             : defaultTime(hour: 17, on: resolvedDay.date)
            return SessionCommand(
                intent: .add, day: resolvedDay.date, hasExplicitDay: resolvedDay.explicit,
                arrival: arrival, departure: departure,
                breakMinutes: mentionsBreak(lower) ? breakMin : 0,
                rawText: text
            )

        case .unknown:
            return SessionCommand(
                intent: .unknown, day: resolvedDay.date, hasExplicitDay: resolvedDay.explicit,
                arrival: nil, departure: nil, breakMinutes: nil, rawText: text
            )
        }
    }

    // MARK: - Intent

    static func detectIntent(in lower: String) -> SessionIntent {
        func has(_ words: [String]) -> Bool { words.contains { lower.contains($0) } }

        let deletes = ["supprim", "efface", "enlèv", "enlev", "retir", "annul", "vire ",
                       "vider", "delete", "remov"]
        let modifies = ["modif", "change", "chang", "corrig", "remplac", "ajust", "rectif",
                        "édit", "edit", "mets ", "met à", "met a ", "décale", "decale",
                        "plutôt", "plutot", "en fait", "finalement", "au lieu"]
        let adds = ["ajout", "rajout", "boss", "travaill", "note", "enregistr", "saisi",
                    "j'ai fait", "jai fait", "fais", "log", "pointe", "j'ai été", "bossé"]

        // « supprime la pause de lundi » removes the break — that's a modify, not
        // a whole-day delete. Only treat it as delete when a day/session is named.
        if has(deletes) {
            if lower.contains("pause") && !has(["journ", "session", "jour ", "la journée",
                                                "le jour", "mes heures", "la ligne"]) {
                return .modify
            }
            return .delete
        }
        if has(modifies) { return .modify }
        if has(adds) { return .add }
        // A bare sentence with times ("9h-17h hier") is understood as an add.
        if !SessionTextParser.detectTimes(in: lower).isEmpty { return .add }
        return .unknown
    }

    // MARK: - Which time is arrival, which is departure

    private struct TimeSlots { var arrival: Date?; var departure: Date? }

    private static func classifyTimes(
        _ times: [(hour: Int, minute: Int)], day: Date, text lower: String
    ) -> TimeSlots {
        if times.count >= 2 {
            return TimeSlots(arrival: time(times[0], on: day), departure: time(times[1], on: day))
        }
        guard let only = times.first else { return TimeSlots() }
        let arrivalWords = ["arriv", "commenc", "début", "debut", "embauch", "démarr",
                            "demarr", "de "]
        let departureWords = ["part", "fini", "fin ", "termin", "quitt", "sort", "débauch",
                              "debauch", "à ", "a "]
        let isArrival = arrivalWords.contains { lower.contains($0) }
        let isDeparture = departureWords.contains { lower.contains($0) }
        // Departure keywords are the more explicit signal ("parti à 18h").
        if isDeparture && !isArrival { return TimeSlots(arrival: nil, departure: time(only, on: day)) }
        if isArrival { return TimeSlots(arrival: time(only, on: day), departure: nil) }
        // No cue: a lone time on a modify is most often a new departure.
        return TimeSlots(arrival: nil, departure: time(only, on: day))
    }

    // MARK: - Break

    static func mentionsBreak(_ lower: String) -> Bool { lower.contains("pause") }

    /// Break in minutes, or 0 when a pause is named without a duration ("sans
    /// pause" / "supprime la pause"). Reuses the shared time-word logic.
    static func detectBreakMinutes(in lower: String) -> Int {
        guard lower.contains("pause") else { return 0 }
        if lower.contains("sans pause") || lower.contains("aucune pause")
            || lower.contains("pas de pause") || lower.contains("plus de pause")
            || lower.contains("supprim") || lower.contains("enlèv") || lower.contains("enlev")
            || lower.contains("retir") {
            return 0
        }
        return SessionTextParser.detectBreakMinutes(in: lower)
    }

    // MARK: - French date parsing

    /// Resolves the day the sentence talks about and whether it was explicit.
    /// Understands: hier / avant-hier / demain / aujourd'hui, « il y a N jours »,
    /// weekday names (optionally « dernier »), and « le 12 », « 12 juillet »,
    /// « 12/07 », « 12/07/2026 ».
    static func detectDay(in text: String) -> (date: Date, explicit: Bool) {
        let lower = text.lowercased()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if let n = numberOfDaysAgo(in: lower) {
            return (cal.date(byAdding: .day, value: -n, to: today) ?? today, true)
        }
        if lower.contains("avant-hier") || lower.contains("avant hier") {
            return (cal.date(byAdding: .day, value: -2, to: today) ?? today, true)
        }
        if lower.contains("hier") {
            return (cal.date(byAdding: .day, value: -1, to: today) ?? today, true)
        }
        if lower.contains("demain") {
            return (cal.date(byAdding: .day, value: 1, to: today) ?? today, true)
        }
        if lower.contains("aujourd") {
            return (today, true)
        }
        if let numeric = numericDate(in: lower, calendar: cal, today: today) {
            return (numeric, true)
        }
        if let weekday = weekday(in: lower, calendar: cal, today: today) {
            return (weekday, true)
        }
        return (today, false)
    }

    private static func numberOfDaysAgo(in lower: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: #"il y a\s+(\d{1,3})\s*jour"#) else { return nil }
        let ns = lower as NSString
        guard let m = re.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1 else { return nil }
        return Int(ns.substring(with: m.range(at: 1)))
    }

    private static let weekdayIndex: [String: Int] = [
        "dimanche": 1, "lundi": 2, "mardi": 3, "mercredi": 4,
        "jeudi": 5, "vendredi": 6, "samedi": 7
    ]

    /// Most recent past occurrence of a named weekday (today if it matches and
    /// « dernier » isn't used). « lundi dernier » always jumps a full week back.
    private static func weekday(in lower: String, calendar cal: Calendar, today: Date) -> Date? {
        for (name, target) in weekdayIndex where lower.contains(name) {
            let current = cal.component(.weekday, from: today)
            var diff = (current - target + 7) % 7  // days back to the most recent one
            let wantsLast = lower.contains("dernier") || lower.contains("dernière")
                || lower.contains("derniere")
            // "lundi" on a Monday means today, unless they said "lundi dernier".
            if diff == 0 && wantsLast { diff = 7 }
            return cal.date(byAdding: .day, value: -diff, to: today)
        }
        return nil
    }

    private static let monthIndex: [String: Int] = [
        "janvier": 1, "février": 2, "fevrier": 2, "mars": 3, "avril": 4, "mai": 5,
        "juin": 6, "juillet": 7, "août": 8, "aout": 8, "septembre": 9, "octobre": 10,
        "novembre": 11, "décembre": 12, "decembre": 12
    ]

    /// « 12/07 », « 12/07/2026 », « 12 juillet », « le 12 » (current month).
    private static func numericDate(in lower: String, calendar cal: Calendar, today: Date) -> Date? {
        let comps = cal.dateComponents([.year, .month, .day], from: today)
        let currentYear = comps.year ?? 2025
        let currentMonth = comps.month ?? 1

        // dd/mm or dd/mm/yyyy
        if let re = try? NSRegularExpression(pattern: #"\b(\d{1,2})[/\-.](\d{1,2})(?:[/\-.](\d{2,4}))?\b"#) {
            let ns = lower as NSString
            if let m = re.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)) {
                let day = Int(ns.substring(with: m.range(at: 1))) ?? 0
                let month = Int(ns.substring(with: m.range(at: 2))) ?? 0
                var year = currentYear
                if m.range(at: 3).location != NSNotFound {
                    let y = Int(ns.substring(with: m.range(at: 3))) ?? currentYear
                    year = y < 100 ? 2000 + y : y
                }
                if (1...31).contains(day) && (1...12).contains(month) {
                    return date(cal, year: year, month: month, day: day)
                }
            }
        }

        // "12 juillet" / "le 12 juillet"
        for (name, month) in monthIndex where lower.contains(name) {
            if let re = try? NSRegularExpression(pattern: #"\b(\d{1,2})\b"#) {
                let ns = lower as NSString
                if let m = re.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)),
                   let day = Int(ns.substring(with: m.range(at: 1))), (1...31).contains(day) {
                    return date(cal, year: currentYear, month: month, day: day)
                }
            }
        }

        // "le 12" — a day number in the current month.
        if let re = try? NSRegularExpression(pattern: #"\ble\s+(\d{1,2})\b"#) {
            let ns = lower as NSString
            if let m = re.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)),
               let day = Int(ns.substring(with: m.range(at: 1))), (1...31).contains(day) {
                return date(cal, year: currentYear, month: currentMonth, day: day)
            }
        }
        return nil
    }

    // MARK: - Small date helpers

    private static func date(_ cal: Calendar, year: Int, month: Int, day: Int) -> Date? {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return cal.date(from: c).map { cal.startOfDay(for: $0) }
    }

    private static func time(_ hm: (hour: Int, minute: Int), on day: Date) -> Date {
        Calendar.current.date(bySettingHour: hm.hour, minute: hm.minute, second: 0, of: day) ?? day
    }

    private static func defaultTime(hour: Int, on day: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }
}
