import Foundation

/// A short, friendly recap of the month's budget. Written by Apple's on-device
/// model when available, otherwise composed from a deterministic template so it
/// works everywhere — including iOS 17 and CI.
enum MonthlySummary {

    struct Input {
        var monthName: String
        var income: Double
        var spending: Double
        var remaining: Double
        var topCategory: String?
        var overtimeHours: Double
    }

    static func generate(_ input: Input) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let ai = await AIMonthlySummary.write(input) {
            return ai
        }
        #endif
        return template(input)
    }

    /// Deterministic fallback — always available, no model required.
    static func template(_ i: Input) -> String {
        var parts: [String] = []
        parts.append("En \(i.monthName), tes revenus s'élèvent à \(Money.string(i.income)).")

        if i.remaining < 0 {
            parts.append("Après \(Money.string(i.spending)) de dépenses, tu es à découvert de \(Money.string(abs(i.remaining))).")
            if let cat = i.topCategory {
                parts.append("Ton principal poste est « \(cat) » : c'est là qu'il y a le plus à gagner.")
            }
        } else {
            parts.append("Après \(Money.string(i.spending)) de dépenses, il te reste \(Money.string(i.remaining)).")
            if let cat = i.topCategory {
                parts.append("Ton principal poste de dépense est « \(cat) ».")
            }
            if i.remaining > 0 {
                parts.append("Pense à mettre une partie de côté.")
            }
        }

        if i.overtimeHours > 0 {
            parts.append("Tu as aussi fait \(formatHours(i.overtimeHours)) d'heures supplémentaires cette semaine.")
        }
        return parts.joined(separator: " ")
    }
}
