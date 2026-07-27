import Foundation

/// A draft work session extracted from a sentence, shown for confirmation.
struct ParsedSession {
    var day: Date
    var arrival: Date       // only the time-of-day is used by the form
    var departure: Date
    var breakMinutes: Int
}

/// Turns "bossé de 9h à 17h avec 1h de pause hier" into structured times.
/// Uses Apple's on-device model when available (iOS 26+), otherwise a
/// heuristic that works everywhere — including iOS 17 and CI.
enum SessionTextParser {

    static func parse(_ text: String) async -> ParsedSession {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let ai = await AISessionParser.parse(text) {
            return ai
        }
        #endif
        return heuristicParse(text)
    }

    // MARK: - Heuristic fallback

    static func heuristicParse(_ text: String) -> ParsedSession {
        let day = ExpenseTextParser.detectDate(in: text)
        let times = detectTimes(in: text)
        let arrival = times.count >= 1 ? timeOn(day, times[0]) : defaultTime(on: day, hour: 9)
        let departure = times.count >= 2 ? timeOn(day, times[1]) : defaultTime(on: day, hour: 17)
        return ParsedSession(
            day: day,
            arrival: arrival,
            departure: departure,
            breakMinutes: detectBreakMinutes(in: text)
        )
    }

    /// All "9h", "9h30", "17h", "9:00" tokens, in order of appearance.
    static func detectTimes(in text: String) -> [(hour: Int, minute: Int)] {
        guard let re = try? NSRegularExpression(pattern: #"(\d{1,2})\s*[h:]\s*(\d{0,2})"#) else { return [] }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var result: [(Int, Int)] = []
        for m in re.matches(in: text, range: full) {
            let hour = Int(ns.substring(with: m.range(at: 1))) ?? -1
            let minRange = m.range(at: 2)
            let minute = minRange.length > 0 ? (Int(ns.substring(with: minRange)) ?? 0) : 0
            if (0..<24).contains(hour) && (0..<60).contains(minute) {
                result.append((hour, minute))
            }
        }
        return result
    }

    /// Break in minutes when the sentence mentions "pause" with a duration.
    /// Clamped to a day: the regex happily reads "999999 h de pause", and that
    /// number would go straight into a stored session.
    static func detectBreakMinutes(in text: String) -> Int {
        let t = text.lowercased()
        guard t.contains("pause") else { return 0 }
        if let hours = firstNumber(#"(\d+)\s*h[^0-9]*pause|pause[^0-9]*(\d+)\s*h"#, in: t) {
            // Clamp before multiplying — "9223372036854775807 h" would trap.
            return Sanitize.breakMinutes(min(hours, 24) * 60)
        }
        if let minutes = firstNumber(#"(\d+)\s*m(?:in)?[^0-9]*pause|pause[^0-9]*(\d+)\s*m(?:in)?"#, in: t) {
            return Sanitize.breakMinutes(minutes)
        }
        return 0
    }

    // MARK: - Helpers

    private static func timeOn(_ day: Date, _ hm: (hour: Int, minute: Int)) -> Date {
        Calendar.current.date(bySettingHour: hm.hour, minute: hm.minute, second: 0, of: day) ?? day
    }

    private static func defaultTime(on day: Date, hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    /// First non-nil numeric capture group of the first match.
    private static func firstNumber(_ pattern: String, in text: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let m = re.firstMatch(in: text, range: full) else { return nil }
        for i in 1..<m.numberOfRanges {
            let r = m.range(at: i)
            if r.length > 0 { return Int(ns.substring(with: r)) }
        }
        return nil
    }
}
