import XCTest
@testable import SeekDictCore

final class SeekDictCoreTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(SeekDictCore.version.isEmpty)
    }
}
