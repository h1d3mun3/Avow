import SwiftUI
import SwiftData

/// "New Task" (⌘N): a task name plus the project it belongs to — an existing one from the menu,
/// or a brand-new one typed in place. Reachable from any Dashboard page, not just a project.
struct NewTaskSheet: View {
    @Environment(Repositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Project.sortOrder)
    private var allProjects: [Project]

    /// Preselected project, typically the one currently shown in the Dashboard.
    let preferredProject: Project?

    /// Called with the project the task landed in, so the Dashboard can show it.
    let onCreated: (Project) -> Void

    @State private var name = ""
    /// nil means "create a new project" (named by `newProjectName`).
    @State private var selectedProjectID: Project.ID?
    @State private var newProjectName = ""
    @State private var didChooseInitialProject = false
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    private var projects: [Project] { allProjects.filter { !$0.isArchived } }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedNewProjectName: String { newProjectName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isCreatingProject: Bool { selectedProjectID == nil }

    private var canCreate: Bool {
        !trimmedName.isEmpty && (!isCreatingProject || !trimmedNewProjectName.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New task")
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

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Task name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Write release notes", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)
                        .onSubmit { if canCreate { createTask() } }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Project")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Picker("Project", selection: $selectedProjectID) {
                        ForEach(projects) { project in
                            Text(project.name).tag(Project.ID?.some(project.id))
                        }
                        if !projects.isEmpty { Divider() }
                        Text("New project…").tag(Project.ID?.none)
                    }
                    .labelsHidden()

                    if isCreatingProject {
                        TextField("New project name", text: $newProjectName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { if canCreate { createTask() } }
                    }
                }
            }
            .padding()

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create task") { createTask() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
            }
            .padding()
        }
        .frame(width: 340)
        .onAppear {
            guard !didChooseInitialProject else { return }
            didChooseInitialProject = true
            if let preferred = preferredProject, projects.contains(where: { $0.id == preferred.id }) {
                selectedProjectID = preferred.id
            } else {
                selectedProjectID = projects.first?.id
            }
            nameFocused = true
        }
        .errorAlert($errorMessage)
    }

    private func createTask() {
        guard canCreate else { return }
        do {
            let project: Project
            if let id = selectedProjectID, let existing = projects.first(where: { $0.id == id }) {
                project = existing
            } else {
                project = try repositories.project.create(named: trimmedNewProjectName)
            }
            try repositories.task.add(named: trimmedName, to: project)
            onCreated(project)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
