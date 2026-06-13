import SwiftUI

struct DashboardView: View {
    @Environment(Repositories.self) private var repositories

    enum SidebarItem: Hashable {
        case overview
        case calendar
        case project(Project)
    }

    @State private var selection: SidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .overview, .none:
                OverviewView()
            case .calendar:
                CalendarView()
            case .project(let project):
                ProjectDetailView(project: project, taskRepository: repositories.task)
                    .id(project.id)
            }
        }
    }
}
