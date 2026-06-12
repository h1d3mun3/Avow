import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Project.name)
    private var projects: [Project]

    @State private var selectedProject: Project?
    @State private var showingNewProject = false
    @State private var showingSettings = false
    @State private var renamingProject: Project?
    @State private var renameText: String = ""
    @FocusState private var renameFieldFocused: Bool

    enum SidebarItem: Hashable {
        case overview
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
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            NavigationLink(value: SidebarItem.overview) {
                Label("Overview", systemImage: "square.grid.2x2")
            }

            Section("Projects") {
                ForEach(projects) { project in
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
        case .project(let project):
            ProjectDetailView(project: project)
        }
    }
}
