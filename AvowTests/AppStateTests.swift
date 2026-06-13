import Testing
import Foundation
import SwiftData
@testable import Avow

// MARK: - Mock

final class ManualClock: AppClock {
    private(set) var scheduledAction: (() -> Void)?

    func scheduleRepeating(interval: TimeInterval, action: @escaping () -> Void) -> ClockToken {
        scheduledAction = action
        return ClockToken { [weak self] in self?.scheduledAction = nil }
    }

    func advance() {
        scheduledAction?()
    }
}

// MARK: - Tests

@Suite("AppState")
struct AppStateTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Project.self, Task.self, TimeEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func tick_incrementsOnClockAdvance() throws {
        let context = try makeContext()
        let clock = ManualClock()
        let appState = AppState(clock: clock)

        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        appState.startTracking(task: task, context: context)
        let before = appState.tick

        clock.advance()
        clock.advance()

        #expect(appState.tick == before + 2)
    }

    @Test func startTracking_setsActiveEntry() throws {
        let context = try makeContext()
        let appState = AppState(clock: ManualClock())

        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        appState.startTracking(task: task, context: context)

        #expect(appState.activeEntry != nil)
        #expect(appState.isTracking == true)
    }

    @Test func stopTracking_clearsActiveEntry() throws {
        let context = try makeContext()
        let clock = ManualClock()
        let appState = AppState(clock: clock)

        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        appState.startTracking(task: task, context: context)
        appState.stopTracking(context: context)

        #expect(appState.activeEntry == nil)
        #expect(appState.isTracking == false)
    }

    @Test func stopTracking_cancelsTimer() throws {
        let context = try makeContext()
        let clock = ManualClock()
        let appState = AppState(clock: clock)

        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        appState.startTracking(task: task, context: context)
        appState.stopTracking(context: context)

        let tickBefore = appState.tick
        clock.advance()

        #expect(appState.tick == tickBefore)
    }

    @Test func switchTask_stopsCurrentAndStartsNew() throws {
        let context = try makeContext()
        let appState = AppState(clock: ManualClock())

        let project = Project(name: "P")
        context.insert(project)
        let t1 = Task(name: "T1", project: project)
        let t2 = Task(name: "T2", project: project)
        [t1, t2].forEach { context.insert($0) }

        appState.startTracking(task: t1, context: context)
        let firstEntry = appState.activeEntry

        appState.switchTask(to: t2, context: context)

        #expect(firstEntry?.endDate != nil)
        #expect(appState.activeEntry?.task?.id == t2.id)
    }
}
