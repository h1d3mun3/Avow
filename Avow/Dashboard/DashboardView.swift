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
                            Circle()
                                .fill(Color(hex: project.colorHex))
                                .frame(width: 8, height: 8)
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
