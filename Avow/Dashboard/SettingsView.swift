import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Repositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    @State private var showingResetConfirmation = false
    @State private var exportMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Data
                    SettingsSection(title: "Data") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Export & import")
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                Button {
                                    exportJSON()
                                } label: {
                                    Label("Export JSON", systemImage: "arrow.down.doc")
                                        .font(.caption)
                                }
                                Button {
                                    exportCSV()
                                } label: {
                                    Label("Export CSV", systemImage: "arrow.down.doc")
                                        .font(.caption)
                                }
                            }
                            if let message = exportMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Danger zone
                    SettingsSection(title: "Danger zone") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Reset all data")
                                    .font(.subheadline)
                                Text("Delete all projects, tasks, and time entries")
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

                    // Version
                    Text("Avow v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding()
            }
        }
        .frame(width: 420, height: 480)
        .alert("Reset all data?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetAllData() }
        } message: {
            Text("This will permanently delete all projects, tasks, and time entries. This action cannot be undone.")
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Actions

    private func exportJSON() {
        do {
            let projects = try repositories.project.allProjectsSortedByName()
            let data = try ExportService().buildJSONData(from: projects)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "avow-export-\(ISO8601DateFormatter().string(from: .now)).json"

            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url)
                exportMessage = "Exported successfully."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportCSV() {
        do {
            let projects = try repositories.project.allProjectsSortedByName()
            let csv = ExportService().buildCSVString(from: projects)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = "avow-export.csv"

            if panel.runModal() == .OK, let url = panel.url {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                exportMessage = "Exported successfully."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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
