import Foundation
import os

public final class DictionaryService {
    public let store: DictionaryStore

    private static let logger = Logger(subsystem: "SeekDict", category: "dictionary")

    public init(store: DictionaryStore) {
        self.store = store
    }

    public static func openDefault(
        storeURL: URL? = nil,
        glossaries: [TranslationDirection: URL]
    ) throws -> DictionaryService {
        let url = try storeURL ?? DictionaryStore.defaultStoreURL()
        let store = try DictionaryStore(path: url.path)
        let reports = try store.importIfNeeded(glossaries)
        for report in reports {
            logger.info("\(report.description)")
        }
        return DictionaryService(store: store)
    }

    public func lookup(
        _ word: String,
        direction: TranslationDirection
    ) -> LookupResult? {
        try? store.lookup(word, direction: direction)
    }

    public func lookup(_ word: String) -> LookupResult? {
        lookup(word, direction: inferredDirection(for: word))
    }

    func inferredDirection(for word: String) -> TranslationDirection {
        word.contains(where: \.isCJK) ? .chineseToEnglish : .englishToChinese
    }
}

private extension Character {
    var isCJK: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }
}
