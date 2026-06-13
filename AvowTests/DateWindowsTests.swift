import Testing
import Foundation
@testable import Avow

@Suite("DateWindows")
struct DateWindowsTests {

    /// Deterministic calendar: Gregorian, UTC, week starts on Monday.
    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    // Wednesday 2024-01-17 13:45:00 UTC
    private var fixedDate: Date {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 17
        components.hour = 13
        components.minute = 45
        return makeCalendar().date(from: components)!
    }

    @Test func startOfToday_returnsMidnightOfNow() {
        let cal = makeCalendar()
        let windows = DateWindows(calendar: cal, now: { self.fixedDate })

        // 2024-01-17 00:00:00 UTC
        var expected = DateComponents()
        expected.year = 2024
        expected.month = 1
        expected.day = 17
        #expect(windows.startOfToday() == cal.date(from: expected)!)
    }

    @Test func startOfWeek_returnsMondayOfNow() {
        let cal = makeCalendar()
        let windows = DateWindows(calendar: cal, now: { self.fixedDate })

        // Week starts Monday 2024-01-15 00:00:00 UTC
        var expected = DateComponents()
        expected.year = 2024
        expected.month = 1
        expected.day = 15
        #expect(windows.startOfWeek() == cal.date(from: expected)!)
    }

    @Test func dayBounds_endIsStartPlusOneDay() {
        let cal = makeCalendar()
        let windows = DateWindows(calendar: cal, now: { self.fixedDate })

        let bounds = windows.dayBounds(for: fixedDate)

        var expectedStart = DateComponents()
        expectedStart.year = 2024
        expectedStart.month = 1
        expectedStart.day = 17
        #expect(bounds.start == cal.date(from: expectedStart)!)
        #expect(bounds.end == bounds.start.addingTimeInterval(86400))
    }
}
