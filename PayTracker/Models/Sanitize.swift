import Foundation

/// Guard-rails for every value that reaches the app from somewhere other than a
/// tap in its own UI — an imported backup, an `.ics` file, Apple Calendar, a
/// dictation, or the on-device model.
///
/// Two families of checks matter here:
///
/// - **Text** displayed in the app must not carry control or bidirectional
///   override characters. Those have no legitimate use in an expense name or a
///   calendar title, and they are the classic way to make a label render as
///   something other than what is stored (a right-to-left override can visually
///   reverse an amount or hide the tail of a string).
/// - **Numbers** must stay finite and inside a plausible range. A `NaN` or a
///   `1e308` hourly rate does not stay put: it propagates into every total, the
///   budget ring, the projected balance, the notifications and the next export.
enum Sanitize {

    // MARK: - Text

    static let maxNameLength = 120
    static let maxTitleLength = 200

    /// Strips control/bidi characters, collapses whitespace and truncates.
    /// Returns an empty string when nothing printable is left.
    static func text(_ raw: String, maxLength: Int = maxNameLength) -> String {
        var stripped = ""
        stripped.unicodeScalars.append(contentsOf: raw.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) && !bidiControls.contains($0)
        })
        var value = stripped
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count > maxLength {
            value = String(value.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        }
        return value
    }

    /// Same as ``text(_:maxLength:)`` but never returns an empty string.
    static func text(_ raw: String, fallback: String, maxLength: Int = maxNameLength) -> String {
        let cleaned = text(raw, maxLength: maxLength)
        return cleaned.isEmpty ? fallback : cleaned
    }

    /// Unicode bidi marks, embeddings, overrides and isolates. Ordinary
    /// right-to-left text renders correctly without any of them.
    private static let bidiControls = CharacterSet(charactersIn:
        "\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}")

    // MARK: - Numbers

    /// Ceiling for a single euro amount (a salary, a rent, an account balance).
    static let maxAmount: Double = 1_000_000
    /// Ceiling for an hourly rate or a per-hour benefit.
    static let maxRate: Double = 10_000
    /// No single session can legitimately span more than a full day.
    static let maxSessionDuration: TimeInterval = 24 * 3600

    /// Finite and inside `range` — `NaN` and `±inf` collapse to the lower bound.
    static func number(_ value: Double, in range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// A positive euro amount.
    static func amount(_ value: Double) -> Double { number(value, in: 0...maxAmount) }

    /// A euro amount that may legitimately be negative (an account balance).
    static func signedAmount(_ value: Double) -> Double { number(value, in: -maxAmount...maxAmount) }

    /// An hourly rate or per-hour benefit.
    static func rate(_ value: Double) -> Double { number(value, in: 0...maxRate) }

    /// A break duration in seconds, never longer than the session that holds it.
    static func breakSeconds(_ value: TimeInterval, within gross: TimeInterval) -> TimeInterval {
        number(value, in: 0...max(0, min(gross, maxSessionDuration)))
    }

    /// A break in minutes, as produced by a text parse or the on-device model.
    /// Both can return an arbitrary integer from a sentence like « 999999 h de
    /// pause ».
    static func breakMinutes(_ value: Int) -> Int {
        min(max(value, 0), Int(maxSessionDuration / 60))
    }

    // MARK: - Dates

    /// 2000-01-01. Anything older in this app is a corrupt record, not history.
    static let earliestDate = Date(timeIntervalSince1970: 946_684_800)

    /// Dates are accepted from 2000 up to five years out (imported timetables
    /// legitimately run into the future; a year 9999 timestamp does not).
    static func isPlausible(_ date: Date, now: Date = Date()) -> Bool {
        date >= earliestDate && date <= now.addingTimeInterval(5 * 365 * 24 * 3600)
    }
}
