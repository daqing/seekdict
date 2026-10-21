import Foundation
import SQLite3

public enum DatabaseError: Error, CustomStringConvertible {
    case openFailed(String)
    case executeFailed(String)

    public var description: String {
        switch self {
        case .openFailed(let message):
            return "failed to open database: \(message)"
        case .executeFailed(let message):
            return "failed to execute statement: \(message)"
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

    public func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errorMessage)
            throw DatabaseError.executeFailed(message)
        }
    }

    func prepareStatement(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard result == SQLITE_OK else {
            throw DatabaseError.executeFailed(lastErrorMessage)
        }
        return statement
    }

    var lastErrorMessage: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
    }
}
