import Foundation

/// Builds the month grid for a given month, using the supplied calendar.
///
/// Normalises `month` to its month start, prepends leading-blank cells so the
/// first day lands on the correct weekday column, appends one concrete `Date`
/// per day, and pads with `nil` until the cell count is a multiple of 7.
/// Returns `[]` if the month-start or day range can't be computed.
func monthDays(for month: Date, calendar: Calendar) -> [Date?] {
    guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
          let range = calendar.range(of: .day, in: .month, for: monthStart)
    else { return [] }

    let firstWeekday = calendar.component(.weekday, from: monthStart)
    let offset = (firstWeekday - calendar.firstWeekday + 7) % 7

    var days: [Date?] = Array(repeating: nil, count: offset)
    for i in 0..<range.count {
        days.append(calendar.date(byAdding: .day, value: i, to: monthStart))
    }
    while days.count % 7 != 0 { days.append(nil) }
    return days
}

/// Weekday header symbols rotated to start on the calendar's first weekday.
func weekdaySymbols(calendar: Calendar) -> [String] {
    let symbols = calendar.veryShortWeekdaySymbols
    let first = calendar.firstWeekday - 1
    return Array(symbols[first...] + symbols[..<first])
}

/// The set of day starts that have at least one entry, using the supplied calendar.
func entriesByDay(_ entries: [TimeEntry], calendar: Calendar) -> Set<Date> {
    Set(entries.map { calendar.startOfDay(for: $0.startDate) })
}
