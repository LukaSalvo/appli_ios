import SwiftData

/// The single source of truth for the app's SwiftData store — shared between
/// the app UI and the Siri App Intents, which run out-of-process and must
/// resolve to the exact same on-disk store to see/save the same data.
enum AppModelContainer {
    static let schema = Schema([
        WorkSession.self,
        Benefit.self,
        Expense.self,
        VariableExpense.self,
        ImportedCalendar.self,
        DayNote.self
    ])

    static var shared: ModelContainer { resolved.container }

    /// True when the on-disk store could not be opened and the app is running
    /// on a throw-away in-memory store — nothing typed will survive a relaunch,
    /// so the UI warns instead of silently losing entries.
    static var isUsingMemoryFallback: Bool { resolved.isMemoryFallback }

    // MARK: - Private

    private struct Resolved {
        let container: ModelContainer
        let isMemoryFallback: Bool
    }

    private static let resolved: Resolved = make()

    /// Opening the store can fail — a partially written file, a store left
    /// behind by a newer build, a device out of space. Failing hard here (the
    /// former `try!`) turned any of those into a crash on every single launch,
    /// with no way back other than deleting the app and its data. Falling back
    /// to memory keeps the app openable, so the user can still export or fix
    /// their setup.
    private static func make() -> Resolved {
        if let onDisk = try? ModelContainer(for: schema,
                                            configurations: [ModelConfiguration(schema: schema)]) {
            return Resolved(container: onDisk, isMemoryFallback: false)
        }

        let memoryOnly = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // An in-memory container has no I/O left to fail on: reaching this and
        // failing again would mean the schema itself is invalid, which is a
        // programming error rather than a runtime condition.
        let fallback = try! ModelContainer(for: schema, configurations: [memoryOnly])
        return Resolved(container: fallback, isMemoryFallback: true)
    }
}
