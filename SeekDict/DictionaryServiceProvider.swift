import Foundation
import SeekDictCore

enum DictionaryServiceProvider {
    private static let lock = NSLock()
    private static var service: DictionaryService?
    private static var isBuilding = false
    private static var pending: [(DictionaryService?) -> Void] = []

    static func service(completion: @escaping (DictionaryService?) -> Void) {
        lock.lock()
        if let service {
            lock.unlock()
            completion(service)
            return
        }
        if isBuilding {
            pending.append(completion)
            lock.unlock()
            return
        }
        isBuilding = true
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async {
            let built = buildService()
            lock.lock()
            service = built
            isBuilding = false
            let callbacks = pending
            pending.removeAll()
            lock.unlock()
            DispatchQueue.main.async {
                completion(built)
                callbacks.forEach { $0(built) }
            }
        }
    }

    private static func buildService() -> DictionaryService? {
        guard
            let zh = Bundle.main.url(forResource: "glossary-zh", withExtension: "tsv"),
            let en = Bundle.main.url(forResource: "glossary-en", withExtension: "tsv")
        else { return nil }
        return try? DictionaryService.openDefault(glossaries: [
            .englishToChinese: zh,
            .chineseToEnglish: en,
        ])
    }
}
