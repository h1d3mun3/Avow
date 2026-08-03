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

extension ProjectGroup {
    /// Projects in this group that are not archived.
    var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }

    /// All time entries across this group's active projects.
    var allTimeEntries: [TimeEntry] {
        activeProjects.flatMap(\.allTimeEntries)
    }

    /// Total tracked duration across this group's active projects.
    var totalDuration: TimeInterval {
        allTimeEntries.totalDuration
    }
}

extension Facet {
    /// Tasks carrying this facet whose project exists and is not archived.
    ///
    /// Mirrors the app-wide convention (see `SidebarViewModel`/`OverviewViewModel`) of
    /// excluding archived projects from current aggregate totals, and (see
    /// `MenuBarViewModel.tasksByProject`) of dropping tasks with no project.
    var tasksInActiveProjects: [Task] {
        tasks.filter { $0.project.map { !$0.isArchived } ?? false }
    }

    /// All time entries across the tasks carrying this facet, excluding archived projects.
    var allTimeEntries: [TimeEntry] {
        tasksInActiveProjects.flatMap(\.timeEntries)
    }

    /// Total tracked duration across all tasks carrying this facet, excluding archived projects.
    var totalDuration: TimeInterval {
        allTimeEntries.totalDuration
    }
}
