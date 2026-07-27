import Foundation
import SwiftData

/// What a day represents — useful for work-study ("alternance") where the
/// calendar mixes company days and school days.
enum SessionKind: String, Codable, CaseIterable, Identifiable {
    case entreprise = "Entreprise"
    case ecole = "École"
    case autre = "Autre"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .entreprise: return "building.2.fill"
        case .ecole: return "graduationcap.fill"
        case .autre: return "calendar"
        }
    }
}

@Model
final class WorkSession {
    var startDate: Date
    var endDate: Date?

    /// Total break time (in seconds) subtracted from the worked hours —
    /// e.g. a lunch break between arrival and departure.
    var breakDuration: TimeInterval = 0

    // Snapshot of the rate/benefits at the time the session started, so past
    // sessions stay accurate even if the user later edits their settings.
    var hourlyRateSnapshot: Double
    var perHourBenefitsSnapshot: Double
    var fixedBenefitsSnapshot: Double

    /// Company / school / other — defaults to company for existing data.
    var kindRaw: String = SessionKind.entreprise.rawValue

    var kind: SessionKind {
        get { SessionKind(rawValue: kindRaw) ?? .entreprise }
        set { kindRaw = newValue.rawValue }
    }

    /// The calendar import that created this session, if any — nil for
    /// sessions logged by hand. Deleting the import cascades to this session.
    var importedCalendar: ImportedCalendar?

    init(
        startDate: Date,
        endDate: Date? = nil,
        breakDuration: TimeInterval = 0,
        hourlyRateSnapshot: Double,
        perHourBenefitsSnapshot: Double,
        fixedBenefitsSnapshot: Double,
        kind: SessionKind = .entreprise,
        importedCalendar: ImportedCalendar? = nil
    ) {
        self.startDate = startDate
        // A departure before the arrival would render as a negative span
        // everywhere. Collapse it to a zero-length finished day rather than
        // dropping the end date, which would resurrect the session as "running"
        // and let it accrue pay forever.
        self.endDate = endDate.map { max($0, startDate) }
        // A negative break *adds* paid time in `duration()` (span − break), so
        // this clamp is what stops a bad value from inflating the pay.
        let span = self.endDate.map { $0.timeIntervalSince(startDate) } ?? Sanitize.maxSessionDuration
        self.breakDuration = Sanitize.breakSeconds(breakDuration, within: span)
        self.hourlyRateSnapshot = Sanitize.rate(hourlyRateSnapshot)
        self.perHourBenefitsSnapshot = Sanitize.rate(perHourBenefitsSnapshot)
        self.fixedBenefitsSnapshot = Sanitize.amount(fixedBenefitsSnapshot)
        self.kindRaw = kind.rawValue
        self.importedCalendar = importedCalendar
    }

    var isActive: Bool { endDate == nil }

    /// Re-times an existing session under the same rules as ``init`` — the edit
    /// form and the assistant both rewrite these three fields, and going
    /// through here keeps a stored session from ever holding a departure before
    /// its arrival or a break longer than the day itself.
    func retime(startDate newStart: Date, endDate newEnd: Date?, breakDuration newBreak: TimeInterval) {
        startDate = newStart
        endDate = newEnd.map { max($0, newStart) }
        let span = endDate.map { $0.timeIntervalSince(newStart) } ?? Sanitize.maxSessionDuration
        breakDuration = Sanitize.breakSeconds(newBreak, within: span)
    }

    /// Gross span between arrival and departure, before removing the break.
    func grossDuration(asOf now: Date = Date()) -> TimeInterval {
        (endDate ?? now).timeIntervalSince(startDate)
    }

    /// Worked time actually paid = arrival→departure minus break (never negative).
    func duration(asOf now: Date = Date()) -> TimeInterval {
        max(0, grossDuration(asOf: now) - breakDuration)
    }

    func totalPay(asOf now: Date = Date()) -> Double {
        let hours = duration(asOf: now) / 3600
        return hours * (hourlyRateSnapshot + perHourBenefitsSnapshot) + fixedBenefitsSnapshot
    }
}
