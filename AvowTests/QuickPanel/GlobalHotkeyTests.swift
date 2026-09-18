import Testing
import Carbon.HIToolbox
@testable import Avow

/// Exercises the Carbon registration lifecycle against the real system API.
///
/// Every `GlobalHotkey` registers the same `EventHotKeyID`, which is what makes these assertions
/// possible: if a previous registration is still live, the next `init?` hits `eventHotKeyExistsErr`
/// and returns nil. A leaked registration is therefore observable as a nil, not as a silent pass.
///
/// Serialized because those registrations are process-wide shared state.
@Suite("GlobalHotkey", .serialized)
struct GlobalHotkeyTests {

    // F19 with every modifier — unlikely to collide with a system or third-party shortcut.
    private static let keyCode = kVK_F19
    private static let modifiers = cmdKey | optionKey | controlKey | shiftKey

    private static func makeHotkey() -> GlobalHotkey? {
        GlobalHotkey(keyCode: keyCode, modifiers: modifiers) {}
    }

    @Test func registersSuccessfully() {
        let hotkey = Self.makeHotkey()
        #expect(hotkey != nil)
        hotkey?.unregister()
    }

    @Test func unregisterFreesTheIDForAReplacement() {
        let first = Self.makeHotkey()
        #expect(first != nil)

        first?.unregister()

        // Fails with nil if unregister() did not actually release the registration.
        let second = Self.makeHotkey()
        #expect(second != nil)
        second?.unregister()
    }

    @Test func registeringOverALiveHotkeyFails() {
        let first = Self.makeHotkey()
        #expect(first != nil)

        // The negative case the ordering in QuickPanelController.registerHotkey exists to avoid.
        let second = Self.makeHotkey()
        #expect(second == nil)

        first?.unregister()
    }

    @Test func unregisterIsIdempotent() {
        let hotkey = Self.makeHotkey()
        #expect(hotkey != nil)

        hotkey?.unregister()
        hotkey?.unregister()

        let next = Self.makeHotkey()
        #expect(next != nil)
        next?.unregister()
    }

    @Test func droppingTheLastReferenceUnregisters() {
        do {
            let hotkey = Self.makeHotkey()
            #expect(hotkey != nil)
        }
        // The isolated deinit runs synchronously here: the release happens on the main actor, which
        // is the actor the deinit is isolated to. If it were deferred, the next init? would fail.
        let next = Self.makeHotkey()
        #expect(next != nil)
        next?.unregister()
    }
}
