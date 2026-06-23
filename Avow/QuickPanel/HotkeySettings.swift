import Foundation
import Observation

/// Observable holder for the quick-panel hotkey. The view edits `preference`; the controller
/// installs `onChange` to re-register the system hotkey, and persistence happens automatically.
@MainActor
@Observable
final class HotkeySettings {
    var preference: HotkeyPreference {
        didSet {
            guard preference != oldValue else { return }
            HotkeyStore.save(preference)
            onChange?(preference)
        }
    }

    /// Set by the controller; invoked whenever the preference changes.
    @ObservationIgnored var onChange: ((HotkeyPreference) -> Void)?

    init() {
        preference = HotkeyStore.load()
    }
}
