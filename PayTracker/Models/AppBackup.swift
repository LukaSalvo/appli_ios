import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A complete, portable snapshot of the app's data — sessions, benefits,
/// expenses and settings — used for manual export/import backups.
struct AppBackup: Codable {
    var formatVersion: Int = 1
    var exportedAt: Date = Date()
    var settings: Settings
    var sessions: [Session]
    var benefits: [Benefit]
    var expenses: [Expense]

    struct Settings: Codable {
        var payMode: String
        var hourlyRate: Double
        var monthlySalary: Double
        var daysWorkedPerMonth: Int
        var currentBalance: Double
        var mealTicketsEnabled: Bool
        var mealTicketValue: Double
        var mealTicketEmployerPct: Double
        var appearanceMode: String?
    }

    struct Session: Codable {
        var startDate: Date
        var endDate: Date?
        var breakDuration: TimeInterval
        var hourlyRateSnapshot: Double
        var perHourBenefitsSnapshot: Double
        var fixedBenefitsSnapshot: Double
    }

    struct Benefit: Codable {
        var name: String
        var amount: Double
        var type: String
        var isEnabled: Bool
        var createdAt: Date
    }

    struct Expense: Codable {
        var name: String
        var amount: Double
        var category: String
        var createdAt: Date
    }
}

extension AppBackup {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

// MARK: - Import validation

/// Applies the clamps of ``Sanitize`` while counting how much had to be
/// repaired, so the confirmation dialog can tell the user their file was not
/// clean instead of quietly fixing it behind their back.
private struct BackupCorrections {
    private(set) var adjusted = 0
    private(set) var dropped = 0

    /// A record that could not be repaired at all.
    mutating func drop() { dropped += 1 }

    /// A correction applied outside ``clamp`` (an unknown enum case, a capped date).
    mutating func note() { adjusted += 1 }

    /// `NaN != NaN` is true, so a non-finite input always registers as adjusted.
    mutating func clamp(_ value: Double, _ transform: (Double) -> Double) -> Double {
        let corrected = transform(value)
        if corrected != value { adjusted += 1 }
        return corrected
    }

    mutating func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        let corrected = min(max(value, range.lowerBound), range.upperBound)
        if corrected != value { adjusted += 1 }
        return corrected
    }

    mutating func clean(_ value: String, fallback: String) -> String {
        let corrected = Sanitize.text(value, fallback: fallback)
        if corrected != value { adjusted += 1 }
        return corrected
    }
}

/// A backup file is the one place where arbitrary, externally-authored content
/// becomes the app's financial history. The file is picked by the user, but it
/// can come from anywhere — a messaging app, a shared folder, a synced drive —
/// and nothing about the picker guarantees the app itself wrote it.
///
/// So the file is treated as untrusted input: bounded in size, checked for a
/// known format version, capped in record count, and every field clamped to a
/// plausible range before a single row is written. Without this, a hand-edited
/// file yields a negative `breakDuration` (which *inflates* pay, because worked
/// time is `span − break`), a `1e308` rate that turns every total into `inf €`,
/// a departure before the arrival, or enough records to wedge the app on launch.
extension AppBackup {

    enum Limits {
        /// A real backup of several years of sessions stays well under a
        /// megabyte; 8 Mo leaves generous headroom without risking the app.
        static let maxFileBytes = 8 * 1024 * 1024
        static let supportedFormatVersions = 1...1
        static let maxSessions = 20_000
        static let maxBenefits = 500
        static let maxExpenses = 2_000
    }

