import Foundation

struct DateWindows {
    var calendar: Calendar = .current
    var now: () -> Date = { Date.now }

    func startOfToday() -> Date { calendar.startOfDay(for: now()) }
    func startOfWeek() -> Date { calendar.dateInterval(of: .weekOfYear, for: now())?.start ?? now() }
    func dayBounds(for date: Date) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }
}
