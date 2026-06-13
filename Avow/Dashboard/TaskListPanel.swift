import SwiftUI

struct TaskListPanel: View {
    let viewModel: ProjectDetailViewModel
    @Binding var selectedTask: Task?
    @Binding var newTaskName: String

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
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !viewModel.activeTasks.isEmpty {
                            Text("Active tasks")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            ForEach(viewModel.activeTasks) { task in
                                TaskDetailRow(
                                    task: task,
                                    isSelected: selectedTask?.id == task.id,
                                    onToggle: { try? viewModel.toggleStatus(task) },
                                    onSelect: { selectedTask = task },
                                    onDelete: {
                                        if selectedTask?.id == task.id { selectedTask = nil }
                                        try? viewModel.delete(task)
                                    },
                                    onRename: { try? viewModel.rename(task, to: $0) }
                                )
                            }
                        }

                        if !viewModel.completedTasks.isEmpty {
                            Text("Completed")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.tertiary)

                            ForEach(viewModel.completedTasks) { task in
                                TaskDetailRow(
                                    task: task,
                                    isCompleted: true,
                                    isSelected: selectedTask?.id == task.id,
                                    onToggle: { try? viewModel.toggleStatus(task) },
                                    onSelect: { selectedTask = task },
                                    onDelete: {
                                        if selectedTask?.id == task.id { selectedTask = nil }
                                        try? viewModel.delete(task)
                                    },
                                    onRename: { try? viewModel.rename(task, to: $0) }
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private func addTask() {
        let name = newTaskName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        try? viewModel.addTask(named: name)
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
    }
}
