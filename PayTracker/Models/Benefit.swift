import Foundation
import SwiftData

enum BenefitType: String, Codable, CaseIterable, Identifiable {
    case perHour = "Par heure"
    case perShift = "Par prise de poste"

    var id: String { rawValue }
}

@Model
final class Benefit {
    var name: String
    var amount: Double
    var typeRawValue: String
    var isEnabled: Bool
    var createdAt: Date

    var type: BenefitType {
        get { BenefitType(rawValue: typeRawValue) ?? .perShift }
        set { typeRawValue = newValue.rawValue }
    }

    init(name: String, amount: Double, type: BenefitType = .perShift, isEnabled: Bool = true) {
        self.name = name
        self.amount = amount
        self.typeRawValue = type.rawValue
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }
}
