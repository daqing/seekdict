import Foundation

#if canImport(UIKit)
import UIKit
public typealias MarkdownFont = UIFont
public typealias MarkdownColor = UIColor
typealias MarkdownFontDescriptor = UIFontDescriptor
#elseif canImport(AppKit)
import AppKit
public typealias MarkdownFont = NSFont
public typealias MarkdownColor = NSColor
typealias MarkdownFontDescriptor = NSFontDescriptor
#endif

public struct MarkdownStyle: Equatable {
    public var fontSize: CGFloat
    public var textColor: MarkdownColor
    public var linkColor: MarkdownColor

    private static var defaultTextColor: MarkdownColor {
        #if canImport(UIKit)
        return .label
        #else
        return .labelColor
        #endif
    }

    public init(
        fontSize: CGFloat = 17,
        textColor: MarkdownColor? = nil,
        linkColor: MarkdownColor? = nil
    ) {
        self.fontSize = fontSize
        self.textColor = textColor ?? Self.defaultTextColor
        self.linkColor = linkColor ?? .systemBlue
    }
}

public struct MarkdownRenderer {
    public var style: MarkdownStyle

    private static let headingScales: [CGFloat] = [1.6, 1.35, 1.2, 1.1, 1.05, 1.0]

    public init(style: MarkdownStyle = MarkdownStyle()) {
        self.style = style
    }

    public func render(_ markdown: String) -> NSAttributedString {
        var blocks: [NSAttributedString] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            let text = paragraphLines.joined(separator: " ")
            blocks.append(wrapBlock(inline(text), paragraphSpacing: 6))
            paragraphLines.removeAll()
        }

        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
            } else if let (level, text) = heading(trimmed) {
                flushParagraph()
                let font = self.font(
                    bold: true,
                    size: style.fontSize * Self.headingScales[min(level, 6) - 1]
                )
                blocks.append(wrapBlock(plain(text, font: font), paragraphSpacing: level <= 2 ? 8 : 4))
            } else if let text = unorderedItem(trimmed) {
                flushParagraph()
                blocks.append(listItem("•  " + text))
            } else if let (number, text) = orderedItem(trimmed) {
                flushParagraph()
                blocks.append(listItem("\(number).  " + text))
            } else {
                paragraphLines.append(trimmed)
            }
        }
        flushParagraph()

        let output = NSMutableAttributedString()
        for (index, block) in blocks.enumerated() {
            output.append(block)
            if index < blocks.count - 1 {
                output.append(NSAttributedString(string: "\n"))
            }
        }
        return output
    }

    private struct InlineRun {
        var text: String
        var url: URL?
        var bold = false
        var italic = false
        var code = false
    }

    private func heading(_ line: String) -> (level: Int, text: String)? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count), line.dropFirst(hashes.count).hasPrefix(" ") else {
            return nil
        }
        return (hashes.count, line.dropFirst(hashes.count + 1).trimmingCharacters(in: .whitespaces))
    }

    private func unorderedItem(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    private func orderedItem(_ line: String) -> (number: String, text: String)? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        for marker in [". ", ") "] where rest.hasPrefix(marker) {
            return (String(digits), String(rest.dropFirst(marker.count)))
        }
        return nil
    }

    private func inline(_ text: String) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for run in inlineRuns(text) {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font(bold: run.bold, italic: run.italic, code: run.code, size: style.fontSize),
                .foregroundColor: style.textColor,
            ]
            if let url = run.url {
                attributes[.link] = url
                attributes[.foregroundColor] = style.linkColor
            }
            output.append(NSAttributedString(string: run.text, attributes: attributes))
        }
        return output
    }

    private func plain(_ text: String, font: MarkdownFont) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: style.textColor,
        ])
    }

    private func wrapBlock(_ content: NSAttributedString, paragraphSpacing: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = paragraphSpacing
        let output = NSMutableAttributedString(attributedString: content)
        output.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: output.length))
        return output
    }

    private func listItem(_ text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 2
        paragraph.headIndent = 16
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraph,
        ]
        let output = NSMutableAttributedString(attributedString: inline(text))
        output.addAttributes(attributes, range: NSRange(location: 0, length: output.length))
        return output
    }

    private func inlineRuns(_ text: String) -> [InlineRun] {
        var runs: [InlineRun] = []
        var literal = ""
        var index = text.startIndex

        func flushLiteral() {
            if !literal.isEmpty {
                runs.append(InlineRun(text: literal))
                literal = ""
            }
        }
        func appendMerging(_ newRuns: [InlineRun], bold: Bool? = nil, italic: Bool? = nil) {
            for var run in newRuns {
                if let bold { run.bold = bold }
                if let italic { run.italic = true }
                runs.append(run)
            }
        }

        while index < text.endIndex {
            let rest = text[index...]
            if rest.hasPrefix("`"),
               let close = rest.dropFirst().range(of: "`") {
                flushLiteral()
                runs.append(InlineRun(text: String(rest[rest.index(after: rest.startIndex)..<close.lowerBound]), code: true))
                index = close.upperBound
            } else if rest.hasPrefix("**"),
                      let close = rest.dropFirst(2).range(of: "**") {
                flushLiteral()
                let inner = String(rest[rest.index(rest.startIndex, offsetBy: 2)..<close.lowerBound])
                appendMerging(inlineRuns(inner), bold: true)
                index = close.upperBound
            } else if rest.hasPrefix("["),
                      let labelEnd = rest.range(of: "]("),
                      let close = rest[labelEnd.upperBound...].range(of: ")"),
                      let url = URL(string: String(rest[labelEnd.upperBound..<close.lowerBound])) {
                flushLiteral()
                let label = String(rest[rest.index(after: rest.startIndex)..<labelEnd.lowerBound])
                runs.append(InlineRun(text: label, url: url))
                index = close.upperBound
            } else if rest.hasPrefix("*"),
                      let close = rest.dropFirst().range(of: "*") {
                flushLiteral()
                let inner = String(rest[rest.index(after: rest.startIndex)..<close.lowerBound])
                appendMerging(inlineRuns(inner), italic: true)
                index = close.upperBound
            } else {
                literal.append(rest.first!)
                index = rest.index(after: rest.startIndex)
            }
        }
        flushLiteral()
        return runs
    }

    private func font(bold: Bool = false, italic: Bool = false, code: Bool = false, size: CGFloat) -> MarkdownFont {
        if code {
            return MarkdownFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        }
        let font = MarkdownFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        guard italic else { return font }
        #if canImport(UIKit)
        guard let descriptor = font.fontDescriptor.withSymbolicTraits([.traitItalic]) else { return font }
        return MarkdownFont(descriptor: descriptor, size: size)
        #else
        let descriptor = font.fontDescriptor.withSymbolicTraits(.italic)
        return MarkdownFont(descriptor: descriptor, size: size) ?? font
        #endif
    }
}
