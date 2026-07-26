#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Intent + hours extraction backed by Apple's on-device model.
/// Compiled only when the Foundation Models SDK is present (Xcode 26+).
///
/// The model classifies the order (add / modify / delete) and pulls out the
/// times mentioned; the *date* is still resolved locally (the model has no
/// reliable notion of "today", weekdays or "hier").
@available(iOS 26.0, *)
enum AISessionCommandParser {

    @Generable
    struct Draft {
        @Guide(description: "Action demandée : ajouter, modifier ou supprimer une journée de travail")
        var action: String
        @Guide(description: "Vrai si une heure d'arrivée est mentionnée")
        var hasArrival: Bool
        @Guide(description: "Heure d'arrivée, format 24h, 0 à 23")
        var arrivalHour: Int
        @Guide(description: "Minutes de l'heure d'arrivée, 0 à 59")
        var arrivalMinute: Int
        @Guide(description: "Vrai si une heure de départ est mentionnée")
        var hasDeparture: Bool
        @Guide(description: "Heure de départ, format 24h, 0 à 23")
        var departureHour: Int
        @Guide(description: "Minutes de l'heure de départ, 0 à 59")
        var departureMinute: Int
        @Guide(description: "Vrai si une durée de pause est mentionnée (même « sans pause »)")
        var hasBreak: Bool
        @Guide(description: "Durée totale de pause en minutes, 0 si aucune")
        var breakMinutes: Int
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func parse(_ text: String) async -> SessionCommand? {
        guard isAvailable else { return nil }
        do {
            let session = LanguageModelSession(
                instructions: """
                Tu analyses une phrase en français à propos d'une journée de
                travail. Détermine si l'utilisateur veut AJOUTER une journée,
                MODIFIER une journée existante, ou SUPPRIMER une journée.
                Extrais l'heure d'arrivée, l'heure de départ et la pause
                uniquement si elles sont mentionnées. Ne renseigne pas la date :
                elle est traitée séparément.
                """
            )
            let response = try await session.respond(to: text, generating: Draft.self)
            let d = response.content

            let intent = mapIntent(d.action, fallbackText: text)
            let resolved = SessionCommandParser.detectDay(in: text)
            let cal = Calendar.current

            var arrival: Date?
            if d.hasArrival {
                arrival = cal.date(bySettingHour: clampHour(d.arrivalHour),
                                   minute: clampMinute(d.arrivalMinute), second: 0, of: resolved.date)
            }
            var departure: Date?
            if d.hasDeparture {
                departure = cal.date(bySettingHour: clampHour(d.departureHour),
                                     minute: clampMinute(d.departureMinute), second: 0, of: resolved.date)
            }

            // For an *add*, fill in the classic 9→17 defaults when unspecified.
            if intent == .add {
                if arrival == nil { arrival = cal.date(bySettingHour: 9, minute: 0, second: 0, of: resolved.date) }
                if departure == nil { departure = cal.date(bySettingHour: 17, minute: 0, second: 0, of: resolved.date) }
            }

            let breakMinutes: Int? = d.hasBreak ? max(0, d.breakMinutes) : (intent == .add ? 0 : nil)

            return SessionCommand(
                intent: intent,
                day: resolved.date,
                hasExplicitDay: resolved.explicit,
                arrival: arrival,
                departure: departure,
                breakMinutes: breakMinutes,
                rawText: text
            )
        } catch {
            return nil
        }
    }

    private static func mapIntent(_ raw: String, fallbackText: String) -> SessionIntent {
        let a = raw.lowercased()
        if a.contains("supprim") || a.contains("delete") || a.contains("efface")
            || a.contains("retir") || a.contains("enlèv") || a.contains("enlev") {
            // "enlève la pause" is really a modify — defer to the heuristic rule.
            return SessionCommandParser.detectIntent(in: fallbackText.lowercased())
        }
        if a.contains("modif") || a.contains("change") || a.contains("corrig")
            || a.contains("update") || a.contains("edit") { return .modify }
        if a.contains("ajout") || a.contains("add") || a.contains("créer")
            || a.contains("creer") || a.contains("nouvelle") { return .add }
        // Ambiguous label from the model — trust the keyword heuristic.
        return SessionCommandParser.detectIntent(in: fallbackText.lowercased())
    }

    private static func clampHour(_ h: Int) -> Int { min(max(h, 0), 23) }
    private static func clampMinute(_ m: Int) -> Int { min(max(m, 0), 59) }
}
#endif
