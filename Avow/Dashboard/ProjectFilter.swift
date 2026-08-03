import Foundation

/// Which projects' entries are visible in the Calendar tab. `nil` means no
/// filter is applied — every project (including ones created later) is shown.
struct ProjectFilter: Equatable {
    var selectedIDs: Set<UUID>?

    static let all = ProjectFilter(selectedIDs: nil)

    func includes(_ project: Project?) -> Bool {
        guard let selectedIDs else { return true }
        guard let project else { return false }
        return selectedIDs.contains(project.id)
    }
}

extension Sequence where Element == TimeEntry {
    /// Entries whose task's project is included by `filter`.
    func filtered(by filter: ProjectFilter) -> [TimeEntry] {
        guard filter.selectedIDs != nil else { return Array(self) }
        return self.filter { filter.includes($0.task?.project) }
    }
}
