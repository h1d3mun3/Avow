import Foundation
import SwiftData

struct SwiftDataProjectRepository: ProjectRepository {
    let context: ModelContext

    func create(named name: String) throws -> Project {
        let count = (try? context.fetchCount(FetchDescriptor<Project>())) ?? 0
        let project = Project(name: name, sortOrder: count)
        context.insert(project)
        try context.save()
        return project
    }

    func allProjectsSortedByName() throws -> [Project] {
        try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\Project.name)]))
    }

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

    @discardableResult
    func add(named name: String, to project: Project) throws -> Task {
        let task = Task(name: name, project: project)
        context.insert(task)
        try context.save()
        return task
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

struct SwiftDataFacetRepository: FacetRepository {
    let context: ModelContext

    func allFacetsSortedByName() throws -> [Facet] {
        try context.fetch(FetchDescriptor<Facet>(sortBy: [SortDescriptor(\Facet.name)]))
    }

    func findOrCreate(named name: String) throws -> Facet {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = try context.fetch(
            FetchDescriptor<Facet>(predicate: #Predicate { $0.name == trimmed })
        ).first
        if let existing { return existing }
        let facet = Facet(name: trimmed)
        context.insert(facet)
        try context.save()
        return facet
    }

    func rename(_ facet: Facet, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != facet.name else { return }
        let existing = try context.fetch(
            FetchDescriptor<Facet>(predicate: #Predicate { $0.name == trimmed })
        ).first
        if let existing, existing.id != facet.id {
            throw FacetRepositoryError.duplicateName(trimmed)
        }
        facet.name = trimmed
        try context.save()
    }

    func attach(_ facet: Facet, to task: Task) throws {
        guard !task.facets.contains(where: { $0.id == facet.id }) else { return }
        task.facets.append(facet)
        task.updatedAt = .now
        try context.save()
    }

    func detach(_ facet: Facet, from task: Task) throws {
        task.facets.removeAll { $0.id == facet.id }
        task.updatedAt = .now
        try context.save()
    }

    func delete(_ facet: Facet) throws {
        context.delete(facet)
        try context.save()
    }
}

struct SwiftDataTimeEntryRepository: TimeEntryRepository {
    let context: ModelContext

    func start(task: Task) throws -> TimeEntry {
        let entry = TimeEntry(task: task)
        context.insert(entry)
        try context.save()
        return entry
    }

    func add(task: Task, start: Date, end: Date) throws -> TimeEntry {
        guard end >= start else { throw TimeEntryRepositoryError.endBeforeStart }
        let entry = TimeEntry(startDate: start, task: task)
        entry.endDate = end
        context.insert(entry)
        try context.save()
        return entry
    }

    func stop(_ entry: TimeEntry) throws {
        entry.stop()
        try context.save()
    }

    func fetchRunning() throws -> TimeEntry? {
        try context.fetch(FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.endDate == nil })).first
    }

    func update(_ entry: TimeEntry, start: Date, end: Date?) throws {
        // Only a stopped entry can have its end edited; a running entry stays running.
        let editsEnd = entry.endDate != nil
        if editsEnd, let end, end < start {
            throw TimeEntryRepositoryError.endBeforeStart
        }
        entry.startDate = start
        if editsEnd {
            entry.endDate = end
        }
        try context.save()
    }

    func delete(_ entry: TimeEntry) throws {
        context.delete(entry)
        try context.save()
    }
}
