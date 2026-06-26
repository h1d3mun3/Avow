import SwiftUI

struct TaskDetailRow: View {
    let task: Task
    var isCompleted: Bool = false
    let onToggle: () -> Void
    var onDelete: (() -> Void)? = nil
    var onRename: (String) -> Void = { _ in }

    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showDeleteConfirmation = false
    @State private var showFacetPicker = false
    @FocusState private var fieldFocused: Bool

    private var taskDuration: TimeInterval {
        task.totalDuration
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.name)
                        .font(.subheadline)
                        .strikethrough(isCompleted)
                        .foregroundStyle(isCompleted ? .secondary : .primary)

                    if !task.facets.isEmpty {
                        Text(task.facets.map(\.name).sorted().joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(taskDuration.shortFormatted)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // Selection highlight is now owned by the enclosing List(selection:);
        // this only keeps the faint tint that sets completed rows apart.
        .background(
            .quaternary.opacity(isCompleted ? 0.2 : 0.0),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button("Rename") {
                isRenaming = true
                renameText = task.name
                fieldFocused = true
            }
            Button("Facets…") {
                showFacetPicker = true
            }
            Divider()
            Button("Delete…", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .popover(isPresented: $showFacetPicker) {
            FacetPicker(task: task)
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
