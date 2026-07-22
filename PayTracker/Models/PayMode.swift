import Foundation

/// How the user is paid: by the hour (with live tracking) or a fixed monthly salary.
enum PayMode: String, Codable, CaseIterable, Identifiable {
    case hourly = "À l'heure"
    case monthly = "Au mois"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .hourly: return "clock.fill"
        case .monthly: return "calendar"
        }
    }
}

/// Shared currency formatting so every screen shows amounts the same way.
enum Money {
    static func string(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR"))
    }
}

/// Fraction of the current month that has elapsed (0...1), used to accrue a
/// monthly salary "so far this month" in real time.
func monthElapsedFraction(now: Date = Date(), calendar: Calendar = .current) -> Double {
    guard
        let interval = calendar.dateInterval(of: .month, for: now),
        interval.duration > 0
    else { return 0 }
    let elapsed = now.timeIntervalSince(interval.start)
    return min(max(elapsed / interval.duration, 0), 1)
}
