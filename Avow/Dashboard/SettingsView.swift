import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showElapsedInMenuBar") private var showElapsedInMenuBar = true
    @AppStorage("showTaskNameInMenuBar") private var showTaskNameInMenuBar = false

    @State private var showingResetConfirmation = false
    @State private var exportMessage: String?

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
                    // General
                    SettingsSection(title: "General") {
                        Toggle("Launch at login", isOn: $launchAtLogin)
                    }

                    // Menu bar
                    SettingsSection(title: "Menu bar") {
                        Toggle("Show elapsed time", isOn: $showElapsedInMenuBar)
                        Toggle("Show task name", isOn: $showTaskNameInMenuBar)
                    }

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
                    Text("Avow v0.1.0")
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
    }

    // MARK: - Actions

    private func exportJSON() {
        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\Project.name)])
        guard let projects = try? modelContext.fetch(descriptor) else { return }

        let schema = ExportSchema(
            version: ExportSchema.version,
            exportedAt: .now,
            projects: projects.map { project in
                ExportSchema.ExportProject(
                    id: project.id,
                    name: project.name,
                    createdAt: project.createdAt,
                    tasks: project.tasks.map { task in
                        ExportSchema.ExportTask(
                            id: task.id,
                            name: task.name,
                            status: task.status.rawValue,
                            createdAt: task.createdAt,
                            timeEntries: task.timeEntries.map { entry in
                                ExportSchema.ExportTimeEntry(
                                    id: entry.id,
                                    startDate: entry.startDate,
                                    endDate: entry.endDate
                                )
                            }
                        )
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(schema) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "avow-export-\(ISO8601DateFormatter().string(from: .now)).json"

        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
            exportMessage = "Exported successfully."
        }
    }

    private func exportCSV() {
        let descriptor = FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\TimeEntry.startDate)])
        guard let entries = try? modelContext.fetch(descriptor) else { return }

        var csv = "project,task,start,end,duration_seconds\n"
        for entry in entries {
            let project = entry.task?.project?.name ?? ""
            let task = entry.task?.name ?? ""
            let start = ISO8601DateFormatter().string(from: entry.startDate)
            let end = entry.endDate.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            let duration = Int(entry.duration)
            csv += "\"\(project)\",\"\(task)\",\(start),\(end),\(duration)\n"
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "avow-export.csv"

        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
            exportMessage = "Exported successfully."
        }
    }

    private func resetAllData() {
        try? modelContext.delete(model: TimeEntry.self)
        try? modelContext.delete(model: Task.self)
        try? modelContext.delete(model: Project.self)
        try? modelContext.save()
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
