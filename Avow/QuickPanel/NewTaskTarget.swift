import Foundation

/// Where a task typed as `name @project` will be created: an existing project, or a project that
/// doesn't exist yet and is created along with the task. Shared by the quick panel and the
/// Dashboard's New Task sheet so both resolve `@project` identically.
enum NewTaskTarget: Identifiable {
    case project(Project)
    case newProject(String)

    var id: String {
        switch self {
        case .project(let project): "project-\(project.id.uuidString)"
        case .newProject: "new-project"
        }
    }

    /// Short description for the row under the task name, e.g. `in Avow`.
    var locationLabel: String {
        switch self {
        case .project(let project): "in \(project.name)"
        case .newProject(let name): "in new project \"\(name)\""
        }
    }

    var isNewProject: Bool {
        if case .newProject = self { return true }
        return false
    }

    /// The targets to offer for `query`, best first.
    /// - With `@` and no task name (`@Foo`): just a new project of that name, unless one already
    ///   exists — there is no task to place, so only creating the project makes sense.
    /// - With `@`: every project matching the text after it, then — unless one matches exactly — a
    ///   new project of that name.
    /// - Without `@`: just `defaultProject`.
    static func targets(for query: QuickPanelQuery, in projects: [Project], defaultProject: Project?) -> [NewTaskTarget] {
        guard query.hasProjectClause else {
            return defaultProject.map { [.project($0)] } ?? []
        }
        if query.taskText.isEmpty {
            guard let newName = query.newProjectName,
                  !projects.contains(where: { query.isSameProjectName($0.name) }) else { return [] }
            return [.newProject(newName)]
        }
        var result = projects
            .filter { query.matches(projectName: $0.name) }
            .map(NewTaskTarget.project)
        if let newName = query.newProjectName,
           !projects.contains(where: { query.isSameProjectName($0.name) }) {
            result.append(.newProject(newName))
        }
        return result
    }

    /// The project a task goes to when no `@project` is typed: the project of the most recently
    /// tracked task, falling back to the first project when that one is gone or archived.
    static func defaultProject(lastTracked: Project?, in projects: [Project]) -> Project? {
        if let lastTracked, !lastTracked.isArchived { return lastTracked }
        return projects.first
    }

    /// Creates the project first for `.newProject`, then the task in it. An empty `taskName` creates
    /// only the project (`task` is nil).
    @discardableResult
    func create(taskNamed taskName: String, using repositories: Repositories) throws -> (project: Project, task: Task?) {
        let project: Project
        switch self {
        case .project(let existing): project = existing
        case .newProject(let projectName): project = try repositories.project.create(named: projectName)
        }
        guard !taskName.isEmpty else { return (project, nil) }
        return (project, try repositories.task.add(named: taskName, to: project))
    }
}
