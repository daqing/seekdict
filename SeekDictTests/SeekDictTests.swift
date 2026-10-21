import XCTest
import SeekDictCore

final class SeekDictTests: XCTestCase {
    func testCoreModuleLoads() {
        XCTAssertFalse(SeekDictCore.version.isEmpty)
    }
}
