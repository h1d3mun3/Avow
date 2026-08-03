//
//  AvowApp.swift
//  Avow
//
//  Created by hidemune on 6/11/26.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - Window identifiers

enum WindowID { static let dashboard = "dashboard"; static let dashboardTitle = "Dashboard" }

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var openWindow: ((String) -> Void)?
    var quickPanel: QuickPanelController?
    var menuBarStatus: MenuBarStatusController?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            openWindow?(WindowID.dashboard)
        }
        return true
    }
}

@main
struct AvowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let modelContainer: ModelContainer
    let repositories: Repositories
    @State private var appState: AppState
    @State private var hotkeySettings = HotkeySettings()
    @State private var roundingSettings = TimeRoundingSettings()

    init() {
        let schema = Schema([
            Project.self,
            Task.self,
            TimeEntry.self,
            Facet.self,
            ProjectGroup.self,
        ])
        let config = ModelConfiguration(
            "Avow",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        modelContainer = container
        let repos = Repositories(context: container.mainContext)
        repositories = repos
        let state = AppState(timeEntries: repos.timeEntry)
        // Restored synchronously here (rather than a View's .onAppear/.task) since the menu bar
        // status item is now plain AppKit and has no SwiftUI lifecycle hook of its own to hang this on.
        state.restoreActiveEntry()
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        // MARK: - Dashboard window
        //
        // The menu bar icon is a plain NSStatusItem owned by MenuBarStatusController (see
        // AppLaunchSetup below) rather than a MenuBarExtra scene — MenuBarExtra routes its label
        // through an NSHostingView that gets re-laid-out on every SwiftUI state change, which
        // visibly jittered the status item's width once a second while a timer was running.

        Window(WindowID.dashboardTitle, id: WindowID.dashboard) {
            DashboardView()
                .environment(appState)
                .environment(repositories)
                .environment(hotkeySettings)
                .environment(roundingSettings)
                .modelContainer(modelContainer)
                .background(
                    AppLaunchSetup(
                        appDelegate: appDelegate,
                        modelContainer: modelContainer,
                        repositories: repositories,
                        appState: appState,
                        hotkeySettings: hotkeySettings
                    )
                )
        }
        .defaultSize(width: 900, height: 600)
        .defaultPosition(.center)
    }
}

// MARK: - App launch setup

// Runs once at launch: wires openWindow into AppDelegate (so Dock icon clicks can reopen the
// Dashboard window after it's been closed), and installs the global-hotkey quick panel and the
// menu bar status item. Needs to live inside a Scene's content to access the openWindow action.
private struct AppLaunchSetup: View {
    @Environment(\.openWindow) private var openWindow
    let appDelegate: AppDelegate
    let modelContainer: ModelContainer
    let repositories: Repositories
    let appState: AppState
    let hotkeySettings: HotkeySettings

    var body: some View {
        Color.clear
            .onAppear {
                appDelegate.openWindow = { id in openWindow(id: id) }
                openWindow(id: WindowID.dashboard)

                if appDelegate.quickPanel == nil {
                    appDelegate.quickPanel = QuickPanelController(
                        modelContainer: modelContainer,
                        repositories: repositories,
                        appState: appState,
                        hotkeySettings: hotkeySettings
                    )
                }

                if appDelegate.menuBarStatus == nil {
                    appDelegate.menuBarStatus = MenuBarStatusController(
                        modelContainer: modelContainer,
                        repositories: repositories,
                        appState: appState,
                        openDashboard: { [weak appDelegate] in appDelegate?.openWindow?(WindowID.dashboard) }
                    )
                }
            }
    }
}
