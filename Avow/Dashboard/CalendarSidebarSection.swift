import SwiftUI
import SwiftData

struct CalendarSidebarSection: View {
    let selectedDate: Date?
    let onSelectDate: (Date) -> Void

    @Query private var allEntries: [TimeEntry]

    @State private var displayMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: .now))!
    }()

    private let calendar = Calendar.current

    private var activeDates: Set<Date> {
        entriesByDay(allEntries, calendar: calendar)
    }

    private var monthDays: [Date?] {
        Avow.monthDays(for: displayMonth, calendar: calendar)
    }

    private var shortWeekdaySymbols: [String] {
        weekdaySymbols(calendar: calendar)
    }

    var body: some View {
        VStack(spacing: 4) {
            monthHeader
            weekdayRow
            dayGrid
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 0) {
            Button {
                displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption2)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(displayMonth, format: .dateTime.year().month())
                .font(.caption)
                .fontWeight(.medium)

            Spacer()

            Button {
                displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
            spacing: 2
        ) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                if let date {
                    let startOfDay = calendar.startOfDay(for: date)
                    let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                    CalendarDayCell(
                        day: calendar.component(.day, from: date),
                        isSelected: isSelected,
                        isToday: calendar.isDateInToday(date),
                        hasEntries: activeDates.contains(startOfDay),
                        action: { onSelectDate(startOfDay) }
                    )
                } else {
                    Color.clear.frame(height: 26)
                }
            }
        }
    }
}

private struct CalendarDayCell: View {
    let day: Int
    let isSelected: Bool
    let isToday: Bool
    let hasEntries: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text("\(day)")
                    .font(.system(size: 11))
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .white : isToday ? Color.accentColor : .primary)
                    .frame(width: 22, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isSelected ? Color.accentColor : Color.clear)
                    )
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.8) : Color.accentColor)
                    .frame(width: 3, height: 3)
                    .opacity(hasEntries ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