    enum ImportError: LocalizedError {
        case unsupportedVersion(Int)
        case tooManyRecords

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "Format de sauvegarde non reconnu (version \(version)). Mettez l'application à jour."
            case .tooManyRecords:
                return "Ce fichier contient trop d'entrées pour être importé."
            }
        }
    }

    /// A backup that has passed validation, plus what had to be corrected —
    /// surfaced in the confirmation dialog so a silently repaired file never
    /// looks like a clean one.
    struct Checked {
        var backup: AppBackup
        var droppedRecords = 0
        var adjustedValues = 0

        var hasCorrections: Bool { droppedRecords > 0 || adjustedValues > 0 }

        /// One line describing what is about to replace the current data.
        var summary: String {
            var parts = [
                "\(backup.sessions.count) journée(s)",
                "\(backup.benefits.count) avantage(s)",
                "\(backup.expenses.count) dépense(s)"
            ]
            if droppedRecords > 0 { parts.append("\(droppedRecords) entrée(s) ignorée(s)") }
            if adjustedValues > 0 { parts.append("\(adjustedValues) valeur(s) corrigée(s)") }
            return parts.joined(separator: " · ")
        }
    }

    /// Reads, decodes and validates a backup file. Throws rather than importing
    /// anything questionable.
    static func load(from url: URL) throws -> Checked {
        let data = try BoundedFileReader.data(at: url, maxBytes: Limits.maxFileBytes)
        return try decoder.decode(AppBackup.self, from: data).checked()
    }

    /// Clamps every field to a plausible range and drops records that cannot be
    /// repaired (an implausible date, a session ending before it starts).
    func checked(now: Date = Date()) throws -> Checked {
        guard Limits.supportedFormatVersions.contains(formatVersion) else {
            throw ImportError.unsupportedVersion(formatVersion)
        }
        guard sessions.count <= Limits.maxSessions,
              benefits.count <= Limits.maxBenefits,
              expenses.count <= Limits.maxExpenses
        else { throw ImportError.tooManyRecords }

        var fix = BackupCorrections()

        // MARK: Sessions

        var cleanSessions: [Session] = []
        cleanSessions.reserveCapacity(sessions.count)
        for session in sessions {
            guard Sanitize.isPlausible(session.startDate, now: now) else { fix.drop(); continue }

            var endDate = session.endDate
            if let end = endDate {
                // A departure at or before the arrival is not a session.
                guard Sanitize.isPlausible(end, now: now), end > session.startDate else {
                    fix.drop()
                    continue
                }
                // Cap the span at a full day so one bad row can't claim months
                // of paid time.
                let maxEnd = session.startDate.addingTimeInterval(Sanitize.maxSessionDuration)
                if end > maxEnd {
                    endDate = maxEnd
                    fix.note()
                }
            }

            let gross = (endDate ?? session.startDate.addingTimeInterval(Sanitize.maxSessionDuration))
                .timeIntervalSince(session.startDate)

            cleanSessions.append(Session(
                startDate: session.startDate,
                endDate: endDate,
                // Negative breaks would *add* paid time in `duration()`.
                breakDuration: fix.clamp(session.breakDuration, { Sanitize.breakSeconds($0, within: gross) }),
                hourlyRateSnapshot: fix.clamp(session.hourlyRateSnapshot, Sanitize.rate),
                perHourBenefitsSnapshot: fix.clamp(session.perHourBenefitsSnapshot, Sanitize.rate),
                fixedBenefitsSnapshot: fix.clamp(session.fixedBenefitsSnapshot, Sanitize.amount)
            ))
        }

        // MARK: Benefits

        var cleanBenefits: [Benefit] = []
        cleanBenefits.reserveCapacity(benefits.count)
        for benefit in benefits {
            guard Sanitize.isPlausible(benefit.createdAt, now: now) else { fix.drop(); continue }
            let type = BenefitType(rawValue: benefit.type) ?? .perShift
            if type.rawValue != benefit.type { fix.note() }
            // A per-hour benefit is a rate, a per-shift one is a lump sum.
            let clampAmount: (Double) -> Double = type == .perHour ? Sanitize.rate : Sanitize.amount
            cleanBenefits.append(Benefit(
                name: fix.clean(benefit.name, fallback: "Avantage"),
                amount: fix.clamp(benefit.amount, clampAmount),
                type: type.rawValue,
                isEnabled: benefit.isEnabled,
                createdAt: benefit.createdAt
            ))
        }

        // MARK: Expenses

        var cleanExpenses: [Expense] = []
        cleanExpenses.reserveCapacity(expenses.count)
        for expense in expenses {
            guard Sanitize.isPlausible(expense.createdAt, now: now) else { fix.drop(); continue }
            let category = ExpenseCategory(rawValue: expense.category) ?? .other
            if category.rawValue != expense.category { fix.note() }
            cleanExpenses.append(Expense(
                name: fix.clean(expense.name, fallback: "Dépense"),
                amount: fix.clamp(expense.amount, Sanitize.amount),
                category: category.rawValue,
                createdAt: expense.createdAt
            ))
        }

        // MARK: Settings

        let payMode = PayMode(rawValue: settings.payMode) ?? .hourly
        if payMode.rawValue != settings.payMode { fix.note() }
        let appearance = settings.appearanceMode.flatMap { AppearanceMode(rawValue: $0) }

        let cleanSettings = Settings(
            payMode: payMode.rawValue,
            hourlyRate: fix.clamp(settings.hourlyRate, Sanitize.rate),
            monthlySalary: fix.clamp(settings.monthlySalary, Sanitize.amount),
            daysWorkedPerMonth: fix.clamp(settings.daysWorkedPerMonth, to: 0...31),
            currentBalance: fix.clamp(settings.currentBalance, Sanitize.signedAmount),
            mealTicketsEnabled: settings.mealTicketsEnabled,
            mealTicketValue: fix.clamp(settings.mealTicketValue, { Sanitize.number($0, in: 0...1_000) }),
            mealTicketEmployerPct: fix.clamp(settings.mealTicketEmployerPct, { Sanitize.number($0, in: 0...100) }),
            appearanceMode: appearance?.rawValue
        )

        return Checked(
            backup: AppBackup(
                formatVersion: formatVersion,
                exportedAt: Sanitize.isPlausible(exportedAt, now: now) ? exportedAt : now,
                settings: cleanSettings,
                sessions: cleanSessions,
                benefits: cleanBenefits,
                expenses: cleanExpenses
            ),
            droppedRecords: fix.dropped,
            adjustedValues: fix.adjusted
        )
    }
}

/// Wraps an `AppBackup` so it can be handed to `.fileExporter`.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var backup: AppBackup

    init(backup: AppBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              data.count <= AppBackup.Limits.maxFileBytes
        else { throw CocoaError(.fileReadCorruptFile) }
        // Same validation as the in-app importer: no path may produce an
        // `AppBackup` whose contents haven't been checked.
        backup = try AppBackup.decoder.decode(AppBackup.self, from: data).checked().backup
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try AppBackup.encoder.encode(backup))
    }
}
