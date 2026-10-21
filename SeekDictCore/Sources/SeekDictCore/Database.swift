import Foundation
import SQLite3

public enum DatabaseError: Error, CustomStringConvertible {
    case openFailed(String)

    public var description: String {
        switch self {
        case .openFailed(let message):
            return "failed to open database: \(message)"
        }
    }
}

public final class Database {
    private var handle: OpaquePointer?

    public init(path: String) throws {
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(
            path,
            &handle,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK, let opened = handle else {
            let message = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(handle)
            throw DatabaseError.openFailed(message)
        }
        self.handle = opened
    }

    public var isOpen: Bool {
        handle != nil
    }

    public func close() {
        if let handle {
            sqlite3_close(handle)
            self.handle = nil
        }
    }

    deinit {
        close()
    }
}
