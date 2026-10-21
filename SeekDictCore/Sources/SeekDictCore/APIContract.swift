import Foundation

public struct Item: Codable, Equatable {
    public var title: String
    public var url: String
    public var snippet: String
    public var date: String
    public var sourceName: String
    public var sourceIcon: String
    public var score: Double

    public init(
        title: String,
        url: String,
        snippet: String,
        date: String,
        sourceName: String,
        sourceIcon: String,
        score: Double
    ) {
        self.title = title
        self.url = url
        self.snippet = snippet
        self.date = date
        self.sourceName = sourceName
        self.sourceIcon = sourceIcon
        self.score = score
    }

    enum CodingKeys: String, CodingKey {
        case title, url, snippet, date, score
        case sourceName = "source_name"
        case sourceIcon = "source_icon"
    }
}

public struct HotItem: Codable, Equatable {
    public var rank: Int
    public var title: String
    public var url: String
    public var heat: String

    public init(rank: Int, title: String, url: String, heat: String) {
        self.rank = rank
        self.title = title
        self.url = url
        self.heat = heat
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = try container.decode(Int.self, forKey: .rank)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decode(String.self, forKey: .url)
        if let string = try? container.decode(String.self, forKey: .heat) {
            heat = string
        } else if let number = try? container.decode(Int.self, forKey: .heat) {
            heat = String(number)
        } else {
            heat = try container.decode(Double.self, forKey: .heat).description
        }
    }
}

public struct Article: Codable, Equatable {
    public var title: String
    public var contentMarkdown: String

    public init(title: String, contentMarkdown: String) {
        self.title = title
        self.contentMarkdown = contentMarkdown
    }

    enum CodingKeys: String, CodingKey {
        case title
        case contentMarkdown = "content_markdown"
    }
}

public enum APIError: Error, Equatable, CustomStringConvertible {
    case unauthorized
    case quotaExhausted
    case rateLimited
    case serverError(statusCode: Int)
    case invalidRequest(statusCode: Int)
    case decoding(String)
    case transport(String)

    public var description: String {
        switch self {
        case .unauthorized:
            return "unauthorized (401)"
        case .quotaExhausted:
            return "backend quota exhausted (402)"
        case .rateLimited:
            return "rate limited (429)"
        case .serverError(let statusCode):
            return "server error (\(statusCode))"
        case .invalidRequest(let statusCode):
            return "invalid request (\(statusCode))"
        case .decoding(let message):
            return "failed to decode response: \(message)"
        case .transport(let message):
            return "transport error: \(message)"
        }
    }
}
