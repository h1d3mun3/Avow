import SwiftUI

// MARK: - Focused values

// Views that own the "create" behaviour publish it as a focused scene value; the menu commands
// below read it. A value exists only while its view is on screen, so a menu item is enabled
// exactly when the action is meaningful (i.e. when the Dashboard window is the key window).

private struct NewTaskActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct OpenSettingsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var openSettingsAction: (() -> Void)? {
        get { self[OpenSettingsActionKey.self] }
        set { self[OpenSettingsActionKey.self] = newValue }
    }

    var newTaskAction: (() -> Void)? {
        get { self[NewTaskActionKey.self] }
        set { self[NewTaskActionKey.self] = newValue }
    }
}

// MARK: - Commands

struct AppCommands: Commands {
    @FocusedValue(\.newTaskAction) private var newTask
    @FocusedValue(\.openSettingsAction) private var openSettings

    var body: some Commands {
        // Settings lives in the Dashboard sidebar rather than a Settings scene, so the standard
        // App-menu "Settings…" (⌘,) slot is routed to selecting that sidebar item.
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { openSettings?() }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(openSettings == nil)
        }
        CommandGroup(replacing: .newItem) {
            // One entry point for both: the sheet takes `name @project`, and `@project` alone creates
            // just a project, so a separate New Project command would be redundant.
            Button("New Task or Project…") { newTask?() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(newTask == nil)
        }
    }
}
