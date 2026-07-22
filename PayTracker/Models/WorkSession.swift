import Foundation
import SwiftData

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

    init(
        startDate: Date,
        endDate: Date? = nil,
        breakDuration: TimeInterval = 0,
        hourlyRateSnapshot: Double,
        perHourBenefitsSnapshot: Double,
        fixedBenefitsSnapshot: Double
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.breakDuration = breakDuration
        self.hourlyRateSnapshot = hourlyRateSnapshot
        self.perHourBenefitsSnapshot = perHourBenefitsSnapshot
        self.fixedBenefitsSnapshot = fixedBenefitsSnapshot
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
