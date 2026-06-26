import SwiftUI

struct TaskListPanel: View {
    let viewModel: ProjectDetailViewModel
    @Binding var selectedTaskID: Task.ID?
    @Binding var newTaskName: String
    @State private var errorMessage: String?
    /// Completed tasks start folded away to keep the focus on active work. Session-only
    /// by design — resets to collapsed when the view is rebuilt (e.g. switching projects).
    @State private var showCompleted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    ProjectSummaryCard(label: "Total tracked", value: viewModel.totalDuration.shortFormatted)
                    ProjectSummaryCard(label: "This week", value: viewModel.thisWeekDuration.shortFormatted)
                    ProjectSummaryCard(label: "Active tasks", value: "\(viewModel.activeTasks.count)")
                }
                HStack {
                    TextField("New task name…", text: $newTaskName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addTask() }
                    Button("Add") { addTask() }
                        .disabled(newTaskName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)

            Divider()

            if !viewModel.hasTasks {
                ContentUnavailableView(
                    "No tasks yet",
                    systemImage: "checklist",
                    description: Text("Add a task above to start tracking.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // A real List(selection:) so keyboard focus lives with the tasks:
                // arrow keys move between rows (across the Active and Completed
                // groups) instead of leaking to the sidebar's project list.
                List(selection: $selectedTaskID) {
                    if !viewModel.activeTasks.isEmpty {
                        Section {
                            ForEach(viewModel.activeTasks) { task in
                                taskRow(task, isCompleted: false)
                            }
                        } header: {
                            sectionHeader("Active tasks")
                        }
                    }

                    if !viewModel.completedTasks.isEmpty {
                        Section {
                            completedHeader

                            if showCompleted {
                                ForEach(viewModel.completedTasks) { task in
                                    taskRow(task, isCompleted: true)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .errorAlert($errorMessage)
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

    private func taskRow(_ task: Task, isCompleted: Bool) -> some View {
        TaskDetailRow(
            task: task,
            isCompleted: isCompleted,
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

    private func addTask() {
        let name = newTaskName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do { try viewModel.addTask(named: name) } catch { errorMessage = error.localizedDescription }
        newTaskName = ""
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
