import Foundation

public enum PartOfSpeech: String, CaseIterable {
    case noun = "n."
    case verb = "v."
    case adjective = "adj."
    case adverb = "adv."
    case pronoun = "pron."
    case preposition = "prep."
    case conjunction = "conj."
    case numeral = "num."
    case measureWord = "m."
    case particle = "part."
    case interjection = "int."
    case phrase = "phr."
}

public enum TranslationDirection: String, CaseIterable {
    case englishToChinese = "en-zh"
    case chineseToEnglish = "zh-en"
}

public enum GlossaryParseError: Error, Equatable, CustomStringConvertible {
    case missingWord(line: Int)
    case missingSense(line: Int)
    case tooManySenses(line: Int, count: Int)
    case invalidPartOfSpeech(line: Int, value: String)

    public var description: String {
        switch self {
        case .missingWord(let line):
            return "line \(line): missing word"
        case .missingSense(let line):
            return "line \(line): missing sense"
        case .tooManySenses(let line, let count):
            return "line \(line): \(count) senses, at most 2 allowed"
        case .invalidPartOfSpeech(let line, let value):
            return "line \(line): invalid part of speech '\(value)'"
        }
    }
}

public struct GlossarySense: Equatable {
    public let pos: PartOfSpeech?
    public let text: String

    public init(pos: PartOfSpeech?, text: String) {
        self.pos = pos
        self.text = text
    }
}

public struct GlossaryEntry: Equatable {
    public let word: String
    public let senses: [GlossarySense]

    public init(word: String, senses: [GlossarySense]) {
        self.word = word
        self.senses = senses
    }
}

public struct GlossaryParseOutcome: Equatable {
    public let entries: [GlossaryEntry]
    public let totalLines: Int
    public let skippedLines: Int
}

public struct ImportReport: Equatable {
    public let direction: TranslationDirection
    public let linesRead: Int
    public let skippedLines: Int
    public let importedEntries: Int
    public let importedSenses: Int
    public let duration: TimeInterval
}

extension ImportReport: CustomStringConvertible {
    public var description: String {
        String(
            format: "glossary %@: read %d lines, skipped %d, imported %d entries (%d senses) in %.2fs",
            direction.rawValue, linesRead, skippedLines, importedEntries, importedSenses, duration
        )
    }
}

public enum GlossaryParser {
    private static let posPrefixPattern = #"^([a-z]+\.) (.*)$"#

    public static func parse(contents: String) throws -> GlossaryParseOutcome {
        var entries: [GlossaryEntry] = []
        var totalLines = 0
        var skippedLines = 0
        let trimmed = contents.hasSuffix("\n") ? String(contents.dropLast()) : contents
        for (index, line) in trimmed.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineNumber = index + 1
            totalLines += 1
            guard !line.isEmpty, !line.hasPrefix("#") else {
                skippedLines += 1
                continue
            }
            entries.append(try parseLine(line, lineNumber: lineNumber))
        }
        return GlossaryParseOutcome(entries: entries, totalLines: totalLines, skippedLines: skippedLines)
    }

    static func parseLine(_ line: Substring, lineNumber: Int) throws -> GlossaryEntry {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 2 else {
            throw GlossaryParseError.missingSense(line: lineNumber)
        }
        guard fields.count <= 3 else {
            throw GlossaryParseError.tooManySenses(line: lineNumber, count: fields.count - 1)
        }
        guard !fields[0].isEmpty else {
            throw GlossaryParseError.missingWord(line: lineNumber)
        }
        let senses = try fields[1...].map { try parseSense($0, lineNumber: lineNumber) }
        return GlossaryEntry(word: fields[0], senses: senses)
    }

    static func parseSense(_ field: String, lineNumber: Int) throws -> GlossarySense {
        guard !field.isEmpty else {
            throw GlossaryParseError.missingSense(line: lineNumber)
        }
        if let match = field.range(of: posPrefixPattern, options: .regularExpression) {
            let spaceIndex = field.firstIndex(of: " ")!
            let rawPos = String(field[match.lowerBound..<spaceIndex])
            guard let pos = PartOfSpeech(rawValue: rawPos) else {
                throw GlossaryParseError.invalidPartOfSpeech(line: lineNumber, value: rawPos)
            }
            let text = String(field[field.index(after: spaceIndex)...])
            return GlossarySense(pos: pos, text: text)
        }
        return GlossarySense(pos: nil, text: field)
    }
}
