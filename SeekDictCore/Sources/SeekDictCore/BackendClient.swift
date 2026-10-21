import Foundation

public protocol HTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPTransport {}

public final class BackendClient {
    public let baseURL: URL
    private let transport: HTTPTransport
    private let tokenProvider: () -> String?

    public init(
        baseURL: URL,
        transport: HTTPTransport = URLSession.shared,
        tokenProvider: @escaping () -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.tokenProvider = tokenProvider
    }

    public func searchNews(word: String, limit: Int = 10) async throws -> [Item] {
        try await send(
            SearchResponse.self,
            path: "/v1/search/news",
            query: ["word": word, "limit": String(limit)]
        ).results
    }

    public func searchWeibo(word: String, limit: Int = 10) async throws -> [Item] {
        try await send(
            SearchResponse.self,
            path: "/v1/search/weibo",
            query: ["word": word, "limit": String(limit)]
        ).results
    }

    public func hot() async throws -> [HotItem] {
        try await send(HotResponse.self, path: "/v1/hot", query: [:]).items
    }

    public func article(url: String) async throws -> Article {
        try await send(Article.self, path: "/v1/article", query: ["url": url])
    }

    private func send<Response: Decodable>(
        _ type: Response.Type,
        path: String,
        query: [String: String]
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else {
            throw APIError.invalidRequest(statusCode: 0)
        }
        var request = URLRequest(url: url)
        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(String(describing: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("response is not HTTP")
        }
        switch http.statusCode {
        case 200...299:
            break
        case 401:
            throw APIError.unauthorized
        case 402:
            throw APIError.quotaExhausted
        case 429:
            throw APIError.rateLimited
        case 500...599:
            throw APIError.serverError(statusCode: http.statusCode)
        default:
            throw APIError.invalidRequest(statusCode: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}

private struct SearchResponse: Decodable {
    let results: [Item]
}

private struct HotResponse: Decodable {
    let items: [HotItem]
}
