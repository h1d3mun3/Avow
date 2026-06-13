import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("TimeEntry+Aggregation")
struct TimeEntryAggregationTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Project.self, Task.self, TimeEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func finishedEntry(
        start: TimeInterval,
        end: TimeInterval,
        task: Task,
        context: ModelContext
    ) -> TimeEntry {
        let entry = TimeEntry(startDate: Date(timeIntervalSinceReferenceDate: start), task: task)
        entry.endDate = Date(timeIntervalSinceReferenceDate: end)
        context.insert(entry)
        return entry
    }

    // MARK: - Sequence.totalDuration

    @Test func sequenceTotalDuration_emptyIsZero() throws {
        let entries: [TimeEntry] = []
        #expect(entries.totalDuration == 0)
    }

    @Test func sequenceTotalDuration_singleEntry() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let entry = finishedEntry(start: 0, end: 3600, task: task, context: context)

        #expect([entry].totalDuration == 3600)
    }

    @Test func sequenceTotalDuration_multipleEntriesSum() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let e1 = finishedEntry(start: 0, end: 3600, task: task, context: context)
        let e2 = finishedEntry(start: 7200, end: 9000, task: task, context: context)

        #expect([e1, e2].totalDuration == 5400)
    }

    @Test func sequenceTotalDuration_isOrderIndependent() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let e1 = finishedEntry(start: 0, end: 3600, task: task, context: context)
        let e2 = finishedEntry(start: 7200, end: 9000, task: task, context: context)

        #expect([e1, e2].totalDuration == [e2, e1].totalDuration)
    }

    // MARK: - Project.totalDuration

    @Test func projectTotalDuration_sumsAcrossTasks() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let taskA = Task(name: "A", project: project)
        let taskB = Task(name: "B", project: project)
        [taskA, taskB].forEach { context.insert($0) }
        _ = finishedEntry(start: 0, end: 3600, task: taskA, context: context)
        _ = finishedEntry(start: 0, end: 1800, task: taskB, context: context)

        #expect(project.totalDuration == 5400)
    }

    // MARK: - Task.totalDuration

    @Test func taskTotalDuration_sumsTaskEntries() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        _ = finishedEntry(start: 0, end: 3600, task: task, context: context)
        _ = finishedEntry(start: 7200, end: 9000, task: task, context: context)

        #expect(task.totalDuration == 5400)
    }
}
