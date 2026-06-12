import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var newTaskName = ""
    @State private var selectedTask: Task?

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
        HStack(spacing: 0) {
            taskListPanel
            if let task = selectedTask {
                Divider()
                timeEntryPanel(for: task)
            }
        }
        .navigationTitle(project.name)
    }

    // MARK: - Left panel

    private var taskListPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary cards
                HStack(spacing: 12) {
                    SummaryCard(label: "Total tracked", value: totalDuration.shortFormatted)
                    SummaryCard(label: "This week", value: thisWeekDuration.shortFormatted)
                    SummaryCard(label: "Active tasks", value: "\(activeTasks.count)")
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
                        TaskDetailRow(
                            task: task,
                            isSelected: selectedTask?.id == task.id,
                            onToggle: {
                                task.status = .completed
                                task.updatedAt = .now
                                try? modelContext.save()
                            },
                            onSelect: { selectedTask = task }
                        )
                    }
                }

                // Completed tasks
                if !completedTasks.isEmpty {
                    Text("Completed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)

                    ForEach(completedTasks) { task in
                        TaskDetailRow(
                            task: task,
                            isCompleted: true,
                            isSelected: selectedTask?.id == task.id,
                            onToggle: {
                                task.status = .active
                                task.updatedAt = .now
                                try? modelContext.save()
                            },
                            onSelect: { selectedTask = task }
                        )
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
    }

    // MARK: - Right panel

    private func timeEntryPanel(for task: Task) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(task.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button {
                    selectedTask = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Entries
            let entries = task.timeEntries.sorted { $0.startDate > $1.startDate }
            if entries.isEmpty {
                VStack {
                    Spacer()
                    ContentUnavailableView(
                        "No records",
                        systemImage: "clock",
                        description: Text("Start tracking this task to create records.")
                    )
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(entries) { entry in
                            TimeEntryRow(entry: entry)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(minWidth: 260, maxWidth: .infinity)
    }

    // MARK: - Helpers

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

// MARK: - Task row

private struct TaskDetailRow: View {
    let task: Task
    var isCompleted: Bool = false
    var isSelected: Bool = false
    let onToggle: () -> Void
    var onSelect: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var fieldFocused: Bool

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

            if isRenaming {
                TextField("", text: $renameText)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onSubmit { commitRename() }
                    .onExitCommand { isRenaming = false }
            } else {
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? AnyShapeStyle(Color.accentColor.opacity(0.12))
                : AnyShapeStyle(.quaternary.opacity(isCompleted ? 0.2 : 0.0)),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Rename") {
                isRenaming = true
                renameText = task.name
                fieldFocused = true
            }
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            task.name = trimmed
            task.updatedAt = .now
            try? modelContext.save()
        }
        isRenaming = false
        renameText = ""
    }
}

