import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \Task.name)
    private var allTasks: [Task]

    @State private var viewModel = MenuBarViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            if let entry = appState.activeEntry {
                NowPlayingView(entry: entry)
            }

            SearchField(text: $viewModel.filterText)

            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.tasksByProject.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.tasksByProject, id: \.project.id) { project, tasks in
                            ProjectSection(
                                project: project,
                                tasks: tasks,
                                activeEntry: appState.activeEntry
                            )
                        }
                    }
                }
            }
            .frame(height: 320)

            Divider()

            footer
        }
        .frame(width: 280)
        .onChange(of: allTasks, initial: true) { _, new in
            viewModel.update(tasks: new)
        }
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
                if let window = NSApp.windows.first(where: { $0.title == WindowID.dashboardTitle }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    openWindow(id: WindowID.dashboard)
                }
                NSApp.activate()
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
        let total = todayEntries.totalDuration
        Text("Today: \(total.timerFormatted)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}
