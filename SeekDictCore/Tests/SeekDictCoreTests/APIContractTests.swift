import XCTest
@testable import SeekDictCore

final class APIContractTests: XCTestCase {
    func testItemDecodesSnakeCaseKeys() throws {
        let json = """
        {
            "title": "Abandon ship: markets sink",
            "url": "https://example.com/news/1",
            "snippet": "Markets fell sharply...",
            "date": "2026-10-20",
            "source_name": "Example News",
            "source_icon": "https://example.com/icon.png",
            "score": 0.93
        }
        """
        let item = try JSONDecoder().decode(Item.self, from: Data(json.utf8))
        XCTAssertEqual(item.title, "Abandon ship: markets sink")
        XCTAssertEqual(item.url, "https://example.com/news/1")
        XCTAssertEqual(item.snippet, "Markets fell sharply...")
        XCTAssertEqual(item.date, "2026-10-20")
        XCTAssertEqual(item.sourceName, "Example News")
        XCTAssertEqual(item.sourceIcon, "https://example.com/icon.png")
        XCTAssertEqual(item.score, 0.93)
    }

    func testItemEncodesSnakeCaseKeys() throws {
        let item = Item(
            title: "t",
            url: "https://example.com",
            snippet: "s",
            date: "2026-10-20",
            sourceName: "src",
            sourceIcon: "icon",
            score: 1.0
        )
        let data = try JSONEncoder().encode(item)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["source_name"] as? String, "src")
        XCTAssertEqual(object["source_icon"] as? String, "icon")
        XCTAssertNil(object["sourceName"])
    }

    func testHotItemDecodesStringHeat() throws {
        let json = #"""
        {"rank": 1, "title": "台风登陆", "url": "https://weibo.com/hot/1", "heat": "45.2万"}
        """#
        let hot = try JSONDecoder().decode(HotItem.self, from: Data(json.utf8))
        XCTAssertEqual(hot.rank, 1)
        XCTAssertEqual(hot.title, "台风登陆")
        XCTAssertEqual(hot.url, "https://weibo.com/hot/1")
        XCTAssertEqual(hot.heat, "45.2万")
    }

    func testHotItemDecodesNumericHeat() throws {
        let json = #"""
        {"rank": 2, "title": "发布会", "url": "https://weibo.com/hot/2", "heat": 1234567}
        """#
        let hot = try JSONDecoder().decode(HotItem.self, from: Data(json.utf8))
        XCTAssertEqual(hot.heat, "1234567")
    }

    func testArticleDecodesContentMarkdown() throws {
        let json = #"""
        {"title": "Deep dive", "content_markdown": "# Deep dive\n\nHello **world**."}
        """#
        let article = try JSONDecoder().decode(Article.self, from: Data(json.utf8))
        XCTAssertEqual(article.title, "Deep dive")
        XCTAssertEqual(article.contentMarkdown, "# Deep dive\n\nHello **world**.")
    }

    func testAPIErrorDescriptions() {
        XCTAssertEqual(APIError.unauthorized.description, "unauthorized (401)")
        XCTAssertEqual(APIError.serverError(statusCode: 503).description, "server error (503)")
        XCTAssertEqual(APIError.invalidRequest(statusCode: 400).description, "invalid request (400)")
    }
}
