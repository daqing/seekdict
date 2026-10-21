import XCTest
@testable import SeekDictCore

final class DictionaryServiceTests: XCTestCase {
    private var tempPaths: [String] = []

    override func tearDown() {
        for path in tempPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempPaths.removeAll()
    }

    private func makeService() throws -> DictionaryService {
        let dir = NSTemporaryDirectory().appending("seekdict-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        tempPaths.append(dir)
        let zhTSV = dir.appending("/glossary-zh.tsv")
        let enTSV = dir.appending("/glossary-en.tsv")
        try "abandon\tv. 放弃\n".write(toFile: zhTSV, atomically: true, encoding: .utf8)
        try "放弃\tv. abandon\n".write(toFile: enTSV, atomically: true, encoding: .utf8)
        let dbPath = dir.appending("/dict.sqlite")
        tempPaths.append(dbPath)
        let store = try DictionaryStore(path: dbPath)
        try store.importGlossary(at: URL(fileURLWithPath: zhTSV), direction: .englishToChinese)
        try store.importGlossary(at: URL(fileURLWithPath: enTSV), direction: .chineseToEnglish)
        return DictionaryService(store: store)
    }

    func testLookupInfersEnglishToChinese() throws {
        let service = try makeService()
        let result = service.lookup("abandon")
        XCTAssertEqual(result?.direction, .englishToChinese)
        XCTAssertEqual(result?.senses, [GlossarySense(pos: .verb, text: "放弃")])
    }

    func testLookupInfersChineseToEnglish() throws {
        let service = try makeService()
        let result = service.lookup("放弃")
        XCTAssertEqual(result?.direction, .chineseToEnglish)
    }

    func testMissReturnsNil() throws {
        let service = try makeService()
        XCTAssertNil(service.lookup("nosuchword"))
    }

    func testOpenDefaultImportsOnceAndLooksUp() throws {
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
        let dir = NSTemporaryDirectory().appending("seekdict-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        tempPaths.append(dir)
        let dbPath = dir.appending("/dict.sqlite")
        tempPaths.append(dbPath)

        let glossaries: [TranslationDirection: URL] = [
            .englishToChinese: zhURL,
            .chineseToEnglish: enURL,
        ]
        let storeURL = URL(fileURLWithPath: dbPath)
        _ = try DictionaryService.openDefault(storeURL: storeURL, glossaries: glossaries)
        let service = try DictionaryService.openDefault(storeURL: storeURL, glossaries: glossaries)
        XCTAssertEqual(service.lookup("apple")?.word, "apple")
    }
}
