import Foundation
import SwiftData

@Observable
final class OverviewViewModel {
    private(set) var projects: [Project] = []
    var quickStartFilter: String = ""

    private let clock: any AppClock

    init(clock: any AppClock = SystemClock()) {
        self.clock = clock
    }

    func update(projects: [Project]) {
        self.projects = projects
    }

    // MARK: - Derived state

    var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }

    private var activeEntries: [TimeEntry] {
        activeProjects.flatMap(\.allTimeEntries)
    }

    var totalDuration: TimeInterval {
        activeEntries.totalDuration
    }

    var thisWeekDuration: TimeInterval {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: clock.now())?.start ?? clock.now()
        return activeEntries
            .filter { $0.startDate >= startOfWeek }
            .totalDuration
    }

    var todayDuration: TimeInterval {
        let startOfDay = Calendar.current.startOfDay(for: clock.now())
        return activeEntries
            .filter { $0.startDate >= startOfDay }
            .totalDuration
    }

    var allActiveTasks: [Task] {
        activeProjects
            .flatMap(\.tasks)
            .filter { $0.status == .active }
    }

    var projectBreakdown: [(project: Project, duration: TimeInterval, fraction: Double)] {
        let total = totalDuration
        return activeProjects.map { (project: $0, duration: $0.totalDuration, fraction: total > 0 ? $0.totalDuration / total : 0) }
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
