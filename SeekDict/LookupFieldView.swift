#if os(macOS)
import AppKit
import SeekDictCore
import SwiftUI

final class LookupFieldView: NSView {
    let searchField = NSSearchField()
    let resultText: NSTextField = {
        let field = NSTextField()
        field.isEditable = false
        field.isBordered = false
        field.drawsBackground = false
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        return field
    }()

    var onSubmit: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        searchField.placeholderString = "输入单词查词"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self
        searchField.action = #selector(submit)

        resultText.isSelectable = true
        resultText.translatesAutoresizingMaskIntoConstraints = false

        addSubview(searchField)
        addSubview(resultText)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: topAnchor),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor),

            resultText.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            resultText.leadingAnchor.constraint(equalTo: leadingAnchor),
            resultText.trailingAnchor.constraint(equalTo: trailingAnchor),
            resultText.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
        showMessage("词典加载中…")
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func submit() {
        onSubmit?(searchField.stringValue)
    }

    func showMessage(_ message: String) {
        resultText.stringValue = message
    }

    func showResult(_ result: LookupResult) {
        var lines = [result.word]
        for sense in result.senses {
            if let pos = sense.pos {
                lines.append("\(pos.rawValue) \(sense.text)")
            } else {
                lines.append(sense.text)
            }
        }
        resultText.stringValue = lines.joined(separator: "\n")
    }
}

struct LookupFieldRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> LookupFieldView {
        let view = LookupFieldView()
        view.onSubmit = { word in
            let query = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }
            view.showMessage("查询中…")
            DictionaryServiceProvider.service { service in
                guard let service else {
                    view.showMessage("词典初始化失败")
                    return
                }
                guard let result = service.lookup(query) else {
                    view.showMessage("未找到:\(query)")
                    return
                }
                view.showResult(result)
            }
        }
        return view
    }

    func updateNSView(_ nsView: LookupFieldView, context: Context) {}
}
#endif
