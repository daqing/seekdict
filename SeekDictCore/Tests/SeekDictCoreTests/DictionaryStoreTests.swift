import XCTest
@testable import SeekDictCore

final class DictionaryStoreTests: XCTestCase {
    private var tempPaths: [String] = []

    override func tearDown() {
        for path in tempPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempPaths.removeAll()
    }

    private func makeTempFile(containing contents: String, name: String = "glossary.tsv") -> URL {
        let path = NSTemporaryDirectory().appending("seekdict-test-\(UUID().uuidString)-\(name)")
        tempPaths.append(path)
        try! contents.write(toFile: path, atomically: true, encoding: .utf8)
        return URL(fileURLWithPath: path)
    }

    private func makeTempDatabase() throws -> String {
        let path = NSTemporaryDirectory().appending("seekdict-test-\(UUID().uuidString).sqlite")
        tempPaths.append(path)
        return path
    }

    func testImportGlossaryInsertsEntriesWithSenses() throws {
        let url = makeTempFile(containing: """
        # comment line
        abandon	v. 放弃	n. 放任
        abbey	n. 修道院

        """)
        let store = try DictionaryStore(path: makeTempDatabase())

        let report = try store.importGlossary(at: url, direction: .englishToChinese)

        XCTAssertEqual(report.linesRead, 3)
        XCTAssertEqual(report.skippedLines, 1)
        XCTAssertEqual(report.importedEntries, 2)
        XCTAssertEqual(report.importedSenses, 3)
        XCTAssertTrue(store.isImported(.englishToChinese))
        XCTAssertFalse(store.isImported(.chineseToEnglish))
    }

    func testFirstLaunchImportIsIdempotent() throws {
        let zh = makeTempFile(containing: "abandon\tv. 放弃\n", name: "glossary-zh.tsv")
        let en = makeTempFile(containing: "放弃\tv. abandon\n", name: "glossary-en.tsv")
        let path = try makeTempDatabase()
        let glossaries: [TranslationDirection: URL] = [
            .englishToChinese: zh,
            .chineseToEnglish: en,
        ]

        let store = try DictionaryStore(path: path)
        let firstReports = try store.importIfNeeded(glossaries)
        XCTAssertEqual(firstReports.count, 2)
        XCTAssertTrue(store.isImported(.englishToChinese))
        XCTAssertTrue(store.isImported(.chineseToEnglish))

        let reopened = try DictionaryStore(path: path)
        let secondReports = try reopened.importIfNeeded(glossaries)
        XCTAssertTrue(secondReports.isEmpty)
    }

    func testRealGlossariesImportCleanly() throws {
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

        let store = try DictionaryStore(path: makeTempDatabase())
        let zhReport = try store.importGlossary(at: zhURL, direction: .englishToChinese)
        let enReport = try store.importGlossary(at: enURL, direction: .chineseToEnglish)

        XCTAssertGreaterThan(zhReport.importedEntries, 40_000)
        XCTAssertGreaterThan(enReport.importedEntries, 200_000)
        XCTAssertEqual(zhReport.skippedLines, 1)
        XCTAssertEqual(enReport.skippedLines, 1)
    }
}
