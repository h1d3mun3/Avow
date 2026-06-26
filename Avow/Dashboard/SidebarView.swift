import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(Repositories.self) private var repositories
    @Environment(TimeRoundingSettings.self) private var roundingSettings

    @Query(sort: \Project.sortOrder)
    private var projects: [Project]

    @Query(sort: \Facet.name)
    private var facets: [Facet]

    @State private var viewModel: SidebarViewModel

    @Binding var selection: DashboardView.SidebarItem?

    @State private var showingNewProject = false
    @State private var renamingProject: Project?
    @State private var renameText: String = ""
    @FocusState private var renameFieldFocused: Bool
    @State private var showArchived = false
    @State private var showProjects = true
    @State private var showFacets = true
    @State private var projectToDelete: Project?
    @State private var renamingFacet: Facet?
    @State private var facetToDelete: Facet?
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

            Section("Projects", isExpanded: $showProjects) {
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
                                let total = roundingSettings.display(project.totalDuration)
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
                                    let total = roundingSettings.display(project.totalDuration)
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

            if !facets.isEmpty {
                Section("Facets", isExpanded: $showFacets) {
                    ForEach(facets) { facet in
                        NavigationLink(value: DashboardView.SidebarItem.facet(facet)) {
                            HStack(spacing: 8) {
                                if renamingFacet?.id == facet.id {
                                    TextField("", text: $renameText)
                                        .textFieldStyle(.plain)
                                        .focused($renameFieldFocused)
                                        .onSubmit { commitFacetRename() }
                                        .onExitCommand { renamingFacet = nil }
                                } else {
                                    Text(facet.name)
                                    Spacer()
                                    Text(roundingSettings.display(facet.totalDuration).shortFormatted)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        .contextMenu {
                            Button("Rename") {
                                renamingFacet = facet
                                renameText = facet.name
                                renameFieldFocused = true
                            }
                            Divider()
                            Button("Delete…", role: .destructive) {
                                facetToDelete = facet
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: projects, initial: true) { _, new in
            viewModel.update(projects: new)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            List(selection: $selection) {
                NavigationLink(value: DashboardView.SidebarItem.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .listStyle(.sidebar)
            .scrollDisabled(true)
            .frame(height: 44)
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
        .sheet(isPresented: $showingNewProject) {
            NewProjectSheet()
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
        .confirmationDialog(
            "Delete \"\(facetToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { facetToDelete != nil }, set: { if !$0 { facetToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Facet", role: .destructive) {
                if let facet = facetToDelete {
                    if case .facet(let selected) = selection, selected.id == facet.id {
                        selection = .overview
                    }
                    do { try repositories.facet.delete(facet) } catch { errorMessage = error.localizedDescription }
                }
                facetToDelete = nil
            }
        } message: {
            Text("This facet will be removed from every task that carries it. Time records are not affected.")
        }
        .errorAlert($errorMessage)
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

    private func commitFacetRename() {
        if let facet = renamingFacet {
            do { try repositories.facet.rename(facet, to: renameText) } catch { errorMessage = error.localizedDescription }
        }
        renamingFacet = nil
        renameText = ""
    }
}
