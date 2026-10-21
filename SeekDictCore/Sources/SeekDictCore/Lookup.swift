import Foundation
import SQLite3

public struct LookupResult: Equatable {
    public let direction: TranslationDirection
    public let word: String
    public let senses: [GlossarySense]

    public init(direction: TranslationDirection, word: String, senses: [GlossarySense]) {
        self.direction = direction
        self.word = word
        self.senses = senses
    }
}

public extension DictionaryStore {
    func lookup(_ word: String, direction: TranslationDirection) throws -> LookupResult? {
        var key = word.trimmingCharacters(in: .whitespacesAndNewlines)
        if direction == .englishToChinese {
            key = key.lowercased()
        }
        guard !key.isEmpty else { return nil }

        let statement = try database.prepareStatement(
            """
            SELECT word, pos, sense FROM entries
            WHERE direction = ? AND word = ?
            ORDER BY sense_order;
            """
        )
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, direction.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, key, -1, sqliteTransient)

        var senses: [GlossarySense] = []
        var matchedWord: String?
        while sqlite3_step(statement) == SQLITE_ROW {
            matchedWord = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? key
            let pos = sqlite3_column_text(statement, 1).flatMap { PartOfSpeech(rawValue: String(cString: $0)) }
            let sense = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
            senses.append(GlossarySense(pos: pos, text: sense))
        }
        guard let word = matchedWord else { return nil }
        return LookupResult(direction: direction, word: word, senses: senses)
    }
}
