#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Classifies a calendar event as school / company / other using Apple's
/// on-device model. Compiled only with the Foundation Models SDK (Xcode 26+).
@available(iOS 26.0, *)
enum AIScheduleClassifier {

    @Generable
    struct Draft {
        @Guide(description: "Type de l'événement d'un alternant : ecole, entreprise ou autre")
        var kind: String
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func classify(_ title: String) async -> SessionKind? {
        guard isAvailable else { return nil }
        do {
            let session = LanguageModelSession(
                instructions: """
                Tu classes un événement d'emploi du temps d'un alternant.
                Réponds « ecole » pour un cours/TD/TP/examen, « entreprise » pour
                une journée en entreprise, « autre » sinon.
                """
            )
            let response = try await session.respond(to: title, generating: Draft.self)
            let k = response.content.kind.lowercased()
            if k.contains("ecole") || k.contains("école") || k.contains("cours") { return .ecole }
            if k.contains("entreprise") || k.contains("travail") { return .entreprise }
            return .autre
        } catch {
            return nil
        }
    }
}
#endif
