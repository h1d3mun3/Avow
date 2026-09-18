import AppKit
import Carbon.HIToolbox

/// A single system-wide hotkey registered through Carbon's `RegisterEventHotKey`.
///
/// This API works inside the App Sandbox with no extra entitlement (unlike a global
/// `CGEventTap`, which needs Accessibility access). The hotkey stays registered until
/// `unregister()` is called, or until this object is deallocated.
final class GlobalHotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onFire: () -> Void

    /// - Parameters:
    ///   - keyCode: a Carbon virtual key code (e.g. `kVK_Space`).
    ///   - modifiers: Carbon modifier flags (e.g. `cmdKey | controlKey`).
    ///   - onFire: invoked on the main thread each time the hotkey is pressed.
    init?(keyCode: Int, modifiers: Int, onFire: @escaping () -> Void) {
        self.onFire = onFire

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Carbon hotkey events are delivered on the main thread, so assumeIsolated is safe.
        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            MainActor.assumeIsolated {
                Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue().onFire()
            }
            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard installStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: 0x41564B59 /* "AVKY" */, id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else { return nil }
    }

    /// Releases the Carbon registration. Idempotent: calling it more than once does nothing.
    ///
    /// Every instance registers the same `EventHotKeyID`, so a replacement created before the
    /// previous one is torn down hits `eventHotKeyExistsErr` and its `init?` returns nil. Callers
    /// that replace a hotkey should therefore call this explicitly rather than relying on when the
    /// last reference happens to be dropped.
    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }

    // A safety net for callers that just drop the reference — the ordering-sensitive path calls
    // unregister() directly. Isolated so the teardown runs on the main actor alongside the
    // registration: both refs are opaque Carbon pointers, which a nonisolated deinit may not
    // touch under Swift 6.
    isolated deinit {
        unregister()
    }
}
