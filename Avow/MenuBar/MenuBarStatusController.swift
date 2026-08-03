import AppKit
import SwiftUI
import SwiftData

/// Owns the menu bar `NSStatusItem` directly instead of going through SwiftUI's `MenuBarExtra`.
///
/// `MenuBarExtra` renders its label through an `NSHostingView`, which gets re-laid-out on every
/// SwiftUI state change — with a per-second timer driving the elapsed-time text, that reflow has
/// been observed to jitter the status item's width and flicker the icon in and out of the menu bar
/// (a known instability in the SwiftUI/AppKit status-item bridge, see PR #60). Updating the button's
/// title with plain AppKit sidesteps that bridge entirely for the frequently-changing part; only the
/// click-to-open task list (updated rarely) still goes through SwiftUI.
@MainActor
final class MenuBarStatusController: NSObject, NSWindowDelegate {
    private let modelContainer: ModelContainer
    private let repositories: Repositories
    private let appState: AppState
    private let openDashboard: () -> Void

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var panel: NSPanel?
    private var updateTimer: Timer?

    init(
        modelContainer: ModelContainer,
        repositories: Repositories,
        appState: AppState,
        openDashboard: @escaping () -> Void
    ) {
        self.modelContainer = modelContainer
        self.repositories = repositories
        self.appState = appState
        self.openDashboard = openDashboard
        super.init()

        configureButton()
        refreshButton()

        // Polls once a second rather than observing AppState directly — simpler than bridging
        // @Observable into AppKit, and the cost of refreshing an idle button is negligible.
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            // `Task` here would otherwise resolve to the SwiftData `Task` model, not _Concurrency.Task.
            _Concurrency.Task { @MainActor in
                self?.refreshButton()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        updateTimer = timer
    }

    // MARK: - Button

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.target = self
        button.action = #selector(togglePanel)
    }

    private func refreshButton() {
        guard let button = statusItem.button else { return }

        let symbolName = appState.isTracking ? "clock.fill" : "clock"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        image?.isTemplate = true
        button.image = image

        if let entry = appState.activeEntry {
            button.imagePosition = .imageLeading
            button.title = entry.duration.timerFormatted
        } else {
            button.imagePosition = .imageOnly
            button.title = ""
        }
    }

    // MARK: - Panel

    @objc private func togglePanel() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    private func show() {
        let panel = ensurePanel()
        // Rebuild the SwiftUI content each time so onAppear re-runs (reset filter, restore state).
        let hostingView = makeHostingView()
        panel.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        panel.setContentSize(hostingView.fittingSize)
        position(panel)
        // A .nonactivatingPanel becomes key and receives clicks without activating Avow, matching
        // the borderless-popover feel MenuBarExtra's .window style used to provide.
        panel.makeKeyAndOrderFront(nil)
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - Building

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 420),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        self.panel = panel
        return panel
    }

    private func makeHostingView() -> NSHostingView<some View> {
        let root = MenuBarView(openDashboard: openDashboard)
            .environment(appState)
            .environment(repositories)
            .modelContainer(modelContainer)
        return NSHostingView(rootView: root)
    }

    private func position(_ panel: NSPanel) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
        let size = panel.frame.size
        let origin = NSPoint(
            x: buttonFrameOnScreen.midX - size.width / 2,
            y: buttonFrameOnScreen.minY - size.height - 4
        )
        panel.setFrameOrigin(origin)
    }
}
