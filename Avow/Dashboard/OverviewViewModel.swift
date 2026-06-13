import Foundation
import SwiftData

@Observable
final class OverviewViewModel {
    private(set) var projects: [Project] = []
    var quickStartFilter: String = ""

    func update(projects: [Project]) {
        self.projects = projects
    }

    // MARK: - Derived state

    var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }

    private var activeEntries: [TimeEntry] {
        activeProjects.flatMap(\.tasks).flatMap(\.timeEntries)
    }

    var totalDuration: TimeInterval {
        activeEntries.reduce(0.0) { $0 + $1.duration }
    }

    var thisWeekDuration: TimeInterval {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return activeEntries
            .filter { $0.startDate >= startOfWeek }
            .reduce(0.0) { $0 + $1.duration }
    }

    var todayDuration: TimeInterval {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return activeEntries
            .filter { $0.startDate >= startOfDay }
            .reduce(0.0) { $0 + $1.duration }
    }

    var allActiveTasks: [Task] {
        activeProjects
            .flatMap(\.tasks)
            .filter { $0.status == .active }
    }

    var quickStartTasks: [Task] {
        quickStartFilter.isEmpty ? recentTasks : searchResults
    }

    // MARK: - Private helpers

    private var recentTasks: [Task] {
        Array(
            allActiveTasks
                .sorted { a, b in
                    let aDate = a.timeEntries.map(\.startDate).max() ?? .distantPast
                    let bDate = b.timeEntries.map(\.startDate).max() ?? .distantPast
                    return aDate > bDate
                }
                .prefix(5)
        )
    }

    private var searchResults: [Task] {
        allActiveTasks
            .filter { $0.name.localizedCaseInsensitiveContains(quickStartFilter) }
            .sorted { $0.name < $1.name }
    }
}
