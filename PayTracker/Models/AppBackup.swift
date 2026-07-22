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

/// Wraps an `AppBackup` so it can be handed to `.fileExporter`.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var backup: AppBackup

    init(backup: AppBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        backup = try AppBackup.decoder.decode(AppBackup.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try AppBackup.encoder.encode(backup))
    }
}
