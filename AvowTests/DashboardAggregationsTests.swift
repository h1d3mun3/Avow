import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("DashboardAggregations")
struct DashboardAggregationsTests {

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

    // MARK: - DayBreakdown

    @Test func dayBreakdown_groupsByProjectName() throws {
        let context = try makeContext()
        let alpha = Project(name: "Alpha")
        let beta = Project(name: "Beta")
        [alpha, beta].forEach { context.insert($0) }
        let alphaTask = Task(name: "AT", project: alpha)
        let betaTask = Task(name: "BT", project: beta)
        [alphaTask, betaTask].forEach { context.insert($0) }

        // Alpha: 1800 (two entries summed), Beta: 3600 (single entry).
        let e1 = finishedEntry(start: 0, end: 600, task: alphaTask, context: context)
        let e2 = finishedEntry(start: 600, end: 1800, task: alphaTask, context: context)
        let e3 = finishedEntry(start: 0, end: 3600, task: betaTask, context: context)

        let breakdown = DayBreakdown(entries: [e1, e2, e3])

        #expect(breakdown.total == 5400)
        let durations = Dictionary(uniqueKeysWithValues: breakdown.items.map { ($0.name, $0.duration) })
        #expect(durations["Alpha"] == 1800)
        #expect(durations["Beta"] == 3600)
    }

    @Test func dayBreakdown_nilProjectFallsBackToDash() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        let entry = finishedEntry(start: 0, end: 600, task: task, context: context)
        // Detach the entry's task so project lookup yields nil.
        entry.task = nil

        let breakdown = DayBreakdown(entries: [entry])

        #expect(breakdown.items.count == 1)
        #expect(breakdown.items[0].name == "—")
        #expect(breakdown.items[0].duration == 600)
    }

    @Test func dayBreakdown_itemsSortedByDurationDescending() throws {
        let context = try makeContext()
        let small = Project(name: "Small")
        let large = Project(name: "Large")
        [small, large].forEach { context.insert($0) }
        let smallTask = Task(name: "ST", project: small)
        let largeTask = Task(name: "LT", project: large)
        [smallTask, largeTask].forEach { context.insert($0) }

        let smallEntry = finishedEntry(start: 0, end: 600, task: smallTask, context: context)
        let largeEntry = finishedEntry(start: 0, end: 3600, task: largeTask, context: context)

        let breakdown = DayBreakdown(entries: [smallEntry, largeEntry])

        #expect(breakdown.items.map(\.name) == ["Large", "Small"])
    }

    @Test func dayBreakdown_fractionsReflectShareOfTotal() throws {
        let context = try makeContext()
        let alpha = Project(name: "Alpha")
        let beta = Project(name: "Beta")
        [alpha, beta].forEach { context.insert($0) }
        let alphaTask = Task(name: "AT", project: alpha)
        let betaTask = Task(name: "BT", project: beta)
        [alphaTask, betaTask].forEach { context.insert($0) }

        // Alpha 3000, Beta 1000 -> total 4000.
        let alphaEntry = finishedEntry(start: 0, end: 3000, task: alphaTask, context: context)
        let betaEntry = finishedEntry(start: 0, end: 1000, task: betaTask, context: context)

        let breakdown = DayBreakdown(entries: [alphaEntry, betaEntry])

        let fractions = Dictionary(uniqueKeysWithValues: breakdown.items.map { ($0.name, $0.fraction) })
        #expect(fractions["Alpha"] == 0.75)
        #expect(fractions["Beta"] == 0.25)
    }

    @Test func dayBreakdown_emptyEntries_totalZeroAndFractionZero() throws {
        let breakdown = DayBreakdown(entries: [])

        #expect(breakdown.total == 0)
        #expect(breakdown.items.isEmpty)
    }

    @Test func dayBreakdown_zeroDurationEntries_fractionIsZero() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        // Zero-length entry: total is 0, so the guard yields fraction 0 (not NaN).
        let entry = finishedEntry(start: 100, end: 100, task: task, context: context)

        let breakdown = DayBreakdown(entries: [entry])

        #expect(breakdown.total == 0)
        #expect(breakdown.items.count == 1)
        #expect(breakdown.items[0].fraction == 0)
    }

    // MARK: - groupEntriesByTask

    @Test func groupEntriesByTask_twoTasksProduceTwoGroupsSortedByName() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let alpha = Task(name: "Alpha", project: project)
        let beta = Task(name: "Beta", project: project)
        [alpha, beta].forEach { context.insert($0) }

        let betaEntry = finishedEntry(start: 0, end: 600, task: beta, context: context)
        let alphaEntry = finishedEntry(start: 0, end: 600, task: alpha, context: context)

        let groups = groupEntriesByTask([betaEntry, alphaEntry])

        #expect(groups.count == 2)
        #expect(groups.map { $0.task?.name } == ["Alpha", "Beta"])
    }

    @Test func groupEntriesByTask_nilTaskEntriesCollapseIntoOneGroup() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        let e1 = finishedEntry(start: 0, end: 600, task: task, context: context)
        let e2 = finishedEntry(start: 600, end: 1200, task: task, context: context)
        // Detach both so they share the nil-task bucket.
        e1.task = nil
        e2.task = nil

        let groups = groupEntriesByTask([e1, e2])

        #expect(groups.count == 1)
        #expect(groups[0].task == nil)
        #expect(groups[0].entries.count == 2)
    }

    @Test func groupEntriesByTask_preservesIntraGroupOrder() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        // Distinct start dates so we can assert the input order is preserved.
        let first = finishedEntry(start: 0, end: 600, task: task, context: context)
        let second = finishedEntry(start: 600, end: 1200, task: task, context: context)
        let third = finishedEntry(start: 1200, end: 1800, task: task, context: context)

        let groups = groupEntriesByTask([first, second, third])

        #expect(groups.count == 1)
        #expect(groups[0].entries.map(\.startDate) == [first, second, third].map(\.startDate))
    }
}
