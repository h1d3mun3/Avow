import SwiftUI
import SwiftData

struct OverviewView: View {
    @Query(sort: \Project.name)
    private var projects: [Project]

    @Query
    private var allEntries: [TimeEntry]

    private var totalDuration: TimeInterval {
        allEntries.reduce(0.0) { $0 + $1.duration }
    }

    private var thisWeekDuration: TimeInterval {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return allEntries
            .filter { $0.startDate >= startOfWeek }
            .reduce(0.0) { $0 + $1.duration }
    }

    private var todayDuration: TimeInterval {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allEntries
            .filter { $0.startDate >= startOfDay }
            .reduce(0.0) { $0 + $1.duration }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary cards
                HStack(spacing: 12) {
                    SummaryCard(
                        label: "Total tracked",
                        value: totalDuration.shortFormatted,
                        sub: "\(projects.count) projects"
                    )
                    SummaryCard(
                        label: "This week",
                        value: thisWeekDuration.shortFormatted,
                        sub: ""
                    )
                    SummaryCard(
                        label: "Today",
                        value: todayDuration.shortFormatted,
                        sub: ""
                    )
                }

                // Project breakdown
                Text("Time by project")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                ForEach(projects) { project in
                    let duration = project.tasks
                        .flatMap(\.timeEntries)
                        .reduce(0.0) { $0 + $1.duration }
                    let fraction = totalDuration > 0 ? duration / totalDuration : 0

                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: project.colorHex))
                            .frame(width: 8, height: 8)
                        Text(project.name)
                            .font(.subheadline)
                        Spacer()
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: project.colorHex).opacity(0.3))
                                .frame(width: geo.size.width)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: project.colorHex))
                                        .frame(width: geo.size.width * fraction)
                                }
                        }
                        .frame(width: 100, height: 6)
                        Text(duration.shortFormatted)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                        Text(String(format: "%.0f%%", fraction * 100))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                if projects.isEmpty {
                    ContentUnavailableView(
                        "No projects yet",
                        systemImage: "folder",
                        description: Text("Create a project to start tracking your time.")
                    )
                }
            }
            .padding(20)
        }
        .navigationTitle("Overview")
    }
}

// MARK: - Summary card

private struct SummaryCard: View {
    let label: String
    let value: String
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.medium)
                .monospacedDigit()
            if !sub.isEmpty {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
