import Testing
import SwiftData
@testable import Avow

@Suite("SwiftDataProjectRepository")
struct SwiftDataProjectRepositoryTests {

    private func makeRepository() throws -> (SwiftDataProjectRepository, ModelContext) {
        let schema = Schema([Project.self, Task.self, TimeEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return (SwiftDataProjectRepository(context: context), context)
    }

    @Test func create_returnsProjectWithNextSortOrder() throws {
        let (repo, context) = try makeRepository()
        for i in 0..<3 {
            context.insert(Project(name: "P\(i)", sortOrder: i))
        }
        try context.save()

        let created = try repo.create(named: "New")

        #expect(created.sortOrder == 3)
        let all = try context.fetch(FetchDescriptor<Project>())
        #expect(all.contains { $0.id == created.id })
    }

    @Test func allProjectsSortedByName_returnsNameSorted() throws {
        let (repo, context) = try makeRepository()
        context.insert(Project(name: "Charlie"))
        context.insert(Project(name: "Alpha"))
        context.insert(Project(name: "Bravo"))
        try context.save()

        let projects = try repo.allProjectsSortedByName()

        #expect(projects.map(\.name) == ["Alpha", "Bravo", "Charlie"])
    }

    @Test func archive_setsIsArchivedTrue() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "Test")
        context.insert(project)

        try repo.archive(project)

        #expect(project.isArchived)
    }

    @Test func unarchive_setsIsArchivedFalse() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "Test")
        project.isArchived = true
        context.insert(project)

        try repo.unarchive(project)

        #expect(!project.isArchived)
    }

    @Test func delete_removesProjectFromStore() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "Test")
        context.insert(project)
        try context.save()

        try repo.delete(project)

        let remaining = try context.fetch(FetchDescriptor<Project>())
        #expect(remaining.isEmpty)
    }

    @Test func rename_updatesProjectName() throws {
        let (repo, context) = try makeRepository()
        let project = Project(name: "Old Name")
        context.insert(project)

        try repo.rename(project, to: "New Name")

        #expect(project.name == "New Name")
    }

    @Test func reorder_updatesSortOrdersInGivenOrder() throws {
        let (repo, context) = try makeRepository()
        let p1 = Project(name: "A")
        let p2 = Project(name: "B")
        let p3 = Project(name: "C")
        [p1, p2, p3].forEach { context.insert($0) }

        try repo.reorder([p3, p1, p2])

        #expect(p3.sortOrder == 0)
        #expect(p1.sortOrder == 1)
        #expect(p2.sortOrder == 2)
    }
}
