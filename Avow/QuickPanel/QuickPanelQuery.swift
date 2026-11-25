import Foundation

/// Parses the quick panel's search text. A `@` splits it into a task part and a project part
/// (`review notes @Avow`): the text before the first `@` is the task name / filter, everything
/// after it is a filter for the project the task should be created in. Factored out as plain
/// value logic so it can be tested without a running UI.
nonisolated struct QuickPanelQuery: Equatable {
    /// Trimmed text before the first `@` (the whole text when there is no `@`).
    let taskText: String
    /// Trimmed text after the first `@`, or nil when the text has no `@`.
    let projectText: String?

    init(_ raw: String) {
        let whitespace = CharacterSet.whitespacesAndNewlines
        if let at = raw.firstIndex(of: "@") {
            taskText = String(raw[..<at]).trimmingCharacters(in: whitespace)
            projectText = String(raw[raw.index(after: at)...]).trimmingCharacters(in: whitespace)
        } else {
            taskText = raw.trimmingCharacters(in: whitespace)
            projectText = nil
        }
    }

    /// True once the user has typed `@`, i.e. is choosing a project for a new task.
    var hasProjectClause: Bool { projectText != nil }

    /// Whether `projectName` matches the text typed after `@` (everything matches an empty one).
    func matches(projectName: String) -> Bool {
        guard let projectText, !projectText.isEmpty else { return true }
        return projectName.localizedCaseInsensitiveContains(projectText)
    }

    /// The project name to create when none matches exactly: the text typed after `@`, if any.
    var newProjectName: String? {
        guard let projectText, !projectText.isEmpty else { return nil }
        return projectText
    }

    /// Whether `projectName` is exactly the typed project text, ignoring case.
    func isSameProjectName(_ projectName: String) -> Bool {
        guard let newProjectName else { return false }
        return projectName.compare(newProjectName, options: .caseInsensitive) == .orderedSame
    }

    /// Whether `taskName` is exactly the typed task name, ignoring case — creating it would only
    /// duplicate an existing task, so no "create" row is offered.
    func isSameTaskName(_ taskName: String) -> Bool {
        !taskText.isEmpty && taskName.compare(taskText, options: .caseInsensitive) == .orderedSame
    }
}
