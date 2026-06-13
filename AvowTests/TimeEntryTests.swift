import Testing
import Foundation
@testable import Avow

@Suite("TimeEntry")
struct TimeEntryTests {

    private func makeTask() -> Task {
        Task(name: "T", project: Project(name: "P"))
    }

    @Test func isRunning_trueWhenEndDateNil() {
        let entry = TimeEntry(startDate: .now, task: makeTask())

        #expect(entry.isRunning == true)
    }

    @Test func isRunning_falseWhenEndDateSet() {
        let entry = TimeEntry(startDate: .now, task: makeTask())
        entry.endDate = .now

        #expect(entry.isRunning == false)
    }

    @Test func duration_finishedEntryReturnsEndMinusStart() {
        let entry = TimeEntry(
            startDate: Date(timeIntervalSinceReferenceDate: 0),
            task: makeTask()
        )
        entry.endDate = Date(timeIntervalSinceReferenceDate: 3600)

        #expect(entry.duration == 3600)
    }

    @Test func stop_setsEndDateAndStopsRunning() {
        let entry = TimeEntry(startDate: .now, task: makeTask())
        #expect(entry.endDate == nil)

        entry.stop()

        #expect(entry.endDate != nil)
        #expect(entry.isRunning == false)
    }
}
