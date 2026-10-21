#if os(iOS)
import SwiftUI
import UIKit

final class LookupFieldView: UIView {
    let textField = UITextField()

    override init(frame: CGRect) {
        super.init(frame: frame)
        textField.placeholder = "输入单词查词"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct LookupFieldRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> LookupFieldView {
        LookupFieldView()
    }

    func updateUIView(_ uiView: LookupFieldView, context: Context) {}
}
#endif
