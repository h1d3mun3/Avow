import Testing
import Foundation
import SwiftData
@testable import Avow

// MARK: - Fake repository

private enum FakeRepositoryError: Error { case forced }

final class FakeTimeEntryRepository: TimeEntryRepository {
    private(set) var startedTasks: [Task] = []
    private(set) var stoppedEntries: [TimeEntry] = []
    var running: TimeEntry?

    // Inject errors to exercise AppState's silent-failure handling.
    var startError: Error?
    var stopError: Error?
    var fetchError: Error?

    func start(task: Task) throws -> TimeEntry {
        if let startError { throw startError }
        let e = TimeEntry(task: task)
        startedTasks.append(task)
        return e
    }

    func add(task: Task, start: Date, end: Date) throws -> TimeEntry {
        let e = TimeEntry(startDate: start, task: task)
        e.endDate = end
        return e
    }

    func stop(_ entry: TimeEntry) throws {
        if let stopError { throw stopError }
        entry.stop()
        stoppedEntries.append(entry)
    }

    func fetchRunning() throws -> TimeEntry? {
        if let fetchError { throw fetchError }
        return running
    }

    func update(_ entry: TimeEntry, start: Date, end: Date?) throws {}

    func delete(_ entry: TimeEntry) throws {}
}

// MARK: - Tests

@Suite("AppState")
struct AppStateTests {

    @Test func tick_incrementsOnClockAdvance() throws {
        let clock = ManualClock()
        let appState = AppState(clock: clock, timeEntries: FakeTimeEntryRepository())

        let task = Task(name: "T", project: Project(name: "P"))

        appState.startTracking(task: task)
        let before = appState.tick

        clock.advance()
        clock.advance()

        #expect(appState.tick == before + 2)
    }

    @Test func startTracking_setsActiveEntry() throws {
        let appState = AppState(clock: ManualClock(), timeEntries: FakeTimeEntryRepository())

        let task = Task(name: "T", project: Project(name: "P"))

        appState.startTracking(task: task)

        #expect(appState.activeEntry != nil)
        #expect(appState.isTracking == true)
    }

    @Test func stopTracking_clearsActiveEntry() throws {
        let clock = ManualClock()
        let appState = AppState(clock: clock, timeEntries: FakeTimeEntryRepository())

        let task = Task(name: "T", project: Project(name: "P"))

        appState.startTracking(task: task)
        appState.stopTracking()

        #expect(appState.activeEntry == nil)
        #expect(appState.isTracking == false)
    }

    @Test func stopTracking_cancelsTimer() throws {
        let clock = ManualClock()
        let appState = AppState(clock: clock, timeEntries: FakeTimeEntryRepository())

        let task = Task(name: "T", project: Project(name: "P"))

        appState.startTracking(task: task)
        appState.stopTracking()

        let tickBefore = appState.tick
        clock.advance()

        #expect(appState.tick == tickBefore)
    }

    @Test func switchTask_stopsCurrentAndStartsNew() throws {
        let appState = AppState(clock: ManualClock(), timeEntries: FakeTimeEntryRepository())

        let project = Project(name: "P")
        let t1 = Task(name: "T1", project: project)
        let t2 = Task(name: "T2", project: project)

        appState.startTracking(task: t1)
        let firstEntry = appState.activeEntry

        appState.switchTask(to: t2)

        #expect(firstEntry?.endDate != nil)
        #expect(appState.activeEntry?.task?.id == t2.id)
    }

    // MARK: - restoreActiveEntry

    @Test func restoreActiveEntry_noOpenEntry_leavesNil() throws {
        let clock = ManualClock()
        let fake = FakeTimeEntryRepository()
        fake.running = nil
        let appState = AppState(clock: clock, timeEntries: fake)

        appState.restoreActiveEntry()

        #expect(appState.activeEntry == nil)

        // No timer was scheduled, so advancing the clock must not change tick.
        let tickBefore = appState.tick
        clock.advance()
        #expect(appState.tick == tickBefore)
    }

    @Test func restoreActiveEntry_withRunningEntry_adoptsItAndTicks() throws {
        let clock = ManualClock()
        let fake = FakeTimeEntryRepository()
        let task = Task(name: "T", project: Project(name: "P"))
        let running = TimeEntry(task: task)
        fake.running = running
        let appState = AppState(clock: clock, timeEntries: fake)

        appState.restoreActiveEntry()

        #expect(appState.activeEntry != nil)
        #expect(appState.activeEntry?.id == running.id)

        let tickBefore = appState.tick
        clock.advance()
        #expect(appState.tick == tickBefore + 1)
    }

    // MARK: - Silent failure (repository errors are swallowed)

    @Test func startTracking_whenStartThrows_leavesNoActiveEntry() throws {
        let fake = FakeTimeEntryRepository()
        fake.startError = FakeRepositoryError.forced
        let appState = AppState(clock: ManualClock(), timeEntries: fake)

        appState.startTracking(task: Task(name: "T", project: Project(name: "P")))

        #expect(appState.activeEntry == nil)
        #expect(appState.isTracking == false)
    }

    @Test func stopTracking_whenStopThrows_stillClearsActiveEntry() throws {
        let fake = FakeTimeEntryRepository()
        let appState = AppState(clock: ManualClock(), timeEntries: fake)
        appState.startTracking(task: Task(name: "T", project: Project(name: "P")))
        #expect(appState.activeEntry != nil)

        fake.stopError = FakeRepositoryError.forced
        appState.stopTracking()

        // A stop failure must not strand the UI in a "tracking" state.
        #expect(appState.activeEntry == nil)
        #expect(appState.isTracking == false)
    }

    @Test func restoreActiveEntry_whenFetchThrows_leavesNil() throws {
        let clock = ManualClock()
        let fake = FakeTimeEntryRepository()
        fake.fetchError = FakeRepositoryError.forced
        let appState = AppState(clock: clock, timeEntries: fake)

        appState.restoreActiveEntry()

        #expect(appState.activeEntry == nil)
        let tickBefore = appState.tick
        clock.advance()
        #expect(appState.tick == tickBefore)
    }
}
