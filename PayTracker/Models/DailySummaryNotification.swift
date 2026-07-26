import Foundation
import UserNotifications

/// Daily 18:00 recap of the day's work and the week's progress toward the
/// weekly contract (35 h by default).
///
/// A local notification carries **static** content fixed when it is scheduled —
/// it can't run code at fire time. So we recompute the figures and re-schedule
/// this notification whenever the app has fresh data (foreground, or a session
/// changed). The trigger itself repeats every day at 18:00 so the reminder
/// keeps firing even if the app isn't opened; its content reflects the last
/// time the app refreshed it.
enum DailySummaryNotification {
    static let identifier = "daily-summary-18h"
    static let fireHour = 18
    static let fireMinute = 0

    /// Re-schedule (or cancel) the 18:00 recap with the latest figures.
    ///
    /// Handles authorization transparently: asks the first time, and silently
    /// does nothing if the user has denied notifications.
    static func refresh(
        enabled: Bool,
        hoursToday: Double,
        earningsToday: Double,
        weeklyHours: Double,
        weeklyTarget: Double
    ) {
        let center = UNUserNotificationCenter.current()
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        let body = makeBody(
            hoursToday: hoursToday,
            earningsToday: earningsToday,
            weeklyHours: weeklyHours,
            weeklyTarget: weeklyTarget
        )

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                schedule(body: body)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { schedule(body: body) }
                }
            default:
                break // denied — respect the user's choice
            }
        }
    }

    /// Stop posting the daily recap.
    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Private

    private static func schedule(body: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Bilan de la journée"
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = fireHour
        components.minute = fireMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// Two-line recap: today's hours + pay, then the week's progress toward the
    /// contract and the time left to reach it. Kept as a static helper so it can
    /// be unit-tested and reused.
    static func makeBody(
        hoursToday: Double,
        earningsToday: Double,
        weeklyHours: Double,
        weeklyTarget: Double
    ) -> String {
        let today = "Aujourd'hui : \(formatHours(hoursToday)) travaillées · \(Money.string(earningsToday))"

        guard weeklyTarget > 0 else { return today }
        let remaining = weeklyTarget - weeklyHours
        let week: String
        if remaining <= 0 {
            week = "Semaine : \(formatHours(weeklyHours)) — objectif de \(formatHours(weeklyTarget)) atteint 🎉"
        } else {
            week = "Semaine : \(formatHours(weeklyHours)) / \(formatHours(weeklyTarget)) — il reste \(formatHours(remaining)) pour tes \(formatHours(weeklyTarget))"
        }
        return "\(today)\n\(week)"
    }
}
