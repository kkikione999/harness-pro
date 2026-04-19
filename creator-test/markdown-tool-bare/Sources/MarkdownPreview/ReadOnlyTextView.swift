import AppKit
import SwiftUI

struct ReadOnlyTextView: NSViewRepresentable {
    let text: String
    var isMonospaced = false
    var onTextChange: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        let textView = EditableTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 28, height: 24)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        update(textView: textView, context: context)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        update(textView: textView, context: context)
    }

    private func update(textView: NSTextView, context: Context) {
        if textView.string != text {
            textView.string = text
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 10
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: isMonospaced ? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular) : NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        textView.textStorage?.setAttributedString(NSAttributedString(string: textView.string, attributes: attributes))
        context.coordinator.onTextChange = onTextChange
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var onTextChange: ((String) -> Void)?
        private var parent: ReadOnlyTextView

        init(_ parent: ReadOnlyTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            onTextChange?(textView.string)
        }
    }
}

class EditableTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "z" {
                if event.modifierFlags.contains(.shift) {
                    undoManager?.redo()
                } else {
                    undoManager?.undo()
                }
                return
            }
        }
        super.keyDown(with: event)
    }
}
