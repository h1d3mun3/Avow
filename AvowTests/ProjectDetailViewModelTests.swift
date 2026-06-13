import Testing
import Foundation
import SwiftData
@testable import Avow

// MARK: - Mock

final class MockTaskRepository: TaskRepository {
    var addedNames: [String] = []
    var updatedStatuses: [(Task, TaskStatus)] = []
    var deletedTasks: [Task] = []
    var renamedTasks: [(Task, String)] = []

    func add(named name: String, to project: Project) throws { addedNames.append(name) }
    func updateStatus(_ task: Task, to status: TaskStatus) throws { updatedStatuses.append((task, status)) }
    func rename(_ task: Task, to name: String) throws { renamedTasks.append((task, name)) }
    func delete(_ task: Task) throws { deletedTasks.append(task) }
}

// MARK: - Tests

@Suite("ProjectDetailViewModel")
struct ProjectDetailViewModelTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Project.self, Task.self, TimeEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Derived state

    @Test func activeTasks_returnsActiveOnlySortedByName() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let t1 = Task(name: "Zebra", project: project)
        let t2 = Task(name: "Alpha", project: project)
        let t3 = Task(name: "Beta", project: project)
        t3.status = .completed
        [t1, t2, t3].forEach { context.insert($0) }

        let vm = ProjectDetailViewModel(project: project, taskRepository: MockTaskRepository())

        #expect(vm.activeTasks.map(\.name) == ["Alpha", "Zebra"])
    }

    @Test func completedTasks_returnsCompletedOnlySortedByName() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let t1 = Task(name: "Zebra", project: project)
        let t2 = Task(name: "Alpha", project: project)
        t1.status = .completed
        t2.status = .completed
        let t3 = Task(name: "Active", project: project)
        [t1, t2, t3].forEach { context.insert($0) }

        let vm = ProjectDetailViewModel(project: project, taskRepository: MockTaskRepository())

        #expect(vm.completedTasks.map(\.name) == ["Alpha", "Zebra"])
    }

    @Test func totalDuration_sumsAllEntries() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let e1 = TimeEntry(startDate: Date(timeIntervalSinceReferenceDate: 0), task: task)
        e1.endDate = Date(timeIntervalSinceReferenceDate: 3600)
        let e2 = TimeEntry(startDate: Date(timeIntervalSinceReferenceDate: 7200), task: task)
        e2.endDate = Date(timeIntervalSinceReferenceDate: 9000)
        [e1, e2].forEach { context.insert($0) }

        let vm = ProjectDetailViewModel(project: project, taskRepository: MockTaskRepository())

        #expect(vm.totalDuration == 5400)
    }

    @Test func thisWeekDuration_excludesEntriesBeforeWeekStart() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        let thisWeek = TimeEntry(startDate: .now, task: task)
        thisWeek.endDate = Date(timeIntervalSinceNow: 1800)
        let oldEntry = TimeEntry(startDate: Date(timeIntervalSinceNow: -14 * 86400), task: task)
        oldEntry.endDate = Date(timeIntervalSinceNow: -14 * 86400 + 3600)
        [thisWeek, oldEntry].forEach { context.insert($0) }

        let vm = ProjectDetailViewModel(project: project, taskRepository: MockTaskRepository())

        #expect(vm.thisWeekDuration == 1800)
    }

    // MARK: - Mutations

    @Test func addTask_callsRepositoryWithName() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)

        let repo = MockTaskRepository()
        let vm = ProjectDetailViewModel(project: project, taskRepository: repo)
        try vm.addTask(named: "New Task")

        #expect(repo.addedNames == ["New Task"])
    }

    @Test func toggleStatus_activeTask_callsRepositoryWithCompleted() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        let repo = MockTaskRepository()
        let vm = ProjectDetailViewModel(project: project, taskRepository: repo)
        try vm.toggleStatus(task)

        #expect(repo.updatedStatuses.count == 1)
        #expect(repo.updatedStatuses[0].1 == .completed)
    }

    @Test func toggleStatus_completedTask_callsRepositoryWithActive() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        task.status = .completed
        context.insert(task)

        let repo = MockTaskRepository()
        let vm = ProjectDetailViewModel(project: project, taskRepository: repo)
        try vm.toggleStatus(task)

        #expect(repo.updatedStatuses[0].1 == .active)
    }

    @Test func delete_callsRepositoryDelete() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        let repo = MockTaskRepository()
        let vm = ProjectDetailViewModel(project: project, taskRepository: repo)
        try vm.delete(task)

        #expect(repo.deletedTasks.count == 1)
    }

    @Test func rename_callsRepositoryWithNewName() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "Old", project: project)
        context.insert(task)

        let repo = MockTaskRepository()
        let vm = ProjectDetailViewModel(project: project, taskRepository: repo)
        try vm.rename(task, to: "New")

        #expect(repo.renamedTasks.count == 1)
        #expect(repo.renamedTasks[0].1 == "New")
    }
}
