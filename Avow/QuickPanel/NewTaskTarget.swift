import Foundation

/// The project a task typed as `name @project` goes to: an existing one, or one that doesn't
/// exist yet and is created along with the task.
enum NewTaskTarget: Identifiable {
    case project(Project)
    case newProject(String)

    var id: String {
        switch self {
        case .project(let project): "project-\(project.id.uuidString)"
        case .newProject(let name): "new-project-\(name.lowercased())"
        }
    }

    var name: String {
        switch self {
        case .project(let project): project.name
        case .newProject(let name): name
        }
    }

    var isNewProject: Bool {
        if case .newProject = self { return true }
        return false
    }

    /// Short description for the row under the task name, e.g. `in Avow`.
    var locationLabel: String {
        switch self {
        case .project(let project): "in \(project.name)"
        case .newProject(let name): "in new project \"\(name)\""
        }
    }

    /// The project a task goes to when no `@project` is typed: the project of the most recently
    /// tracked task, falling back to the first project when that one is gone or archived.
    static func defaultProject(lastTracked: Project?, in projects: [Project]) -> Project? {
        if let lastTracked, !lastTracked.isArchived { return lastTracked }
        return projects.first
    }
}
