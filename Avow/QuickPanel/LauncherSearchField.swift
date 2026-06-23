import AppKit
import SwiftUI

/// A plain AppKit text field for the quick panel's search box. Using AppKit directly (rather than
/// a SwiftUI `TextField`) lets us both grab first-responder focus reliably when the panel opens and
/// forward the field editor's ↑/↓/Return/Esc commands to the list — a focused single-line SwiftUI
/// `TextField` otherwise swallows the vertical arrows, breaking keyboard navigation.
struct LauncherSearchField: NSViewRepresentable {
    @Binding var text: String
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onSubmit: () -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = "Search tasks…"
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.systemFontSize * 1.3)
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        field.delegate = context.coordinator
        // Grab focus once the field is in the (now key) panel window.
        DispatchQueue.main.async { [weak field] in
            field?.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LauncherSearchField

        init(_ parent: LauncherSearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                parent.onMoveUp(); return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onMoveDown(); return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit(); return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel(); return true
            default:
                return false
            }
        }
    }
}
