import XCTest
@testable import SeekDictCore

final class ImportValidationTests: XCTestCase {
    private var tempPaths: [String] = []

    override func tearDown() {
        for path in tempPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempPaths.removeAll()
    }

    func testReportDescribesSkippedLines() throws {
        let dir = NSTemporaryDirectory().appending("seekdict-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        tempPaths.append(dir)
        let tsv = dir.appending("/glossary.tsv")
        try "# header\n\nword\t译词\n".write(toFile: tsv, atomically: true, encoding: .utf8)
        let dbPath = dir.appending("/dict.sqlite")
        tempPaths.append(dbPath)

        let store = try DictionaryStore(path: dbPath)
        let report = try store.importGlossary(at: URL(fileURLWithPath: tsv), direction: .englishToChinese)

        XCTAssertEqual(report.linesRead, 3)
        XCTAssertEqual(report.skippedLines, 2)
        XCTAssertEqual(report.importedEntries, 1)
        XCTAssertTrue(report.description.contains("skipped 2"))
        XCTAssertTrue(report.description.contains("en-zh"))
    }

    func testLookupLatencyStaysUnderTenMilliseconds() throws {
        let dataDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("data")
        let zhURL = dataDir.appendingPathComponent("glossary-zh.tsv")
        let enURL = dataDir.appendingPathComponent("glossary-en.tsv")
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: zhURL.path),
            "vendored data/ glossaries not available in this checkout"
        )

        let dbPath = NSTemporaryDirectory().appending("seekdict-test-\(UUID().uuidString).sqlite")
        tempPaths.append(dbPath)
        let store = try DictionaryStore(path: dbPath)
        try store.importGlossary(at: zhURL, direction: .englishToChinese)
        try store.importGlossary(at: enURL, direction: .chineseToEnglish)

        let enWords = ["abandon", "banana", "committee", "diligent", "ephemeral"]
        let zhWords = ["放弃", "香蕉", "委员会", "勤奋", "短暂的"]
        let iterations = 100

        var total: TimeInterval = 0
        for _ in 0..<iterations {
            for (en, zh) in zip(enWords, zhWords) {
                let start = Date()
                _ = try store.lookup(en, direction: .englishToChinese)
                _ = try store.lookup(zh, direction: .chineseToEnglish)
                total += Date().timeIntervalSince(start)
            }
        }
        let average = total / Double(iterations * enWords.count * 2)
        XCTAssertLessThan(average, 0.010, "average lookup took \(average)s")
    }
}
