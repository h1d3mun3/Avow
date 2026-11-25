import SwiftUI
import SwiftData

/// "New Task or Project…" (⌘N), driven entirely from the keyboard like the quick panel. Type a
/// task name, optionally followed by `@project`, `#facet` and `+group` (each can be repeated for
/// facets and groups; names may contain spaces). ↑/↓ chooses among the suggestions for the part
/// being typed, Tab completes it, Return creates, Esc cancels. Anything named that doesn't exist
/// yet is created. With no task name, `@Foo` creates just a project and `@Foo +Group` also files it
/// in a group. Reachable from any Dashboard page, not just a project.
struct NewTaskSheet: View {
    @Environment(Repositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Project.sortOrder)
    private var allProjects: [Project]

    @Query(sort: \Facet.name)
    private var allFacets: [Facet]

    @Query(sort: \ProjectGroup.name)
    private var allGroups: [ProjectGroup]

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

    private var plans: [NewTaskPlan] {
        let fallback = preferredProject ?? latestEntries.first?.task?.project
        return NewTaskPlan.plans(
            for: query,
            context: NewTaskPlan.Context(
                projects: projects,
                facets: allFacets,
                groups: allGroups,
                defaultProject: NewTaskTarget.defaultProject(lastTracked: fallback, in: projects)
            )
        )
    }

    private var hint: String? {
        guard plans.isEmpty else { return nil }
        if query.taskText.isEmpty {
            return query.segments.isEmpty
                ? "Type a task name — or @NewProject to create a project"
                : "Type a task name first, or @NewProject to create a project"
        }
        if projects.isEmpty && query.projectText == nil {
            return "No projects yet — add @ and a new project name"
        }
        return "Nothing to suggest here"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.tertiary)
                LauncherSearchField(
                    text: $text,
                    placeholder: "Task name  @project  #facet  +group",
                    onMoveUp: { moveSelection(-1) },
                    onMoveDown: { moveSelection(1) },
                    onSubmit: { create() },
                    onTab: { completeSelection() },
                    onCancel: { dismiss() }
                )
                .frame(height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                        row(plan, index: index)
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

            Text("↩ Create   ⇥ Complete   ↑↓ Choose   @project  #facet  +group   esc Cancel")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 520, height: 300)
        .onChange(of: text) { _, _ in selectionIndex = 0 }
        .errorAlert($errorMessage)
    }

    private func row(_ plan: NewTaskPlan, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(plan.title)
                    .lineLimit(1)
                if !plan.summary.isEmpty {
                    Text(plan.summary)
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
            create()
        }
    }

    private func moveSelection(_ delta: Int) {
        selectionIndex = QuickPanelSelection.moved(from: selectionIndex, by: delta, count: plans.count)
    }

    /// Tab: write the highlighted suggestion over the `@project` / `#facet` / `+group` being typed.
    private func completeSelection() {
        let plans = plans
        guard plans.indices.contains(selectionIndex), let name = plans[selectionIndex].completion else { return }
        text = query.completed(with: name)
    }

    private func create() {
        let plans = plans
        guard plans.indices.contains(selectionIndex) else {
            NSSound.beep()
            return
        }
        do {
            let created = try plans[selectionIndex].perform(using: repositories)
            onCreated(created.project)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
