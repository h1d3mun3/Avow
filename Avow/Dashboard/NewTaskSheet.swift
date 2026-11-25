import SwiftUI
import SwiftData

/// "New Task" (⌘N), driven entirely from the keyboard like the quick panel: type a task name,
/// optionally followed by `@project` to choose where it goes, ↑/↓ to pick among the matching
/// projects, Return to create, Esc to cancel. An `@project` that matches nothing exactly offers to
/// create that project too. Reachable from any Dashboard page, not just a project.
struct NewTaskSheet: View {
    @Environment(Repositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Project.sortOrder)
    private var allProjects: [Project]

    /// Only the most recent entry is needed — its task's project is the fallback destination.
    @Query private var latestEntries: [TimeEntry]

    /// Where a task goes when no `@project` is typed, typically the project shown in the Dashboard.
    let preferredProject: Project?

    /// Called with the project the task landed in, so the Dashboard can show it.
    let onCreated: (Project) -> Void

    @State private var text = ""
    @State private var selectionIndex = 0
    @State private var errorMessage: String?

    init(preferredProject: Project?, onCreated: @escaping (Project) -> Void) {
        self.preferredProject = preferredProject
        self.onCreated = onCreated
        var latest = FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        latest.fetchLimit = 1
        _latestEntries = Query(latest)
    }

    private var query: QuickPanelQuery { QuickPanelQuery(text) }

    private var projects: [Project] { allProjects.filter { !$0.isArchived } }

    private var targets: [NewTaskTarget] {
        let fallback = preferredProject ?? latestEntries.first?.task?.project
        return NewTaskTarget.targets(
            for: query,
            in: projects,
            defaultProject: NewTaskTarget.defaultProject(lastTracked: fallback, in: projects)
        )
    }

    private var hint: String? {
        if targets.isEmpty {
            return query.hasProjectClause ? "Type a project name after @" : "No projects yet — type a name, then @ and a new project name"
        }
        return query.taskText.isEmpty ? "Type a task name" : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.tertiary)
                LauncherSearchField(
                    text: $text,
                    placeholder: "Task name  @project",
                    onMoveUp: { moveSelection(-1) },
                    onMoveDown: { moveSelection(1) },
                    onSubmit: { create() },
                    onCancel: { dismiss() }
                )
                .frame(height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
                        row(target, index: index)
                    }
                    if let hint {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()

            Text("↩ Create   ↑↓ Choose project   @ Pick a project   esc Cancel")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 480, height: 300)
        .onChange(of: text) { _, _ in selectionIndex = 0 }
        .errorAlert($errorMessage)
    }

    private func row(_ target: NewTaskTarget, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(query.taskText.isEmpty ? "New task" : "Create \"\(query.taskText)\"")
                    .lineLimit(1)
                Text(target.locationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
            create()
        }
    }

    private func moveSelection(_ delta: Int) {
        selectionIndex = QuickPanelSelection.moved(from: selectionIndex, by: delta, count: targets.count)
    }

    private func create() {
        let targets = targets
        guard !query.taskText.isEmpty, targets.indices.contains(selectionIndex) else {
            NSSound.beep()
            return
        }
        do {
            let task = try targets[selectionIndex].createTask(named: query.taskText, using: repositories)
            if let project = task.project { onCreated(project) }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
