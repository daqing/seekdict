#if os(macOS)
import AppKit
import SwiftUI

final class LookupFieldView: NSView {
    let searchField = NSSearchField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        searchField.placeholderString = "输入单词查词"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: topAnchor),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor),
            searchField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct LookupFieldRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> LookupFieldView {
        LookupFieldView()
    }

    func updateNSView(_ nsView: LookupFieldView, context: Context) {}
}
#endif
