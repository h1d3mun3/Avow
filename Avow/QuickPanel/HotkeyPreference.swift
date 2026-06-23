import Foundation
import Carbon.HIToolbox

/// A user-configurable global hotkey: a Carbon virtual key code plus Carbon modifier flags,
/// with a human label for the key portion (so display never needs a full keycode→glyph table).
nonisolated struct HotkeyPreference: Equatable {
    var keyCode: Int
    var modifiers: Int
    var keyLabel: String

    /// ⌥⇧Space (⌃⌘Space collides with the system Emoji & Symbols viewer).
    static let `default` = HotkeyPreference(
        keyCode: kVK_Space,
        modifiers: optionKey | shiftKey,
        keyLabel: "Space"
    )

    /// e.g. "⌃⌘Space" — modifier glyphs in the conventional ⌃⌥⇧⌘ order, then the key.
    var displayString: String {
        var glyphs = ""
        if modifiers & controlKey != 0 { glyphs += "⌃" }
        if modifiers & optionKey != 0 { glyphs += "⌥" }
        if modifiers & shiftKey != 0 { glyphs += "⇧" }
        if modifiers & cmdKey != 0 { glyphs += "⌘" }
        return glyphs + keyLabel
    }

    /// True when at least one of ⌘/⌃/⌥ is held — required so the hotkey is usable system-wide.
    var hasRequiredModifier: Bool {
        modifiers & (cmdKey | controlKey | optionKey) != 0
    }

    /// Builds the key label for a recorded keypress (special keys, else the typed character).
    static func keyLabel(forKeyCode keyCode: Int, characters: String?) -> String {
        if let special = specialKeyLabels[keyCode] { return special }
        if let characters, !characters.isEmpty, characters != " " {
            return characters.uppercased()
        }
        return "Key \(keyCode)"
    }

    private static let specialKeyLabels: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab",
        kVK_Escape: "Esc", kVK_Delete: "Delete", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

/// Persists the quick-panel hotkey in `UserDefaults`.
nonisolated enum HotkeyStore {
    private static let keyCodeKey = "quickPanelHotkey.keyCode"
    private static let modifiersKey = "quickPanelHotkey.modifiers"
    private static let labelKey = "quickPanelHotkey.keyLabel"

    static func load(from defaults: UserDefaults = .standard) -> HotkeyPreference {
        guard defaults.object(forKey: keyCodeKey) != nil else { return .default }
        return HotkeyPreference(
            keyCode: defaults.integer(forKey: keyCodeKey),
            modifiers: defaults.integer(forKey: modifiersKey),
            keyLabel: defaults.string(forKey: labelKey) ?? HotkeyPreference.default.keyLabel
        )
    }

    static func save(_ preference: HotkeyPreference, to defaults: UserDefaults = .standard) {
        defaults.set(preference.keyCode, forKey: keyCodeKey)
        defaults.set(preference.modifiers, forKey: modifiersKey)
        defaults.set(preference.keyLabel, forKey: labelKey)
    }
}
