import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("CalendarMonthGrid")
struct CalendarMonthGridTests {

    private func makeCalendar(firstWeekday: Int) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = firstWeekday
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - monthDays grid length

    @Test(arguments: [
        (2024, 1), (2024, 2), (2024, 4), (2024, 12),
        (2025, 2), (2025, 6), (2025, 11),
    ])
    func monthDays_lengthIsMultipleOfSeven_firstWeekdaySunday(year: Int, month: Int) {
        let cal = makeCalendar(firstWeekday: 1)
        let days = monthDays(for: date(year, month, 1, calendar: cal), calendar: cal)
        #expect(days.count % 7 == 0)
        #expect(!days.isEmpty)
    }

    @Test(arguments: [
        (2024, 1), (2024, 2), (2024, 4), (2024, 12),
        (2025, 2), (2025, 6), (2025, 11),
    ])
    func monthDays_lengthIsMultipleOfSeven_firstWeekdayMonday(year: Int, month: Int) {
        let cal = makeCalendar(firstWeekday: 2)
        let days = monthDays(for: date(year, month, 1, calendar: cal), calendar: cal)
        #expect(days.count % 7 == 0)
        #expect(!days.isEmpty)
    }

    // MARK: - leading-nil offset

    private func leadingNilCount(_ days: [Date?]) -> Int {
        days.prefix { $0 == nil }.count
    }

    // June 1, 2025 is a Sunday.
    @Test func monthDays_leadingNils_june2025_sundayStart() {
        let cal = makeCalendar(firstWeekday: 1)
        let days = monthDays(for: date(2025, 6, 1, calendar: cal), calendar: cal)
        // First day (Sunday) lands in the first column → no leading blanks.
        #expect(leadingNilCount(days) == 0)
    }

    @Test func monthDays_leadingNils_june2025_mondayStart() {
        let cal = makeCalendar(firstWeekday: 2)
        let days = monthDays(for: date(2025, 6, 1, calendar: cal), calendar: cal)
        // With Monday as the first column, a Sunday 1st lands in the last column → 6 blanks.
        #expect(leadingNilCount(days) == 6)
    }

    // February 1, 2025 is a Saturday.
    @Test func monthDays_leadingNils_february2025_sundayStart() {
        let cal = makeCalendar(firstWeekday: 1)
        let days = monthDays(for: date(2025, 2, 1, calendar: cal), calendar: cal)
        // Saturday is the seventh column when the week starts on Sunday → 6 blanks.
        #expect(leadingNilCount(days) == 6)
    }

    @Test func monthDays_leadingNils_february2025_mondayStart() {
        let cal = makeCalendar(firstWeekday: 2)
        let days = monthDays(for: date(2025, 2, 1, calendar: cal), calendar: cal)
        // Saturday is the sixth column when the week starts on Monday → 5 blanks.
        #expect(leadingNilCount(days) == 5)
    }

    // MARK: - day-cell counts (leap year)

    @Test func monthDays_february2024_has29DayCells() {
        let cal = makeCalendar(firstWeekday: 1)
        let days = monthDays(for: date(2024, 2, 1, calendar: cal), calendar: cal)
        #expect(days.compactMap { $0 }.count == 29)
    }

    @Test func monthDays_february2025_has28DayCells() {
        let cal = makeCalendar(firstWeekday: 1)
        let days = monthDays(for: date(2025, 2, 1, calendar: cal), calendar: cal)
        #expect(days.compactMap { $0 }.count == 28)
    }

    @Test func monthDays_normalisesAnyDayInMonthToMonthStart() {
        let cal = makeCalendar(firstWeekday: 1)
        let fromFirst = monthDays(for: date(2025, 6, 1, calendar: cal), calendar: cal)
        let fromMidMonth = monthDays(for: date(2025, 6, 17, calendar: cal), calendar: cal)
        #expect(fromFirst == fromMidMonth)
    }

    // MARK: - weekdaySymbols rotation

    @Test func weekdaySymbols_rotationDiffersBetweenSundayAndMondayStart() {
        let sunday = weekdaySymbols(calendar: makeCalendar(firstWeekday: 1))
        let monday = weekdaySymbols(calendar: makeCalendar(firstWeekday: 2))
        #expect(sunday.count == 7)
        #expect(monday.count == 7)
        // First column symbol changes when the first weekday changes.
        #expect(sunday.first != monday.first)
        // Monday-start begins with the symbol that sat in the second column of a Sunday-start week.
        #expect(monday.first == sunday[1])
    }

    // MARK: - entriesByDay

    @Test func entriesByDay_collapsesEntriesToStartOfDay() throws {
        let cal = makeCalendar(firstWeekday: 1)
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let task = Task(name: "T", project: project)
        context.insert(task)

        // Two entries on the same calendar day at different times.
        let morning = TimeEntry(startDate: date(2025, 6, 10, calendar: cal).addingTimeInterval(3600), task: task)
        let evening = TimeEntry(startDate: date(2025, 6, 10, calendar: cal).addingTimeInterval(72_000), task: task)
        // One entry on a different day.
        let nextDay = TimeEntry(startDate: date(2025, 6, 11, calendar: cal).addingTimeInterval(3600), task: task)
        [morning, evening, nextDay].forEach { context.insert($0) }

        let days = entriesByDay([morning, evening, nextDay], calendar: cal)
        #expect(days.count == 2)
        #expect(days.contains(date(2025, 6, 10, calendar: cal)))
        #expect(days.contains(date(2025, 6, 11, calendar: cal)))
    }

    @Test func entriesByDay_emptyIsEmpty() {
        let cal = makeCalendar(firstWeekday: 1)
        #expect(entriesByDay([], calendar: cal).isEmpty)
    }
}
