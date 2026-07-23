import AppIntents
import SwiftData
import Foundation

/// Lets Siri log a work day hands-free: "Dis à Siri, enregistre ma journée
/// dans Paie Horaire" prompts for a spoken description, which is parsed the
/// same way as the in-app "Saisie rapide" field (Apple's on-device model when
/// available, heuristic fallback otherwise).
struct LogWorkDayIntent: AppIntent {
    static var title: LocalizedStringResource = "Enregistrer ma journée"
    static var description = IntentDescription(
        "Décrivez votre journée de travail à voix haute — horaires et pause — pour l'enregistrer dans Paie Horaire."
    )

    @Parameter(
        title: "Description de la journée",
        requestValueDialog: "Décrivez votre journée : heure d'arrivée, de départ et la pause."
    )
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Enregistrer : \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let parsed = await SessionTextParser.parse(text)
        let context = ModelContext(AppModelContainer.shared)

        let benefits = (try? context.fetch(FetchDescriptor<Benefit>())) ?? []
        let perHour = benefits.filter { $0.isEnabled && $0.type == .perHour }.reduce(0) { $0 + $1.amount }
        let fixed = benefits.filter { $0.isEnabled && $0.type == .perShift }.reduce(0) { $0 + $1.amount }
        let storedRate = UserDefaults.standard.double(forKey: "hourlyRate")
        let rate = storedRate == 0 ? 11.65 : storedRate

        let session = WorkSession(
            startDate: parsed.arrival,
            endDate: parsed.departure,
            breakDuration: Double(parsed.breakMinutes) * 60,
            hourlyRateSnapshot: rate,
            perHourBenefitsSnapshot: perHour,
            fixedBenefitsSnapshot: fixed
        )
        context.insert(session)
        try context.save()

        let hours = session.duration() / 3600
        return .result(
            dialog: "Journée enregistrée : \(formatHours(hours)) travaillées, \(Money.string(session.totalPay()))."
        )
    }
}

/// Exposes the intent to Siri/Spotlight without any extra setup — App
/// Shortcuts are discovered automatically from the app bundle.
struct PayTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWorkDayIntent(),
            phrases: [
                "Enregistre ma journée dans \(.applicationName)",
                "Ajoute ma journée dans \(.applicationName)",
                "Décris ta journée dans \(.applicationName)"
            ],
            shortTitle: "Enregistrer ma journée",
            systemImageName: "mic.fill"
        )
    }
}
