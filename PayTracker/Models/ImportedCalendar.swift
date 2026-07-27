import Foundation
import SwiftData

/// One "batch" of imported days — an .ics file or an Apple Calendar sync.
/// Deleting it removes every `WorkSession` it created (cascade), so the user
/// can undo an import without hunting down the individual days by hand.
@Model
final class ImportedCalendar {
    var name: String
    var importedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkSession.importedCalendar)
    var sessions: [WorkSession] = []

    init(name: String, importedAt: Date = .now) {
        // The name is a file name chosen by whoever produced the timetable.
        self.name = Sanitize.text(name, fallback: "Calendrier importé")
        self.importedAt = importedAt
    }
}
