import Foundation
import SwiftData

@Observable
final class ProjectDetailViewModel {
    private let project: Project
    private let taskRepository: any TaskRepository
    private let clock: any AppClock

    init(project: Project, taskRepository: any TaskRepository, clock: any AppClock = SystemClock()) {
        self.project = project
        self.taskRepository = taskRepository
        self.clock = clock
    }

    // MARK: - Derived state

    var projectName: String { project.name }

    var hasTasks: Bool { !project.tasks.isEmpty }

    var activeTasks: [Task] {
        project.tasks
            .filter { $0.status == .active }
            .sorted { $0.name < $1.name }
    }

    var completedTasks: [Task] {
        project.tasks
            .filter { $0.status == .completed }
            .sorted { $0.name < $1.name }
    }

    /// Resolves a selection id back to its task. The list selects by `Task.ID`
    /// (stable across SwiftData refetches), while the detail panel needs the
    /// concrete task. Returns nil for a nil or unknown id.
    func task(withID id: Task.ID?) -> Task? {
        guard let id else { return nil }
        return project.tasks.first { $0.id == id }
    }

    var totalDuration: TimeInterval {
        project.totalDuration
    }

    var thisWeekDuration: TimeInterval {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: clock.now())?.start ?? clock.now()
        return project.allTimeEntries
            .filter { $0.startDate >= startOfWeek }
            .totalDuration
    }

    // MARK: - Mutations

    func addTask(named name: String) throws {
        try taskRepository.add(named: name, to: project)
    }

    func toggleStatus(_ task: Task) throws {
        let next: TaskStatus = task.status == .active ? .completed : .active
        try taskRepository.updateStatus(task, to: next)
    }

    func delete(_ task: Task) throws {
        try taskRepository.delete(task)
    }

    func rename(_ task: Task, to name: String) throws {
        try taskRepository.rename(task, to: name)
    }
}
