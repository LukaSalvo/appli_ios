import Foundation

/// Reads a user-picked file with a hard ceiling on how much is pulled into
/// memory.
///
/// `Data(contentsOf:)` and `String(contentsOf:)` happily allocate a whole
/// multi-gigabyte file: the app is killed by the OS long before any validation
/// code gets to run, and re-picking the same file kills it again. Every import
/// path (backup `.json`, timetable `.ics`) goes through here instead, so an
/// oversized or hostile file is rejected with a message rather than a crash.
enum BoundedFileReader {

    enum Failure: LocalizedError {
        case tooLarge(limitBytes: Int)
        case unreadable
        case notText

        var errorDescription: String? {
            switch self {
            case .tooLarge(let limit):
                let mb = max(1, limit / (1024 * 1024))
                return "Fichier trop volumineux (limite : \(mb) Mo)."
            case .unreadable:
                return "Fichier illisible ou inaccessible."
            case .notText:
                return "Le contenu du fichier n'est pas du texte lisible."
            }
        }
    }

    /// How much is read in one pass. A regular file can return a short read, so
    /// the loop below keeps going until the budget or the end of file is hit.
    private static let chunkSize = 64 * 1024

    /// Reads at most `maxBytes`; a bigger file is rejected without ever being
    /// fully loaded. Opens and closes the security-scoped access that the
    /// document picker hands over with the URL.
    static func data(at url: URL, maxBytes: Int) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw Failure.unreadable
        }
        defer { try? handle.close() }

        // Read one byte past the budget: getting it proves the file is too big.
        let budget = maxBytes + 1
        var buffer = Data()
        while buffer.count < budget {
            let wanted = min(chunkSize, budget - buffer.count)
            guard let chunk = try? handle.read(upToCount: wanted), !chunk.isEmpty else { break }
            buffer.append(chunk)
        }

        guard buffer.count <= maxBytes else { throw Failure.tooLarge(limitBytes: maxBytes) }
        return buffer
    }

    /// Same ceiling, decoded as text. UTF-8 first, Latin-1 as a fallback for
    /// timetable exports that still ship in a legacy encoding.
    static func text(at url: URL, maxBytes: Int) throws -> String {
        let bytes = try data(at: url, maxBytes: maxBytes)
        if let utf8 = String(data: bytes, encoding: .utf8) { return utf8 }
        if let latin1 = String(data: bytes, encoding: .isoLatin1) { return latin1 }
        throw Failure.notText
    }
}
