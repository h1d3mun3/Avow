import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("SwiftDataTaskRepository")
struct SwiftDataTaskRepositoryTests {

    private func makeRepository() throws -> (SwiftDataTaskRepository, ModelContext) {
        let schema = Schema([Project.self, Task.self, TimeEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return (SwiftDataTaskRepository(context: context), context)
    }

    @Test func add_insertsTaskIntoProject() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "P")
        context.insert(project)

        try repo.add(named: "New Task", to: project)

        let tasks = try context.fetch(FetchDescriptor<Task>())
        #expect(tasks.count == 1)
        #expect(tasks[0].name == "New Task")
        #expect(tasks[0].project?.id == project.id)
    }

    @Test func updateStatus_changesStatus() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        try repo.updateStatus(task, to: .completed)

        #expect(task.status == .completed)
    }

    @Test func rename_changesName() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "Old Name", project: project)
        context.insert(task)

        try repo.rename(task, to: "New Name")

        #expect(task.name == "New Name")
    }

    @Test func delete_removesTaskFromStore() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        try context.save()

        try repo.delete(task)

        let remaining = try context.fetch(FetchDescriptor<Task>())
        #expect(remaining.isEmpty)
    }

    @Test func updateStatus_advancesUpdatedAt() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        task.updatedAt = .distantPast

        try repo.updateStatus(task, to: .completed)

        #expect(task.updatedAt > .distantPast)
    }

    @Test func rename_advancesUpdatedAt() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        task.updatedAt = .distantPast

        try repo.rename(task, to: "Renamed")

        #expect(task.updatedAt > .distantPast)
    }
}
