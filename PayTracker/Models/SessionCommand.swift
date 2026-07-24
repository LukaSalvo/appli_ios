import Foundation

/// What the user wants the assistant to do with a work day.
enum SessionIntent: String {
    case add       // create a new day
    case modify    // change the hours of an existing day
    case delete    // remove a day
    case unknown   // couldn't tell — ask the user to rephrase
}

/// A structured order extracted from a free-text (or dictated) sentence such as
/// « supprime mes heures de lundi » or « modifie hier, je suis parti à 18h ».
///
/// Times are optional: on a *modify* only the fields actually mentioned are set,
/// so « change jeudi, 1h de pause » keeps the arrival and departure untouched.
struct SessionCommand {
    var intent: SessionIntent
    /// The calendar day the order targets (a new day for `.add`).
    var day: Date
    /// Whether the sentence explicitly named a day (vs. defaulting to today).
    var hasExplicitDay: Bool

    /// Arrival time-of-day, when the sentence mentions it.
    var arrival: Date?
    /// Departure time-of-day, when the sentence mentions it.
    var departure: Date?
    /// Break in minutes, when the sentence mentions it.
    var breakMinutes: Int?

    var rawText: String

    /// True when the order carries nothing actionable for a modify.
    var hasAnyField: Bool { arrival != nil || departure != nil || breakMinutes != nil }
}
