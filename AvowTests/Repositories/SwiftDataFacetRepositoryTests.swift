import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("SwiftDataFacetRepository")
struct SwiftDataFacetRepositoryTests {

    private func makeRepository() throws -> (SwiftDataFacetRepository, ModelContext) {
        let context = try makeInMemoryContext()
        return (SwiftDataFacetRepository(context: context), context)
    }

    private func makeTask(in context: ModelContext) -> Task {
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        return task
    }

    @Test func findOrCreate_insertsNewFacet() throws {
        let (repo, context) = try makeRepository()

        let facet = try repo.findOrCreate(named: "bullshit-job")

        #expect(facet.name == "bullshit-job")
        let stored = try context.fetch(FetchDescriptor<Facet>())
        #expect(stored.count == 1)
    }

    @Test func findOrCreate_reusesExistingFacetByName() throws {
        let (repo, context) = try makeRepository()

        let first = try repo.findOrCreate(named: "MTG")
        let second = try repo.findOrCreate(named: "MTG")

        #expect(first.id == second.id)
        #expect(try context.fetch(FetchDescriptor<Facet>()).count == 1)
    }

    @Test func findOrCreate_trimsWhitespace() throws {
        let (repo, _) = try makeRepository()

        let facet = try repo.findOrCreate(named: "  deep-work  ")

        #expect(facet.name == "deep-work")
    }

    @Test func rename_updatesFacetName() throws {
        let (repo, _) = try makeRepository()
        let facet = try repo.findOrCreate(named: "MTG")

        try repo.rename(facet, to: "Meetings")

        #expect(facet.name == "Meetings")
    }

    @Test func rename_trimsWhitespace() throws {
        let (repo, _) = try makeRepository()
        let facet = try repo.findOrCreate(named: "MTG")

        try repo.rename(facet, to: "  Meetings  ")

        #expect(facet.name == "Meetings")
    }

    @Test func rename_emptyNameIsNoOp() throws {
        let (repo, _) = try makeRepository()
        let facet = try repo.findOrCreate(named: "MTG")

        try repo.rename(facet, to: "   ")

        #expect(facet.name == "MTG")
    }

    @Test func rename_toExistingNameThrows() throws {
        let (repo, _) = try makeRepository()
        _ = try repo.findOrCreate(named: "Meetings")
        let facet = try repo.findOrCreate(named: "MTG")

        #expect(throws: FacetRepositoryError.self) {
            try repo.rename(facet, to: "Meetings")
        }
        #expect(facet.name == "MTG")
    }

    @Test func rename_toSameNameIsNoOp() throws {
        let (repo, context) = try makeRepository()
        let facet = try repo.findOrCreate(named: "MTG")

        try repo.rename(facet, to: "MTG")

        #expect(facet.name == "MTG")
        #expect(try context.fetch(FetchDescriptor<Facet>()).count == 1)
    }

    @Test func attach_addsFacetToTask() throws {
        let (repo, context) = try makeRepository()
        let task = makeTask(in: context)
        let facet = try repo.findOrCreate(named: "MTG")

        try repo.attach(facet, to: task)

        #expect(task.facets.map(\.id) == [facet.id])
    }

    @Test func attach_isIdempotent() throws {
        let (repo, context) = try makeRepository()
        let task = makeTask(in: context)
        let facet = try repo.findOrCreate(named: "MTG")

        try repo.attach(facet, to: task)
        try repo.attach(facet, to: task)

        #expect(task.facets.count == 1)
    }

    @Test func detach_removesFacetFromTask() throws {
        let (repo, context) = try makeRepository()
        let task = makeTask(in: context)
        let facet = try repo.findOrCreate(named: "MTG")
        try repo.attach(facet, to: task)

        try repo.detach(facet, from: task)

        #expect(task.facets.isEmpty)
    }

    @Test func delete_removesFacetAndDetachesFromTasks() throws {
        let (repo, context) = try makeRepository()
        let task = makeTask(in: context)
        let facet = try repo.findOrCreate(named: "MTG")
        try repo.attach(facet, to: task)

        try repo.delete(facet)

        #expect(try context.fetch(FetchDescriptor<Facet>()).isEmpty)
        #expect(task.facets.isEmpty)
    }

    @Test func allFacetsSortedByName_returnsAlphabetical() throws {
        let (repo, _) = try makeRepository()
        _ = try repo.findOrCreate(named: "charlie")
        _ = try repo.findOrCreate(named: "alpha")
        _ = try repo.findOrCreate(named: "bravo")

        let names = try repo.allFacetsSortedByName().map(\.name)

        #expect(names == ["alpha", "bravo", "charlie"])
    }
}
