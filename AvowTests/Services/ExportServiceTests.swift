import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("ExportService")
struct ExportServiceTests {

    private let service = ExportService()

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Project.self, Task.self, TimeEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - CSV

    @Test func buildCSVString_emptyProjects_returnsHeaderOnly() {
        let csv = service.buildCSVString(from: [])
        #expect(csv == "project,task,start,end,duration_seconds\n")
    }

    @Test func buildCSVString_includesProjectAndTaskName() throws {
        let context = try makeContext()
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
        #expect(csv.contains(",3600\n"))
    }

    @Test func buildCSVString_runningEntry_hasEmptyEndField() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        context.insert(entry)

        let csv = service.buildCSVString(from: [project])
        let dataLine = csv.components(separatedBy: "\n").dropFirst().first ?? ""

        // end field should be empty: ....,<start>,,<duration>
        #expect(dataLine.contains(",,"))
    }

    // MARK: - JSON

    @Test func buildJSONData_emptyProjects_decodesCorrectly() throws {
        let data = try service.buildJSONData(from: [])
        let decoded = try JSONDecoder().decode(ExportSchema.self, from: data)
        #expect(decoded.version == ExportSchema.version)
        #expect(decoded.projects.isEmpty)
    }

    @Test func buildJSONData_includesProjectData() throws {
        let context = try makeContext()
        let project = Project(name: "Work")
        context.insert(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try service.buildJSONData(from: [project])
        let decoded = try decoder.decode(ExportSchema.self, from: data)

        #expect(decoded.projects.count == 1)
        #expect(decoded.projects[0].name == "Work")
    }

    @Test func buildJSONData_includesNestedTasksAndEntries() throws {
        let context = try makeContext()
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
}
