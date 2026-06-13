import SwiftUI
import SwiftData

struct OverviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Project.name)
    private var projects: [Project]

    @Query
    private var allEntries: [TimeEntry]

    @State private var quickStartFilter = ""

    private var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }

    private var activeEntries: [TimeEntry] {
        activeProjects.flatMap { $0.tasks }.flatMap { $0.timeEntries }
    }

    private var totalDuration: TimeInterval {
        activeEntries.reduce(0.0) { $0 + $1.duration }
    }

    private var thisWeekDuration: TimeInterval {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return activeEntries
            .filter { $0.startDate >= startOfWeek }
            .reduce(0.0) { $0 + $1.duration }
    }

    private var todayDuration: TimeInterval {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return activeEntries
            .filter { $0.startDate >= startOfDay }
            .reduce(0.0) { $0 + $1.duration }
    }

    private var allActiveTasks: [Task] {
        projects
            .filter { !$0.isArchived }
            .flatMap { $0.tasks }
            .filter { $0.status == .active }
    }

    // Default: up to 5 tasks sorted by most recently tracked
    private var recentTasks: [Task] {
        Array(
            allActiveTasks
                .sorted { a, b in
                    let aDate = a.timeEntries.map(\.startDate).max() ?? .distantPast
                    let bDate = b.timeEntries.map(\.startDate).max() ?? .distantPast
                    return aDate > bDate
                }
                .prefix(5)
        )
    }

    // Search: all active tasks matching the query
    private var searchResults: [Task] {
        allActiveTasks
            .filter { $0.name.localizedCaseInsensitiveContains(quickStartFilter) }
            .sorted { $0.name < $1.name }
    }

    private var quickStartTasks: [Task] {
        quickStartFilter.isEmpty ? recentTasks : searchResults
    }

    var body: some View {
        if activeProjects.isEmpty {
            ContentUnavailableView(
                "No projects yet",
                systemImage: "folder",
                description: Text("Create a project to start tracking your time.")
            )
            .navigationTitle("Overview")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary cards
                    HStack(spacing: 12) {
                        SummaryCard(
                            label: "Total tracked",
                            value: totalDuration.shortFormatted,
                            sub: "\(activeProjects.count) projects"
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
                    if !allActiveTasks.isEmpty {
                        Text("Quick start")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        QuickStartSearchField(text: $quickStartFilter)

                        if quickStartTasks.isEmpty {
                            Text("No tasks found")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 4)
                        } else {
                            ForEach(quickStartTasks) { task in
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

                    // Project breakdown
                    Text("Time by project")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ForEach(activeProjects) { project in
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
                }
                .padding(20)
            }
            .navigationTitle("Overview")
        }
    }
}

// MARK: - Quick start search field

private struct QuickStartSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.tertiary)
            TextField("Search tasks…", text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
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

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let projectName = task.project?.name {
                        Text(projectName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

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
