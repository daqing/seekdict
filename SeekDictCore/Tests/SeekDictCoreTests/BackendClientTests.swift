import XCTest
@testable import SeekDictCore

final class MockTransport: HTTPTransport {
    struct Stub {
        let statusCode: Int
        let body: Data
    }

    private(set) var requests: [URLRequest] = []
    private var stubs: [Stub]
    private let error: Error?

    init(stubs: [Stub], error: Error? = nil) {
        self.stubs = stubs
        self.error = error
    }

    init(json: String, statusCode: Int = 200) {
        self.stubs = [Stub(statusCode: statusCode, body: Data(json.utf8))]
        self.error = nil
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if let error {
            throw error
        }
        guard let stub = stubs.isEmpty ? nil : stubs.removeFirst() else {
            throw APIError.transport("no stub left")
        }
        let response = HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (stub.body, response)
    }
}

final class BackendClientTests: XCTestCase {
    private let baseURL = URL(string: "https://api.seekdict.example")!

    private func makeClient(
        transport: MockTransport,
        token: String? = "test-token"
    ) -> BackendClient {
        BackendClient(baseURL: baseURL, transport: transport, tokenProvider: { token })
    }

    func testSearchNewsHitsEndpointAndDecodesResults() async throws {
        let transport = MockTransport(json: #"""
        {"results": [{"title": "N", "url": "https://a/1", "snippet": "s",
                      "date": "2026-10-20", "source_name": "sn", "source_icon": "si", "score": 0.5}]}
        """#)
        let client = makeClient(transport: transport)

        let items = try await client.searchNews(word: "abandon", limit: 5)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "N")
        XCTAssertEqual(items[0].sourceName, "sn")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/search/news")
        XCTAssertEqual(try query(of: request), ["word": "abandon", "limit": "5"])
    }

    func testSearchWeiboHitsEndpointAndDecodesResults() async throws {
        let transport = MockTransport(json: #"""
        {"results": [{"title": "W", "url": "https://a/2", "snippet": "s",
                      "date": "2026-10-21", "source_name": "sn", "source_icon": "si", "score": 0.9}]}
        """#)
        let client = makeClient(transport: transport)

        let items = try await client.searchWeibo(word: "放弃", limit: 3)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "W")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/search/weibo")
        XCTAssertEqual(try query(of: request), ["word": "放弃", "limit": "3"])
    }

    func testHotHitsEndpointAndDecodesItems() async throws {
        let transport = MockTransport(json: #"""
        {"items": [{"rank": 1, "title": "T", "url": "https://w/1", "heat": "12万"}]}
        """#)
        let client = makeClient(transport: transport)

        let items = try await client.hot()

        XCTAssertEqual(items, [HotItem(rank: 1, title: "T", url: "https://w/1", heat: "12万")])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/hot")
        XCTAssertTrue(request.url?.query?.isEmpty ?? true)
    }

    func testArticleHitsEndpointAndDecodesPayload() async throws {
        let transport = MockTransport(json: #"""
        {"title": "A", "content_markdown": "# A\n\nbody"}
        """#)
        let client = makeClient(transport: transport)

        let article = try await client.article(url: "https://a/9")

        XCTAssertEqual(article.title, "A")
        XCTAssertEqual(article.contentMarkdown, "# A\n\nbody")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/article")
        XCTAssertEqual(request.url?.query, "url=https://a/9")
    }

    func testBearerTokenIsInjected() async throws {
        let transport = MockTransport(json: #"{"items": []}"#)
        let client = makeClient(transport: transport, token: "tok-123")

        _ = try await client.hot()

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
    }

    func testAuthorizationHeaderOmittedWithoutToken() async throws {
        let transport = MockTransport(json: #"{"items": []}"#)
        let client = makeClient(transport: transport, token: nil)

        _ = try await client.hot()

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testStatusCodesMapToAPIError() async throws {
        let cases: [(Int, APIError)] = [
            (401, .unauthorized),
            (402, .quotaExhausted),
            (429, .rateLimited),
            (500, .serverError(statusCode: 500)),
            (503, .serverError(statusCode: 503)),
            (400, .invalidRequest(statusCode: 400)),
            (404, .invalidRequest(statusCode: 404)),
        ]
        for (statusCode, expected) in cases {
            let transport = MockTransport(json: #"{"results": []}"#, statusCode: statusCode)
            let client = makeClient(transport: transport)
            do {
                _ = try await client.searchNews(word: "x")
                XCTFail("expected error for status \(statusCode)")
            } catch let error as APIError {
                XCTAssertEqual(error, expected, "status \(statusCode)")
            }
        }
    }

    func testMalformedPayloadThrowsDecodingError() async throws {
        let transport = MockTransport(json: #"{"unexpected": true}"#)
        let client = makeClient(transport: transport)

        do {
            _ = try await client.hot()
            XCTFail("expected decoding error")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("expected .decoding, got \(error)")
            }
        }
    }

    func testTransportFailureIsWrapped() async throws {
        enum Fake: Error { case offline }
        let transport = MockTransport(stubs: [], error: Fake.offline)
        let client = makeClient(transport: transport)

        do {
            _ = try await client.hot()
            XCTFail("expected transport error")
        } catch let error as APIError {
            guard case .transport = error else {
                return XCTFail("expected .transport, got \(error)")
            }
        }
    }

    private func query(of request: URLRequest) throws -> [String: String] {
        let components = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        return Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
    }
}
