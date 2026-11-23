import SwiftUI

struct DashboardView: View {
    @Environment(Repositories.self) private var repositories

    enum SidebarItem: Hashable {
        case overview
        case calendar
        case project(Project)
        case facet(Facet)
        case projectGroup(ProjectGroup)
        case settings
    }

    @State private var selection: SidebarItem? = .overview
    @State private var showingNewTask = false

    /// The project whose detail is on screen, if any — the default home for a new task.
    private var shownProject: Project? {
        if case .project(let project) = selection { return project }
        return nil
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, projectRepository: repositories.project)
        } detail: {
            switch selection {
            case .overview, .none:
                OverviewView()
            case .calendar:
                CalendarView()
            case .project(let project):
                ProjectDetailView(project: project, taskRepository: repositories.task)
                    .id(project.id)
            case .facet(let facet):
                FacetDetailView(facet: facet)
                    .id(facet.id)
            case .projectGroup(let group):
                ProjectGroupDetailView(group: group)
                    .id(group.id)
            case .settings:
                SettingsView()
            }
        }
        .focusedSceneValue(\.openSettingsAction) { selection = .settings }
        .focusedSceneValue(\.showSidebarItemAction) { selection = $0 }
        .focusedSceneValue(\.newTaskAction) { showingNewTask = true }
        .sheet(isPresented: $showingNewTask) {
            NewTaskSheet(preferredProject: shownProject) { project in
                selection = .project(project)
            }
        }
    }
}
