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

    init(
        startDate: Date,
        endDate: Date? = nil,
        breakDuration: TimeInterval = 0,
        hourlyRateSnapshot: Double,
        perHourBenefitsSnapshot: Double,
        fixedBenefitsSnapshot: Double,
        kind: SessionKind = .entreprise
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.breakDuration = breakDuration
        self.hourlyRateSnapshot = hourlyRateSnapshot
        self.perHourBenefitsSnapshot = perHourBenefitsSnapshot
        self.fixedBenefitsSnapshot = fixedBenefitsSnapshot
        self.kindRaw = kind.rawValue
    }

    var isActive: Bool { endDate == nil }

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
