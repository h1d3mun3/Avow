import SwiftUI

struct TaskDetailRow: View {
    let task: Task
    var isCompleted: Bool = false
    /// Pre-rounded duration to show, supplied by the parent so the task rows add up
    /// to the project total. Falls back to the task's own total when not provided.
    var displayDuration: TimeInterval? = nil
    /// When true, the row opens directly in rename mode with the keyboard focus —
    /// used for a freshly added blank task so the user names it inline.
    var beginInEditMode: Bool = false
    /// Called once the row has entered edit mode, so the parent can drop the
    /// "new task" flag and avoid re-triggering on later reappearances.
    var onBeginEdit: () -> Void = {}
    let onToggle: () -> Void
    var onDelete: (() -> Void)? = nil
    var onRename: (String) -> Void = { _ in }

    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showDeleteConfirmation = false
    @State private var showFacetPicker = false
    @FocusState private var fieldFocused: Bool

    private var taskDuration: TimeInterval {
        displayDuration ?? task.totalDuration
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
                TextField("Task name…", text: $renameText)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onSubmit { commitRename() }
                    .onExitCommand { cancelRename() }
                    .onChange(of: fieldFocused) { _, focused in
                        // Clicking away commits, mirroring how new-item naming
                        // works elsewhere; an empty new task is then discarded.
                        if !focused, isRenaming { commitRename() }
                    }
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
        .onAppear { if beginInEditMode { startEditing() } }
    }

    /// Opens the row's inline editor and grabs the keyboard focus. Focus is set
    /// asynchronously so it lands after the TextField has been inserted.
    private func startEditing() {
        guard !isRenaming else { return }
        isRenaming = true
        renameText = task.name
        DispatchQueue.main.async { fieldFocused = true }
        onBeginEdit()
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // A brand-new task left blank is discarded rather than kept nameless.
            if task.name.isEmpty { onDelete?() }
        } else {
            onRename(trimmed)
        }
        isRenaming = false
        renameText = ""
    }

    private func cancelRename() {
        // Escaping out of a never-named task discards it too.
        if task.name.isEmpty { onDelete?() }
        isRenaming = false
        renameText = ""
    }
}
