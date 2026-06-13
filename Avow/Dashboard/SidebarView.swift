import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(Repositories.self) private var repositories

    @Query(sort: \Project.sortOrder)
    private var projects: [Project]

    @State private var viewModel: SidebarViewModel

    @Binding var selection: DashboardView.SidebarItem?

    @State private var showingNewProject = false
    @State private var showingSettings = false
    @State private var renamingProject: Project?
    @State private var renameText: String = ""
    @FocusState private var renameFieldFocused: Bool
    @State private var showArchived = false
    @State private var projectToDelete: Project?
    @State private var errorMessage: String?

    init(selection: Binding<DashboardView.SidebarItem?>, projectRepository: any ProjectRepository) {
        _selection = selection
        _viewModel = State(initialValue: SidebarViewModel(projectRepository: projectRepository))
    }

    var body: some View {
        List(selection: $selection) {
            NavigationLink(value: DashboardView.SidebarItem.overview) {
                Label("Overview", systemImage: "square.grid.2x2")
            }
            NavigationLink(value: DashboardView.SidebarItem.calendar) {
                Label("Calendar", systemImage: "calendar")
            }

            Section("Projects") {
                ForEach(viewModel.activeProjects) { project in
                    NavigationLink(value: DashboardView.SidebarItem.project(project)) {
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
                                let total = project.totalDuration
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
                            if case .project(let selected) = selection, selected.id == project.id {
                                selection = .overview
                            }
                            do { try repositories.project.archive(project) } catch { errorMessage = error.localizedDescription }
                        }
                        Divider()
                        Button("Delete…", role: .destructive) {
                            projectToDelete = project
                        }
                    }
                }
                .onMove(perform: moveProjects)
            }

            if !viewModel.archivedProjects.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showArchived) {
                        ForEach(viewModel.archivedProjects) { project in
                            NavigationLink(value: DashboardView.SidebarItem.project(project)) {
                                HStack(spacing: 8) {
                                    Text(project.name)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    let total = project.totalDuration
                                    Text(total.shortFormatted)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .monospacedDigit()
                                }
                            }
                            .contextMenu {
                                Button("Unarchive") {
                                    do { try repositories.project.unarchive(project) } catch { errorMessage = error.localizedDescription }
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
        .onChange(of: projects, initial: true) { _, new in
            viewModel.update(projects: new)
        }
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewProject = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New project")
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
                    do { try repositories.project.delete(project) } catch { errorMessage = error.localizedDescription }
                }
                projectToDelete = nil
            }
        } message: {
            Text("All tasks and time records in this project will be permanently deleted.")
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func moveProjects(from source: IndexSet, to destination: Int) {
        do { try viewModel.move(from: source, to: destination) } catch { errorMessage = error.localizedDescription }
    }

    private func commitRename() {
        if let project = renamingProject {
            do { try viewModel.commitRename(project, to: renameText) } catch { errorMessage = error.localizedDescription }
        }
        renamingProject = nil
        renameText = ""
    }
}
