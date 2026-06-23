import Foundation

/// Keyboard selection math for the quick panel's task list, factored out so it can be tested
/// without a running UI.
nonisolated enum QuickPanelSelection {
    /// Moves the highlighted index by `delta`, clamped to `[0, count - 1]`.
    /// Returns 0 when the list is empty.
    static func moved(from index: Int, by delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index + delta, 0), count - 1)
    }
}
