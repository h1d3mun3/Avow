import SwiftUI
import SwiftData

struct OverviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

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

    private var projectsWithActiveTasks: [(project: Project, tasks: [Task])] {
        projects
            .filter { !$0.isArchived }
            .compactMap { project in
                let active = project.tasks
                    .filter { $0.status == .active }
                    .sorted { $0.name < $1.name }
                return active.isEmpty ? nil : (project, active)
            }
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

                // Quick start
                if !projectsWithActiveTasks.isEmpty {
                    Text("Quick start")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ForEach(projectsWithActiveTasks, id: \.project.id) { project, tasks in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 4)

                            ForEach(tasks) { task in
                                let isActive = appState.activeEntry?.task?.id == task.id
                                QuickStartRow(task: task, isActive: isActive) {
                                    if isActive {
                                        appState.stopTracking(context: modelContext)
                                    } else {
                                        appState.switchTask(to: task, context: modelContext)
                                    }
                                }
                            }
                        }
                    }
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
                        Text(project.name)
                            .font(.subheadline)
                        Spacer()
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)
                                .frame(width: geo.size.width)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(.secondary)
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

// MARK: - Quick start row

private struct QuickStartRow: View {
    let task: Task
    let isActive: Bool
    let action: () -> Void

    @Environment(AppState.self) private var appState

    private var todayDuration: TimeInterval {
        let start = Calendar.current.startOfDay(for: .now)
        return task.timeEntries
            .filter { $0.startDate >= start }
            .reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isActive ? "stop.circle.fill" : "play.circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))

                Text(task.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if isActive {
                    let _ = appState.tick
                    Text(appState.activeEntry?.duration.timerFormatted ?? "")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else if todayDuration > 0 {
                    Text(todayDuration.shortFormatted)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isActive
                    ? AnyShapeStyle(Color.accentColor.opacity(0.1))
                    : AnyShapeStyle(.quaternary.opacity(0.4)),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
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
