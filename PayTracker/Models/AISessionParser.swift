#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Work-session extraction backed by Apple's on-device model.
/// Compiled only when the Foundation Models SDK is present (Xcode 26+).
@available(iOS 26.0, *)
enum AISessionParser {

    @Generable
    struct Draft {
        @Guide(description: "Heure d'arrivée, format 24h, 0 à 23")
        var arrivalHour: Int
        @Guide(description: "Minutes de l'heure d'arrivée, 0 à 59")
        var arrivalMinute: Int
        @Guide(description: "Heure de départ, format 24h, 0 à 23")
        var departureHour: Int
        @Guide(description: "Minutes de l'heure de départ, 0 à 59")
        var departureMinute: Int
        @Guide(description: "Durée totale de pause en minutes, 0 si aucune")
        var breakMinutes: Int
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func parse(_ text: String) async -> ParsedSession? {
        guard isAvailable else { return nil }
        do {
            let session = LanguageModelSession(
                instructions: """
                Tu extrais une journée de travail d'une phrase en français :
                l'heure d'arrivée, l'heure de départ et la durée de pause.
                """
            )
            let response = try await session.respond(to: text, generating: Draft.self)
            let d = response.content

            let day = ExpenseTextParser.detectDate(in: text)
            let cal = Calendar.current
            let arrival = cal.date(bySettingHour: clampHour(d.arrivalHour),
                                   minute: clampMinute(d.arrivalMinute), second: 0, of: day) ?? day
            let departure = cal.date(bySettingHour: clampHour(d.departureHour),
                                     minute: clampMinute(d.departureMinute), second: 0, of: day) ?? day

            return ParsedSession(
                day: day,
                arrival: arrival,
                departure: departure,
                // The model's integer is free-form — keep it inside a day.
                breakMinutes: Sanitize.breakMinutes(d.breakMinutes)
            )
        } catch {
            return nil
        }
    }

    private static func clampHour(_ h: Int) -> Int { min(max(h, 0), 23) }
    private static func clampMinute(_ m: Int) -> Int { min(max(m, 0), 59) }
}
#endif
