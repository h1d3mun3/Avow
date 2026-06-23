import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("ExportService")
struct ExportServiceTests {

    private let service = ExportService()

    private let csvHeader = "project,task,facets,start,end,duration_seconds,project_id,task_id,entry_id"

    /// Data rows (header dropped), split on the RFC 4180 CRLF terminator.
    private func dataLines(_ csv: String) -> [String] {
        Array(csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }.dropFirst())
    }

    // MARK: - CSV

    @Test func buildCSVString_emptyProjects_returnsHeaderOnly() {
        let csv = service.buildCSVString(from: [])
        #expect(csv == csvHeader + "\r\n")
    }

    @Test func buildCSVString_usesCRLFRowTerminator() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        entry.endDate = Date(timeIntervalSinceNow: 60)
        context.insert(entry)

        let csv = service.buildCSVString(from: [project])

        #expect(csv.hasPrefix(csvHeader + "\r\n"))
        #expect(csv.hasSuffix("\r\n"))
    }

    @Test func buildCSVString_includesProjectAndTaskName() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "My Project")
        context.insert(project)
        let task = Task(name: "My Task", project: project)
        context.insert(task)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = Date(timeIntervalSinceReferenceDate: 3600)
        let entry = TimeEntry(startDate: start, task: task)
        entry.endDate = end
        context.insert(entry)

        let csv = service.buildCSVString(from: [project])

        #expect(csv.contains("\"My Project\""))
        #expect(csv.contains("\"My Task\""))
        // Duration is derived from endDate (deterministic), not .now.
        #expect(csv.contains(",3600,"))
    }

    @Test func buildCSVString_includesIdentifiers() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        entry.endDate = Date(timeIntervalSinceNow: 60)
        context.insert(entry)

        let csv = service.buildCSVString(from: [project])

        #expect(csv.contains(project.id.uuidString))
        #expect(csv.contains(task.id.uuidString))
        #expect(csv.contains(entry.id.uuidString))
    }

    @Test func buildCSVString_includesFacetNames() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let coding = Facet(name: "Coding")
        let meetings = Facet(name: "Meetings")
        context.insert(coding)
        context.insert(meetings)
        task.facets.append(meetings)
        task.facets.append(coding)
        let entry = TimeEntry(startDate: .now, task: task)
        entry.endDate = Date(timeIntervalSinceNow: 60)
        context.insert(entry)
        try context.save()

        let csv = service.buildCSVString(from: [project])

        // Facet names are sorted and semicolon-joined inside one quoted column.
        #expect(csv.contains("\"Coding; Meetings\""))
    }

    @Test func buildCSVString_runningEntry_hasEmptyEndAndDuration() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        context.insert(entry)

        let csv = service.buildCSVString(from: [project])
        let fields = (dataLines(csv).first ?? "").components(separatedBy: ",")

        // 0:project 1:task 2:facets 3:start 4:end 5:duration ...
        #expect(fields[4] == "")
        #expect(fields[5] == "")
    }

    @Test func buildCSVString_runningEntry_isDeterministicAcrossExports() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        context.insert(entry)

        // A running entry must not bake in a .now-derived duration, so two exports match.
        #expect(service.buildCSVString(from: [project]) == service.buildCSVString(from: [project]))
    }

    @Test func buildCSVString_escapesEmbeddedQuote() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "a\"b")
        context.insert(project)
        let task = Task(name: "My Task", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        entry.endDate = Date(timeIntervalSinceNow: 60)
        context.insert(entry)

        let csv = service.buildCSVString(from: [project])

        #expect(csv.contains("\"a\"\"b\""))
    }

    @Test func buildCSVString_keepsCommaInsideQuotedField() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "Work, Inc.")
        context.insert(project)
        let task = Task(name: "My Task", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        entry.endDate = Date(timeIntervalSinceNow: 60)
        context.insert(entry)

        let csv = service.buildCSVString(from: [project])

        #expect(csv.contains("\"Work, Inc.\""))
    }

    @Test func buildCSVString_preservesNewlineInName() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "Line1\nLine2")
        context.insert(project)
        let task = Task(name: "My Task", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        entry.endDate = Date(timeIntervalSinceNow: 60)
        context.insert(entry)

        let csv = service.buildCSVString(from: [project])

        // The embedded LF stays inside the quoted field; rows are separated by CRLF.
        #expect(csv.contains("\"Line1\nLine2\""))
    }

    // MARK: - JSON

    @Test func buildJSONData_emptyProjects_decodesCorrectly() throws {
        let data = try service.buildJSONData(from: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportSchema.self, from: data)
        #expect(decoded.version == ExportSchema.version)
        #expect(decoded.version == 2)
        #expect(decoded.projects.isEmpty)
        #expect(decoded.facets.isEmpty)
    }

    @Test func buildJSONData_includesProjectMetadata() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "Work", sortOrder: 5)
        project.isArchived = true
        context.insert(project)
        try context.save()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try service.buildJSONData(from: [project])
        let decoded = try decoder.decode(ExportSchema.self, from: data)

        #expect(decoded.projects.count == 1)
        #expect(decoded.projects[0].name == "Work")
        #expect(decoded.projects[0].sortOrder == 5)
        #expect(decoded.projects[0].isArchived == true)
    }

    @Test func buildJSONData_includesNestedTasksAndEntries() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        entry.endDate = Date(timeIntervalSinceNow: 60)
        context.insert(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try service.buildJSONData(from: [project])
        let decoded = try decoder.decode(ExportSchema.self, from: data)

        #expect(decoded.projects[0].tasks.count == 1)
        #expect(decoded.projects[0].tasks[0].timeEntries.count == 1)
    }

    @Test func buildJSONData_includesTaskStatusAndEntryCreatedAt() throws {
        // Whole-second dates because .iso8601 drops sub-second precision.
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        task.status = .completed
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        entry.createdAt = createdAt
        context.insert(entry)
        try context.save()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try service.buildJSONData(from: [project])
        let decoded = try decoder.decode(ExportSchema.self, from: data)

        #expect(decoded.projects[0].tasks[0].status == "completed")
        #expect(decoded.projects[0].tasks[0].timeEntries[0].createdAt == createdAt)
    }

    @Test func buildJSONData_includesFacetsAndTaskFacetIDs() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let facet = Facet(name: "design")
        context.insert(facet)
        task.facets.append(facet)
        try context.save()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try service.buildJSONData(from: [project], facets: [facet])
        let decoded = try decoder.decode(ExportSchema.self, from: data)

        #expect(decoded.facets.count == 1)
        #expect(decoded.facets[0].name == "design")
        #expect(decoded.projects[0].tasks[0].facetIDs == [facet.id])
    }

    @Test func buildJSONData_exportsTaskFacetEvenWhenFacetListOmitted() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let facet = Facet(name: "design")
        context.insert(facet)
        task.facets.append(facet)
        try context.save()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // facets arg omitted: a task-attached facet must still be exported (union).
        let data = try service.buildJSONData(from: [project])
        let decoded = try decoder.decode(ExportSchema.self, from: data)

        #expect(decoded.facets.map(\.name) == ["design"])
    }

    @Test func buildJSONData_includesStandaloneFacet() throws {
        let context = try makeInMemoryContext()
        let facet = Facet(name: "solo")
        context.insert(facet)
        try context.save()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // A facet attached to no task survives because it is passed in explicitly.
        let data = try service.buildJSONData(from: [], facets: [facet])
        let decoded = try decoder.decode(ExportSchema.self, from: data)

        #expect(decoded.facets.map(\.name) == ["solo"])
    }

    @Test func buildJSONData_usesInjectedTimestamp() throws {
        // Use a whole-second date because .iso8601 drops sub-second precision.
        let exportedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try service.buildJSONData(from: [], exportedAt: exportedAt)
        let decoded = try decoder.decode(ExportSchema.self, from: data)

        #expect(decoded.exportedAt == exportedAt)
    }
}
