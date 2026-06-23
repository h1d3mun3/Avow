import AppKit
import SwiftUI
import Carbon.HIToolbox

/// A click-to-record shortcut field: click it, press a modifier + key, and the combo is captured.
/// Esc cancels recording; a combo without ⌘/⌃/⌥ is rejected (beep) so the hotkey stays usable
/// system-wide.
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var preference: HotkeyPreference

    func makeNSView(context: Context) -> HotkeyRecorderView {
        let view = HotkeyRecorderView()
        view.preference = preference
        view.onChange = { preference = $0 }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderView, context: Context) {
        nsView.preference = preference
    }
}

final class HotkeyRecorderView: NSView {
    var preference: HotkeyPreference = .default { didSet { needsDisplay = true } }
    var onChange: ((HotkeyPreference) -> Void)?

    private var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            window?.makeFirstResponder(nil)
        } else {
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // While recording, capture combos that are also menu key equivalents (e.g. ⌘W) instead
        // of letting them trigger menu items.
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        capture(event)
        return true
    }

    private func capture(_ event: NSEvent) {
        let keyCode = Int(event.keyCode)
        if keyCode == kVK_Escape {
            window?.makeFirstResponder(nil) // cancel without changing
            return
        }

        var carbonModifiers = 0
        let flags = event.modifierFlags
        if flags.contains(.command) { carbonModifiers |= cmdKey }
        if flags.contains(.option) { carbonModifiers |= optionKey }
        if flags.contains(.control) { carbonModifiers |= controlKey }
        if flags.contains(.shift) { carbonModifiers |= shiftKey }

        let candidate = HotkeyPreference(
            keyCode: keyCode,
            modifiers: carbonModifiers,
            keyLabel: HotkeyPreference.keyLabel(forKeyCode: keyCode, characters: event.charactersIgnoringModifiers)
        )

        guard candidate.hasRequiredModifier else {
            NSSound.beep() // needs at least one of ⌘ / ⌃ / ⌥
            return
        }

        preference = candidate
        onChange?(candidate)
        window?.makeFirstResponder(nil) // done recording
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.12) : .clear).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "Press keys…" : preference.displayString
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        let attributed = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
            .paragraphStyle: style,
        ])
        let size = attributed.size()
        attributed.draw(in: NSRect(x: 4, y: (bounds.height - size.height) / 2, width: bounds.width - 8, height: size.height))
    }
}
