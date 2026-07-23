#if canImport(EventKit)
import Foundation
import EventKit

/// Reads events from Apple Calendar so they can be imported into the app.
enum EventKitService {

    /// Ask for calendar access, then return events in a window around today.
    static func fetchEvents(daysBack: Int = 30, daysForward: Int = 90) async -> [ImportedEvent] {
        let store = EKEventStore()
        guard await requestAccess(store) else { return [] }

        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let end = calendar.date(byAdding: .day, value: daysForward, to: Date()) ?? Date()

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map {
            ImportedEvent(
                title: $0.title ?? "Événement",
                start: $0.startDate,
                end: $0.endDate ?? $0.startDate.addingTimeInterval(3600)
            )
        }
    }

    private static func requestAccess(_ store: EKEventStore) async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                store.requestFullAccessToEvents { granted, _ in continuation.resume(returning: granted) }
            } else {
                store.requestAccess(to: .event) { granted, _ in continuation.resume(returning: granted) }
            }
        }
    }
}
#endif
