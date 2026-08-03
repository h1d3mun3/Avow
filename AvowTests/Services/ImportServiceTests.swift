import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("ImportService")
struct ImportServiceTests {

    // MARK: - JSON round trip

    @Test func importJSON_roundTripsFullGraph() throws {
        // Whole-second dates: .iso8601 drops sub-second precision.
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let start = Date(timeIntervalSince1970: 1_700_000_100)
        let end = Date(timeIntervalSince1970: 1_700_003_700)

        let source = try makeInMemoryContext()
        let project = Project(name: "Work", sortOrder: 3)
        project.isArchived = true
        project.createdAt = createdAt
        project.updatedAt = createdAt
        source.insert(project)
        let task = Task(name: "Build", project: project)
        task.status = .completed
        task.createdAt = createdAt
        task.updatedAt = createdAt
        source.insert(task)
        let facet = Facet(name: "Coding")
        facet.createdAt = createdAt
        source.insert(facet)
        task.facets.append(facet)
        let group = ProjectGroup(name: "Client A")
        group.createdAt = createdAt
        source.insert(group)
        project.projectGroups.append(group)
        let entry = TimeEntry(startDate: start, task: task)
        entry.endDate = end
        entry.createdAt = createdAt
        source.insert(entry)
        try source.save()

        let data = try ExportService().buildJSONData(from: [project], facets: [facet], projectGroups: [group])

        // Import into a fresh, empty store.
        let dest = try makeInMemoryContext()
        try ImportService(context: dest).importJSON(data, mode: .replace)

        let projects = try dest.fetch(FetchDescriptor<Project>())
        #expect(projects.count == 1)
        let p = try #require(projects.first)
        #expect(p.id == project.id)
        #expect(p.name == "Work")
        #expect(p.sortOrder == 3)
        #expect(p.isArchived == true)
        #expect(p.createdAt == createdAt)

        #expect(p.tasks.count == 1)
        let t = try #require(p.tasks.first)
        #expect(t.id == task.id)
        #expect(t.status == .completed)
        #expect(t.facets.map(\.name) == ["Coding"])

        #expect(t.timeEntries.count == 1)
        let e = try #require(t.timeEntries.first)
        #expect(e.id == entry.id)
        #expect(e.startDate == start)
        #expect(e.endDate == end)
        #expect(e.createdAt == createdAt)

        #expect(p.projectGroups.map(\.name) == ["Client A"])

        let facets = try dest.fetch(FetchDescriptor<Facet>())
        #expect(facets.count == 1)
        #expect(facets.first?.id == facet.id)

        let groups = try dest.fetch(FetchDescriptor<ProjectGroup>())
        #expect(groups.count == 1)
        #expect(groups.first?.id == group.id)
    }

    @Test func importJSON_mergeIsIdempotent() throws {
        let source = try makeInMemoryContext()
        let project = Project(name: "P")
        source.insert(project)
        let task = Task(name: "T", project: project)
        source.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        entry.endDate = Date(timeIntervalSinceNow: 60)
        source.insert(entry)
        try source.save()
        let data = try ExportService().buildJSONData(from: [project])

        let dest = try makeInMemoryContext()
        try ImportService(context: dest).importJSON(data, mode: .merge)
        try ImportService(context: dest).importJSON(data, mode: .merge)

        // Importing the same file twice must not duplicate anything.
        #expect(try dest.fetch(FetchDescriptor<Project>()).count == 1)
        #expect(try dest.fetch(FetchDescriptor<Task>()).count == 1)
        #expect(try dest.fetch(FetchDescriptor<TimeEntry>()).count == 1)
    }

    @Test func importJSON_mergeKeepsExistingAndUpdatesMatching() throws {
        let dest = try makeInMemoryContext()
        let existing = Project(name: "Existing")
        dest.insert(existing)
        let toUpdate = Project(name: "Old Name")
        dest.insert(toUpdate)
        try dest.save()

        // A file that renames `toUpdate` and adds a brand-new project.
        let source = try makeInMemoryContext()
        let renamed = Project(name: "New Name")
        renamed.id = toUpdate.id
        source.insert(renamed)
        let added = Project(name: "Added")
        source.insert(added)
        try source.save()
        let data = try ExportService().buildJSONData(from: [renamed, added])

        try ImportService(context: dest).importJSON(data, mode: .merge)

        let names = Set(try dest.fetch(FetchDescriptor<Project>()).map(\.name))
        #expect(names == ["Existing", "New Name", "Added"])
    }

    @Test func importJSON_replaceWipesExisting() throws {
        let dest = try makeInMemoryContext()
        let stale = Project(name: "Stale")
        dest.insert(stale)
        try dest.save()

        let source = try makeInMemoryContext()
        let fresh = Project(name: "Fresh")
        source.insert(fresh)
        try source.save()
        let data = try ExportService().buildJSONData(from: [fresh])

        try ImportService(context: dest).importJSON(data, mode: .replace)

        let projects = try dest.fetch(FetchDescriptor<Project>())
        #expect(projects.map(\.name) == ["Fresh"])
    }

