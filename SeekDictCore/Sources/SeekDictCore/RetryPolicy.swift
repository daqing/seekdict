import Foundation

public enum RetryAction: Equatable {
    case reauthenticate
    case notifyUser(String)
    case retryAfter(TimeInterval)
    case fail
}

public struct RetryPolicy: Equatable {
    public var baseDelay: TimeInterval
    public var multiplier: Double
    public var maxAttempts: Int

    public static let `default` = RetryPolicy()

    public init(baseDelay: TimeInterval = 2, multiplier: Double = 2, maxAttempts: Int = 3) {
        self.baseDelay = baseDelay
        self.multiplier = multiplier
        self.maxAttempts = maxAttempts
    }

    public func action(for error: APIError, after attempt: Int) -> RetryAction {
        switch error {
        case .unauthorized:
            return .reauthenticate
        case .quotaExhausted:
            return .notifyUser("The service is temporarily out of quota. Please try again later.")
        case .rateLimited, .serverError, .transport:
            guard attempt < maxAttempts else { return .fail }
            return .retryAfter(delay(for: attempt))
        case .invalidRequest, .decoding:
            return .fail
        }
    }

    private func delay(for attempt: Int) -> TimeInterval {
        baseDelay * pow(multiplier, Double(attempt - 1))
    }
}
