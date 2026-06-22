import SwiftUI
import SwiftData

struct CalendarView: View {
    @State private var selectedDate: Date? = Calendar.current.startOfDay(for: .now)

    var body: some View {
        HSplitView {
            calendarPanel
            if let date = selectedDate {
                DailyTimelineView(date: date)
                    .frame(minWidth: 320)
            }
        }
        .navigationTitle("Calendar")
    }

    private var calendarPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CalendarSidebarSection(
                    selectedDate: selectedDate,
                    onSelectDate: { selectedDate = $0 }
                )

                if let date = selectedDate {
                    DayProjectBreakdown(date: date)
                    DayFacetBreakdown(date: date)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 360)
    }
}

// MARK: - Project breakdown for a single day

private struct DayProjectBreakdown: View {
    let date: Date

    @Query private var entries: [TimeEntry]

    init(date: Date) {
        self.date = date
        let (start, end) = DateWindows().dayBounds(for: date)
        _entries = Query(filter: #Predicate<TimeEntry> { entry in
            entry.startDate >= start && entry.startDate < end
        })
    }

    var body: some View {
        if !entries.isEmpty {
            let breakdown = DayBreakdown(entries: entries)
            VStack(alignment: .leading, spacing: 10) {
                Text("By project")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                ForEach(breakdown.items, id: \.name) { item in
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)
                                .frame(width: geo.size.width)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(.secondary)
                                        .frame(width: geo.size.width * item.fraction)
                                }
                        }
                        .frame(width: 44, height: 5)
                        Text(item.duration.shortFormatted)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
    }
}

// MARK: - Facet breakdown for a single day

private struct DayFacetBreakdown: View {
    let date: Date

    @Query private var entries: [TimeEntry]

    init(date: Date) {
        self.date = date
        let (start, end) = DateWindows().dayBounds(for: date)
        _entries = Query(filter: #Predicate<TimeEntry> { entry in
            entry.startDate >= start && entry.startDate < end
        })
    }

    var body: some View {
        let breakdown = FacetBreakdown(entries: entries)
        // Absolute time only, sorted descending; unfaceted time and the whole
        // section are omitted when there is nothing to show.
        if !breakdown.items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("By facet")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                ForEach(breakdown.items, id: \.name) { item in
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(item.duration.shortFormatted)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
