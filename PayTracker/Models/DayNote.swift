import Foundation
import SwiftData

/// A free-form note or a timed appointment attached to a calendar day.
/// `time` is nil for a plain note, set for a rendez-vous ("14h30 - dentiste").
@Model
final class DayNote {
    var day: Date
    var text: String
    var time: Date?
    var createdAt: Date

    init(day: Date, text: String, time: Date? = nil, createdAt: Date = .now) {
        self.day = Calendar.current.startOfDay(for: day)
        self.text = Sanitize.text(text, fallback: "Note", maxLength: Sanitize.maxTitleLength)
        self.time = time
        self.createdAt = createdAt
    }

    var isAppointment: Bool { time != nil }
}
