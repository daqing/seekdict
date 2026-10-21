import XCTest
@testable import SeekDictCore

final class DatabaseTests: XCTestCase {
    func testOpenCreatesDatabaseFile() throws {
        let path = NSTemporaryDirectory().appending("seekdict-test-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let database = try Database(path: path)
        XCTAssertTrue(database.isOpen)
        database.close()
        XCTAssertFalse(database.isOpen)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }
}
