import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var newTaskName = ""

    private var activeTasks: [Task] {
        project.tasks
            .filter { $0.status == .active }
            .sorted { $0.name < $1.name }
    }

    private var completedTasks: [Task] {
        project.tasks
            .filter { $0.status == .completed }
            .sorted { $0.name < $1.name }
    }

    private var totalDuration: TimeInterval {
        project.tasks
            .flatMap(\.timeEntries)
            .reduce(0.0) { $0 + $1.duration }
    }

    private var thisWeekDuration: TimeInterval {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return project.tasks
            .flatMap(\.timeEntries)
            .filter { $0.startDate >= startOfWeek }
            .reduce(0.0) { $0 + $1.duration }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary cards
                HStack(spacing: 12) {
                    SummaryCard(
                        label: "Total tracked",
                        value: totalDuration.shortFormatted,
                        color: Color(hex: project.colorHex)
                    )
                    SummaryCard(
                        label: "This week",
                        value: thisWeekDuration.shortFormatted,
                        color: Color(hex: project.colorHex)
                    )
                    SummaryCard(
                        label: "Active tasks",
                        value: "\(activeTasks.count)",
                        color: Color(hex: project.colorHex)
                    )
                }

                // Add task
                HStack {
                    TextField("New task name…", text: $newTaskName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addTask() }
                    Button("Add") { addTask() }
                        .disabled(newTaskName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // Active tasks
                if !activeTasks.isEmpty {
                    Text("Active tasks")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ForEach(activeTasks) { task in
                        TaskDetailRow(task: task) {
                            task.status = .completed
                            task.updatedAt = .now
                            try? modelContext.save()
                        }
                    }
                }

                // Completed tasks
                if !completedTasks.isEmpty {
                    Text("Completed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)

                    ForEach(completedTasks) { task in
                        TaskDetailRow(task: task, isCompleted: true) {
                            task.status = .active
                            task.updatedAt = .now
                            try? modelContext.save()
                        }
                    }
                }

                if project.tasks.isEmpty {
                    ContentUnavailableView(
                        "No tasks yet",
                        systemImage: "checklist",
                        description: Text("Add a task above to start tracking.")
                    )
                }
            }
            .padding(20)
        }
        .navigationTitle(project.name)
    }

    private func addTask() {
        let name = newTaskName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let task = Task(name: name, project: project)
        modelContext.insert(task)
        try? modelContext.save()
        newTaskName = ""
    }
}

// MARK: - Summary card

private struct SummaryCard: View {
    let label: String
    let value: String
    let color: Color

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
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Task row

private struct TaskDetailRow: View {
    let task: Task
    var isCompleted: Bool = false
    let onToggle: () -> Void

    private var taskDuration: TimeInterval {
        task.timeEntries.reduce(0.0) { $0 + $1.duration }
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .secondary : .primary)
            }
            .buttonStyle(.plain)

            Text(task.name)
                .font(.subheadline)
                .strikethrough(isCompleted)
                .foregroundStyle(isCompleted ? .secondary : .primary)

            Spacer()

            Text(taskDuration.shortFormatted)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(isCompleted ? 0.2 : 0.0), in: RoundedRectangle(cornerRadius: 8))
    }
}
