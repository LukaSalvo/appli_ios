#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Expense extraction backed by Apple's on-device model (Foundation Models).
/// Compiled only when the SDK is present (Xcode 26+/iOS 26 SDK); on older
/// toolchains the whole file is excluded and the heuristic parser is used.
@available(iOS 26.0, *)
enum AIExpenseParser {

    /// The structure the model is guided to produce.
    @Generable
    struct Draft {
        @Guide(description: "Libellé court de la dépense, en français, sans le montant")
        var name: String

        @Guide(description: "Montant dépensé en euros, nombre positif")
        var amount: Double

        @Guide(description: "Catégorie exacte parmi : Logement, Abonnements, Transport, Alimentation, Assurances, Autre")
        var category: String
    }

    /// True when the on-device model is ready to use on this device.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Ask the model to extract a structured expense. Returns nil on any
    /// failure so the caller can fall back to the heuristic parser.
    static func parse(_ text: String) async -> ParsedExpense? {
        guard isAvailable else { return nil }
        do {
            let session = LanguageModelSession(
                instructions: """
                Tu extrais une dépense personnelle d'une phrase en français.
                Rends uniquement le libellé, le montant en euros et la catégorie.
                """
            )
            let response = try await session.respond(to: text, generating: Draft.self)
            let draft = response.content

            // The date is handled locally (the model doesn't know "today").
            let category = ExpenseCategory(rawValue: draft.category)
                ?? ExpenseTextParser.detectCategory(in: text)
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)

            return ParsedExpense(
                name: name.isEmpty ? category.rawValue : name,
                amount: draft.amount,
                category: category,
                date: ExpenseTextParser.detectDate(in: text)
            )
        } catch {
            return nil
        }
    }
}
#endif
