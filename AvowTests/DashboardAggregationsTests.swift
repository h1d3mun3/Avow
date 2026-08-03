import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("DashboardAggregations")
struct DashboardAggregationsTests {

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
        let context = try makeInMemoryContext()
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
        let context = try makeInMemoryContext()
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
        let context = try makeInMemoryContext()
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
        let context = try makeInMemoryContext()
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
        let context = try makeInMemoryContext()
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

    // MARK: - ProjectGroupBreakdown

    @Test func projectGroupBreakdown_projectInMultipleGroups_countsDurationForEach() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let clientA = ProjectGroup(name: "Client A")
        let internalWork = ProjectGroup(name: "Internal")
        [clientA, internalWork].forEach { context.insert($0) }
        project.projectGroups = [clientA, internalWork]

        let entry = finishedEntry(start: 0, end: 600, task: task, context: context)

        let breakdown = ProjectGroupBreakdown(entries: [entry])

        // Both groups get the full duration: each is an independent question.
        let durations = Dictionary(uniqueKeysWithValues: breakdown.items.map { ($0.name, $0.duration) })
        #expect(durations["Client A"] == 600)
        #expect(durations["Internal"] == 600)
    }

    @Test func projectGroupBreakdown_sameGroupAcrossProjects_sumsDurations() throws {
        let context = try makeInMemoryContext()
        let siteRedesign = Project(name: "Site Redesign")
        let apiMigration = Project(name: "API Migration")
        [siteRedesign, apiMigration].forEach { context.insert($0) }
        let clientA = ProjectGroup(name: "Client A")
        context.insert(clientA)
        siteRedesign.projectGroups = [clientA]
        apiMigration.projectGroups = [clientA]
        let t1 = Task(name: "T1", project: siteRedesign)
        let t2 = Task(name: "T2", project: apiMigration)
        [t1, t2].forEach { context.insert($0) }

        let e1 = finishedEntry(start: 0, end: 600, task: t1, context: context)
        let e2 = finishedEntry(start: 600, end: 1200, task: t2, context: context)

        let breakdown = ProjectGroupBreakdown(entries: [e1, e2])

        #expect(breakdown.items.count == 1)
        #expect(breakdown.items[0].name == "Client A")
        #expect(breakdown.items[0].duration == 1200)
    }

    @Test func projectGroupBreakdown_ungroupedEntriesOmitted() throws {
        let context = try makeInMemoryContext()
        let grouped = Project(name: "Grouped")
        let ungrouped = Project(name: "Ungrouped")
        [grouped, ungrouped].forEach { context.insert($0) }
        let group = ProjectGroup(name: "Client A")
        context.insert(group)
        grouped.projectGroups = [group]
        let taggedTask = Task(name: "Tagged", project: grouped)
        let untaggedTask = Task(name: "Untagged", project: ungrouped)
        [taggedTask, untaggedTask].forEach { context.insert($0) }

        let e1 = finishedEntry(start: 0, end: 600, task: taggedTask, context: context)
        let e2 = finishedEntry(start: 600, end: 1800, task: untaggedTask, context: context)

        let breakdown = ProjectGroupBreakdown(entries: [e1, e2])

        #expect(breakdown.items.count == 1)
        #expect(breakdown.items[0].name == "Client A")
        #expect(breakdown.items[0].duration == 600)
    }

    @Test func projectGroupBreakdown_itemsSortedByDurationDescending() throws {
        let context = try makeInMemoryContext()
        let small = ProjectGroup(name: "small")
        let large = ProjectGroup(name: "large")
        [small, large].forEach { context.insert($0) }
        let smallProject = Project(name: "S")
        let largeProject = Project(name: "L")
        [smallProject, largeProject].forEach { context.insert($0) }
        smallProject.projectGroups = [small]
        largeProject.projectGroups = [large]
        let smallTask = Task(name: "ST", project: smallProject)
        let largeTask = Task(name: "LT", project: largeProject)
        [smallTask, largeTask].forEach { context.insert($0) }

        let smallEntry = finishedEntry(start: 0, end: 600, task: smallTask, context: context)
        let largeEntry = finishedEntry(start: 0, end: 3600, task: largeTask, context: context)

        let breakdown = ProjectGroupBreakdown(entries: [smallEntry, largeEntry])

        #expect(breakdown.items.map(\.name) == ["large", "small"])
    }

    @Test func projectGroupBreakdown_emptyEntries_isEmpty() throws {
        let breakdown = ProjectGroupBreakdown(entries: [])

        #expect(breakdown.items.isEmpty)
    }

    // MARK: - FacetBreakdown

    @Test func facetBreakdown_taskWithMultipleFacets_countsDurationForEach() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let bullshit = Facet(name: "bullshit-job")
        let mtg = Facet(name: "MTG")
        [bullshit, mtg].forEach { context.insert($0) }
        task.facets = [bullshit, mtg]

        let entry = finishedEntry(start: 0, end: 600, task: task, context: context)

        let breakdown = FacetBreakdown(entries: [entry])

        // Both facets get the full duration: each is an independent question.
        let durations = Dictionary(uniqueKeysWithValues: breakdown.items.map { ($0.name, $0.duration) })
        #expect(durations["bullshit-job"] == 600)
        #expect(durations["MTG"] == 600)
    }

    @Test func facetBreakdown_sameFacetAcrossTasks_sumsDurations() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let filing = Task(name: "Document filing", project: project)
        let apps = Task(name: "Application management", project: project)
        [filing, apps].forEach { context.insert($0) }
        let bullshit = Facet(name: "bullshit-job")
        context.insert(bullshit)
        filing.facets = [bullshit]
        apps.facets = [bullshit]

        let e1 = finishedEntry(start: 0, end: 600, task: filing, context: context)
        let e2 = finishedEntry(start: 600, end: 1200, task: apps, context: context)

        let breakdown = FacetBreakdown(entries: [e1, e2])

        #expect(breakdown.items.count == 1)
        #expect(breakdown.items[0].name == "bullshit-job")
        #expect(breakdown.items[0].duration == 1200)
    }

    @Test func facetBreakdown_unfacetedEntriesOmitted() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let tagged = Task(name: "Tagged", project: project)
        let untagged = Task(name: "Untagged", project: project)
        [tagged, untagged].forEach { context.insert($0) }
        let facet = Facet(name: "deep-work")
        context.insert(facet)
        tagged.facets = [facet]

        let e1 = finishedEntry(start: 0, end: 600, task: tagged, context: context)
        let e2 = finishedEntry(start: 600, end: 1800, task: untagged, context: context)

        let breakdown = FacetBreakdown(entries: [e1, e2])

        #expect(breakdown.items.count == 1)
        #expect(breakdown.items[0].name == "deep-work")
        #expect(breakdown.items[0].duration == 600)
    }

    @Test func facetBreakdown_itemsSortedByDurationDescending() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let smallTask = Task(name: "S", project: project)
        let largeTask = Task(name: "L", project: project)
        [smallTask, largeTask].forEach { context.insert($0) }
        let small = Facet(name: "small")
        let large = Facet(name: "large")
        [small, large].forEach { context.insert($0) }
        smallTask.facets = [small]
        largeTask.facets = [large]

        let smallEntry = finishedEntry(start: 0, end: 600, task: smallTask, context: context)
        let largeEntry = finishedEntry(start: 0, end: 3600, task: largeTask, context: context)

        let breakdown = FacetBreakdown(entries: [smallEntry, largeEntry])

        #expect(breakdown.items.map(\.name) == ["large", "small"])
    }

    @Test func facetBreakdown_emptyEntries_isEmpty() throws {
        let breakdown = FacetBreakdown(entries: [])

        #expect(breakdown.items.isEmpty)
    }
}
