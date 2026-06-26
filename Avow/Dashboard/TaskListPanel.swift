import SwiftUI

struct TaskListPanel: View {
    let viewModel: ProjectDetailViewModel
    @Binding var selectedTask: Task?
    @Binding var newTaskName: String
    @State private var errorMessage: String?
    @Environment(TimeRoundingSettings.self) private var roundingSettings

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
                                    displayDuration: displayDurations[task.id],
                                    onToggle: { do { try viewModel.toggleStatus(task) } catch { errorMessage = error.localizedDescription } },
                                    onSelect: { selectedTask = task },
                                    onDelete: {
                                        if selectedTask?.id == task.id { selectedTask = nil }
                                        do { try viewModel.delete(task) } catch { errorMessage = error.localizedDescription }
                                    },
                                    onRename: { do { try viewModel.rename(task, to: $0) } catch { errorMessage = error.localizedDescription } }
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
                                    displayDuration: displayDurations[task.id],
                                    onToggle: { do { try viewModel.toggleStatus(task) } catch { errorMessage = error.localizedDescription } },
                                    onSelect: { selectedTask = task },
                                    onDelete: {
                                        if selectedTask?.id == task.id { selectedTask = nil }
                                        do { try viewModel.delete(task) } catch { errorMessage = error.localizedDescription }
                                    },
                                    onRename: { do { try viewModel.rename(task, to: $0) } catch { errorMessage = error.localizedDescription } }
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .errorAlert($errorMessage)
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
