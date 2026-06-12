//
//  AvowApp.swift
//  Avow
//
//  Created by hidemune on 6/11/26.
//

import SwiftUI
import SwiftData

@main
struct AvowApp: App {
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
