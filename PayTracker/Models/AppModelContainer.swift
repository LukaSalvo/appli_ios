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

    static let shared: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()
}
