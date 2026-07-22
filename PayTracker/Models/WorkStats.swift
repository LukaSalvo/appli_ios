import Foundation

/// Hours worked on a single day — one bar in the weekly chart.
struct DailyHours: Identifiable {
    let id = UUID()
    let date: Date
    let hours: Double
}

/// The period the user is looking at in the hours breakdown.
enum StatsPeriod: String, CaseIterable, Identifiable {
    case day = "Jour"
    case week = "Semaine"
    case month = "Mois"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }
}

/// Aggregates completed work sessions into hours / earnings / counts for a
/// day, week or month, plus a per-day breakdown for the current week.
struct WorkStats {
    let sessions: [WorkSession]
    var calendar: Calendar = .current
    var now: Date = Date()

    private func interval(for component: Calendar.Component) -> DateInterval {
        calendar.dateInterval(of: component, for: now) ?? DateInterval(start: now, duration: 0)
    }

    private func sessions(in interval: DateInterval) -> [WorkSession] {
        sessions.filter { interval.contains($0.startDate) }
    }

    func hours(_ period: StatsPeriod) -> Double {
        sessions(in: interval(for: period.calendarComponent))
            .reduce(0) { $0 + $1.duration() } / 3600
    }

    func earnings(_ period: StatsPeriod) -> Double {
        sessions(in: interval(for: period.calendarComponent))
            .reduce(0) { $0 + $1.totalPay() }
    }

    func sessionCount(_ period: StatsPeriod) -> Int {
        sessions(in: interval(for: period.calendarComponent)).count
    }

    /// Hours per day across the current week, for the bar chart.
    var currentWeek: [DailyHours] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        var result: [DailyHours] = []
        var day = week.start
        for _ in 0..<7 {
            let dayInterval = DateInterval(start: day, duration: 24 * 3600)
            let hours = sessions
                .filter { dayInterval.contains($0.startDate) }
                .reduce(0) { $0 + $1.duration() } / 3600
            result.append(DailyHours(date: day, hours: hours))
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 3600)
        }
        return result
    }

    var isToday: (Date) -> Bool {
        { [calendar, now] date in calendar.isDate(date, inSameDayAs: now) }
    }
}

/// "6 h 30", "45 min", "8 h" — a compact, human hours label.
func formatHours(_ hours: Double) -> String {
    let totalMinutes = Int((hours * 60).rounded())
    let h = totalMinutes / 60
    let m = totalMinutes % 60
    if h == 0 { return "\(m) min" }
    if m == 0 { return "\(h) h" }
    return "\(h) h \(String(format: "%02d", m))"
}
