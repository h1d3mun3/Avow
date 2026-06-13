import Testing
import Foundation
import SwiftData
@testable import Avow

// MARK: - Mock

final class MockProjectRepository: ProjectRepository {
    var archivedProjects: [Project] = []
    var unarchivedProjects: [Project] = []
    var deletedProjects: [Project] = []
    var renamedProjects: [(Project, String)] = []
    var reorderedBatches: [[Project]] = []

    func archive(_ project: Project) throws { archivedProjects.append(project) }
    func unarchive(_ project: Project) throws { unarchivedProjects.append(project) }
    func delete(_ project: Project) throws { deletedProjects.append(project) }
    func rename(_ project: Project, to name: String) throws { renamedProjects.append((project, name)) }
    func reorder(_ projects: [Project]) throws { reorderedBatches.append(projects) }
}

// MARK: - Tests

@Suite("SidebarViewModel")
struct SidebarViewModelTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Project.self, Task.self, TimeEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Derived state

    @Test func activeProjects_returnsNonArchivedPreservingOrder() throws {
        let context = try makeContext()
        let p1 = Project(name: "Zebra", sortOrder: 0)
        let p2 = Project(name: "Alpha", sortOrder: 1)
        let p3 = Project(name: "Beta", sortOrder: 2)
        p3.isArchived = true
        [p1, p2, p3].forEach { context.insert($0) }

        let vm = SidebarViewModel(projectRepository: MockProjectRepository())
        vm.update(projects: [p1, p2, p3])

        // Preserves incoming (@Query sortOrder) order — no name sort
        #expect(vm.activeProjects.map(\.name) == ["Zebra", "Alpha"])
    }

    @Test func archivedProjects_returnsArchivedSortedByName() throws {
        let context = try makeContext()
        let p1 = Project(name: "Zebra", sortOrder: 0)
        let p2 = Project(name: "Alpha", sortOrder: 1)
        let p3 = Project(name: "Beta", sortOrder: 2)
        p1.isArchived = true
        p2.isArchived = true
        [p1, p2, p3].forEach { context.insert($0) }

        let vm = SidebarViewModel(projectRepository: MockProjectRepository())
        vm.update(projects: [p1, p2, p3])

        #expect(vm.archivedProjects.map(\.name) == ["Alpha", "Zebra"])
    }

    // MARK: - Mutations

    @Test func move_passesReorderedActiveProjectsToRepository() throws {
        let context = try makeContext()
        let p0 = Project(name: "A", sortOrder: 0)
        let p1 = Project(name: "B", sortOrder: 1)
        let p2 = Project(name: "C", sortOrder: 2)
        [p0, p1, p2].forEach { context.insert($0) }

        let repo = MockProjectRepository()
        let vm = SidebarViewModel(projectRepository: repo)
        vm.update(projects: [p0, p1, p2])

        // Move the last item to the front
        try vm.move(from: IndexSet(integer: 2), to: 0)

        #expect(repo.reorderedBatches.count == 1)
        let captured = repo.reorderedBatches[0]
        #expect(captured.map(\.name) == ["C", "A", "B"])
        // Applying the repo's index-based assignment yields a 0..n-1 sequence
        #expect(Array(captured.indices) == [0, 1, 2])
    }

    @Test func move_excludesArchivedProjects() throws {
        let context = try makeContext()
        let p0 = Project(name: "A", sortOrder: 0)
        let p1 = Project(name: "B", sortOrder: 1)
        let archived = Project(name: "Z", sortOrder: 2)
        archived.isArchived = true
        [p0, p1, archived].forEach { context.insert($0) }

        let repo = MockProjectRepository()
        let vm = SidebarViewModel(projectRepository: repo)
        vm.update(projects: [p0, p1, archived])

        try vm.move(from: IndexSet(integer: 0), to: 2)

        #expect(repo.reorderedBatches[0].map(\.name) == ["B", "A"])
    }

    @Test func commitRename_whitespaceOnly_doesNotCallRepository() throws {
        let context = try makeContext()
        let project = Project(name: "Old")
        context.insert(project)

        let repo = MockProjectRepository()
        let vm = SidebarViewModel(projectRepository: repo)
        vm.update(projects: [project])

        try vm.commitRename(project, to: "   ")

        #expect(repo.renamedProjects.isEmpty)
    }

    @Test func commitRename_validName_callsRepositoryWithTrimmedValue() throws {
        let context = try makeContext()
        let project = Project(name: "Old")
        context.insert(project)

        let repo = MockProjectRepository()
        let vm = SidebarViewModel(projectRepository: repo)
        vm.update(projects: [project])

        try vm.commitRename(project, to: "  New Name  ")

        #expect(repo.renamedProjects.count == 1)
        #expect(repo.renamedProjects[0].1 == "New Name")
    }
}
