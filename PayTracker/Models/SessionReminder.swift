import Foundation
import UserNotifications

/// Local notification that nudges the user to end a live session they may have
/// forgotten to stop — a running session keeps accruing pay on the wall clock,
/// so a forgotten one would silently inflate the day's total.
enum SessionReminder {
    private static let identifier = "active-session-reminder"

    /// Ask once for permission to post local notifications.
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Schedule the reminder to fire `hours` after the session started.
    /// Replaces any pending reminder so only the current session is tracked.
    static func schedule(hours: Double, startedAt: Date = .now) {
        guard hours > 0 else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Time remaining until the reminder should fire, relative to now.
        let fireDelay = startedAt.addingTimeInterval(hours * 3600).timeIntervalSinceNow
        guard fireDelay > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Session toujours en cours"
        content.body = "Tu pointes depuis un moment — pense à terminer ta session pour figer ta paie."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDelay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// Cancel the reminder — called when the session is ended.
    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
