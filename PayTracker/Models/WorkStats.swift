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
    case year = "Année"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

/// Aggregates completed work sessions into hours / earnings / counts.
///
/// Hours are computed **day by day**: every session is clipped to each
/// calendar day it touches (so a night shift is split across midnight instead
/// of being dumped onto its start day), its break is spread proportionally,
/// and a single day can never exceed 24 h. This is what keeps impossible
/// totals like "26 h in one day" from ever appearing.
struct WorkStats {
    let sessions: [WorkSession]
    var calendar: Calendar = .current
    var now: Date = Date()

    /// Worked seconds of one session that fall inside [dayStart, dayEnd).
    private func workedSeconds(_ session: WorkSession, dayStart: Date, dayEnd: Date) -> TimeInterval {
        guard let end = session.endDate else { return 0 }
        let start = session.startDate
        let overlapStart = max(start, dayStart)
        let overlapEnd = min(end, dayEnd)
        let clipped = overlapEnd.timeIntervalSince(overlapStart)
        guard clipped > 0 else { return 0 }

        let gross = end.timeIntervalSince(start)
        guard gross > 0 else { return 0 }

        // Distribute the break proportionally over the time actually spanned.
        let workedFraction = max(0, (gross - session.breakDuration) / gross)
        return clipped * workedFraction
    }

    /// Total worked hours on the calendar day containing `date` (capped at 24 h).
    func hoursOnDay(_ date: Date) -> Double {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 3600)
        let total = sessions.reduce(0) {
            $0 + workedSeconds($1, dayStart: dayStart, dayEnd: dayEnd)
        }
        return min(total, 24 * 3600) / 3600
    }

    private func days(in period: StatsPeriod) -> [Date] {
        guard let interval = calendar.dateInterval(of: period.calendarComponent, for: now) else { return [] }
        var days: [Date] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 3600)
        }
        return days
    }

    func hours(_ period: StatsPeriod) -> Double {
        days(in: period).reduce(0) { $0 + hoursOnDay($1) }
    }

    private func interval(for period: StatsPeriod) -> DateInterval {
        calendar.dateInterval(of: period.calendarComponent, for: now)
            ?? DateInterval(start: now, duration: 0)
    }

    func earnings(_ period: StatsPeriod) -> Double {
        let iv = interval(for: period)
        return sessions.filter { iv.contains($0.startDate) }.reduce(0) { $0 + $1.totalPay() }
    }

    func sessionCount(_ period: StatsPeriod) -> Int {
        let iv = interval(for: period)
        return sessions.filter { iv.contains($0.startDate) }.count
    }

    /// Pay from sessions that started on the given calendar day.
    func earnings(onDay date: Date) -> Double {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return sessions
            .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
            .reduce(0) { $0 + $1.totalPay() }
    }

    /// The dominant day kind (school wins over company) for a given day, or nil.
    func kind(onDay date: Date) -> SessionKind? {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let kinds = sessions
            .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
            .map(\.kind)
        if kinds.contains(.ecole) { return .ecole }
        if kinds.contains(.entreprise) { return .entreprise }
        return kinds.first
    }

    /// Hours per day across the current week, for the bar chart.
    var currentWeek: [DailyHours] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        var result: [DailyHours] = []
        var day = calendar.startOfDay(for: week.start)
        for _ in 0..<7 {
            result.append(DailyHours(date: day, hours: hoursOnDay(day)))
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 3600)
        }
        return result
    }

    var isToday: (Date) -> Bool {
        { [calendar, now] date in calendar.isDate(date, inSameDayAs: now) }
    }

    // MARK: - Overtime (current week)

    /// Total hours worked in the current week.
    var weeklyTotal: Double {
        currentWeek.reduce(0) { $0 + $1.hours }
    }

    /// Overtime hours for the current week.
    ///
    /// - flexible `true` ("entreprise flexible") : only the hours beyond the
    ///   weekly contract count, whatever the daily spread. So 7h15 × 4 + 6h =
    ///   35 h stays a normal 35 h week, with no overtime.
    /// - flexible `false` : each day above its share (contract ÷ jours) counts,
    ///   so a 7h15 day already generates 15 min of overtime.
    func weeklyOvertime(weeklyContract: Double, daysPerWeek: Int, flexible: Bool) -> Double {
        guard weeklyContract > 0 else { return 0 }
        let daily = currentWeek.map(\.hours)
        if flexible {
            return max(0, daily.reduce(0, +) - weeklyContract)
        }
        let dailyContract = daysPerWeek > 0 ? weeklyContract / Double(daysPerWeek) : 0
        return daily.reduce(0) { $0 + max(0, $1 - dailyContract) }
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
