import XCTest
@testable import SeekDictCore

final class LookupTests: XCTestCase {
    private var tempPaths: [String] = []

    override func tearDown() {
        for path in tempPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempPaths.removeAll()
    }

    private func makeStore(
        importingGlossaryZh zhContents: String = "abandon\tv. 放弃\n",
        glossaryEn enContents: String = "放弃\tv. abandon\n"
    ) throws -> DictionaryStore {
        let dir = NSTemporaryDirectory().appending("seekdict-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        tempPaths.append(dir)
        let zhTSV = dir.appending("/glossary-zh.tsv")
        let enTSV = dir.appending("/glossary-en.tsv")
        try zhContents.write(toFile: zhTSV, atomically: true, encoding: .utf8)
        try enContents.write(toFile: enTSV, atomically: true, encoding: .utf8)
        let dbPath = dir.appending("/dict.sqlite")
        let store = try DictionaryStore(path: dbPath)
        try store.importGlossary(at: URL(fileURLWithPath: zhTSV), direction: .englishToChinese)
        try store.importGlossary(at: URL(fileURLWithPath: enTSV), direction: .chineseToEnglish)
        return store
    }

    func testExactMatchReturnsOrderedSenses() throws {
        let store = try makeStore(importingGlossaryZh: "abandon\tv. 放弃\tn. 放任\n")
        let result = try store.lookup("abandon", direction: .englishToChinese)
        XCTAssertEqual(result?.word, "abandon")
        XCTAssertEqual(result?.senses, [
            GlossarySense(pos: .verb, text: "放弃"),
            GlossarySense(pos: .noun, text: "放任"),
        ])
    }

    func testEnglishKeysAreLowercased() throws {
        let store = try makeStore(importingGlossaryZh: "abandon\tv. 放弃\n")
        let result = try store.lookup("Abandon", direction: .englishToChinese)
        XCTAssertEqual(result?.word, "abandon")
        XCTAssertEqual(result?.senses, [GlossarySense(pos: .verb, text: "放弃")])
    }

    func testLeadingAndTrailingWhitespaceIsIgnored() throws {
        let store = try makeStore(importingGlossaryZh: "abandon\tv. 放弃\n")
        let result = try store.lookup("  abandon \n", direction: .englishToChinese)
        XCTAssertNotNil(result)
    }

    func testMissReturnsNil() throws {
        let store = try makeStore(importingGlossaryZh: "abandon\tv. 放弃\n")
        XCTAssertNil(try store.lookup("notaword", direction: .englishToChinese))
    }

    func testLookupIsPerDirection() throws {
        let store = try makeStore(importingGlossaryZh: "abandon\tv. 放弃\n")
        XCTAssertNotNil(try store.lookup("abandon", direction: .englishToChinese))
        XCTAssertNil(try store.lookup("abandon", direction: .chineseToEnglish))
    }

    func testChineseLookupDoesNotLowercaseKey() throws {
        let store = try makeStore(glossaryEn: "OK\tadj. 好的\n")
        XCTAssertNotNil(try store.lookup("OK", direction: .chineseToEnglish))
        XCTAssertNil(try store.lookup("ok", direction: .chineseToEnglish))
    }

    func testAbandonFindsAbandonInRealGlossary() throws {
        let dataDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("data")
        let zhURL = dataDir.appendingPathComponent("glossary-zh.tsv")
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: zhURL.path),
            "vendored data/ glossaries not available in this checkout"
        )
        let dbPath = NSTemporaryDirectory().appending("seekdict-test-\(UUID().uuidString).sqlite")
        tempPaths.append(dbPath)
        let store = try DictionaryStore(path: dbPath)
        try store.importGlossary(at: zhURL, direction: .englishToChinese)

        let result = try store.lookup("Abandon", direction: .englishToChinese)
        XCTAssertEqual(result?.word, "abandon")
        XCTAssertFalse(result?.senses.isEmpty ?? true)
    }
}
