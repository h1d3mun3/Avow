import SwiftUI
import SwiftData

@Observable
final class SidebarViewModel {
    private(set) var projects: [Project] = []
    private let projectRepository: any ProjectRepository

    init(projectRepository: any ProjectRepository) {
        self.projectRepository = projectRepository
    }

    func update(projects: [Project]) {
        self.projects = projects
    }

    // MARK: - Derived state

    var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }

    var archivedProjects: [Project] {
        projects.filter { $0.isArchived }.sorted { $0.name < $1.name }
    }

    // MARK: - Mutations

    func move(from source: IndexSet, to destination: Int) throws {
        var reordered = activeProjects
        reordered.move(fromOffsets: source, toOffset: destination)
        try projectRepository.reorder(reordered)
    }

    func commitRename(_ project: Project, to rawText: String) throws {
        let trimmed = rawText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try projectRepository.rename(project, to: trimmed)
    }
}
