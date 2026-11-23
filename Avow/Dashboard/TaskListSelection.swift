import Foundation

/// Selection math for the project detail's task list, factored out so it can be tested without a
/// running UI.
nonisolated enum TaskListSelection {
    /// Which row to select once `toggled` has been completed or reopened (and so jumps to the other
    /// section, often out of sight): the row below it, else the one above, else nothing. `ids` is
    /// the visible rows in display order, taken before the toggle.
    static func neighbor<ID: Equatable>(of toggled: ID, in ids: [ID]) -> ID? {
        guard let index = ids.firstIndex(of: toggled) else { return nil }
        if ids.indices.contains(index + 1) { return ids[index + 1] }
        if index > 0 { return ids[index - 1] }
        return nil
    }
}
