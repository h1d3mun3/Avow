import SwiftUI
import SwiftData

/// The Alfred-style quick launcher hosted in the floating panel: type to filter, ↑/↓ to move,
/// Enter to start/stop the highlighted task, Esc to dismiss. Text that matches no task can be
/// turned into a new one: Enter on the trailing "Create" row adds it to the project of the last
/// tracked task. `name @project #facet +group` picks the project, facets and groups explicitly
/// (Tab completes the one being typed; anything that doesn't exist yet is created). Either way
/// the new task starts tracking right away.
struct QuickPanelView: View {
    @Environment(AppState.self) private var appState
    @Environment(Repositories.self) private var repositories

    @Query(sort: \Task.name)
    private var allTasks: [Task]

    @Query(sort: \Project.sortOrder)
    private var allProjects: [Project]

    @Query(sort: \Facet.name)
    private var allFacets: [Facet]

    @Query(sort: \ProjectGroup.name)
    private var allGroups: [ProjectGroup]

    /// Only the most recent entry is needed — its task's project is where a new task goes by default.
    @Query private var latestEntries: [TimeEntry]

    @State private var viewModel = MenuBarViewModel()
    @State private var selectionIndex = 0

    /// Dismisses the panel.
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        var latest = FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        latest.fetchLimit = 1
        _latestEntries = Query(latest)
    }

    /// One selectable line in the list: an existing task to start, or a task to create and start.
    private enum Row: Identifiable {
        case task(Task)
        case create(NewTaskPlan)

        var id: String {
            switch self {
            case .task(let task): task.id.uuidString
            case .create(let plan): "create-\(plan.id)"
            }
        }
    }

    private var query: QuickPanelQuery { QuickPanelQuery(viewModel.filterText) }

    private var flatTasks: [Task] {
        viewModel.tasksByProject.flatMap(\.tasks)
    }

    private var unarchivedProjects: [Project] {
        allProjects.filter { !$0.isArchived }
    }

    /// Where a task created without `@project` goes: the project of the most recently tracked
    /// task, falling back to the first project when that one is gone or archived.
    private var defaultProject: Project? {
        NewTaskTarget.defaultProject(lastTracked: latestEntries.first?.task?.project, in: unarchivedProjects)
    }

    /// One plan per suggestion for the segment being typed (see `NewTaskPlan.plans`).
    private var plans: [NewTaskPlan] {
        NewTaskPlan.plans(
            for: query,
            context: NewTaskPlan.Context(
                projects: unarchivedProjects,
                facets: allFacets,
                groups: allGroups,
                defaultProject: defaultProject
            )
        )
    }

    private var rows: [Row] {
        // Once a sigil is typed the user is composing a new task, so only create rows are shown.
        if !query.segments.isEmpty {
            return plans.map(Row.create)
        }
        var result = flatTasks.map(Row.task)
        if !query.taskText.isEmpty,
           !flatTasks.contains(where: { query.isSameTaskName($0.name) }) {
            result += plans.map(Row.create)
        }
        return result
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            if let entry = appState.activeEntry {
                NowPlayingView(entry: entry)
                Divider()
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                LauncherSearchField(
                    text: $viewModel.filterText,
                    onMoveUp: { moveSelection(-1) },
                    onMoveDown: { moveSelection(1) },
                    onSubmit: { activateSelection() },
                    onTab: { completeSelection() },
                    onCancel: { onClose() }
                )
                .frame(height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if rows.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .frame(width: 600, height: 380)
        .background(.regularMaterial)
        .onAppear {
            viewModel.update(tasks: allTasks)
            viewModel.filterText = ""
            selectionIndex = 0
            // Note: the panel only reads activeEntry; launch recovery stays at app launch.
        }
        .onChange(of: allTasks, initial: true) { _, new in
            viewModel.update(tasks: new)
        }
        .onChange(of: viewModel.filterText) { _, _ in
            selectionIndex = 0
        }
    }

    // MARK: - Subviews

    private var taskList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                        Group {
                            switch item {
                            case .task(let task): row(task, index: index)
                            case .create(let plan): createRow(title: plan.title, location: plan.summary, index: index)
                            }
                        }
                        .id(item.id)
                    }
                }
            }
            .onChange(of: selectionIndex) { _, index in
                if rows.indices.contains(index) {
                    proxy.scrollTo(rows[index].id)
                }
            }
        }
    }

    private func row(_ task: Task, index: Int) -> some View {
        let active = isActive(task)
        return HStack(spacing: 10) {
            Image(systemName: active ? "play.fill" : "circle")
                .font(.caption)
                .foregroundStyle(active ? Color.now : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.name)
                    .lineLimit(1)
                if let project = task.project?.name {
                    Text(project)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if active {
                Text("Tracking")
                    .font(.caption)
                    .foregroundStyle(Color.now)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(index == selectionIndex ? Color.accentColor.opacity(0.18) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectionIndex = index
            activateSelection()
        }
    }

    private func createRow(title: String, location: String, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .lineLimit(1)
                if !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(index == selectionIndex ? Color.accentColor.opacity(0.18) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectionIndex = index
            activateSelection()
        }
    }

    private var emptyStateTitle: String {
        if !query.segments.isEmpty {
            return query.taskText.isEmpty ? "Type a task name first, or @NewProject to create a project" : "Nothing to suggest here"
        }
        return viewModel.filterText.isEmpty ? "No active tasks" : "No matches"
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(emptyStateTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if viewModel.filterText.isEmpty {
                Text("Open Dashboard to create projects and tasks.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func isActive(_ task: Task) -> Bool {
        appState.activeEntry?.task?.id == task.id
    }

    private func moveSelection(_ delta: Int) {
        selectionIndex = QuickPanelSelection.moved(from: selectionIndex, by: delta, count: rows.count)
    }

    /// Tab: write the highlighted suggestion over the `@project` / `#facet` / `+group` being typed.
    private func completeSelection() {
        guard rows.indices.contains(selectionIndex),
              case .create(let plan) = rows[selectionIndex],
              let name = plan.completion else { return }
        viewModel.filterText = query.completed(with: name)
    }

    private func activateSelection() {
        guard rows.indices.contains(selectionIndex) else { return }
        switch rows[selectionIndex] {
        case .task(let task):
            if isActive(task) {
                appState.stopTracking()
            } else {
                appState.switchTask(to: task)
            }
        case .create(let plan):
            do {
                // A project-only plan (`@Foo`) has no task to track.
                if let task = try plan.perform(using: repositories).task {
                    appState.switchTask(to: task)
                }
            } catch {
                // The panel has no alert surface; beep and stay open so the typed text isn't lost.
                NSSound.beep()
                return
            }
        }
        onClose()
    }
}
