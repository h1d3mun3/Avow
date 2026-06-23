import SwiftUI
import SwiftData

/// The Alfred-style quick launcher hosted in the floating panel: type to filter, ↑/↓ to move,
/// Enter to start/stop the highlighted task, Esc to dismiss.
struct QuickPanelView: View {
    @Environment(AppState.self) private var appState

    @Query(sort: \Task.name)
    private var allTasks: [Task]

    @State private var viewModel = MenuBarViewModel()
    @State private var selectionIndex = 0

    /// Dismisses the panel.
    let onClose: () -> Void

    private var flatTasks: [Task] {
        viewModel.tasksByProject.flatMap(\.tasks)
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
                    onCancel: { onClose() }
                )
                .frame(height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if flatTasks.isEmpty {
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
                    ForEach(Array(flatTasks.enumerated()), id: \.element.id) { index, task in
                        row(task, index: index)
                            .id(task.id)
                    }
                }
            }
            .onChange(of: selectionIndex) { _, index in
                if flatTasks.indices.contains(index) {
                    proxy.scrollTo(flatTasks[index].id)
                }
            }
        }
    }

    private func row(_ task: Task, index: Int) -> some View {
        let active = isActive(task)
        return HStack(spacing: 10) {
            Image(systemName: active ? "play.fill" : "circle")
                .font(.caption)
                .foregroundStyle(active ? Color.accentColor : .secondary)
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
                    .foregroundStyle(Color.accentColor)
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

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(viewModel.filterText.isEmpty ? "No active tasks" : "No matches")
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
        selectionIndex = QuickPanelSelection.moved(from: selectionIndex, by: delta, count: flatTasks.count)
    }

    private func activateSelection() {
        guard flatTasks.indices.contains(selectionIndex) else { return }
        let task = flatTasks[selectionIndex]
        if isActive(task) {
            appState.stopTracking()
        } else {
            appState.switchTask(to: task)
        }
        onClose()
    }
}
