import SwiftUI

struct TaskDetailRow: View {
    let task: Task
    var isCompleted: Bool = false
    var isSelected: Bool = false
    let onToggle: () -> Void
    var onSelect: () -> Void = {}
    var onDelete: (() -> Void)? = nil
    var onRename: (String) -> Void = { _ in }

    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showDeleteConfirmation = false
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
            .accessibilityLabel(isCompleted ? "Mark \(task.name) as active" : "Mark \(task.name) as completed")

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
            Divider()
            Button("Delete…", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .confirmationDialog(
            "Delete \"\(task.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Task", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("All time records for this task will be permanently deleted.")
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { onRename(trimmed) }
        isRenaming = false
        renameText = ""
    }
}
