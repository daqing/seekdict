import XCTest
@testable import SeekDictCore

final class RetryPolicyTests: XCTestCase {
    private let policy = RetryPolicy.default

    func testUnauthorizedRoutesToReLogin() {
        XCTAssertEqual(policy.action(for: .unauthorized, after: 1), .reauthenticate)
        XCTAssertEqual(policy.action(for: .unauthorized, after: 99), .reauthenticate)
    }

    func testQuotaExhaustedNotifiesUserWithoutRetry() {
        guard case .notifyUser = policy.action(for: .quotaExhausted, after: 1) else {
            return XCTFail("expected .notifyUser, got \(policy.action(for: .quotaExhausted, after: 1))")
        }
        guard case .notifyUser = policy.action(for: .quotaExhausted, after: 99) else {
            return XCTFail("expected .notifyUser regardless of attempt")
        }
    }

    func testRateLimitedBacksOffExponentially() {
        XCTAssertEqual(policy.action(for: .rateLimited, after: 1), .retryAfter(2))
        XCTAssertEqual(policy.action(for: .rateLimited, after: 2), .retryAfter(4))
        XCTAssertEqual(policy.action(for: .rateLimited, after: 3), .fail)
    }

    func testServerErrorBacksOffExponentially() {
        XCTAssertEqual(policy.action(for: .serverError(statusCode: 500), after: 1), .retryAfter(2))
        XCTAssertEqual(policy.action(for: .serverError(statusCode: 503), after: 2), .retryAfter(4))
    }

    func testTransportErrorBacksOffExponentially() {
        XCTAssertEqual(policy.action(for: .transport("offline"), after: 1), .retryAfter(2))
    }

    func testRetryableErrorsGiveUpAfterMaxAttempts() {
        XCTAssertEqual(policy.action(for: .rateLimited, after: 3), .fail)
        XCTAssertEqual(policy.action(for: .serverError(statusCode: 500), after: 4), .fail)
        XCTAssertEqual(policy.action(for: .transport("offline"), after: 3), .fail)
    }

    func testOtherFourXXNeverRetries() {
        XCTAssertEqual(policy.action(for: .invalidRequest(statusCode: 400), after: 1), .fail)
        XCTAssertEqual(policy.action(for: .invalidRequest(statusCode: 404), after: 1), .fail)
    }

    func testDecodingErrorNeverRetries() {
        XCTAssertEqual(policy.action(for: .decoding("bad json"), after: 1), .fail)
    }

    func testCustomPolicyScalesBackoff() {
        let custom = RetryPolicy(baseDelay: 0.5, multiplier: 3, maxAttempts: 3)
        XCTAssertEqual(custom.action(for: .rateLimited, after: 1), .retryAfter(0.5))
        XCTAssertEqual(custom.action(for: .rateLimited, after: 2), .retryAfter(1.5))
        XCTAssertEqual(custom.action(for: .rateLimited, after: 3), .fail)
    }
}
