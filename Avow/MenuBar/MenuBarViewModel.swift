import Foundation
import SwiftData

@Observable
final class MenuBarViewModel {
    private(set) var tasks: [Task] = []
    var filterText: String = ""
    func update(tasks: [Task]) { self.tasks = tasks }

    private var activeTasks: [Task] { tasks.filter { $0.status == .active } }
    var filteredTasks: [Task] {
        filterText.isEmpty ? activeTasks
            : activeTasks.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
    }
    var tasksByProject: [(project: Project, tasks: [Task])] {
        let grouped = Dictionary(grouping: filteredTasks) { $0.project }
        return grouped.compactMap { project, tasks -> (Project, [Task])? in
            guard let project else { return nil }
            return (project, tasks.sorted { $0.name < $1.name })
        }.sorted { $0.0.name < $1.0.name }
    }
}
