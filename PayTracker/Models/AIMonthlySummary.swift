#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Monthly budget recap phrased by Apple's on-device model.
/// Compiled only when the Foundation Models SDK is present (Xcode 26+).
@available(iOS 26.0, *)
enum AIMonthlySummary {

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Returns a friendly recap, or nil so the caller can fall back to the
    /// deterministic template.
    static func write(_ i: MonthlySummary.Input) async -> String? {
        guard isAvailable else { return nil }

        var facts = """
        Mois : \(i.monthName)
        Revenus : \(Money.string(i.income))
        Dépenses : \(Money.string(i.spending))
        Reste à vivre : \(Money.string(i.remaining))
        """
        if let cat = i.topCategory {
            facts += "\nPrincipal poste de dépense : \(cat)"
        }
        if i.overtimeHours > 0 {
            facts += "\nHeures supplémentaires cette semaine : \(formatHours(i.overtimeHours))"
        }

        do {
            let session = LanguageModelSession(
                instructions: """
                Tu es un assistant budget bienveillant. À partir des chiffres
                fournis, rédige en français un bilan de 2 à 3 phrases, ton
                encourageant et tutoiement, suivi d'un conseil pratique et court.
                N'invente aucun chiffre : n'utilise que ceux donnés.
                """
            )
            let response = try await session.respond(to: facts)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
}
#endif
