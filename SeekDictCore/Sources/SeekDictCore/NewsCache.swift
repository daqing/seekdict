import Foundation
import SQLite3

public enum NewsSection: String, CaseIterable {
    case news
    case weibo

    public var defaultTTL: TimeInterval {
        switch self {
        case .news:
            return 15 * 60
        case .weibo:
            return 5 * 60
        }
    }
}

public struct NewsCacheEntry: Equatable {
    public let word: String
    public let payloadJSON: String
    public let fetchedAt: Date

    public init(word: String, payloadJSON: String, fetchedAt: Date) {
        self.word = word
        self.payloadJSON = payloadJSON
        self.fetchedAt = fetchedAt
    }
}

public final class NewsCache {
    public let database: Database
    public var timeToLive: [NewsSection: TimeInterval]
    private let clock: () -> Date

    private static let schemaSQL = """
    CREATE TABLE IF NOT EXISTS news_cache (
        section TEXT NOT NULL,
        word TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        fetched_at REAL NOT NULL,
        PRIMARY KEY (section, word)
    );
    """

    public init(
        database: Database,
        timeToLive: [NewsSection: TimeInterval]? = nil,
        clock: @escaping () -> Date = Date.init
    ) throws {
        self.database = database
        self.timeToLive = timeToLive ?? Dictionary(
            uniqueKeysWithValues: NewsSection.allCases.map { ($0, $0.defaultTTL) }
        )
        self.clock = clock
        try database.execute(Self.schemaSQL)
    }

    public func store(_ payloadJSON: String, section: NewsSection, word: String) throws {
        let statement = try database.prepareStatement(
            """
            INSERT OR REPLACE INTO news_cache (section, word, payload_json, fetched_at)
            VALUES (?, ?, ?, ?);
            """
        )
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, section.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, word, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, payloadJSON, -1, sqliteTransient)
        sqlite3_bind_double(statement, 4, clock().timeIntervalSinceReferenceDate)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(database.lastErrorMessage)
        }
    }

    public func fetch(section: NewsSection, word: String) throws -> NewsCacheEntry? {
        let statement = try database.prepareStatement(
            "SELECT payload_json, fetched_at FROM news_cache WHERE section = ? AND word = ?;"
        )
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, section.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, word, -1, sqliteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let payload = String(cString: sqlite3_column_text(statement, 0))
        let fetchedAt = Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, 1))
        guard clock().timeIntervalSince(fetchedAt) < ttl(for: section) else { return nil }
        return NewsCacheEntry(word: word, payloadJSON: payload, fetchedAt: fetchedAt)
    }

    public func remove(section: NewsSection, word: String) throws {
        let statement = try database.prepareStatement(
            "DELETE FROM news_cache WHERE section = ? AND word = ?;"
        )
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, section.rawValue, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, word, -1, sqliteTransient)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(database.lastErrorMessage)
        }
    }

    private func ttl(for section: NewsSection) -> TimeInterval {
        timeToLive[section] ?? section.defaultTTL
    }
}
