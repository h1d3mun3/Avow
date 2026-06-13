import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("SwiftDataTimeEntryRepository")
struct SwiftDataTimeEntryRepositoryTests {

    private func makeRepository() throws -> (SwiftDataTimeEntryRepository, ModelContext) {
        let schema = Schema([Project.self, Task.self, TimeEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return (SwiftDataTimeEntryRepository(context: context), context)
    }

    /// Inserts a Project -> Task -> TimeEntry chain and returns the entry.
    private func makeEntry(
        in context: ModelContext,
        startDate: Date = Date(timeIntervalSinceReferenceDate: 0)
    ) -> TimeEntry {
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)
        let entry = TimeEntry(startDate: startDate, task: task)
        context.insert(entry)
        return entry
    }

    @Test func update_changesStartDate() throws {
        let (repo, context) = try makeRepository()
        let entry = makeEntry(in: context, startDate: Date(timeIntervalSinceReferenceDate: 0))
        entry.endDate = Date(timeIntervalSinceReferenceDate: 3600)

        let newStart = Date(timeIntervalSinceReferenceDate: 1000)
        try repo.update(entry, start: newStart, end: entry.endDate)

        #expect(entry.startDate == newStart)
    }

    @Test func update_runningEntry_doesNotSetEnd() throws {
        let (repo, context) = try makeRepository()
        let entry = makeEntry(in: context)
        // A running entry has no end date.
        #expect(entry.endDate == nil)

        try repo.update(
            entry,
            start: entry.startDate,
            end: Date(timeIntervalSinceReferenceDate: 3600)
        )

        // The guard must keep a running entry running even when an end is passed.
        #expect(entry.endDate == nil)
    }

    @Test func update_stoppedEntry_setsEnd() throws {
        let (repo, context) = try makeRepository()
        let entry = makeEntry(in: context)
        entry.endDate = Date(timeIntervalSinceReferenceDate: 3600)

        let newEnd = Date(timeIntervalSinceReferenceDate: 7200)
        try repo.update(entry, start: entry.startDate, end: newEnd)

        #expect(entry.endDate == newEnd)
    }

    @Test func update_stoppedEntry_canResetToRunning() throws {
        let (repo, context) = try makeRepository()
        let entry = makeEntry(in: context)
        entry.endDate = Date(timeIntervalSinceReferenceDate: 3600)

        try repo.update(entry, start: entry.startDate, end: nil)

        #expect(entry.endDate == nil)
    }

    @Test func delete_removesEntry() throws {
        let (repo, context) = try makeRepository()
        let entry = makeEntry(in: context)
        try context.save()

        try repo.delete(entry)

        let remaining = try context.fetch(FetchDescriptor<TimeEntry>())
        #expect(remaining.isEmpty)
    }
}
