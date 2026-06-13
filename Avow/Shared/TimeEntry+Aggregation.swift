import Foundation

extension Sequence where Element == TimeEntry {
    /// Total tracked duration across the entries.
    var totalDuration: TimeInterval {
        reduce(0) { $0 + $1.duration }
    }
}

extension Project {
    /// All time entries across this project's tasks.
    var allTimeEntries: [TimeEntry] {
        tasks.flatMap(\.timeEntries)
    }

    /// Total tracked duration across all of this project's tasks.
    var totalDuration: TimeInterval {
        allTimeEntries.totalDuration
    }
}

extension Task {
    /// Total tracked duration across this task's time entries.
    var totalDuration: TimeInterval {
        timeEntries.totalDuration
    }
}
