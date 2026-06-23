import Testing
import Foundation
import Carbon.HIToolbox
@testable import Avow

@Suite("HotkeyPreference")
struct HotkeyPreferenceTests {

    @Test func defaultIsOptionShiftSpace() {
        #expect(HotkeyPreference.default.displayString == "⌥⇧Space")
        #expect(HotkeyPreference.default.hasRequiredModifier)
    }

    @Test func displayOrdersModifiersConventionally() {
        let pref = HotkeyPreference(keyCode: kVK_ANSI_K, modifiers: cmdKey | shiftKey | controlKey | optionKey, keyLabel: "K")
        #expect(pref.displayString == "⌃⌥⇧⌘K")
    }

    @Test func requiresCommandControlOrOption() {
        #expect(HotkeyPreference(keyCode: kVK_ANSI_A, modifiers: shiftKey, keyLabel: "A").hasRequiredModifier == false)
        #expect(HotkeyPreference(keyCode: kVK_ANSI_A, modifiers: cmdKey, keyLabel: "A").hasRequiredModifier == true)
        #expect(HotkeyPreference(keyCode: kVK_ANSI_A, modifiers: controlKey, keyLabel: "A").hasRequiredModifier == true)
        #expect(HotkeyPreference(keyCode: kVK_ANSI_A, modifiers: optionKey, keyLabel: "A").hasRequiredModifier == true)
    }

    @Test func keyLabelUsesSpecialNamesThenCharacters() {
        #expect(HotkeyPreference.keyLabel(forKeyCode: kVK_Space, characters: " ") == "Space")
        #expect(HotkeyPreference.keyLabel(forKeyCode: kVK_Return, characters: "\r") == "Return")
        #expect(HotkeyPreference.keyLabel(forKeyCode: kVK_ANSI_J, characters: "j") == "J")
    }

    @Test func storeRoundTrips() {
        let defaults = UserDefaults(suiteName: "HotkeyPreferenceTests.\(UUID().uuidString)")!
        #expect(HotkeyStore.load(from: defaults) == .default) // nothing saved yet

        let pref = HotkeyPreference(keyCode: kVK_ANSI_T, modifiers: cmdKey | optionKey, keyLabel: "T")
        HotkeyStore.save(pref, to: defaults)
        #expect(HotkeyStore.load(from: defaults) == pref)
    }
}
