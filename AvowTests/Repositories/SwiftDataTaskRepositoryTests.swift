import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("SwiftDataTaskRepository")
struct SwiftDataTaskRepositoryTests {

    private func makeRepository() throws -> (SwiftDataTaskRepository, ModelContext) {
        let context = try makeInMemoryContext()
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

    @Test func move_reassignsTaskToTargetProject() throws {
        let (repo, context) = try makeRepository()
        let source = Project(name: "Source")
        let target = Project(name: "Target")
        [source, target].forEach { context.insert($0) }
        let task = Task(name: "T", project: source)
        context.insert(task)
        try context.save()

        let moved = try repo.move(taskWithID: task.id, to: target)

        #expect(moved)
        #expect(task.project?.id == target.id)
        #expect(target.tasks.map(\.id) == [task.id])
        #expect(source.tasks.isEmpty)
    }

    @Test func move_keepsTimeEntriesWithTheTask() throws {
        let (repo, context) = try makeRepository()
        let source = Project(name: "Source")
        let target = Project(name: "Target")
        [source, target].forEach { context.insert($0) }
        let task = Task(name: "T", project: source)
        context.insert(task)
        let entry = TimeEntry(startDate: Date(timeIntervalSinceReferenceDate: 0), task: task)
        entry.endDate = Date(timeIntervalSinceReferenceDate: 3600)
        context.insert(entry)
        try context.save()

        try repo.move(taskWithID: task.id, to: target)

        #expect(target.totalDuration == 3600)
        #expect(source.totalDuration == 0)
    }

    @Test func move_returnsFalseWhenTaskAlreadyInProject() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        try context.save()

        #expect(try repo.move(taskWithID: task.id, to: project) == false)
    }

    @Test func move_returnsFalseForUnknownID() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "P")
        context.insert(project)
        try context.save()

        #expect(try repo.move(taskWithID: UUID(), to: project) == false)
    }

    @Test func move_advancesUpdatedAt() throws {
        let (repo, context) = try makeRepository()
        let source = Project(name: "Source")
        let target = Project(name: "Target")
        [source, target].forEach { context.insert($0) }
        let task = Task(name: "T", project: source)
        context.insert(task)
        task.updatedAt = .distantPast
        try context.save()

        try repo.move(taskWithID: task.id, to: target)

        #expect(task.updatedAt > .distantPast)
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