    @Test func importJSON_reconcilesFacetByNameToAvoidDuplicate() throws {
        // A facet with the same name already exists under a different id.
        let dest = try makeInMemoryContext()
        let preExisting = Facet(name: "Coding")
        dest.insert(preExisting)
        try dest.save()

        let source = try makeInMemoryContext()
        let project = Project(name: "P")
        source.insert(project)
        let task = Task(name: "T", project: project)
        source.insert(task)
        let facet = Facet(name: "Coding") // different id, same unique name
        source.insert(facet)
        task.facets.append(facet)
        try source.save()
        let data = try ExportService().buildJSONData(from: [project], facets: [facet])

        try ImportService(context: dest).importJSON(data, mode: .merge)

        let facets = try dest.fetch(FetchDescriptor<Facet>())
        #expect(facets.count == 1)
        #expect(facets.first?.id == preExisting.id)
        // The imported task should attach to the reconciled (pre-existing) facet.
        let task2 = try #require(try dest.fetch(FetchDescriptor<Task>()).first)
        #expect(task2.facets.first?.id == preExisting.id)
    }

    @Test func importJSON_reconcilesProjectGroupByNameToAvoidDuplicate() throws {
        // A group with the same name already exists under a different id.
        let dest = try makeInMemoryContext()
        let preExisting = ProjectGroup(name: "Client A")
        dest.insert(preExisting)
        try dest.save()

        let source = try makeInMemoryContext()
        let project = Project(name: "P")
        source.insert(project)
        let group = ProjectGroup(name: "Client A") // different id, same unique name
        source.insert(group)
        project.projectGroups.append(group)
        try source.save()
        let data = try ExportService().buildJSONData(from: [project], projectGroups: [group])

        try ImportService(context: dest).importJSON(data, mode: .merge)

        let groups = try dest.fetch(FetchDescriptor<ProjectGroup>())
        #expect(groups.count == 1)
        #expect(groups.first?.id == preExisting.id)
        // The imported project should attach to the reconciled (pre-existing) group.
        let project2 = try #require(try dest.fetch(FetchDescriptor<Project>()).first)
        #expect(project2.projectGroups.first?.id == preExisting.id)
    }

    // MARK: - Review-driven fixes

    @Test func importJSON_mergeUpdatesFacetMatchedById() throws {
        let dest = try makeInMemoryContext()
        let original = Facet(name: "Coding")
        dest.insert(original)
        try dest.save()

        // Same facet id, renamed in the source file.
        let source = try makeInMemoryContext()
        let renamed = Facet(name: "Programming")
        renamed.id = original.id
        source.insert(renamed)
        try source.save()
        let data = try ExportService().buildJSONData(from: [], facets: [renamed])

        try ImportService(context: dest).importJSON(data, mode: .merge)

        let facets = try dest.fetch(FetchDescriptor<Facet>())
        #expect(facets.count == 1)
        #expect(facets.first?.name == "Programming")
    }

    @Test func importJSON_replace_reimportingSameFileWithCollidingIdsAndNames() throws {
        // The store already holds the exact data being replace-imported (same ids, same unique
        // facet name). The delete+insert must succeed atomically without duplicating or crashing.
        let dest = try makeInMemoryContext()
        let project = Project(name: "Work")
        dest.insert(project)
        let task = Task(name: "Build", project: project)
        dest.insert(task)
        let facet = Facet(name: "Coding")
        dest.insert(facet)
        task.facets.append(facet)
        let group = ProjectGroup(name: "Client A")
        dest.insert(group)
        project.projectGroups.append(group)
        let entry = TimeEntry(startDate: Date(timeIntervalSince1970: 1_700_000_000), task: task)
        entry.endDate = Date(timeIntervalSince1970: 1_700_003_600)
        dest.insert(entry)
        try dest.save()

        let data = try ExportService().buildJSONData(from: [project], facets: [facet], projectGroups: [group])
        try ImportService(context: dest).importJSON(data, mode: .replace)

        #expect(try dest.fetch(FetchDescriptor<Project>()).count == 1)
        #expect(try dest.fetch(FetchDescriptor<Task>()).count == 1)
        #expect(try dest.fetch(FetchDescriptor<TimeEntry>()).count == 1)
        #expect(try dest.fetch(FetchDescriptor<Facet>()).count == 1)
        #expect(try dest.fetch(FetchDescriptor<ProjectGroup>()).count == 1)
    }

    @Test func importJSON_unsupportedFutureVersion_throwsFriendlyError() throws {
        let json = "{\"version\": 99, \"exportedAt\": \"2023-11-14T22:13:20Z\", \"facets\": [], \"projects\": []}"
        let dest = try makeInMemoryContext()
        #expect(throws: ImportService.ImportError.self) {
            try ImportService(context: dest).importJSON(Data(json.utf8), mode: .merge)
        }
    }

    @Test func importJSON_garbageFile_throwsInvalidFile() throws {
        let dest = try makeInMemoryContext()
        #expect(throws: ImportService.ImportError.self) {
            try ImportService(context: dest).importJSON(Data("not json".utf8), mode: .merge)
        }
    }
}
