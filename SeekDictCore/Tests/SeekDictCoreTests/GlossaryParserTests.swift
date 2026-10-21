import XCTest
@testable import SeekDictCore

final class GlossaryParserTests: XCTestCase {
    private func parse(_ contents: String) throws -> GlossaryParseOutcome {
        try GlossaryParser.parse(contents: contents)
    }

    func testParsesSensesWithAndWithoutPos() throws {
        let outcome = try parse("abandon\tv. 放弃\tn. 放任\na\t一\n")
        XCTAssertEqual(outcome.entries, [
            GlossaryEntry(word: "abandon", senses: [
                GlossarySense(pos: .verb, text: "放弃"),
                GlossarySense(pos: .noun, text: "放任"),
            ]),
            GlossaryEntry(word: "a", senses: [
                GlossarySense(pos: nil, text: "一"),
            ]),
        ])
    }

    func testSkipsCommentsAndBlankLinesButCountsThem() throws {
        let outcome = try parse("# header\n\nword\t译词\n\n")
        XCTAssertEqual(outcome.entries.count, 1)
        XCTAssertEqual(outcome.totalLines, 4)
        XCTAssertEqual(outcome.skippedLines, 3)
    }

    func testAllEnumPosValuesAreAccepted() throws {
        let contents = PartOfSpeech.allCases
            .map { "w\t\($0.rawValue) x" }
            .joined(separator: "\n")
        let outcome = try parse(contents)
        XCTAssertEqual(outcome.entries.map { $0.senses[0].pos }, Array(PartOfSpeech.allCases))
    }

    func testSenseStartingWithDottedAbbreviationIsNotPos() throws {
        let outcome = try parse("w\te.g. something\n")
        XCTAssertEqual(outcome.entries[0].senses, [GlossarySense(pos: nil, text: "e.g. something")])
    }

    func testMissingSenseFieldFails() throws {
        XCTAssertThrowsError(try parse("lonelyword\n")) { error in
            XCTAssertEqual(error as? GlossaryParseError, .missingSense(line: 1))
        }
    }

    func testEmptySenseFieldFails() throws {
        XCTAssertThrowsError(try parse("word\t\n")) { error in
            XCTAssertEqual(error as? GlossaryParseError, .missingSense(line: 1))
        }
    }

    func testEmptyWordFieldFails() throws {
        XCTAssertThrowsError(try parse("\t译词\n")) { error in
            XCTAssertEqual(error as? GlossaryParseError, .missingWord(line: 1))
        }
    }

    func testMoreThanTwoSensesFails() throws {
        XCTAssertThrowsError(try parse("word\t1\t2\t3\n")) { error in
            XCTAssertEqual(error as? GlossaryParseError, .tooManySenses(line: 1, count: 3))
        }
    }

    func testUnknownPosPrefixFails() throws {
        XCTAssertThrowsError(try parse("word\tfoo. bar\n")) { error in
            XCTAssertEqual(error as? GlossaryParseError, .invalidPartOfSpeech(line: 1, value: "foo."))
        }
    }

    func testFailFastStopsAtFirstMalformedLine() throws {
        XCTAssertThrowsError(try parse("good\t1\nbad\nworse\t3\n")) { error in
            XCTAssertEqual(error as? GlossaryParseError, .missingSense(line: 2))
        }
    }

    func testLineNumbersAccountForComments() throws {
        XCTAssertThrowsError(try parse("# header\n\nok\t1\nbad\n")) { error in
            XCTAssertEqual(error as? GlossaryParseError, .missingSense(line: 4))
        }
    }

    func testRealGlossariesPassStrictParsing() throws {
        let dataDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("data")
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: dataDir.path),
            "vendored data/ glossaries not available in this checkout"
        )
        for name in ["glossary-zh.tsv", "glossary-en.tsv"] {
            let contents = try String(contentsOf: dataDir.appendingPathComponent(name), encoding: .utf8)
            let outcome = try parse(contents)
            XCTAssertFalse(outcome.entries.isEmpty, name)
        }
    }
}
