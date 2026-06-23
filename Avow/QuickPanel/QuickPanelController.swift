import AppKit
import SwiftUI
import SwiftData

/// Owns the global hotkey and the floating quick-launcher panel, and toggles the panel when the
/// hotkey fires. The menu-bar item is unaffected — this is a purely additive surface.
@MainActor
final class QuickPanelController: NSObject, NSWindowDelegate {
    private let modelContainer: ModelContainer
    private let repositories: Repositories
    private let appState: AppState
    private let hotkeySettings: HotkeySettings

    private var panel: NSPanel?
    private var hotkey: GlobalHotkey?

    init(
        modelContainer: ModelContainer,
        repositories: Repositories,
        appState: AppState,
        hotkeySettings: HotkeySettings
    ) {
        self.modelContainer = modelContainer
        self.repositories = repositories
        self.appState = appState
        self.hotkeySettings = hotkeySettings
        super.init()

        registerHotkey(hotkeySettings.preference)
        hotkeySettings.onChange = { [weak self] preference in
            self?.registerHotkey(preference)
        }
    }

    private func registerHotkey(_ preference: HotkeyPreference) {
        // Release the old hotkey FIRST so its deinit unregisters the shared EventHotKeyID before
        // we register the new one — otherwise the second registration hits eventHotKeyExistsErr
        // and silently fails, disabling the hotkey after a change.
        hotkey = nil
        hotkey = GlobalHotkey(keyCode: preference.keyCode, modifiers: preference.modifiers) { [weak self] in
            self?.toggle()
        }
    }

    // MARK: - Show / hide

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = ensurePanel()
        // Rebuild the SwiftUI content each time so onAppear re-runs (reset filter, refocus search).
        panel.contentView = makeHostingView()
        position(panel)
        // A .nonactivatingPanel becomes key and receives keystrokes without activating Avow, so the
        // launcher floats over the current app without yanking the Dashboard window to the front.
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Dismiss when the user clicks away / switches apps.
        hide()
    }

    // MARK: - Building

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 380),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        self.panel = panel
        return panel
    }

    private func makeHostingView() -> NSHostingView<some View> {
        let root = QuickPanelView(onClose: { [weak self] in self?.hide() })
            .environment(appState)
            .environment(repositories)
            .modelContainer(modelContainer)
        return NSHostingView(rootView: root)
    }

    private func position(_ panel: NSPanel) {
        // The screen under the cursor (where the user is working), not necessarily the main screen.
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        // Centered horizontally, a little above vertical center (launcher convention).
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.12
        )
        panel.setFrameOrigin(origin)
    }
}
