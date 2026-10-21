import Foundation
import SQLite3

let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class DictionaryStore {
    public let database: Database

    private static let schemaSQL = """
    CREATE TABLE IF NOT EXISTS entries (
        direction TEXT NOT NULL,
        word TEXT NOT NULL,
        pos TEXT,
        sense TEXT NOT NULL,
        sense_order INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_entries_direction_word ON entries(direction, word);
    CREATE TABLE IF NOT EXISTS schema_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    );
    """

    public init(path: String) throws {
        database = try Database(path: path)
        try database.execute(Self.schemaSQL)
    }

    public static func defaultStoreURL(subdirectory name: String = "SeekDict") throws -> URL {
        let base = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("dictionary.sqlite")
    }

    public func isImported(_ direction: TranslationDirection) -> Bool {
        guard let statement = try? database.prepareStatement(
            "SELECT value FROM schema_meta WHERE key = ?;"
        ) else { return false }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, metaKey(for: direction), -1, sqliteTransient)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    @discardableResult
    public func importIfNeeded(_ glossaries: [TranslationDirection: URL]) throws -> [ImportReport] {
        var reports: [ImportReport] = []
        for (direction, url) in glossaries where !isImported(direction) {
            reports.append(try importGlossary(at: url, direction: direction))
        }
        return reports
    }

    @discardableResult
    public func importGlossary(at url: URL, direction: TranslationDirection) throws -> ImportReport {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let started = Date()
        let outcome = try GlossaryParser.parse(contents: contents)
        let entries = outcome.entries

        let statement = try database.prepareStatement(
            "INSERT INTO entries (direction, word, pos, sense, sense_order) VALUES (?, ?, ?, ?, ?);"
        )
        defer { sqlite3_finalize(statement) }

        try database.execute("BEGIN IMMEDIATE;")
        do {
            for entry in entries {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, direction.rawValue, -1, sqliteTransient)
                sqlite3_bind_text(statement, 2, entry.word, -1, sqliteTransient)
                for (index, sense) in entry.senses.enumerated() {
                    if let pos = sense.pos {
                        sqlite3_bind_text(statement, 3, pos.rawValue, -1, sqliteTransient)
                    } else {
                        sqlite3_bind_null(statement, 3)
                    }
                    sqlite3_bind_text(statement, 4, sense.text, -1, sqliteTransient)
                    sqlite3_bind_int(statement, 5, Int32(index + 1))
                    guard sqlite3_step(statement) == SQLITE_DONE else {
                        throw DatabaseError.executeFailed(database.lastErrorMessage)
                    }
                    sqlite3_reset(statement)
                }
            }
            try markImported(direction)
            try database.execute("COMMIT;")
        } catch {
            try? database.execute("ROLLBACK;")
            throw error
        }

        return ImportReport(
            direction: direction,
            linesRead: outcome.totalLines,
            skippedLines: outcome.skippedLines,
            importedEntries: entries.count,
            importedSenses: entries.reduce(0) { $0 + $1.senses.count },
            duration: Date().timeIntervalSince(started)
        )
    }

    private func markImported(_ direction: TranslationDirection) throws {
        guard let meta = try database.prepareStatement(
            "INSERT OR REPLACE INTO schema_meta (key, value) VALUES (?, '1');"
        ) else { throw DatabaseError.executeFailed(database.lastErrorMessage) }
        defer { sqlite3_finalize(meta) }
        sqlite3_bind_text(meta, 1, metaKey(for: direction), -1, sqliteTransient)
        guard sqlite3_step(meta) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(database.lastErrorMessage)
        }
    }

    private func metaKey(for direction: TranslationDirection) -> String {
        "imported.\(direction.rawValue)"
    }
}
