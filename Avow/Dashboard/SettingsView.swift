import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Repositories.self) private var repositories
    @Environment(HotkeySettings.self) private var hotkeySettings
    @Environment(TimeRoundingSettings.self) private var roundingSettings

    @State private var showingResetConfirmation = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var pendingImportURL: URL?

    var body: some View {
        @Bindable var hotkeySettings = hotkeySettings
        @Bindable var roundingSettings = roundingSettings

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                    // Shortcuts
                    SettingsSection(title: "Shortcuts") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Quick panel")
                                    .font(.subheadline)
                                Text("Open the quick task switcher from anywhere.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HotkeyRecorder(preference: $hotkeySettings.preference)
                                .frame(width: 130, height: 24)
                        }
                    }

                    // Time display
                    SettingsSection(title: "Time display") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Round summaries to the minute")
                                    .font(.subheadline)
                                Text("Display whole minutes so each entry and its total always add up. Stored times keep full precision.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $roundingSettings.roundToMinute)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityLabel("Round summaries to the minute")
                        }
                    }

                    // Backup & restore (JSON is a faithful round trip)
                    SettingsSection(title: "Export & import") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Back up everything to a JSON file and restore it later.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Button {
                                    exportJSON()
                                } label: {
                                    Label("Export JSON", systemImage: "arrow.down.doc")
                                        .font(.caption)
                                }
                                Button {
                                    beginImport()
                                } label: {
                                    Label("Import JSON", systemImage: "arrow.up.doc")
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    // Reports — CSV is export-only, for spreadsheet analysis
                    SettingsSection(title: "Reports") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Export a CSV of all time entries to analyze in a spreadsheet (Excel, Numbers).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                exportCSV()
                            } label: {
                                Label("Export CSV", systemImage: "tablecells")
                                    .font(.caption)
                            }
                        }
                    }

                    if let message = statusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Danger zone
                    SettingsSection(title: "Danger zone") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Reset all data")
                                    .font(.subheadline)
                                Text("Delete all projects, tasks, time entries, and facets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                showingResetConfirmation = true
                            } label: {
                                Label("Reset", systemImage: "trash")
                                    .font(.caption)
                            }
                        }
                    }
            }
            .padding()
        }
        .navigationTitle("Settings")
        .alert("Reset all data?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetAllData() }
        } message: {
            Text("This will permanently delete all projects, tasks, time entries, and facets. This action cannot be undone.")
        }
        .confirmationDialog(
            "Import data",
            isPresented: Binding(get: { pendingImportURL != nil }, set: { if !$0 { pendingImportURL = nil } }),
            presenting: pendingImportURL
        ) { url in
            Button("Merge into current data") { performImport(url, mode: .merge) }
            Button("Replace all data", role: .destructive) { performImport(url, mode: .replace) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Merge keeps your current data and updates matching items. Replace deletes all current data first.")
        }
        .errorAlert($errorMessage)
    }

    // MARK: - Actions

    private func exportJSON() {
        statusMessage = nil
        errorMessage = nil
        do {
            let projects = try repositories.project.allProjectsSortedByName()
            let facets = try repositories.facet.allFacetsSortedByName()
            let data = try ExportService().buildJSONData(from: projects, facets: facets)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = Self.exportFilename(ext: "json")

            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url)
                statusMessage = "Exported successfully."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportCSV() {
        statusMessage = nil
        errorMessage = nil
        do {
            let projects = try repositories.project.allProjectsSortedByName()
            let csv = ExportService().buildCSVString(from: projects)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = Self.exportFilename(ext: "csv")

            if panel.runModal() == .OK, let url = panel.url {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                statusMessage = "Exported successfully."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Picks a JSON file to import, then defers to the Merge/Replace confirmation dialog.
    private func beginImport() {
        statusMessage = nil
        errorMessage = nil

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            pendingImportURL = url
        }
    }

    private func performImport(_ url: URL, mode: ImportService.Mode) {
        statusMessage = nil
        errorMessage = nil
        do {
            try ImportService(context: modelContext).importJSON(from: url, mode: mode)
            statusMessage = "Imported successfully."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// A filename-safe default like `avow-export-2026-06-24-091530.json`. Avoids the colons an
    /// ISO8601 timestamp would contain, which macOS renders as `/` in the Finder.
    private static func exportFilename(ext: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "avow-export-\(formatter.string(from: .now)).\(ext)"
    }

    private func resetAllData() {
        do {
            try DataAdminService(context: modelContext).deleteAllData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Settings section

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Divider()
            content()
        }
    }
}
