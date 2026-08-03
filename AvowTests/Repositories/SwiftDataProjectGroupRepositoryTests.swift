import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("SwiftDataProjectGroupRepository")
struct SwiftDataProjectGroupRepositoryTests {

    private func makeRepository() throws -> (SwiftDataProjectGroupRepository, ModelContext) {
        let context = try makeInMemoryContext()
        return (SwiftDataProjectGroupRepository(context: context), context)
    }

    private func makeProject(in context: ModelContext) -> Project {
        let project = Project(name: "P")
        context.insert(project)
        return project
    }

    @Test func findOrCreate_insertsNewGroup() throws {
        let (repo, context) = try makeRepository()

        let group = try repo.findOrCreate(named: "Client A")

        #expect(group.name == "Client A")
        let stored = try context.fetch(FetchDescriptor<ProjectGroup>())
        #expect(stored.count == 1)
    }

    @Test func findOrCreate_reusesExistingGroupByName() throws {
        let (repo, context) = try makeRepository()

        let first = try repo.findOrCreate(named: "Client A")
        let second = try repo.findOrCreate(named: "Client A")

        #expect(first.id == second.id)
        #expect(try context.fetch(FetchDescriptor<ProjectGroup>()).count == 1)
    }

    @Test func findOrCreate_trimsWhitespace() throws {
        let (repo, _) = try makeRepository()

        let group = try repo.findOrCreate(named: "  Client A  ")

        #expect(group.name == "Client A")
    }

    @Test func rename_updatesGroupName() throws {
        let (repo, _) = try makeRepository()
        let group = try repo.findOrCreate(named: "Client A")

        try repo.rename(group, to: "Client A Inc.")

        #expect(group.name == "Client A Inc.")
    }

    @Test func rename_trimsWhitespace() throws {
        let (repo, _) = try makeRepository()
        let group = try repo.findOrCreate(named: "Client A")

        try repo.rename(group, to: "  Client A Inc.  ")

        #expect(group.name == "Client A Inc.")
    }

    @Test func rename_emptyNameIsNoOp() throws {
        let (repo, _) = try makeRepository()
        let group = try repo.findOrCreate(named: "Client A")

        try repo.rename(group, to: "   ")

        #expect(group.name == "Client A")
    }

    @Test func rename_toExistingNameThrows() throws {
        let (repo, _) = try makeRepository()
        _ = try repo.findOrCreate(named: "Client B")
        let group = try repo.findOrCreate(named: "Client A")

        #expect(throws: ProjectGroupRepositoryError.self) {
            try repo.rename(group, to: "Client B")
        }
        #expect(group.name == "Client A")
    }

    @Test func rename_toSameNameIsNoOp() throws {
        let (repo, context) = try makeRepository()
        let group = try repo.findOrCreate(named: "Client A")

        try repo.rename(group, to: "Client A")

        #expect(group.name == "Client A")
        #expect(try context.fetch(FetchDescriptor<ProjectGroup>()).count == 1)
    }

    @Test func attach_addsGroupToProject() throws {
        let (repo, context) = try makeRepository()
        let project = makeProject(in: context)
        let group = try repo.findOrCreate(named: "Client A")

        try repo.attach(group, to: project)

        #expect(project.projectGroups.map(\.id) == [group.id])
    }

    @Test func attach_isIdempotent() throws {
        let (repo, context) = try makeRepository()
        let project = makeProject(in: context)
        let group = try repo.findOrCreate(named: "Client A")

        try repo.attach(group, to: project)
        try repo.attach(group, to: project)

        #expect(project.projectGroups.count == 1)
    }

    @Test func attach_allowsProjectInMultipleGroups() throws {
        let (repo, context) = try makeRepository()
        let project = makeProject(in: context)
        let groupA = try repo.findOrCreate(named: "Client A")
        let groupB = try repo.findOrCreate(named: "Client B")

        try repo.attach(groupA, to: project)
        try repo.attach(groupB, to: project)

        #expect(Set(project.projectGroups.map(\.id)) == Set([groupA.id, groupB.id]))
    }

    @Test func detach_removesGroupFromProject() throws {
        let (repo, context) = try makeRepository()
        let project = makeProject(in: context)
        let group = try repo.findOrCreate(named: "Client A")
        try repo.attach(group, to: project)

        try repo.detach(group, from: project)

        #expect(project.projectGroups.isEmpty)
    }

    @Test func delete_removesGroupAndDetachesFromProjects() throws {
        let (repo, context) = try makeRepository()
        let project = makeProject(in: context)
        let group = try repo.findOrCreate(named: "Client A")
        try repo.attach(group, to: project)

        try repo.delete(group)

        #expect(try context.fetch(FetchDescriptor<ProjectGroup>()).isEmpty)
        #expect(project.projectGroups.isEmpty)
    }

    @Test func allProjectGroupsSortedByName_returnsAlphabetical() throws {
        let (repo, _) = try makeRepository()
        _ = try repo.findOrCreate(named: "charlie")
        _ = try repo.findOrCreate(named: "alpha")
        _ = try repo.findOrCreate(named: "bravo")

        let names = try repo.allProjectGroupsSortedByName().map(\.name)

        #expect(names == ["alpha", "bravo", "charlie"])
    }
}
