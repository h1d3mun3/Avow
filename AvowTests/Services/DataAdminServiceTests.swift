import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("DataAdminService")
struct DataAdminServiceTests {

    @Test func deleteAllData_removesProjectsTasksAndTimeEntries() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "Project")
        context.insert(project)
        let task = Task(name: "Task", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: .now, task: task)
        context.insert(entry)
        try context.save()

        try DataAdminService(context: context).deleteAllData()

        #expect(try context.fetch(FetchDescriptor<TimeEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Task>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Project>()).isEmpty)
    }
}
