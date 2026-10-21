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

public struct GlossarySense: Equatable {
    public let pos: String?
    public let text: String

    public init(pos: String?, text: String) {
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

public struct ImportReport: Equatable {
    public let direction: TranslationDirection
    public let linesRead: Int
    public let skippedLines: Int
    public let importedEntries: Int
    public let importedSenses: Int
    public let duration: TimeInterval
}

public struct GlossaryParseOutcome: Equatable {
    public let entries: [GlossaryEntry]
    public let totalLines: Int
    public let skippedLines: Int
}

public enum GlossaryParser {
    public static func parse(contents: String) throws -> GlossaryParseOutcome {
        var entries: [GlossaryEntry] = []
        var totalLines = 0
        var skippedLines = 0
        let trimmed = contents.hasSuffix("\n") ? String(contents.dropLast()) : contents
        for line in trimmed.split(separator: "\n", omittingEmptySubsequences: false) {
            totalLines += 1
            guard !line.isEmpty, !line.hasPrefix("#") else {
                skippedLines += 1
                continue
            }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            let senses = fields.dropFirst().map(parseSense(_:))
            entries.append(GlossaryEntry(word: fields[0], senses: senses))
        }
        return GlossaryParseOutcome(entries: entries, totalLines: totalLines, skippedLines: skippedLines)
    }

    static func parseSense(_ field: String) -> GlossarySense {
        if let spaceIndex = field.firstIndex(of: " "),
           field[field.startIndex..<spaceIndex].range(of: #"^[a-z]+\.$"#, options: .regularExpression) != nil {
            let pos = String(field[field.startIndex..<spaceIndex])
            let text = String(field[field.index(after: spaceIndex)...])
            return GlossarySense(pos: pos, text: text)
        }
        return GlossarySense(pos: nil, text: field)
    }
}
