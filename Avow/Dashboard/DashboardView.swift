import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Project.sortOrder)
    private var projects: [Project]

    @State private var selectedProject: Project?
    @State private var showingNewProject = false
    @State private var showingSettings = false
    @State private var renamingProject: Project?
    @State private var renameText: String = ""
    @FocusState private var renameFieldFocused: Bool
    @State private var showArchived = false
    @State private var projectToDelete: Project?

    private var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }

    private var archivedProjects: [Project] {
        projects.filter { $0.isArchived }.sorted { $0.name < $1.name }
    }

    enum SidebarItem: Hashable {
        case overview
        case calendar
        case project(Project)
    }

    @State private var selection: SidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .sheet(isPresented: $showingNewProject) {
            NewProjectSheet()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "Delete \"\(projectToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { projectToDelete != nil }, set: { if !$0 { projectToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive) {
                if let project = projectToDelete {
                    if case .project(let selected) = selection, selected.id == project.id {
                        selection = .overview
                    }
                    modelContext.delete(project)
                    try? modelContext.save()
                }
                projectToDelete = nil
            }
        } message: {
            Text("All tasks and time records in this project will be permanently deleted.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            NavigationLink(value: SidebarItem.overview) {
                Label("Overview", systemImage: "square.grid.2x2")
            }
            NavigationLink(value: SidebarItem.calendar) {
                Label("Calendar", systemImage: "calendar")
            }

            Section("Projects") {
                ForEach(activeProjects) { project in
                    NavigationLink(value: SidebarItem.project(project)) {
                        HStack(spacing: 8) {
                            if renamingProject?.id == project.id {
                                TextField("", text: $renameText)
                                    .textFieldStyle(.plain)
                                    .focused($renameFieldFocused)
                                    .onSubmit { commitRename() }
                                    .onExitCommand { renamingProject = nil }
                            } else {
                                Text(project.name)
                                Spacer()
                                let total = project.tasks
                                    .flatMap(\.timeEntries)
                                    .reduce(0.0) { $0 + $1.duration }
                                Text(total.shortFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .contextMenu {
                        Button("Rename") {
                            renamingProject = project
                            renameText = project.name
                            renameFieldFocused = true
                        }
                        Button("Archive") {
                            project.isArchived = true
                            project.updatedAt = .now
                            if case .project(let selected) = selection, selected.id == project.id {
                                selection = .overview
                            }
                            try? modelContext.save()
                        }
                        Divider()
                        Button("Delete…", role: .destructive) {
                            projectToDelete = project
                        }
                    }
                }
                .onMove(perform: moveProjects)
            }

            if !archivedProjects.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showArchived) {
                        ForEach(archivedProjects) { project in
                            NavigationLink(value: SidebarItem.project(project)) {
                                HStack(spacing: 8) {
                                    Text(project.name)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    let total = project.tasks
                                        .flatMap(\.timeEntries)
                                        .reduce(0.0) { $0 + $1.duration }
                                    Text(total.shortFormatted)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .monospacedDigit()
                                }
                            }
                            .contextMenu {
                                Button("Unarchive") {
                                    project.isArchived = false
                                    project.updatedAt = .now
                                    try? modelContext.save()
                                }
                                Divider()
                                Button("Delete…", role: .destructive) {
                                    projectToDelete = project
                                }
                            }
                        }
                    } label: {
                        Text("Archived")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewProject = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Divider()
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Reorder

    private func moveProjects(from source: IndexSet, to destination: Int) {
        var reordered = activeProjects
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, project) in reordered.enumerated() {
            project.sortOrder = index
        }
        try? modelContext.save()
    }

    // MARK: - Rename

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let project = renamingProject {
            project.name = trimmed
            project.updatedAt = .now
            try? modelContext.save()
        }
        renamingProject = nil
        renameText = ""
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .overview, .none:
            OverviewView()
        case .calendar:
            CalendarView()
        case .project(let project):
            ProjectDetailView(project: project)
        }
    }
}
