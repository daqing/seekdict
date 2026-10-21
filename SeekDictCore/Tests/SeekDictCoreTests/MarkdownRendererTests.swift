import XCTest
@testable import SeekDictCore

final class MarkdownRendererTests: XCTestCase {
    private let renderer = MarkdownRenderer()

    private func font(of output: NSAttributedString, at location: Int) -> MarkdownFont? {
        output.attribute(.font, at: location, effectiveRange: nil) as? MarkdownFont
    }

    private func isBold(_ font: MarkdownFont?) -> Bool {
        font?.fontDescriptor.symbolicTraits.contains(boldTrait) ?? false
    }

    private func isItalic(_ font: MarkdownFont?) -> Bool {
        font?.fontDescriptor.symbolicTraits.contains(italicTrait) ?? false
    }

    private func isMonospaced(_ font: MarkdownFont?) -> Bool {
        font?.fontDescriptor.symbolicTraits.contains(monospaceTrait) ?? false
    }

    #if canImport(UIKit)
    private let boldTrait = MarkdownFontDescriptor.SymbolicTraits.traitBold
    private let italicTrait = MarkdownFontDescriptor.SymbolicTraits.traitItalic
    private let monospaceTrait = MarkdownFontDescriptor.SymbolicTraits.traitMonoSpace
    #else
    private let boldTrait = MarkdownFontDescriptor.SymbolicTraits.bold
    private let italicTrait = MarkdownFontDescriptor.SymbolicTraits.italic
    private let monospaceTrait = MarkdownFontDescriptor.SymbolicTraits.monoSpace
    #endif

    func testHeadingLevelsScaleAndBold() {
        let output = renderer.render("# One\n\n## Two\n\n### Three")
        XCTAssertEqual(output.string, "One\nTwo\nThree")

        let oneFont = font(of: output, at: 0)
        XCTAssertEqual(oneFont?.pointSize ?? 0, 17 * 1.6, accuracy: 0.01)
        XCTAssertTrue(isBold(oneFont))

        let twoRange = output.string.range(of: "Two")!
        let twoFont = font(of: output, at: twoRange.lowerBound.utf16Offset(in: output.string))
        XCTAssertEqual(twoFont?.pointSize ?? 0, 17 * 1.35, accuracy: 0.01)

        let threeRange = output.string.range(of: "Three")!
        let threeFont = font(of: output, at: threeRange.lowerBound.utf16Offset(in: output.string))
        XCTAssertEqual(threeFont?.pointSize ?? 0, 17 * 1.2, accuracy: 0.01)
    }

    func testPlainParagraphJoinsLines() {
        let output = renderer.render("first line\nsecond line")
        XCTAssertEqual(output.string, "first line second line")
        let font = font(of: output, at: 0)
        XCTAssertEqual(font?.pointSize ?? 0, 17, accuracy: 0.01)
        XCTAssertFalse(isBold(font))
    }

    func testUnorderedListRendersBullets() {
        let output = renderer.render("- one\n- two")
        XCTAssertEqual(output.string, "•  one\n•  two")
    }

    func testOrderedListRendersSourceNumbers() {
        let output = renderer.render("1. one\n2. two\n10. ten")
        XCTAssertEqual(output.string, "1.  one\n2.  two\n10.  ten")
    }

    func testLinkGetsLinkAttributeAndText() {
        let output = renderer.render("see [the docs](https://example.com) here")
        XCTAssertEqual(output.string, "see the docs here")
        let range = output.string.range(of: "the docs")!
        let location = range.lowerBound.utf16Offset(in: output.string)
        XCTAssertEqual(
            output.attribute(.link, at: location, effectiveRange: nil) as? URL,
            URL(string: "https://example.com")
        )
    }

    func testBoldRendersBoldFont() {
        let output = renderer.render("a **bold** word")
        let range = output.string.range(of: "bold")!
        let boldFont = font(of: output, at: range.lowerBound.utf16Offset(in: output.string))
        XCTAssertTrue(isBold(boldFont))

        let plainRange = output.string.range(of: "word")!
        let plainFont = font(of: output, at: plainRange.lowerBound.utf16Offset(in: output.string))
        XCTAssertFalse(isBold(plainFont))
    }

    func testItalicRendersItalicFont() {
        let output = renderer.render("an *italic* word")
        let range = output.string.range(of: "italic")!
        let italicFont = font(of: output, at: range.lowerBound.utf16Offset(in: output.string))
        XCTAssertTrue(isItalic(italicFont))
    }

    func testInlineCodeRendersMonospacedFont() {
        let output = renderer.render("call `main()` now")
        let range = output.string.range(of: "main()")!
        let font = font(of: output, at: range.lowerBound.utf16Offset(in: output.string))
        XCTAssertTrue(isMonospaced(font))
    }

    func testUnmatchedMarkersRenderLiterally() {
        let output = renderer.render("a * b and [c]( and `d")
        XCTAssertEqual(output.string, "a * b and [c]( and `d")
    }

    func testMixedBlocks() {
        let markdown = """
        # Title

        Intro with **bold** and a [link](https://example.com).

        - item one
        - item two
        """
        let output = renderer.render(markdown)
        XCTAssertTrue(output.string.hasPrefix("Title\nIntro with bold and a link."))
        XCTAssertTrue(output.string.contains("•  item one\n•  item two"))

        let linkRange = output.string.range(of: "link")!
        XCTAssertNotNil(
            output.attribute(.link, at: linkRange.lowerBound.utf16Offset(in: output.string), effectiveRange: nil)
        )
    }
}
