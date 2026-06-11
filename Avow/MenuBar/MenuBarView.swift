import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \Task.name)
    private var allTasks: [Task]

    private var activeTasks: [Task] {
        allTasks.filter { $0.status == .active }
    }

    @State private var filterText = ""

    private var filteredTasks: [Task] {
        if filterText.isEmpty {
            return activeTasks
        }
        return activeTasks.filter {
            $0.name.localizedCaseInsensitiveContains(filterText)
        }
    }

    private var tasksByProject: [(project: Project, tasks: [Task])] {
        let grouped = Dictionary(grouping: filteredTasks) { $0.project }
        return grouped
            .compactMap { project, tasks -> (Project, [Task])? in
                guard let project else { return nil }
                return (project, tasks.sorted { $0.name < $1.name })
            }
            .sorted { $0.0.name < $1.0.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let entry = appState.activeEntry {
                NowPlayingView(entry: entry)
            }

            SearchField(text: $filterText)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if tasksByProject.isEmpty {
                        emptyState
                    } else {
                        ForEach(tasksByProject, id: \.project.id) { project, tasks in
                            ProjectSection(
                                project: project,
                                tasks: tasks,
                                activeEntry: appState.activeEntry
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 320)

            Divider()

            footer
        }
        .frame(width: 280)
        .onAppear {
            appState.restoreActiveEntry(context: modelContext)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No active tasks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Open Dashboard to create projects and tasks.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .padding(.horizontal)
    }

    private var footer: some View {
        HStack {
            TodayTotalLabel()
            Spacer()
            Button {
                openWindow(id: "dashboard")
            } label: {
                Label("Dashboard", systemImage: "square.grid.2x2")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Search field

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.tertiary)
            TextField("Filter tasks…", text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Project section

private struct ProjectSection: View {
    let project: Project
    let tasks: [Task]
    let activeEntry: TimeEntry?

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 7, height: 7)
                Text(project.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)

            ForEach(tasks) { task in
                TaskRowView(
                    task: task,
                    isActive: activeEntry?.task?.id == task.id
                ) {
                    if activeEntry?.task?.id == task.id {
                        appState.stopTracking(context: modelContext)
                    } else {
                        appState.switchTask(to: task, context: modelContext)
                    }
                }
            }
        }
    }
}

// MARK: - Today's total

private struct TodayTotalLabel: View {
    @Query private var todayEntries: [TimeEntry]

    init() {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        _todayEntries = Query(
            filter: #Predicate<TimeEntry> { $0.startDate >= startOfDay }
        )
    }

    var body: some View {
        let total = todayEntries.reduce(0.0) { $0 + $1.duration }
        Text("Today: \(total.timerFormatted)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}
