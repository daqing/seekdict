import XCTest
@testable import SeekDictCore

final class NewsCacheTests: XCTestCase {
    private var tempPaths: [String] = []
    private var now = Date(timeIntervalSinceReferenceDate: 800_000)

    override func tearDown() {
        for path in tempPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempPaths.removeAll()
    }

    private func makeCache(
        timeToLive: [NewsSection: TimeInterval]? = nil
    ) throws -> NewsCache {
        let dbPath = NSTemporaryDirectory().appending("seekdict-test-\(UUID().uuidString).sqlite")
        tempPaths.append(dbPath)
        let database = try Database(path: dbPath)
        return try NewsCache(database: database, timeToLive: timeToLive) { [weak self] in
            self?.now ?? Date()
        }
    }

    func testStoreThenFetchReturnsEntry() throws {
        let cache = try makeCache()
        try cache.store(#"{"results":[]}"#, section: .news, word: "abandon")

        let entry = try cache.fetch(section: .news, word: "abandon")

        XCTAssertEqual(entry?.payloadJSON, #"{"results":[]}"#)
        XCTAssertEqual(entry?.fetchedAt, now)
    }

    func testMissReturnsNil() throws {
        let cache = try makeCache()
        XCTAssertNil(try cache.fetch(section: .news, word: "missing"))
    }

    func testExpiredEntryReturnsNil() throws {
        let cache = try makeCache(timeToLive: [.news: 60])
        try cache.store("payload", section: .news, word: "abandon")

        now += 59
        XCTAssertNotNil(try cache.fetch(section: .news, word: "abandon"))
        now += 2
        XCTAssertNil(try cache.fetch(section: .news, word: "abandon"))
    }

    func testTTLIsPerSection() throws {
        let cache = try makeCache(timeToLive: [.news: 60, .weibo: 10])
        try cache.store("news-payload", section: .news, word: "abandon")
        try cache.store("weibo-payload", section: .weibo, word: "abandon")

        now += 30
        XCTAssertNotNil(try cache.fetch(section: .news, word: "abandon"))
        XCTAssertNil(try cache.fetch(section: .weibo, word: "abandon"))
    }

    func testSectionsWithSameWordAreIsolated() throws {
        let cache = try makeCache()
        try cache.store("news-payload", section: .news, word: "abandon")
        try cache.store("weibo-payload", section: .weibo, word: "abandon")

        XCTAssertEqual(try cache.fetch(section: .news, word: "abandon")?.payloadJSON, "news-payload")
        XCTAssertEqual(try cache.fetch(section: .weibo, word: "abandon")?.payloadJSON, "weibo-payload")
    }

    func testStoreOverwritesPayloadAndTimestamp() throws {
        let cache = try makeCache(timeToLive: [.news: 60])
        try cache.store("old", section: .news, word: "abandon")

        now += 59
        try cache.store("new", section: .news, word: "abandon")

        let entry = try cache.fetch(section: .news, word: "abandon")
        XCTAssertEqual(entry?.payloadJSON, "new")
        XCTAssertEqual(entry?.fetchedAt, now)

        now += 59
        XCTAssertNotNil(try cache.fetch(section: .news, word: "abandon"))
    }

    func testRemoveDeletesEntry() throws {
        let cache = try makeCache()
        try cache.store("payload", section: .news, word: "abandon")
        try cache.remove(section: .news, word: "abandon")

        XCTAssertNil(try cache.fetch(section: .news, word: "abandon"))
    }
}
