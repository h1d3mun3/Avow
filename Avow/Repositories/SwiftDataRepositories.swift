import Foundation
import SwiftData

struct SwiftDataProjectRepository: ProjectRepository {
    let context: ModelContext

    func archive(_ project: Project) throws {
        project.isArchived = true
        project.updatedAt = .now
        try context.save()
    }

    func unarchive(_ project: Project) throws {
        project.isArchived = false
        project.updatedAt = .now
        try context.save()
    }

    func delete(_ project: Project) throws {
        context.delete(project)
        try context.save()
    }

    func rename(_ project: Project, to name: String) throws {
        project.name = name
        project.updatedAt = .now
        try context.save()
    }

    func reorder(_ projects: [Project]) throws {
        for (index, project) in projects.enumerated() {
            project.sortOrder = index
        }
        try context.save()
    }
}

struct SwiftDataTaskRepository: TaskRepository {
    let context: ModelContext

    func add(named name: String, to project: Project) throws {
        let task = Task(name: name, project: project)
        context.insert(task)
        try context.save()
    }

    func updateStatus(_ task: Task, to status: TaskStatus) throws {
        task.status = status
        task.updatedAt = .now
        try context.save()
    }

    func rename(_ task: Task, to name: String) throws {
        task.name = name
        task.updatedAt = .now
        try context.save()
    }

    func delete(_ task: Task) throws {
        context.delete(task)
        try context.save()
    }
}

struct SwiftDataTimeEntryRepository: TimeEntryRepository {
    let context: ModelContext

    func update(_ entry: TimeEntry, start: Date, end: Date?) throws {
        entry.startDate = start
        if entry.endDate != nil {
            entry.endDate = end
        }
        try context.save()
    }

    func delete(_ entry: TimeEntry) throws {
        context.delete(entry)
        try context.save()
    }
}
