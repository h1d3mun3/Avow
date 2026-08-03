import Foundation

protocol ProjectGroupRepository {
    /// All project groups, sorted by name.
    func allProjectGroupsSortedByName() throws -> [ProjectGroup]
    /// Returns the project group with this name, creating and persisting it if none exists.
    func findOrCreate(named name: String) throws -> ProjectGroup
    /// Renames the project group. No-op for an empty or unchanged name; throws if another group already carries the name.
    func rename(_ group: ProjectGroup, to name: String) throws
    /// Attaches the group to the project (no-op if already attached).
    func attach(_ group: ProjectGroup, to project: Project) throws
    /// Detaches the group from the project (no-op if not attached).
    func detach(_ group: ProjectGroup, from project: Project) throws
    /// Deletes the project group, removing it from every project that carries it.
    func delete(_ group: ProjectGroup) throws
}

enum ProjectGroupRepositoryError: LocalizedError {
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .duplicateName(let name):
            return "A project group named \"\(name)\" already exists."
        }
    }
}
