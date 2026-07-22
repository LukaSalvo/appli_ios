import Foundation
import SwiftData

@Model
final class WorkSession {
    var startDate: Date
    var endDate: Date?

    // Snapshot of the rate/benefits at the time the session started, so past
    // sessions stay accurate even if the user later edits their settings.
    var hourlyRateSnapshot: Double
    var perHourBenefitsSnapshot: Double
    var fixedBenefitsSnapshot: Double

    init(
        startDate: Date,
        hourlyRateSnapshot: Double,
        perHourBenefitsSnapshot: Double,
        fixedBenefitsSnapshot: Double
    ) {
        self.startDate = startDate
        self.endDate = nil
        self.hourlyRateSnapshot = hourlyRateSnapshot
        self.perHourBenefitsSnapshot = perHourBenefitsSnapshot
        self.fixedBenefitsSnapshot = fixedBenefitsSnapshot
    }

    var isActive: Bool { endDate == nil }

    func duration(asOf now: Date = Date()) -> TimeInterval {
        (endDate ?? now).timeIntervalSince(startDate)
    }

    func totalPay(asOf now: Date = Date()) -> Double {
        let hours = duration(asOf: now) / 3600
        return hours * (hourlyRateSnapshot + perHourBenefitsSnapshot) + fixedBenefitsSnapshot
    }
}
