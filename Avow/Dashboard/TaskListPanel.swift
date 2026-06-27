import SwiftUI

struct TaskListPanel: View {
    let viewModel: ProjectDetailViewModel
    @Binding var selectedTaskID: Task.ID?
    @State private var errorMessage: String?
    @Environment(TimeRoundingSettings.self) private var roundingSettings

    /// Completed tasks start folded away to keep the focus on active work. Session-only
    /// by design — resets to collapsed when the view is rebuilt (e.g. switching projects).
    @State private var showCompleted = false

    /// Id of a freshly added task that should open in inline rename mode with the
    /// keyboard focus, so the user types its name right in the list. Cleared once
    /// the row has taken focus.
    @State private var editingNewTaskID: Task.ID?

    /// Per-task display durations, rounded together (active tasks then completed,
    /// matching display order) so every task row adds up to the "Total tracked" card.
    private var taskDisplayDurations: [Task.ID: TimeInterval] {
        let ordered = viewModel.activeTasks + viewModel.completedTasks
        let displayed = roundingSettings.display(ordered.map(\.totalDuration))
        return Dictionary(uniqueKeysWithValues: zip(ordered.map(\.id), displayed))
    }

    var body: some View {
        let displayDurations = taskDisplayDurations
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    ProjectSummaryCard(label: "Total tracked", value: roundingSettings.display(viewModel.totalDuration).shortFormatted)
                    ProjectSummaryCard(label: "This week", value: roundingSettings.display(viewModel.thisWeekDuration).shortFormatted)
                    ProjectSummaryCard(label: "Active tasks", value: "\(viewModel.activeTasks.count)")
                }
            }
            .padding(20)

            Divider()

            // A real List(selection:) so keyboard focus lives with the tasks:
            // arrow keys move between rows (across the Active and Completed
            // groups) instead of leaking to the sidebar's project list.
            List(selection: $selectedTaskID) {
                // Always show the Active tasks section so the heading — and its
                // "+" add button — stay put even when there are no active tasks
                // (or no tasks at all). An empty placeholder keeps the absence
                // of active work explicit.
                Section {
                    if viewModel.activeTasks.isEmpty {
                        emptyActiveTasksRow
                    } else {
                        ForEach(viewModel.activeTasks) { task in
                            taskRow(task, isCompleted: false, displayDuration: displayDurations[task.id])
                        }
                    }
                } header: {
                    activeTasksHeader
                }

                if !viewModel.completedTasks.isEmpty {
                    Section {
                        completedHeader

                        if showCompleted {
                            ForEach(viewModel.completedTasks) { task in
                                taskRow(task, isCompleted: true, displayDuration: displayDurations[task.id])
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
        .errorAlert($errorMessage)
    }

    /// Placeholder shown under the Active tasks header when no task is active,
    /// so the section never collapses out of view. Carries no selection tag,
    /// so List arrow navigation skips it.
    private var emptyActiveTasksRow: some View {
        Text("No active tasks")
            .font(.subheadline)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowSeparator(.hidden)
            .accessibilityLabel("No active tasks")
    }

    /// Active tasks header carrying the "+" button: tapping it creates a blank
    /// task and drops the keyboard focus into its row for inline naming.
    private var activeTasksHeader: some View {
        HStack(spacing: 6) {
            sectionHeader("Active tasks")
            Spacer()
            Button(action: addTask) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Add task")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }

    /// Collapsible disclosure for the Completed group. It carries no selection
    /// tag, so List arrow navigation skips it; when collapsed the rows below are
    /// absent from the tree, so they are unreachable by keyboard too.
    private var completedHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { showCompleted.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .rotationEffect(.degrees(showCompleted ? 90 : 0))
                Text("Completed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(viewModel.completedTasks.count)")
                    .font(.caption)
                    .monospacedDigit()
                Spacer()
            }
            .foregroundStyle(.tertiary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .accessibilityLabel("Completed, \(viewModel.completedTasks.count) tasks")
        .accessibilityValue(showCompleted ? "Expanded" : "Collapsed")
        .accessibilityHint("Double tap to \(showCompleted ? "collapse" : "expand")")
    }

    private func taskRow(_ task: Task, isCompleted: Bool, displayDuration: TimeInterval?) -> some View {
        TaskDetailRow(
            task: task,
            isCompleted: isCompleted,
            displayDuration: displayDuration,
            beginInEditMode: task.id == editingNewTaskID,
            onBeginEdit: { editingNewTaskID = nil },
            onToggle: { do { try viewModel.toggleStatus(task) } catch { errorMessage = error.localizedDescription } },
            onDelete: {
                if selectedTaskID == task.id { selectedTaskID = nil }
                do { try viewModel.delete(task) } catch { errorMessage = error.localizedDescription }
            },
            onRename: { do { try viewModel.rename(task, to: $0) } catch { errorMessage = error.localizedDescription } }
        )
        .listRowSeparator(.hidden)
        .tag(task.id)
    }

    /// Adds a blank task and hands keyboard focus to its row so the user types
    /// the name inline. A task left unnamed is discarded by the row itself.
    private func addTask() {
        do {
            let task = try viewModel.addTask()
            editingNewTaskID = task.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ProjectSummaryCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
