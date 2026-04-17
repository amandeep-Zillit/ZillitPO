import SwiftUI
import UIKit

struct MultilineTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = UIFont.systemFont(ofSize: 14)
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        tv.isScrollEnabled = false
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updatePlaceholder(tv)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if text.isEmpty && !tv.isFirstResponder {
            tv.text = placeholder
            tv.textColor = UIColor.placeholderText
        } else if tv.textColor == UIColor.placeholderText && !text.isEmpty {
            tv.text = text
            tv.textColor = UIColor.label
        } else if tv.textColor != UIColor.placeholderText {
            if tv.text != text { tv.text = text }
            tv.textColor = UIColor.label
        }
    }

    private func updatePlaceholder(_ tv: UITextView) {
        if text.isEmpty {
            tv.text = placeholder
            tv.textColor = UIColor.placeholderText
        } else {
            tv.text = text
            tv.textColor = UIColor.label
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MultilineTextView
        init(_ parent: MultilineTextView) { self.parent = parent }

        func textViewDidBeginEditing(_ tv: UITextView) {
            if tv.textColor == UIColor.placeholderText {
                tv.text = ""
                tv.textColor = UIColor.label
            }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            if tv.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tv.text = parent.placeholder
                tv.textColor = UIColor.placeholderText
                parent.text = ""
            }
        }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
        }
    }
}
