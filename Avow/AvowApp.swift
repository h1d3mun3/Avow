//
//  AvowApp.swift
//  Avow
//
//  Created by hidemune on 6/11/26.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var openWindow: ((String) -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            openWindow?("dashboard")
        }
        return true
    }
}

@main
struct AvowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let modelContainer: ModelContainer
    @State private var appState = AppState()

    init() {
        do {
            let schema = Schema([
                Project.self,
                Task.self,
                TimeEntry.self,
            ])
            let config = ModelConfiguration(
                "Avow",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        // MARK: - Menu bar popover

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .modelContainer(modelContainer)
        } label: {
            MenuBarLabel(appState: appState)
                .task {
                    appState.restoreActiveEntry(context: modelContainer.mainContext)
                }
                .background(DashboardWindowOpener(appDelegate: appDelegate))
        }
        .menuBarExtraStyle(.window)

        // MARK: - Dashboard window

        Window("Dashboard", id: "dashboard") {
            DashboardView()
                .environment(appState)
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 900, height: 600)
        .defaultPosition(.center)
    }
}

// MARK: - Dashboard window opener

// Opens the Dashboard window on launch and wires openWindow into AppDelegate
// so Dock icon clicks can reopen the window after it's been closed.
private struct DashboardWindowOpener: View {
    @Environment(\.openWindow) private var openWindow
    let appDelegate: AppDelegate

    var body: some View {
        Color.clear
            .onAppear {
                appDelegate.openWindow = { id in openWindow(id: id) }
                openWindow(id: "dashboard")
            }
    }
}

// MARK: - Menu bar label

struct MenuBarLabel: View {
    let appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            if let entry = appState.activeEntry {
                let _ = appState.tick
                Text(entry.duration.timerFormatted)
                    .fontDesign(.monospaced)
            }
            Image(systemName: appState.isTracking ? "clock.fill" : "clock")
        }
    }
}
