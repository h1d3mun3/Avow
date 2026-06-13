import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("OverviewViewModel")
struct OverviewViewModelTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Project.self, Task.self, TimeEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - activeProjects

    @Test func activeProjects_excludesArchived() throws {
        let context = try makeContext()
        let active = Project(name: "Active")
        let archived = Project(name: "Archived")
        archived.isArchived = true
        [active, archived].forEach { context.insert($0) }

        let vm = OverviewViewModel()
        vm.update(projects: [active, archived])

        #expect(vm.activeProjects.count == 1)
        #expect(vm.activeProjects[0].name == "Active")
    }

    // MARK: - Duration aggregations

    @Test func totalDuration_sumsAllActiveProjectEntries() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let e1 = TimeEntry(startDate: Date(timeIntervalSinceReferenceDate: 0), task: task)
        e1.endDate = Date(timeIntervalSinceReferenceDate: 3600)
        let e2 = TimeEntry(startDate: Date(timeIntervalSinceReferenceDate: 7200), task: task)
        e2.endDate = Date(timeIntervalSinceReferenceDate: 9000)
        [e1, e2].forEach { context.insert($0) }

        let vm = OverviewViewModel()
        vm.update(projects: [project])

        #expect(vm.totalDuration == 5400)
    }

    @Test func totalDuration_excludesArchivedProjects() throws {
        let context = try makeContext()
        let active = Project(name: "Active")
        let archived = Project(name: "Archived")
        archived.isArchived = true
        [active, archived].forEach { context.insert($0) }

        let activeTask = Task(name: "AT", project: active)
        let archivedTask = Task(name: "AT2", project: archived)
        [activeTask, archivedTask].forEach { context.insert($0) }

        let e1 = TimeEntry(startDate: Date(timeIntervalSinceReferenceDate: 0), task: activeTask)
        e1.endDate = Date(timeIntervalSinceReferenceDate: 1800)
        let e2 = TimeEntry(startDate: Date(timeIntervalSinceReferenceDate: 0), task: archivedTask)
        e2.endDate = Date(timeIntervalSinceReferenceDate: 3600)
        [e1, e2].forEach { context.insert($0) }

        let vm = OverviewViewModel()
        vm.update(projects: [active, archived])

        #expect(vm.totalDuration == 1800)
    }

    @Test func thisWeekDuration_excludesOldEntries() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        let today = Calendar.current.startOfDay(for: .now)
        let thisWeekEntry = TimeEntry(startDate: today, task: task)
        thisWeekEntry.endDate = today.addingTimeInterval(1800)

        let twoWeeksAgo = today.addingTimeInterval(-14 * 86400)
        let oldEntry = TimeEntry(startDate: twoWeeksAgo, task: task)
        oldEntry.endDate = twoWeeksAgo.addingTimeInterval(3600)

        [thisWeekEntry, oldEntry].forEach { context.insert($0) }

        let vm = OverviewViewModel()
        vm.update(projects: [project])

        #expect(vm.thisWeekDuration == 1800)
    }

    @Test func todayDuration_excludesYesterdayEntries() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        let today = Calendar.current.startOfDay(for: .now)
        let todayEntry = TimeEntry(startDate: today, task: task)
        todayEntry.endDate = today.addingTimeInterval(900)

        let yesterday = today.addingTimeInterval(-86400)
        let oldEntry = TimeEntry(startDate: yesterday, task: task)
        oldEntry.endDate = yesterday.addingTimeInterval(3600)

        [todayEntry, oldEntry].forEach { context.insert($0) }

        let vm = OverviewViewModel()
        vm.update(projects: [project])

        #expect(vm.todayDuration == 900)
    }

    // MARK: - Deterministic duration boundaries (injected clock)

    @Test func thisWeekDuration_entryExactlyAtWeekStart_counts() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        // Fixed "now": Thursday 2024-01-18 15:45 UTC.
        let now = Date(timeIntervalSinceReferenceDate: 727285500)
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: now)!.start

        let atStart = TimeEntry(startDate: weekStart, task: task)
        atStart.endDate = weekStart.addingTimeInterval(600)
        context.insert(atStart)

        let vm = OverviewViewModel(clock: ManualClock(now: now))
        vm.update(projects: [project])

        #expect(vm.thisWeekDuration == 600)
    }

    @Test func thisWeekDuration_entryASecondBeforeWeekStart_excluded() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        let now = Date(timeIntervalSinceReferenceDate: 727285500)
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: now)!.start

        // One second before the week start: must be excluded.
        let justBefore = TimeEntry(startDate: weekStart.addingTimeInterval(-1), task: task)
        justBefore.endDate = weekStart.addingTimeInterval(600)
        context.insert(justBefore)

        let vm = OverviewViewModel(clock: ManualClock(now: now))
        vm.update(projects: [project])

        #expect(vm.thisWeekDuration == 0)
    }

    @Test func todayDuration_entryExactlyAtMidnight_counts_oneSecondBeforeExcluded() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        let now = Date(timeIntervalSinceReferenceDate: 727285500)
        let startOfDay = Calendar.current.startOfDay(for: now)

        let atMidnight = TimeEntry(startDate: startOfDay, task: task)
        atMidnight.endDate = startOfDay.addingTimeInterval(300)
        let justBefore = TimeEntry(startDate: startOfDay.addingTimeInterval(-1), task: task)
        justBefore.endDate = startOfDay.addingTimeInterval(300)
        [atMidnight, justBefore].forEach { context.insert($0) }

        let vm = OverviewViewModel(clock: ManualClock(now: now))
        vm.update(projects: [project])

        #expect(vm.todayDuration == 300)
    }

    // MARK: - allActiveTasks

    @Test func allActiveTasks_excludesCompletedAndArchivedProjects() throws {
        let context = try makeContext()
        let active = Project(name: "Active")
        let archived = Project(name: "Archived")
        archived.isArchived = true
        [active, archived].forEach { context.insert($0) }

        let t1 = Task(name: "Active task", project: active)
        let t2 = Task(name: "Completed task", project: active)
        t2.status = .completed
        let t3 = Task(name: "Archived project task", project: archived)
        [t1, t2, t3].forEach { context.insert($0) }

        let vm = OverviewViewModel()
        vm.update(projects: [active, archived])

        #expect(vm.allActiveTasks.count == 1)
        #expect(vm.allActiveTasks[0].name == "Active task")
    }

    // MARK: - quickStartTasks

    @Test func quickStartTasks_emptyFilter_returnsUpToFiveRecentTasks() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)

        let tasks = (1...6).map { i -> Task in
            let t = Task(name: "Task \(i)", project: project)
            context.insert(t)
            let anchor = Date(timeIntervalSinceReferenceDate: Double(i) * 3600)
            let entry = TimeEntry(startDate: anchor, task: t)
            entry.endDate = anchor.addingTimeInterval(60)
            context.insert(entry)
            return t
        }
        _ = tasks

        let vm = OverviewViewModel()
        vm.update(projects: [project])

        #expect(vm.quickStartTasks.count == 5)
    }

    @Test func quickStartTasks_withFilter_returnsMatchingTasksSortedByName() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)
        let t1 = Task(name: "Alpha work", project: project)
        let t2 = Task(name: "Beta work", project: project)
        let t3 = Task(name: "Unrelated", project: project)
        [t1, t2, t3].forEach { context.insert($0) }

        let vm = OverviewViewModel()
        vm.update(projects: [project])
        vm.quickStartFilter = "work"

        #expect(vm.quickStartTasks.map(\.name) == ["Alpha work", "Beta work"])
    }

    @Test func quickStartTasks_emptyFilter_ordersByMostRecentEntryDescending() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)

        // Distinct latest-entry dates: "Newest" most recent, "Oldest" least.
        let newest = Task(name: "Newest", project: project)
        let middle = Task(name: "Middle", project: project)
        let oldest = Task(name: "Oldest", project: project)
        [newest, middle, oldest].forEach { context.insert($0) }

        func addEntry(to task: Task, ref: Double) {
            let entry = TimeEntry(startDate: Date(timeIntervalSinceReferenceDate: ref), task: task)
            entry.endDate = Date(timeIntervalSinceReferenceDate: ref + 60)
            context.insert(entry)
        }
        addEntry(to: oldest, ref: 1000)
        addEntry(to: middle, ref: 5000)
        addEntry(to: newest, ref: 9000)

        let vm = OverviewViewModel()
        vm.update(projects: [project])

        #expect(vm.quickStartTasks.map(\.name) == ["Newest", "Middle", "Oldest"])
    }

    @Test func quickStartTasks_neverTrackedTask_sortsLast() throws {
        let context = try makeContext()
        let project = Project(name: "P")
        context.insert(project)

        let tracked = Task(name: "Tracked", project: project)
        let neverTracked = Task(name: "NeverTracked", project: project)
        [tracked, neverTracked].forEach { context.insert($0) }

        let entry = TimeEntry(startDate: Date(timeIntervalSinceReferenceDate: 1000), task: tracked)
        entry.endDate = Date(timeIntervalSinceReferenceDate: 1060)
        context.insert(entry)

        let vm = OverviewViewModel()
        vm.update(projects: [project])

        // The never-tracked task (distantPast) must sort after the tracked one.
        let names = vm.quickStartTasks.map(\.name)
        #expect(names == ["Tracked", "NeverTracked"])
    }
}
