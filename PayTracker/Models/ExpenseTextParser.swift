import Foundation

/// A draft expense extracted from a free-text sentence, shown to the user for
/// confirmation before saving.
struct ParsedExpense {
    var name: String
    var amount: Double
    var category: ExpenseCategory
    var date: Date
}

/// Turns a sentence like "25€ resto hier" into a structured draft.
///
/// When Apple's on-device model is available (Foundation Models, iOS 26+ on a
/// compatible iPhone) it does the heavy lifting; otherwise a lightweight
/// heuristic keeps the feature working everywhere — including on iOS 17 and in
/// CI, where the Foundation Models SDK isn't present.
enum ExpenseTextParser {

    /// Best-effort parse — always returns something usable.
    static func parse(_ text: String) async -> ParsedExpense {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let ai = await AIExpenseParser.parse(text) {
            return ai
        }
        #endif
        return heuristicParse(text)
    }

    /// Whether the on-device model can be used right now (device + OS support).
    static var isOnDeviceModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AIExpenseParser.isAvailable
        }
        #endif
        return false
    }

    // MARK: - Heuristic fallback

    static func heuristicParse(_ text: String) -> ParsedExpense {
        let amount = detectAmount(in: text)
        let category = detectCategory(in: text)
        let date = detectDate(in: text)
        let name = cleanedName(from: text, fallback: category.rawValue)
        return ParsedExpense(name: name, amount: amount, category: category, date: date)
    }

    /// First number in the text, treated as euros ("25", "12,50", "9.99").
    static func detectAmount(in text: String) -> Double {
        guard let range = text.range(of: #"\d+(?:[.,]\d{1,2})?"#, options: .regularExpression) else {
            return 0
        }
        let raw = text[range].replacingOccurrences(of: ",", with: ".")
        return Double(raw) ?? 0
    }

    static func detectCategory(in text: String) -> ExpenseCategory {
        let t = text.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }

        if has(["resto", "restaurant", "manger", "course", "supermarch", "déjeuner",
                "dejeuner", "dîner", "diner", "repas", "boulanger", "café", "cafe",
                "mcdo", "burger", "pizza", "kebab", "snack"]) {
            return .food
        }
        if has(["essence", "carburant", "train", "métro", "metro", "bus", "uber",
                "taxi", "péage", "peage", "parking", "sncf", "billet", "trajet"]) {
            return .transport
        }
        if has(["loyer", "edf", "électricit", "electricit", "gaz", "eau", "charges"]) {
            return .housing
        }
        if has(["netflix", "spotify", "abonnement", "disney", "canal", "forfait",
                "mobile", "internet", "box", "prime"]) {
            return .subscriptions
        }
        if has(["assurance", "mutuelle"]) {
            return .insurance
        }
        return .other
    }

    /// Understands "hier", "avant-hier", "demain"; defaults to today.
    static func detectDate(in text: String) -> Date {
        let t = text.lowercased()
        let cal = Calendar.current
        let today = Date()
        if t.contains("avant-hier") {
            return cal.date(byAdding: .day, value: -2, to: today) ?? today
        }
        if t.contains("hier") {
            return cal.date(byAdding: .day, value: -1, to: today) ?? today
        }
        if t.contains("demain") {
            return cal.date(byAdding: .day, value: 1, to: today) ?? today
        }
        return today
    }

    /// Strips the amount, currency and date words to leave a short label.
    static func cleanedName(from text: String, fallback: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: #"\d+(?:[.,]\d{1,2})?"#, with: "", options: .regularExpression)
        for word in ["€", "euros", "euro", "avant-hier", "hier", "aujourd'hui",
                     "aujourdhui", "demain", "j'ai", "jai", "dépensé", "depense",
                     "dépense", "payé", "paye", "pour", "de la", "de l'", "du",
                     "au", "à", "a "] {
            s = s.replacingOccurrences(of: word, with: " ", options: .caseInsensitive)
        }
        let cleaned = s
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = cleaned.count >= 2 ? cleaned : fallback
        return name.prefix(1).uppercased() + String(name.dropFirst())
    }
}
