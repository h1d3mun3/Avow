import SwiftUI
import SwiftData

struct DailyTimelineView: View {
    let date: Date

    @Query private var entries: [TimeEntry]

    init(date: Date) {
        self.date = date
        let (start, end) = DateWindows().dayBounds(for: date)
        _entries = Query(
            filter: #Predicate<TimeEntry> { entry in
                entry.startDate >= start && entry.startDate < end
            },
            sort: \.startDate
        )
    }

    private var totalDuration: TimeInterval {
        entries.totalDuration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryHeader
                .padding(20)

            Divider()

            if entries.isEmpty {
                ContentUnavailableView(
                    "No entries",
                    systemImage: "clock",
                    description: Text("No time was tracked on this day.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entries) { entry in
                            TimeEntryRow(entry: entry)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private var summaryHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date, format: .dateTime.weekday(.wide).month().day())
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(totalDuration.shortFormatted)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
        }
    }
}
